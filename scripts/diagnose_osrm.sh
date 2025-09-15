#!/bin/bash

# OSRM Diagnostic Script
# Usage: ./scripts/diagnose_osrm.sh

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

echo "🔍 OSRM Diagnostic Report"
echo "========================="

# Check if we're in the right directory
if [ ! -f "run.sh" ]; then
    print_error "run.sh not found. Please run from project root directory."
    exit 1
fi

# Check Docker
print_status "Checking Docker..."
if docker ps > /dev/null 2>&1; then
    DOCKER_CMD="docker"
    print_success "Docker is working"
else
    DOCKER_CMD="sudo docker"
    print_warning "Using sudo docker"
fi

# Check OSRM data directory
print_status "Checking OSRM data directory..."
if [ -d "osrm-data" ]; then
    print_success "osrm-data directory exists"
    
    # List all files
    print_status "Files in osrm-data directory:"
    ls -la osrm-data/
    
    # Check for main OSRM files
    print_status "Checking for main OSRM files..."
    if [ -f "osrm-data/us-latest.osrm" ]; then
        print_success "Main OSRM file found: us-latest.osrm"
        FILE_SIZE=$(du -h osrm-data/us-latest.osrm | cut -f1)
        print_status "Size: $FILE_SIZE"
    else
        print_error "Main OSRM file missing: us-latest.osrm"
    fi
    
    if [ -f "osrm-data/us-latest.osrm.hsgr" ]; then
        print_success "HSGR file found: us-latest.osrm.hsgr"
        FILE_SIZE=$(du -h osrm-data/us-latest.osrm.hsgr | cut -f1)
        print_status "Size: $FILE_SIZE"
    else
        print_warning "HSGR file missing: us-latest.osrm.hsgr"
    fi
    
    if [ -f "osrm-data/us-latest.osrm.edges" ]; then
        print_success "Edges file found: us-latest.osrm.edges"
        FILE_SIZE=$(du -h osrm-data/us-latest.osrm.edges | cut -f1)
        print_status "Size: $FILE_SIZE"
    else
        print_warning "Edges file missing: us-latest.osrm.edges"
    fi
    
    # Check file permissions
    print_status "Checking file permissions..."
    ls -la osrm-data/us-latest.osrm* 2>/dev/null | head -5
    
else
    print_error "osrm-data directory not found"
    exit 1
fi

# Check Docker containers
print_status "Checking Docker containers..."
CONTAINERS=$($DOCKER_CMD ps -a --filter "name=osrm" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}")
if [ -n "$CONTAINERS" ]; then
    print_status "OSRM containers:"
    echo "$CONTAINERS"
else
    print_warning "No OSRM containers found"
fi

# Check if port 5001 is in use
print_status "Checking port 5001..."
if netstat -tlnp 2>/dev/null | grep -q ":5001"; then
    print_warning "Port 5001 is in use"
    netstat -tlnp 2>/dev/null | grep ":5001"
else
    print_status "Port 5001 is available"
fi

# Try to start OSRM server manually for testing
print_status "Testing OSRM server startup..."
cd osrm-data

print_status "Starting OSRM server for testing..."
$DOCKER_CMD run -d --name osrm-test-server -p 5002:5000 -v "$PWD:/data" ghcr.io/project-osrm/osrm-backend osrm-routed --algorithm mld /data/us-latest.osrm

sleep 5

# Check if server started
if $DOCKER_CMD ps | grep -q "osrm-test-server"; then
    print_success "Test server started successfully"
    
    # Test the server
    print_status "Testing server response..."
    sleep 5
    RESPONSE=$(curl -s --max-time 10 "http://localhost:5002/health" 2>/dev/null || echo "FAILED")
    
    if [ "$RESPONSE" = "FAILED" ]; then
        print_error "Server health check failed"
        
        # Check server logs
        print_status "Server logs:"
        $DOCKER_CMD logs osrm-test-server 2>&1 | tail -20
    else
        print_success "Server is responding: $RESPONSE"
    fi
    
    # Clean up test server
    print_status "Cleaning up test server..."
    $DOCKER_CMD stop osrm-test-server 2>/dev/null || true
    $DOCKER_CMD rm osrm-test-server 2>/dev/null || true
    
else
    print_error "Test server failed to start"
    
    # Check why it failed
    print_status "Docker logs:"
    $DOCKER_CMD logs osrm-test-server 2>&1 | tail -20
    
    # Clean up
    $DOCKER_CMD rm osrm-test-server 2>/dev/null || true
