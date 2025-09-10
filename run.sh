#!/bin/bash

# OSRM Distance Route Calculator - Setup Script (Latest OSRM + MLD)
# For Ubuntu AWS Instance with 64GB RAM
# US-wide routing

set -e

echo "🚀 OSRM Distance Route Calculator Setup (Latest OSRM + MLD)"
echo "========================================================="
echo "Start time: $(date)"
echo "Process ID: $$"
echo ""

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

print_status()   { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success()  { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning()  { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()    { echo -e "${RED}[ERROR]${NC} $1"; }
print_progress() { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }

check_memory() {
    local available=$(free -g | awk '/^Mem:/{print $7}')
    local used=$(free -g | awk '/^Mem:/{print $3}')
    local total=$(free -g | awk '/^Mem:/{print $2}')
    print_progress "Memory: ${used}GB used, ${available}GB available, ${total}GB total"
    if [ "$available" -lt 5 ]; then
        print_warning "CRITICAL: Only ${available}GB memory available!"
        return 1
    elif [ "$available" -lt 10 ]; then
        print_warning "Low memory (${available}GB). Monitor closely."
    fi
    return 0
}

show_system_resources() {
    print_progress "=== SYSTEM RESOURCES ==="
    check_memory
    print_progress "Disk usage: $(df -h . | tail -1 | awk '{print $5}')"
    print_progress "CPU load: $(uptime | awk -F'load average:' '{print $2}')"
    print_progress "Docker processes: $(ps aux | grep docker | wc -l)"
    print_progress "========================"
}

# Ensure non-root
if [[ $EUID -eq 0 ]]; then
   print_error "Do not run as root"
   exit 1
fi

# Update & upgrade system
print_status "Updating system..."
sudo apt-get update -y && sudo apt-get upgrade -y

# Docker installation
print_status "Installing Docker..."
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    print_success "Docker installed"
else
    print_success "Docker already installed"
fi

# Docker Compose installation
print_status "Installing Docker Compose..."
if ! command -v docker-compose &>/dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    print_success "Docker Compose installed"
else
    print_success "Docker Compose already installed"
fi

# Python 3.11 installation
print_status "Installing Python 3.11..."
sudo apt-get install -y software-properties-common
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt-get update -y
sudo apt-get install -y python3.11 python3.11-venv python3.11-dev python3-pip

python3.11 -m venv venv
source venv/bin/activate
pip install --upgrade pip
print_success "Python 3.11 virtual environment ready"

# Python dependencies
print_status "Installing Python dependencies..."
pip install -r requirements.txt
print_success "Python dependencies installed"

# OSRM data directory
mkdir -p osrm-data && cd osrm-data
PBF_URL="http://download.geofabrik.de/north-america/us-latest.osm.pbf"
if [ ! -f "us-latest.osm.pbf" ]; then
    print_status "Downloading US map data (~11GB)..."
    wget -O us-latest.osm.pbf $PBF_URL
    print_success "Downloaded US map data"
else
    print_status "Using existing US map data"
fi

# Use official MLD-enabled OSRM image
THREADS=$(free -g | awk '/^Mem:/{if($7>25) print 4; else print 2}')
OSRM_IMG="osrm/osrm-backend:5.36.0"
docker pull $OSRM_IMG

# OSRM processing (MLD)
print_status "Extracting OSRM data with MLD..."
docker run -t -v "$PWD:/data" -v "$PWD/../truck.lua:/opt/truck.lua" $OSRM_IMG osrm-extract -p /opt/truck.lua /data/us-latest.osm.pbf --algorithm mld --threads $THREADS
docker run -t -v "$PWD:/data" $OSRM_IMG osrm-partition /data/us-latest.osrm --algorithm mld --threads $THREADS
docker run -t -v "$PWD:/data" $OSRM_IMG osrm-customize /data/us-latest.osrm --algorithm mld --threads $THREADS
print_success "OSRM MLD processing completed"

# Start OSRM server
print_status "Starting OSRM MLD server on port 5001..."
docker run -d --name osrm-us-server -p 0.0.0.0:5001:5000 -v "$PWD:/data" $OSRM_IMG osrm-routed --algorithm mld /data/us-latest.osrm
print_success "OSRM server started"

# Server test
print_status "Testing server (NYC -> LA)..."
TEST_COORDS="-74.0060,40.7128;-118.2437,34.0522"
RESPONSE=$(curl -s "http://localhost:5001/route/v1/driving/${TEST_COORDS}?overview=false&annotations=distance,duration")
if echo "$RESPONSE" | grep -q '"code":"Ok"'; then
    print_success "Server test successful"
else
    print_error "Server test failed"
fi

echo ""
print_success "🎉 OSRM Distance Route Calculator Setup Complete (Official MLD-enabled OSRM)!"
