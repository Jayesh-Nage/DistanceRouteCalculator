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
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show progress with timestamp
print_progress() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

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
    
    # Show disk usage
    local disk_usage=$(df -h . | tail -1 | awk '{print $5}')
    print_progress "Disk usage: $disk_usage"
    
    # Show CPU load
    local cpu_load=$(uptime | awk -F'load average:' '{print $2}')
    print_progress "CPU load:$cpu_load"
    
    # Show running processes
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
    print_warning "System has ${TOTAL_MEM}GB RAM. Recommended: 32GB+ for US dataset"
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
    # Install Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    print_success "Docker installed successfully"
    print_warning "You may need to logout and login again for Docker group changes to take effect"
else
    print_success "Docker already installed"
fi

# Check if user is in docker group
if ! groups $USER | grep -q '\bdocker\b'; then
    print_warning "User not in docker group. Adding user to docker group..."
    sudo usermod -aG docker $USER
    print_warning "Please logout and login again, or run: newgrp docker"
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

# Clean up any existing Docker containers
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

# Create virtual environment
print_status "Creating Python virtual environment..."
python3.11 -m venv venv
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip

print_success "Python 3.11 and virtual environment ready"

# Step 5: Install Python dependencies
print_status "Installing Python dependencies..."
pip install -r requirements.txt
print_success "Python dependencies installed"

# Step 6: Create directories and download US map data
print_status "Setting up OSRM data directory..."
mkdir -p osrm-data
PROJECT_ROOT="$PWD"
cd osrm-data

# Check if PBF file already exists
if [ -f "us-latest.osm.pbf" ]; then
    FILE_SIZE=$(du -h us-latest.osm.pbf | cut -f1)
    print_warning "US map data already exists (${FILE_SIZE})"
    print_status "File: us-latest.osm.pbf"
    print_status "Location: $(pwd)/us-latest.osm.pbf"
    
    # Check if running in background (non-interactive)
    if [ -t 0 ]; then
        # Interactive mode - ask user
        echo ""
        read -p "Do you want to re-download the US map data? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "Re-downloading US map data (this may take 30-60 minutes)..."
            print_warning "File size: ~11GB - ensure you have sufficient disk space"
            wget -O us-latest.osm.pbf http://download.geofabrik.de/north-america/us-latest.osm.pbf
            if [ -f "us-latest.osm.pbf" ]; then
                FILE_SIZE=$(du -h us-latest.osm.pbf | cut -f1)
                print_success "US map data re-downloaded successfully (${FILE_SIZE})"
            else
                print_error "Failed to re-download US map data"
                exit 1
            fi
        else
            print_success "Using existing US map data (${FILE_SIZE})"
        fi
    else
        # Non-interactive mode (background) - use existing file
        print_success "Using existing US map data (${FILE_SIZE})"
    fi
else
    # Download US map data (11GB)
    print_status "Downloading US map data (this may take 30-60 minutes)..."
    print_warning "File size: ~11GB - ensure you have sufficient disk space"
    wget -O us-latest.osm.pbf http://download.geofabrik.de/north-america/us-latest.osm.pbf

    if [ -f "us-latest.osm.pbf" ]; then
        FILE_SIZE=$(du -h us-latest.osm.pbf | cut -f1)
        print_success "US map data downloaded successfully (${FILE_SIZE})"
    else
        print_error "Failed to download US map data"
        exit 1
    fi
fi