fi

cd ..

# Analyze logs to find the failure reason
print_status "Analyzing processing logs to find failure reason..."
echo ""

# Find the latest log file
LATEST_LOG=$(ls -t logs/osrm_setup_*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    print_status "Analyzing log file: $LATEST_LOG"
    echo ""
    
    # Check for common failure patterns
    print_status "=== FAILURE ANALYSIS ==="
    
    # Check for memory issues
    if grep -q "Out of memory\|OOM\|killed\|terminate called" "$LATEST_LOG"; then
        print_error "MEMORY ISSUE DETECTED:"
        grep -i "out of memory\|OOM\|killed\|terminate called" "$LATEST_LOG" | tail -3
        echo ""
    fi
    
    # Check for Docker issues
    if grep -q "docker.*error\|container.*failed\|permission denied" "$LATEST_LOG"; then
        print_error "DOCKER ISSUE DETECTED:"
        grep -i "docker.*error\|container.*failed\|permission denied" "$LATEST_LOG" | tail -3
        echo ""
    fi
    
    # Check for OSRM processing errors
    if grep -q "no edges remaining\|Profile.*error\|extraction.*failed" "$LATEST_LOG"; then
        print_error "OSRM PROCESSING ERROR:"
        grep -i "no edges remaining\|Profile.*error\|extraction.*failed" "$LATEST_LOG" | tail -3
        echo ""
    fi
    
    # Check for file system issues
    if grep -q "No space left\|disk full\|write error" "$LATEST_LOG"; then
        print_error "DISK SPACE ISSUE:"
        grep -i "No space left\|disk full\|write error" "$LATEST_LOG" | tail -3
        echo ""
    fi
    
    # Check for process termination
    if grep -q "Process.*killed\|SIGKILL\|exit code 137" "$LATEST_LOG"; then
        print_error "PROCESS TERMINATED:"
        grep -i "Process.*killed\|SIGKILL\|exit code 137" "$LATEST_LOG" | tail -3
        echo ""
    fi
    
    # Show the last 20 lines of the log
    print_status "=== LAST 20 LINES OF LOG ==="
    tail -20 "$LATEST_LOG"
    echo ""
    
    # Check if processing completed any steps
    print_status "=== PROCESSING STEPS ANALYSIS ==="
    
    if grep -q "Extraction completed successfully" "$LATEST_LOG"; then
        print_success "✓ Extraction completed"
    else
        print_error "✗ Extraction failed or incomplete"
    fi
    
    if grep -q "Partition completed successfully" "$LATEST_LOG"; then
        print_success "✓ Partition completed"
    else
        print_error "✗ Partition failed or incomplete"
    fi
    
    if grep -q "Customize completed successfully" "$LATEST_LOG"; then
        print_success "✓ Customize completed"
    else
        print_error "✗ Customize failed or incomplete"
    fi
    
    # Check memory usage during processing
    print_status "=== MEMORY USAGE DURING PROCESSING ==="
    if grep -q "Memory:" "$LATEST_LOG"; then
        grep "Memory:" "$LATEST_LOG" | tail -5
    else
        print_warning "No memory usage data found in logs"
    fi
    
else
    print_warning "No log files found to analyze"
fi

echo ""
print_status "=== RECOMMENDATIONS ==="

# Check current memory
CURRENT_MEMORY=$(free -g | awk '/^Mem:/{print $7}')
if [ "$CURRENT_MEMORY" -lt 25 ]; then
    print_error "Low memory detected (${CURRENT_MEMORY}GB available)"
    print_status "Recommendation: Restart with more memory or wait for other processes to finish"
else
    print_success "Memory looks good (${CURRENT_MEMORY}GB available)"
fi

# Check disk space
DISK_USAGE=$(df -h . | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 90 ]; then
    print_error "Disk space low (${DISK_USAGE}% used)"
    print_status "Recommendation: Free up disk space"
else
    print_success "Disk space looks good (${DISK_USAGE}% used)"
fi

print_status "Next steps:"
print_status "1. If memory/disk issues: Fix them and restart"
print_status "2. If processing failed: Run ./scripts/run_background.sh"
print_status "3. Monitor with: ./scripts/monitor_setup.sh"

echo ""
print_status "Diagnostic complete!"
