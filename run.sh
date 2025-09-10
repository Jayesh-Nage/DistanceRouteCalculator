#!/bin/bash

# OSRM Distance Route Calculator - Complete Setup Script
# For Ubuntu AWS Instance with 64GB RAM
# This script sets up everything needed for US-wide routing

set -e  # Exit on any error

echo "🚀 OSRM Distance Route Calculator Setup"
echo "========================================"
echo "Target: Ubuntu AWS Instance (64GB RAM)"
echo "Coverage: Entire US Region"
echo "Start time: $(date)"
echo "Process ID: $$"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_progress() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }

check_memory() {
    local available_memory=$(free -g | awk '/^Mem:/{print $7}')
    local used_memory=$(free -g | awk '/^Mem:/{print $3}')
    local total_memory=$(free -g | awk '/^Mem:/{print $2}')
    print_progress "Memory: ${used_memory}GB used, ${available_memory}GB available, ${total_memory}GB total"
    
    if [ "$available_memory" -lt 5 ]; then
        print_warning "CRITICAL: Only ${available_memory}GB memory available! Process may fail."
        return 1
    elif [ "$available_memory" -lt 10 ]; then
        print_warning "WARNING: Low memory (${available_memory}GB available). Monitor closely."
    fi
    return 0
}

show_system_resources() {
    print_progress "=== SYSTEM RESOURCES ==="
    check_memory
    local disk_usage=$(df -h . | tail -1 | awk '{print $5}')
    print_progress "Disk usage: $disk_usage"
    local cpu_load=$(uptime | awk -F'load average:' '{print $2}')
    print_progress "CPU load:$cpu_load"
    local docker_processes=$(ps aux | grep docker | wc -l)
    print_progress "Docker processes: $docker_processes"
    print_progress "========================"
}

if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root"
   exit 1
fi

TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
if [ $TOTAL_MEM -lt 32 ]; then
    print_warning "System has ${TOTAL_MEM}GB RAM. Recommended: 32GB+ for US dataset"
    print_warning "Proceeding anyway, but may encounter memory issues..."
fi
print_status "System has ${TOTAL_MEM}GB RAM"

print_status "Updating system packages..."
sudo apt-get update -y
sudo apt-get upgrade -y

print_status "Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    print_success "Docker installed successfully"
else
    print_success "Docker already installed"
fi

if ! groups $USER | grep -q '\bdocker\b'; then
    print_warning "User not in docker group. Adding user..."
    sudo usermod -aG docker $USER
    print_warning "Please logout/login again or run: newgrp docker"
    exit 1
fi

print_status "Testing Docker permissions..."
if ! docker ps &> /dev/null; then
    print_warning "Docker requires sudo. Using sudo..."
    DOCKER_CMD="sudo docker"
else
    print_success "Docker works without sudo"
    DOCKER_CMD="docker"
fi

print_status "Cleaning up existing Docker containers..."
$DOCKER_CMD stop $($DOCKER_CMD ps -q) 2>/dev/null || true
$DOCKER_CMD rm $($DOCKER_CMD ps -aq) 2>/dev/null || true
print_success "Docker cleanup completed"

print_status "Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    print_success "Docker Compose installed successfully"
else
    print_success "Docker Compose already installed"
fi

print_status "Installing Python 3.11 and pip..."
sudo apt-get install -y software-properties-common
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt-get update -y
sudo apt-get install -y python3.11 python3.11-venv python3.11-dev python3-pip

print_status "Creating Python virtual environment..."
python3.11 -m venv venv
source venv/bin/activate
pip install --upgrade pip
print_success "Python 3.11 and virtual environment ready"

print_status "Installing Python dependencies..."
pip install -r requirements.txt
print_success "Python dependencies installed"

print_status "Setting up OSRM data directory..."
mkdir -p osrm-data
PROJECT_ROOT="$PWD"
cd osrm-data

# Step 6: Ensure US PBF exists
if [ -f "us-latest.osm.pbf" ]; then
    FILE_SIZE=$(du -h us-latest.osm.pbf | cut -f1)
    print_success "Using existing US map data (${FILE_SIZE})"
else
    print_status "Downloading US map data..."
    wget -O us-latest.osm.pbf http://download.geofabrik.de/north-america/us-latest.osm.pbf
fi

# Step 7: OSRM Processing
if ls us-latest.osrm.cnbg* >/dev/null 2>&1; then
    print_success "OSRM extraction files already exist — skipping extraction"
    SKIP_EXTRACTION=true
else
    print_status "No extraction files found — running full extraction"
    SKIP_EXTRACTION=false
fi

# Run extraction if needed
if [ "$SKIP_EXTRACTION" = "false" ]; then
    print_progress "Running extraction..."
    $DOCKER_CMD run -t -v "$PWD:/data" -v "$PWD/../truck.lua:/opt/truck.lua" \
        ghcr.io/project-osrm/osrm-backend osrm-extract \
        -p /opt/truck.lua /data/us-latest.osm.pbf --threads 4
    print_success "Extraction completed"
fi

# Always run partition + customize
print_progress "Step 1/2: Partitioning data..."
$DOCKER_CMD run -t -v "$PWD:/data" ghcr.io/project-osrm/osrm-backend \
    osrm-partition /data/us-latest.osrm --threads 4
print_success "Partition completed"

print_progress "Step 2/2: Customizing data..."
$DOCKER_CMD run -t -v "$PWD:/data" ghcr.io/project-osrm/osrm-backend \
    osrm-customize /data/us-latest.osrm --threads 4
print_success "Customize completed"

print_success "OSRM processing completed successfully!"

# Step 8: Start OSRM Server
print_status "Starting OSRM Server with US map data..."
$DOCKER_CMD run -d --name osrm-us-server \
    -p 0.0.0.0:5001:5000 \
    -v "$PWD:/data" \
    ghcr.io/project-osrm/osrm-backend \
    osrm-routed --algorithm mld /data/us-latest.osrm

print_success "OSRM Server started on port 5001"
