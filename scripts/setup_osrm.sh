#!/bin/bash

# OSRM Setup Script for Distance Route Calculator
# This script downloads and preprocesses OSM data for OSRM

set -e

echo "🚀 Setting up OSRM for Distance Route Calculator..."

# Create data directory
mkdir -p osrm-data
cd osrm-data

# Download US map extract (you can change this to your specific US city/state)
echo "📥 Downloading US map extract..."
wget -O us-latest.osm.pbf http://download.geofabrik.de/north-america/us-latest.osm.pbf

echo "🔧 Preprocessing data with MLD algorithm..."

# Extract with truck profile (optimized for movers and packers)
echo "Step 1/3: Extracting with truck profile (optimized for movers)..."
docker run -t -v "$PWD:/data" -v "$PWD/../truck.lua:/opt/truck.lua" ghcr.io/project-osrm/osrm-backend \
  osrm-extract -p /opt/truck.lua /data/us-latest.osm.pbf

# Partition
echo "Step 2/3: Partitioning..."
docker run -t -v "$PWD:/data" ghcr.io/project-osrm/osrm-backend \
  osrm-partition /data/us-latest.osrm

# Customize
echo "Step 3/3: Customizing..."
docker run -t -v "$PWD:/data" ghcr.io/project-osrm/osrm-backend \
  osrm-customize /data/us-latest.osrm

echo "✅ OSRM data preprocessing complete!"
echo "📁 Data files saved in ./osrm-data/"
echo ""
echo "🚀 To start the server, run:"
echo "   docker-compose up -d"
echo ""
echo "🧪 To test the API, run:"
echo "   python test_routes.py"
