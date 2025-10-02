#!/bin/bash

echo "🔧 Docker Permission Fix Script"
echo "================================"

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Error: docker-compose.yml not found. Please run this script from the project root."
    exit 1
fi

echo "📋 Stopping all containers..."
docker compose down

echo "🗑️ Removing old containers and volumes..."
docker compose rm -f laravel.test
docker volume prune -f

echo "🏗️ Rebuilding Laravel container with permission fixes..."
docker compose build --no-cache laravel.test

echo "📁 Fixing local permissions..."
# Fix local permissions for files that need to be writable
chmod 664 .env.example 2>/dev/null || true
chmod 755 storage/ -R 2>/dev/null || true
chmod 755 bootstrap/cache/ -R 2>/dev/null || true

echo "🚀 Starting containers with fresh permissions..."
docker compose up -d

echo "⏳ Waiting for container to be ready..."
sleep 10

echo "📊 Checking container status..."
docker compose ps

echo "📋 Container logs (last 20 lines):"
docker compose logs --tail=20 laravel.test

echo ""
echo "✅ Permission fix completed!"
echo "🌐 Application should be available at: http://localhost:8082"
echo ""
echo "If issues persist, check logs with:"
echo "  docker compose logs -f laravel.test"