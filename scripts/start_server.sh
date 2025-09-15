#!/bin/bash

# Quick start script for already processed OSRM data
# Usage: ./scripts/start_server.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if we're in the right directory
if [ ! -f "run.sh" ]; then
    print_error "run.sh not found. Please run from project root directory."
    exit 1
fi

# Check if OSRM data exists
print_status "Checking for OSRM data..."

# Look for OSRM files in osrm-data directory
if [ -d "osrm-data" ]; then
    print_status "osrm-data directory found, checking for OSRM files..."
    ls -la osrm-data/*.osrm* 2>/dev/null || print_warning "No .osrm files found in osrm-data/"
    
    # Check if any OSRM files exist
    OSRM_FILES=$(ls osrm-data/*.osrm* 2>/dev/null | wc -l)
    if [ "$OSRM_FILES" -eq 0 ]; then
        print_error "No OSRM files found in osrm-data directory"
        print_status "Please run the full setup first: ./run.sh"
        exit 1
    fi
    
    # Check if main OSRM file exists (not just timestamp)
    if [ ! -f "osrm-data/us-latest.osrm" ]; then
        print_error "Main OSRM file (us-latest.osrm) not found!"
        print_status "Only found:"
        ls -la osrm-data/*.osrm* 2>/dev/null
        print_status "OSRM processing may have failed. Please run the full setup again: ./run.sh"
        exit 1
    fi
    
    print_success "Found $OSRM_FILES OSRM file(s) in osrm-data directory"
    ls -la osrm-data/*.osrm* 2>/dev/null
else
    print_error "osrm-data directory not found"
    print_status "Please run the full setup first: ./run.sh"
    exit 1
fi

print_success "OSRM data found, starting server..."

# Change to osrm-data directory
cd osrm-data

# Check Docker permissions
if docker ps > /dev/null 2>&1; then
    DOCKER_CMD="docker"
else
    DOCKER_CMD="sudo docker"
fi

# Stop any existing OSRM server
print_status "Stopping any existing OSRM server..."
$DOCKER_CMD stop osrm-us-server 2>/dev/null || true
$DOCKER_CMD rm osrm-us-server 2>/dev/null || true

# Start OSRM server
print_status "Starting OSRM Server with processed US map data..."
print_status "Binding to 0.0.0.0:5001 for external access"

$DOCKER_CMD run -d --name osrm-us-server -p 0.0.0.0:5001:5000 -v "$PWD:/data" ghcr.io/project-osrm/osrm-backend osrm-routed --algorithm mld /data/us-latest.osrm

if [ $? -eq 0 ]; then
    print_success "OSRM Server started successfully on port 5001"
    
    # Get external IP
    EXTERNAL_IP=$(curl -s --max-time 5 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "YOUR_AWS_IP")
    print_status "Server URL: http://localhost:5001 (local)"
    if [ "$EXTERNAL_IP" = "YOUR_AWS_IP" ]; then
        print_status "External URL: http://YOUR_AWS_IP:5001 (replace YOUR_AWS_IP with your actual AWS public IP)"
        print_status "To find your IP: curl http://169.254.169.254/latest/meta-data/public-ipv4"
    else
        print_status "External URL: http://${EXTERNAL_IP}:5001 (external)"
    fi
    
    print_status "Waiting 10 seconds for server to fully start..."
    sleep 10
    
    # Test the server
    print_status "Testing server..."
    TEST_COORDS="-74.0060,40.7128;-118.2437,34.0522"
    RESPONSE=$(curl -s --max-time 30 "http://localhost:5001/route/v1/driving/${TEST_COORDS}?overview=false&annotations=distance,duration")
    
    if echo "$RESPONSE" | grep -q '"code":"Ok"'; then
        DISTANCE=$(echo "$RESPONSE" | jq -r '.routes[0].distance')
        DURATION=$(echo "$RESPONSE" | jq -r '.routes[0].duration')
        print_success "Server test successful!"
        print_status "NYC to LA: ${DISTANCE}m distance, ${DURATION}s duration"
    else
        print_warning "Server test failed, but server is running"
        print_status "Response: $RESPONSE"
    fi
    
    echo ""
    print_success "OSRM Server is ready!"
    print_status "Use these URLs for API calls:"
    print_status "  Local:  http://localhost:5001"
    print_status "  External: http://${EXTERNAL_IP}:5001"
    print_status ""
    print_status "Example API call:"
    print_status "  curl \"http://${EXTERNAL_IP}:5001/route/v1/driving/-74.0060,40.7128;-118.2437,34.0522?overview=false\""
    
else
    print_error "Failed to start OSRM server"
    exit 1
fi
