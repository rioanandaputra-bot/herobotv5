#!/bin/bash

echo "🚀 Docker Build Optimization Script"
echo "==================================="

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Error: docker-compose.yml not found. Please run this script from the project root."
    exit 1
fi

echo "🔧 Docker Build Optimization Options:"
echo "1. Use optimized Dockerfile (multi-stage, better caching)"
echo "2. Use original Dockerfile"
echo "3. Clean Docker cache and rebuild"
echo "4. Show current Docker cache usage"
echo ""

read -p "Select option (1-4): " choice

case $choice in
    1)
        echo "📦 Switching to optimized Dockerfile..."
        
        # Backup original if it doesn't exist
        if [ ! -f "docker/sail/Dockerfile.original" ]; then
            cp docker/sail/Dockerfile docker/sail/Dockerfile.original
            echo "✅ Original Dockerfile backed up"
        fi
        
        # Switch to optimized
        cp docker/sail/Dockerfile.optimized docker/sail/Dockerfile
        echo "✅ Switched to optimized Dockerfile"
        
        echo "🏗️ Building with optimized Dockerfile..."
        docker compose build --progress=plain laravel.test
        ;;
        
    2)
        echo "📦 Switching to original Dockerfile..."
        
        if [ -f "docker/sail/Dockerfile.original" ]; then
            cp docker/sail/Dockerfile.original docker/sail/Dockerfile
            echo "✅ Switched to original Dockerfile"
        else
            echo "⚠️  Original Dockerfile backup not found, keeping current"
        fi
        
        echo "🏗️ Building with original Dockerfile..."
        docker compose build laravel.test
        ;;
        
    3)
        echo "🧹 Cleaning Docker cache..."
        
        # Remove containers
        docker compose down
        docker compose rm -f
        
        # Clean build cache
        docker builder prune -f
        docker system prune -f
        
        # Remove images
        docker rmi $(docker images -f "reference=sail-8.4/app*" -q) 2>/dev/null || true
        
        echo "🏗️ Rebuilding from scratch..."
        docker compose build --no-cache --progress=plain laravel.test
        ;;
        
    4)
        echo "📊 Docker cache usage:"
        echo ""
        echo "=== Docker System Info ==="
        docker system df
        echo ""
        echo "=== Build Cache ==="
        docker buildx du
        echo ""
        echo "=== Images ==="
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | grep -E "(sail|laravel|SIZE)"
        ;;
        
    *)
        echo "❌ Invalid option selected"
        exit 1
        ;;
esac

echo ""
echo "✅ Build optimization completed!"
echo ""
echo "💡 Tips to speed up future builds:"
echo "   - Use .dockerignore to exclude unnecessary files"
echo "   - Leverage multi-stage builds"
echo "   - Order Dockerfile commands from least to most frequently changing"
echo "   - Use docker compose build --parallel for multiple services"