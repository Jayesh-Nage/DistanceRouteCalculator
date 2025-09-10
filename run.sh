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

# Function to print colored output
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

# Function to show system resources
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

# Ensure not running as root
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

# Step 1: Update packages
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

# Docker group check
if ! groups $USER | grep -q '\bdocker\b'; then
    print_warning "User not in docker group. Adding..."
    sudo usermod -aG docker $USER
    print_warning "Logout/login or run: newgrp docker, then rerun script"
    exit 1
fi

# Test Docker permissions
print_status "Testing Docker permissions..."
if ! docker ps &> /dev/null; then
    print_warning "Docker requires sudo. Using sudo for Docker commands..."
    DOCKER_CMD="sudo docker"
else
    print_success "Docker works without sudo"
    DOCKER_CMD="docker"
fi

# Cleanup existing Docker containers
print_status "Cleaning up existing Docker containers..."
$DOCKER_CMD stop $($DOCKER_CMD ps -q) 2>/dev/null || true
$DOCKER_CMD rm $($DOCKER_CMD ps -aq) 2>/dev/null || true
$DOCKER_CMD ps -q --filter "name=osrm" | xargs -r $DOCKER_CMD stop 2>/dev/null || true
$DOCKER_CMD ps -aq --filter "name=osrm" | xargs -r $DOCKER_CMD rm 2>/dev/null || true
print_success "Docker cleanup completed"

# Step 3: Docker Compose
print_status "Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    print_success "Docker Compose installed successfully"
else
    print_success "Docker Compose already installed"
fi

# Step 4: Python 3.11
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

# Step 5: Python dependencies
print_status "Installing Python dependencies..."
pip install -r requirements.txt
print_success "Python dependencies installed"

# Step 6: OSRM data directory & download
print_status "Setting up OSRM data directory..."
mkdir -p osrm-data
cd osrm-data
if [ ! -f "us-latest.osm.pbf" ]; then
    print_status "Downloading US map data (~11GB)..."
    wget -O us-latest.osm.pbf http://download.geofabrik.de/north-america/us-latest.osm.pbf
    if [ ! -f "us-latest.osm.pbf" ]; then
        print_error "Failed to download US map data"
        exit 1
    fi
    FILE_SIZE=$(du -h us-latest.osm.pbf | cut -f1)
    print_success "US map data downloaded successfully (${FILE_SIZE})"
else
    FILE_SIZE=$(du -h us-latest.osm.pbf | cut -f1)
    print_success "Using existing US map data (${FILE_SIZE})"
fi

# Step 7: OSRM Extract only
print_progress "Extracting with truck profile (32-foot moving truck)"
check_memory
AVAILABLE_MEMORY=$(free -g | awk '/^Mem:/{print $7}')
THREADS=$([ "$AVAILABLE_MEMORY" -lt 25 ] && echo 2 || echo 4)

$DOCKER_CMD run -t -v "$PWD:/data" -v "$PWD/../truck.lua:/opt/truck.lua" \
    ghcr.io/project-osrm/osrm-backend osrm-extract -p /opt/truck.lua /data/us-latest.osm.pbf --threads $THREADS

print_success "OSRM extraction completed"

# Step 8: Start OSRM server (MLD)
print_status "Starting OSRM Server with MLD algorithm..."
$DOCKER_CMD run -d --name osrm-us-server -p 0.0.0.0:5001:5000 \
    -v "$PWD:/data" ghcr.io/project-osrm/osrm-backend osrm-routed --algorithm mld /data/us-latest.osrm

sleep 10

# Step 9: Test server
print_status "Testing OSRM server..."
HEALTH_RESPONSE=$(curl -s -w "%{http_code}" "http://localhost:5001/health" -o /dev/null)
if [ "$HEALTH_RESPONSE" != "200" ]; then
    print_warning "Server health check failed (HTTP $HEALTH_RESPONSE)"
fi

TEST_COORDS="-74.0060,40.7128;-118.2437,34.0522"
RESPONSE=$(curl -s --max-time 30 "http://localhost:5001/route/v1/driving/${TEST_COORDS}?overview=false&annotations=distance,duration")

if echo "$RESPONSE" | grep -q '"code":"Ok"'; then
    DISTANCE=$(echo "$RESPONSE" | jq -r '.routes[0].distance')
    DURATION=$(echo "$RESPONSE" | jq -r '.routes[0].duration')
    print_success "Server test successful! NYC to LA: ${DISTANCE}m, ${DURATION}s"
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
source = (-74.0060, 40.7128)
destination = (-118.2437, 34.0522)
routes = analyzer.get_routes(source, destination, alternatives=1)
print(f'✅ Python test successful: {routes.routes[0].distance_km:.1f}km route found')
"

print_success "Python integration test successful!"

# Final message
echo ""
echo "🎉 OSRM Distance Route Calculator Setup Complete!"
echo "🌐 Server URL: http://localhost:5001"
echo "📊 Coverage: Entire United States"
echo "🚚 Ready for movers and packers routing!"
echo ""
print_success "Setup completed successfully!"
