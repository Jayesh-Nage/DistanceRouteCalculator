#!/bin/bash

# OSRM Distance Route Calculator - Texas Setup Script
# For Ubuntu AWS Instance with 64GB RAM
# This script sets up everything needed for Texas routing

set -e  # Exit on any error

echo "🚀 OSRM Distance Route Calculator Setup"
echo "========================================"
echo "Target: Ubuntu AWS Instance (64GB RAM)"
echo "Coverage: Texas"
echo "Start time: $(date)"
echo "Process ID: $$"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions for colored output
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_progress() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }

# Function to check memory usage
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

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root"
   exit 1
fi

# Check available memory
TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
if [ $TOTAL_MEM -lt 32 ]; then
    print_warning "System has ${TOTAL_MEM}GB RAM. Recommended: 32GB+ for large maps"
    print_warning "Proceeding anyway, but may encounter memory issues..."
fi

print_status "System has ${TOTAL_MEM}GB RAM"

# Step 1: Update system packages
print_status "Updating system packages..."
sudo apt-get update -y
sudo apt-get upgrade -y

# Step 2: Install Docker
print_status "Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    print_success "Docker installed successfully"
    print_warning "You may need to logout/login for Docker group changes to take effect"
else
    print_success "Docker already installed"
fi

# Check if user is in docker group
if ! groups $USER | grep -q '\bdocker\b'; then
    print_warning "User not in docker group. Adding user to docker group..."
    sudo usermod -aG docker $USER
    print_warning "Please logout/login again, or run: newgrp docker"
    print_warning "Then run this script again."
    exit 1
fi

# Test Docker without sudo
print_status "Testing Docker permissions..."
if ! docker ps &> /dev/null; then
    print_warning "Docker requires sudo. Using sudo for Docker commands..."
    DOCKER_CMD="sudo docker"
else
    print_success "Docker works without sudo"
    DOCKER_CMD="docker"
fi

# Clean up existing Docker containers
print_status "Cleaning up existing Docker containers..."
$DOCKER_CMD stop $($DOCKER_CMD ps -q) 2>/dev/null || true
$DOCKER_CMD rm $($DOCKER_CMD ps -aq) 2>/dev/null || true

# Specifically clean up OSRM containers
print_status "Cleaning up OSRM containers..."
$DOCKER_CMD ps -q --filter "name=osrm" | xargs -r $DOCKER_CMD stop 2>/dev/null || true
$DOCKER_CMD ps -aq --filter "name=osrm" | xargs -r $DOCKER_CMD rm 2>/dev/null || true
print_success "Docker cleanup completed"

# Step 3: Install Docker Compose
print_status "Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    print_success "Docker Compose installed successfully"
else
    print_success "Docker Compose already installed"
fi

# Step 4: Install Python 3.11 and pip
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

# Step 5: Install Python dependencies
print_status "Installing Python dependencies..."
pip install -r requirements.txt
print_success "Python dependencies installed"

# Step 6: Download Texas map
print_status "Setting up OSRM data directory..."
mkdir -p osrm-data
PROJECT_ROOT="$PWD"
cd osrm-data

TEXAS_PBF="texas-latest.osm.pbf"
if [ -f "$TEXAS_PBF" ]; then
    FILE_SIZE=$(du -h $TEXAS_PBF | cut -f1)
    print_warning "Texas map data already exists (${FILE_SIZE})"
    print_status "File: $TEXAS_PBF"
    
    if [ -t 0 ]; then
        echo ""
        read -p "Do you want to re-download Texas map data? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "Re-downloading Texas map data..."
            wget -O $TEXAS_PBF http://download.geofabrik.de/north-america/us/texas-latest.osm.pbf
        else
            print_success "Using existing Texas map data (${FILE_SIZE})"
        fi
    else
        print_success "Using existing Texas map data (${FILE_SIZE})"
    fi
else
    print_status "Downloading Texas map data..."
    wget -O $TEXAS_PBF http://download.geofabrik.de/north-america/us/texas-latest.osm.pbf
    if [ -f "$TEXAS_PBF" ]; then
        FILE_SIZE=$(du -h $TEXAS_PBF | cut -f1)
        print_success "Texas map data downloaded successfully (${FILE_SIZE})"
    else
        print_error "Failed to download Texas map data"
        exit 1
    fi
fi

# Step 7: OSRM Processing (Extract, Partition, Customize)
if [ -f "texas-latest.osrm" ]; then
    print_warning "OSRM processed files already exist"
    SKIP_PROCESSING=true
else
    print_status "Starting OSRM processing..."
    SKIP_PROCESSING=false
fi

if [ "$SKIP_PROCESSING" != "true" ]; then
    # Determine threads based on memory
    AVAILABLE_MEMORY=$(free -g | awk '/^Mem:/{print $7}')
    THREADS=4
    if [ "$AVAILABLE_MEMORY" -lt 25 ]; then
        print_warning "Low memory detected (${AVAILABLE_MEMORY}GB). Using 2 threads"
        THREADS=2
    fi

    print_progress "Extracting with truck.lua profile..."
    $DOCKER_CMD run -t -v "$PWD:/data" -v "$PWD/../truck.lua:/opt/truck.lua" ghcr.io/project-osrm/osrm-backend osrm-extract -p /opt/truck.lua /data/$TEXAS_PBF --threads $THREADS

    print_progress "Partitioning data..."
    $DOCKER_CMD run -t -v "$PWD:/data" ghcr.io/project-osrm/osrm-backend osrm-partition /data/texas-latest.osrm --threads $THREADS

    print_progress "Customizing data..."
    $DOCKER_CMD run -t -v "$PWD:/data" ghcr.io/project-osrm/osrm-backend osrm-customize /data/texas-latest.osrm --threads $THREADS

    print_success "OSRM processing completed successfully!"
fi

# Step 8: Start OSRM Server
print_status "Starting OSRM Server for Texas..."
$DOCKER_CMD run -d --name osrm-texas-server -p 0.0.0.0:5001:5000 -v "$PWD:/data" ghcr.io/project-osrm/osrm-backend osrm-routed --algorithm mld /data/texas-latest.osrm

print_success "OSRM Server started successfully on port 5001"

# Step 9: Test server
print_status "Testing OSRM server..."
TEST_COORDS="-95.3698,29.7604;-96.7970,32.7767"  # Houston to Dallas example
RESPONSE=$(curl -s --max-time 30 "http://localhost:5001/route/v1/driving/${TEST_COORDS}?overview=false&annotations=distance,duration")

if echo "$RESPONSE" | grep -q '"code":"Ok"'; then
    DISTANCE=$(echo "$RESPONSE" | jq -r '.routes[0].distance')
    DURATION=$(echo "$RESPONSE" | jq -r '.routes[0].duration')
    print_success "Server test successful: ${DISTANCE}m distance, ${DURATION}s duration"
else
    print_error "Server test failed"
    print_error "Response: $RESPONSE"
    exit 1
fi

# Python integration test
print_status "Testing Python integration..."
cd ..
source venv/bin/activate

python3 -c "
from route_calculator import create_movers_route_analyzer
analyzer = create_movers_route_analyzer('http://localhost:5001')
source = (-95.3698, 29.7604)  # Houston
destination = (-96.7970, 32.7767)  # Dallas
routes = analyzer.get_routes(source, destination, alternatives=1)
print(f'✅ Python test successful: {routes.routes[0].distance_km:.1f}km route found')
"

print_success "Python integration test successful!"
print_success "Setup completed successfully!"
