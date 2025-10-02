#!/bin/bash

echo "🔧 Docker Services Fix Script"
echo "============================="

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Error: docker-compose.yml not found. Please run this script from the project root."
    exit 1
fi

echo "📋 Stopping containers..."
docker compose down

echo "🏗️ Rebuilding containers..."
docker compose build --no-cache

echo "🚀 Starting containers..."
docker compose up -d

echo "⏳ Waiting for containers to be ready..."
sleep 15

echo "🔧 Fixing permissions and dependencies..."

# Fix public directory permissions for FrankenPHP worker
echo "📁 Fixing public directory permissions..."
docker compose exec laravel.test chown -R sail:sail /var/www/html/public
docker compose exec laravel.test chmod -R 755 /var/www/html/public

# Install PHP dependencies and setup Octane
echo "🔧 Setting up Laravel Octane..."
docker compose exec laravel.test composer install --no-dev --optimize-autoloader
docker compose exec laravel.test php artisan octane:install --server=frankenphp

# Install Node.js dependencies
echo "📦 Installing Node.js dependencies..."
docker compose exec laravel.test npm install

# Install WhatsApp server dependencies
echo "📱 Installing WhatsApp server dependencies..."
docker compose exec laravel.test bash -c "cd /var/www/html/whatsapp-server && npm install"

# Fix storage permissions
echo "📁 Fixing storage permissions..."
docker compose exec laravel.test chown -R sail:sail /var/www/html/storage
docker compose exec laravel.test chmod -R 755 /var/www/html/storage

# Create necessary cache directories
echo "📂 Creating cache directories..."
docker compose exec laravel.test php artisan config:cache
docker compose exec laravel.test php artisan route:cache
docker compose exec laravel.test php artisan view:cache

echo "🔄 Restarting services..."
docker compose restart laravel.test

echo "⏳ Waiting for services to restart..."
sleep 20

echo "📊 Checking container status..."
docker compose ps

echo "📋 Checking service logs..."
echo ""
echo "=== OCTANE LOGS ==="
docker compose exec laravel.test tail -10 /var/www/html/storage/logs/octane.log 2>/dev/null || echo "No octane logs yet"

echo ""
echo "=== VITE LOGS ==="
docker compose exec laravel.test tail -10 /var/www/html/storage/logs/vite.log 2>/dev/null || echo "No vite logs yet"

echo ""
echo "=== WHATSAPP LOGS ==="
docker compose exec laravel.test tail -10 /var/www/html/storage/logs/whatsapp.log 2>/dev/null || echo "No whatsapp logs yet"

echo ""
echo "✅ Services fix completed!"
echo "🌐 Application should be available at: http://localhost:8082"
echo ""
echo "To monitor services:"
echo "  docker compose logs -f laravel.test"