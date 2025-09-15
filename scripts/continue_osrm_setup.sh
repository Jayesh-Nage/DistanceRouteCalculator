#!/bin/bash

# Continue OSRM Setup after extraction completes
# This script runs the partition and customize steps, then starts the server

echo "🚀 Continuing OSRM Setup for US Map Data"
echo "========================================"

cd osrm-data

# Check if extraction completed
if [ ! -f "texas-latest.osrm" ]; then
    echo "❌ Extraction not completed yet. texas-latest.osrm file not found."
    echo "Please wait for the extraction to complete first."
    exit 1
fi

echo "✅ Extraction completed. Starting partition step..."

# Step 2: Partition
echo "📊 Step 2/3: Partitioning data..."
docker run -t -v "$PWD:/data" ghcr.io/project-osrm/osrm-backend osrm-partition /data/texas-latest.osrm

if [ $? -eq 0 ]; then
    echo "✅ Partition completed successfully"
else
    echo "❌ Partition failed"
    exit 1
fi

# Step 3: Customize
echo "🔧 Step 3/3: Customizing data..."
docker run -t -v "$PWD:/data" ghcr.io/project-osrm/osrm-backend osrm-customize /data/texas-latest.osrm

if [ $? -eq 0 ]; then
    echo "✅ Customize completed successfully"
else
    echo "❌ Customize failed"
    exit 1
fi

# Step 4: Start OSRM Server
echo "🌐 Starting OSRM Server with US map data..."
docker run -d -p 5001:5000 -v "$PWD:/data" ghcr.io/project-osrm/osrm-backend osrm-routed --algorithm mld /data/texas-latest.osrm

if [ $? -eq 0 ]; then
    echo "✅ OSRM Server started successfully on port 5001"
    echo "🔗 Server URL: http://localhost:5001"
    echo ""
    echo "🧪 Testing the server..."
    sleep 5
    
    # Test with your coordinates
    echo "Testing with your coordinates:"
    curl -s "http://localhost:5001/route/v1/driving/-84.287,33.8513;-84.119427888778,33.975029869697?overview=false&annotations=distance,duration" | jq '.routes[0] | {distance, duration}'
    
    echo ""
    echo "🎉 US OSRM Server is ready!"
    echo "You can now use http://localhost:5001 for all your routing needs"
else
    echo "❌ Failed to start OSRM server"
    exit 1
fi
