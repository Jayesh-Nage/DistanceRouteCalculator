#!/bin/bash

# OSRM Distance Route Calculator Setup (Patched for MLD / Latest OSRM)
# For Ubuntu AWS Instance with 64GB RAM

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

DOCKER_CMD="docker"

THREADS=4
OSRM_DATA_DIR="$PWD/osrm-data"
TRUCK_PROFILE="$PWD/../truck.lua"
PBF_FILE="$OSRM_DATA_DIR/us-latest.osm.pbf"
OSRM_FILE="$OSRM_DATA_DIR/us-latest.osrm"

mkdir -p "$OSRM_DATA_DIR"

# --- Use Latest OSRM Image ---
OSRM_IMAGE="ghcr.io/project-osrm/osrm-backend:latest"
print_status "Using OSRM Docker image: $OSRM_IMAGE"

# --- Check if --algorithm flag is supported ---
print_status "Checking if --algorithm flag is supported..."
if $DOCKER_CMD run --rm $OSRM_IMAGE osrm-extract --help 2>&1 | grep -q -- '--algorithm'; then
    ALGO_FLAG="--algorithm mld"
    print_status "--algorithm is supported. Using MLD mode for extraction."
else
    ALGO_FLAG=""
    print_warning "--algorithm not supported. Extraction will run in CH mode (MLD not available)."
fi

# --- Run Extraction ---
print_status "Starting OSRM extraction..."
$DOCKER_CMD run -t -v "$OSRM_DATA_DIR:/data" -v "$TRUCK_PROFILE:/opt/truck.lua" \
    $OSRM_IMAGE osrm-extract -p /opt/truck.lua $ALGO_FLAG /data/us-latest.osm.pbf --threads $THREADS

print_success "Extraction completed. OSRM files generated in $OSRM_DATA_DIR"

# --- Partition ---
print_status "Partitioning OSRM data..."
$DOCKER_CMD run -t -v "$OSRM_DATA_DIR:/data" $OSRM_IMAGE \
    osrm-partition /data/us-latest.osrm
print_success "Partition completed"

# --- Customize ---
print_status "Customizing OSRM data..."
$DOCKER_CMD run -t -v "$OSRM_DATA_DIR:/data" $OSRM_IMAGE \
    osrm-customize /data/us-latest.osrm
print_success "Customize completed"

# --- Start Server ---
print_status "Starting OSRM server on port 5001..."
$DOCKER_CMD run -d --name osrm-us-server -p 5001:5000 -v "$OSRM_DATA_DIR:/data" \
    $OSRM_IMAGE osrm-routed --algorithm mld /data/us-latest.osrm
print_success "OSRM server started! Access via http://localhost:5001"

# --- Test Server ---
print_status "Testing server health..."
sleep 10
HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5001/health)
if [ "$HEALTH" == "200" ]; then
    print_success "Server is healthy!"
else
    print_warning "Server health check failed: HTTP $HEALTH"
fi
