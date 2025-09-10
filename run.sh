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

# Step 0: Ensure user is not root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root"
   exit 1
fi

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
    print_warning "Logout/login required for Docker group changes"
fi

# Step 3: Test Docker
DOCKER_CMD="docker"
if ! docker ps &> /dev/null; then
    print_warning "Docker requires sudo. Using sudo for Docker commands..."
    DOCKER_CMD="sudo docker"
else
    print_success "Docker works without sudo"
fi

# Step 4: Clean previous OSRM containers
print_status "Cleaning up existing OSRM containers..."
$DOCKER_CMD stop $($DOCKER_CMD ps -q) 2>/dev/null || true
$DOCKER_CMD rm $($DOCKER_CMD ps -aq) 2>/dev/null || true
$DOCKER_CMD ps -q --filter "name=osrm" | xargs -r $DOCKER_CMD stop 2>/dev/null || true
$DOCKER_CMD ps -aq --filter "name=osrm" | xargs -r $DOCKER_CMD rm 2>/dev/null || true
print_success "Docker cleanup completed"

# Step 5: Install Docker Compose
print_status "Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    print_success "Docker Compose installed successfully"
else
    print_success "Docker Compose already installed"
fi

# Step 6: Install Python 3.11 and pip
print_status "Installing Python 3.11..."
sudo apt-get install -y software-properties-common
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt-get update -y
sudo apt-get install -y python3.11 python3.11-venv python3.11-dev python3-pip
print_success "Python 3.11 installed"

# Step 7: Create virtual environment
print_status "Creating Python virtual environment..."
python3.11 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
print_success "Python virtual environment ready"

# Step 8: Prepare OSRM data directory
print_status "Preparing OSRM data directory..."
mkdir -p osrm-data
cd osrm-data
TEXAS_PBF="texas-latest.osm.pbf"

# Download Texas map if not present
if [ ! -f "$TEXAS_PBF" ]; then
    print_status "Downloading Texas map..."
    wget -O $TEXAS_PBF http://download.geofabrik.de/north-america/us/texas-latest.osm.pbf
    print_success "Texas map downloaded"
else
    print_status "Texas map already exists"
fi

# Step 9: OSRM extraction, partition, and customize with threads
AVAILABLE_MEMORY=$(free -g | awk '/^Mem:/{print $7}')
THREADS=4
if [ "$AVAILABLE_MEMORY" -lt 25 ]; then
    THREADS=2
    print_warning "Low memory (${AVAILABLE_MEMORY}GB). Using $THREADS threads"
fi

print_progress "Starting OSRM extraction with $THREADS threads..."
$DOCKER_CMD run -t -v "$PWD:/data" -v "$PWD/../truck.lua:/opt/truck.lua" ghcr.io/project-osrm/osrm-backend osrm-extract -p /opt/truck.lua /data/$TEXAS_PBF --threads $THREADS

print_progress "Partitioning OSRM data..."
$DOCKER_CMD run -t -v "$PWD:/data" ghcr.io/project-osrm/osrm-backend osrm-partition /data/texas-latest.osrm --threads $THREADS

print_progress "Customizing OSRM data..."
$DOCKER_CMD run -t -v "$PWD:/data" ghcr.io/project-osrm/osrm-backend osrm-customize /data/texas-latest.osrm --threads $THREADS
print_success "OSRM processing completed successfully!"

# Step 10: Start OSRM Server
print_status "Starting OSRM Server..."
$DOCKER_CMD run -d --name osrm-texas-server -p 0.0.0.0:5001:5000 -v "$PWD:/data" ghcr.io/project-osrm/osrm-backend osrm-routed --algorithm mld /data/texas-latest.osrm
print_success "OSRM Server started on port 5001"

cd ..
