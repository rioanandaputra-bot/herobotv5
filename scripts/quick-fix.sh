#!/bin/bash

# Quick fix script for Herobot container issues

echo "🔧 Fixing Herobot container issues..."

# Stop all containers
echo "Stopping containers..."
docker-compose down

# Remove the problematic container image
echo "Removing old container image..."
docker rmi sail-8.4/app 2>/dev/null || true

# Rebuild the container
echo "Rebuilding container..."
docker-compose build --no-cache laravel.test

# Start services
echo "Starting services..."
docker-compose up -d

# Wait for services to stabilize
echo "Waiting for services to start..."
sleep 15

# Check status
echo "Checking container status..."
docker-compose ps

echo "✅ Fix completed! Check the logs with: docker logs herobotv5-laravel.test-1"