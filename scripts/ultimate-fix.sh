#!/bin/bash

# Ultimate Fix Script for Herobot Container Issues
# This script addresses all known issues with the container setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚑 Herobot Ultimate Fix - Starting...${NC}"

# Step 1: Stop all containers
echo -e "${YELLOW}Step 1: Stopping all containers...${NC}"
docker-compose down -v

# Step 2: Clean up problematic volumes and directories
echo -e "${YELLOW}Step 2: Cleaning up...${NC}"
if [ -d "./vendor" ]; then
    echo "Removing host vendor directory..."
    sudo rm -rf ./vendor
fi

if [ -d "./node_modules" ]; then
    echo "Removing host node_modules directory..."
    sudo rm -rf ./node_modules
fi

# Step 3: Remove old container images
echo -e "${YELLOW}Step 3: Removing old container images...${NC}"
docker rmi sail-8.4/app 2>/dev/null || echo "Image already removed"
docker system prune -f

# Step 4: Create .env file if not exists
echo -e "${YELLOW}Step 4: Setting up environment...${NC}"
if [ ! -f .env ]; then
    echo "Creating .env file from .env.example..."
    cp .env.example .env
fi

# Step 5: Create necessary directories with proper permissions
echo -e "${YELLOW}Step 5: Creating directories...${NC}"
mkdir -p data/{mysql,redis}
mkdir -p storage/{app,framework,logs}
mkdir -p bootstrap/cache
sudo chown -R 1000:1000 data/ storage/ bootstrap/cache/ 2>/dev/null || true

# Step 6: Rebuild containers
echo -e "${YELLOW}Step 6: Rebuilding containers...${NC}"
docker-compose build --no-cache

# Step 7: Start only database and redis first
echo -e "${YELLOW}Step 7: Starting database services...${NC}"
docker-compose up -d mariadb redis

# Wait for database to be ready
echo -e "${YELLOW}Waiting for database to be ready...${NC}"
sleep 20

# Step 8: Start Laravel container
echo -e "${YELLOW}Step 8: Starting Laravel container...${NC}"
docker-compose up -d laravel.test

# Step 9: Wait and monitor startup
echo -e "${YELLOW}Step 9: Monitoring startup...${NC}"
for i in {1..60}; do
    status=$(docker-compose ps laravel.test --format "table {{.Status}}" | tail -n +2)
    if [[ $status == *"Up"* ]]; then
        echo -e "${GREEN}✅ Laravel container is running!${NC}"
        break
    elif [[ $status == *"Exited"* ]]; then
        echo -e "${RED}❌ Container exited. Checking logs...${NC}"
        docker logs herobotv5-laravel.test-1 --tail 20
        break
    fi
    echo "Waiting for container to start... ($i/60)"
    sleep 5
done

# Step 10: Final checks
echo -e "${YELLOW}Step 10: Running final checks...${NC}"

# Check container status
echo "Container Status:"
docker-compose ps

# Wait a bit more for application to fully start
echo "Waiting for application to fully initialize..."
sleep 30

# Check if port is accessible
echo "Testing port accessibility..."
if command -v curl > /dev/null 2>&1; then
    if curl -f http://localhost:8080 2>/dev/null; then
        echo -e "${GREEN}✅ Application is accessible at http://localhost:8080${NC}"
    else
        echo -e "${YELLOW}⚠️ Application not yet accessible, may need more time${NC}"
    fi
else
    echo "curl not available, skipping port test"
fi

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}   Ultimate Fix Completed!      ${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "Next steps:"
echo "1. Check container status: docker-compose ps"
echo "2. View logs: docker logs herobotv5-laravel.test-1"
echo "3. Access application: http://localhost:8080"
echo "4. If issues persist, check individual logs:"
echo "   - make logs-app"
echo "   - make logs-db"
echo ""

# Final status check
final_status=$(docker-compose ps laravel.test --format "table {{.Status}}" | tail -n +2)
if [[ $final_status == *"Up"* ]]; then
    echo -e "${GREEN}🎉 SUCCESS: All containers are running!${NC}"
    exit 0
else
    echo -e "${RED}⚠️ WARNING: Container may have issues. Check logs above.${NC}"
    exit 1
fi