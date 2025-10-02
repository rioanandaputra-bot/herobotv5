#!/bin/bash

# Debug script for Herobot container issues

echo "🔍 Diagnosing Herobot container issues..."

echo "1. Checking if .env file exists..."
if [ -f .env ]; then
    echo "✅ .env file exists"
    echo "📋 .env file content preview:"
    head -10 .env
else
    echo "❌ .env file missing - creating from .env.example"
    cp .env.example .env
fi

echo ""
echo "2. Checking container status..."
docker-compose ps

echo ""
echo "3. Checking container logs (last 20 lines)..."
docker logs herobotv5-laravel.test-1 --tail 20

echo ""
echo "4. Checking port availability..."
if command -v netstat > /dev/null 2>&1; then
    netstat -tlnp | grep 8080 || echo "Port 8080 is available"
elif command -v ss > /dev/null 2>&1; then
    ss -tlnp | grep 8080 || echo "Port 8080 is available"
else
    echo "Install net-tools or ss to check ports"
fi

echo ""
echo "5. Checking Docker resources..."
docker system df

echo ""
echo "🔧 Suggested fixes:"
echo "   make rebuild     # Rebuild Laravel container"
echo "   make quick-fix   # Run automated fix"
echo "   make clean       # Clean and restart"