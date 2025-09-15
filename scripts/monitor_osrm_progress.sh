#!/bin/bash

# OSRM US Map Processing Monitor
# This script monitors the progress of US map data processing

CONTAINER_ID="d93057d2952c"
LOG_FILE="osrm_progress.log"

echo "🚀 OSRM US Map Processing Monitor"
echo "=================================="
echo "Container ID: $CONTAINER_ID"
echo "Started: $(date)"
echo ""

while true; do
    echo "📊 Status Check - $(date)"
    echo "------------------------"
    
    # Check if container is still running
    if docker ps | grep -q "$CONTAINER_ID"; then
        echo "✅ Container is running"
        
        # Get resource usage
        echo "📈 Resource Usage:"
        docker stats "$CONTAINER_ID" --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
        
        # Check for new files
        echo "📁 Files created:"
        ls -la osrm-data/ | grep "us-latest.osrm" | wc -l | xargs echo "OSRM files:"
        
        # Get latest logs
        echo "📝 Latest logs:"
        docker logs "$CONTAINER_ID" --tail 3
        
    else
        echo "❌ Container stopped or completed"
        echo "📋 Final logs:"
        docker logs "$CONTAINER_ID" --tail 10
        break
    fi
    
    echo ""
    echo "⏳ Waiting 5 minutes before next check..."
    echo "=========================================="
    sleep 300  # Wait 5 minutes
done

echo "🏁 Monitoring completed at $(date)"
