#!/bin/bash

# Herobot Health Monitor Script
# This script monitors the health of all Docker containers and services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_PROJECT_NAME="herobot"
LOG_FILE="/tmp/herobot_health.log"

echo "==================================="
echo "    Herobot Health Check Report"
echo "==================================="
echo "Timestamp: $(date)"
echo ""

# Function to check container health
check_container_health() {
    local container_name=$1
    local status=$(docker-compose ps -q $container_name | xargs docker inspect --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
    
    case $status in
        "healthy")
            echo -e "${GREEN}✓${NC} $container_name: Healthy"
            ;;
        "unhealthy")
            echo -e "${RED}✗${NC} $container_name: Unhealthy"
            return 1
            ;;
        "starting")
            echo -e "${YELLOW}⚠${NC} $container_name: Starting"
            ;;
        *)
            echo -e "${YELLOW}?${NC} $container_name: Unknown status ($status)"
            ;;
    esac
}

# Function to check container running status
check_container_running() {
    local container_name=$1
    local status=$(docker-compose ps -q $container_name | xargs docker inspect --format='{{.State.Status}}' 2>/dev/null || echo "not_found")
    
    case $status in
        "running")
            echo -e "${GREEN}✓${NC} $container_name: Running"
            ;;
        "exited")
            echo -e "${RED}✗${NC} $container_name: Exited"
            return 1
            ;;
        "restarting")
            echo -e "${YELLOW}⚠${NC} $container_name: Restarting"
            ;;
        *)
            echo -e "${RED}✗${NC} $container_name: Not found or stopped"
            return 1
            ;;
    esac
}

# Function to check service endpoints
check_service_endpoint() {
    local name=$1
    local url=$2
    local expected_code=${3:-200}
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    
    if [ "$response" = "$expected_code" ]; then
        echo -e "${GREEN}✓${NC} $name: Responding ($response)"
    else
        echo -e "${RED}✗${NC} $name: Not responding (got $response, expected $expected_code)"
        return 1
    fi
}

# Function to check database connectivity
check_database() {
    local result=$(docker-compose exec -T mariadb mysql -u root -e "SELECT 1;" 2>/dev/null || echo "error")
    
    if [ "$result" != "error" ]; then
        echo -e "${GREEN}✓${NC} Database: Accessible"
    else
        echo -e "${RED}✗${NC} Database: Connection failed"
        return 1
    fi
}

# Function to check Redis connectivity
check_redis() {
    local result=$(docker-compose exec -T redis redis-cli ping 2>/dev/null || echo "error")
    
    if [ "$result" = "PONG" ]; then
        echo -e "${GREEN}✓${NC} Redis: Responding"
    else
        echo -e "${RED}✗${NC} Redis: Connection failed"
        return 1
    fi
}

# Function to check Laravel application
check_laravel() {
    local result=$(docker-compose exec -T laravel.test php artisan about --only=environment 2>/dev/null || echo "error")
    
    if [ "$result" != "error" ]; then
        echo -e "${GREEN}✓${NC} Laravel: Application healthy"
    else
        echo -e "${RED}✗${NC} Laravel: Application error"
        return 1
    fi
}

# Function to check disk space
check_disk_space() {
    local usage=$(df /var/lib/docker | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$usage" -lt 80 ]; then
        echo -e "${GREEN}✓${NC} Disk Space: ${usage}% used"
    elif [ "$usage" -lt 90 ]; then
        echo -e "${YELLOW}⚠${NC} Disk Space: ${usage}% used (warning)"
    else
        echo -e "${RED}✗${NC} Disk Space: ${usage}% used (critical)"
        return 1
    fi
}

# Function to check memory usage
check_memory() {
    local total_memory=$(docker stats --no-stream --format "table {{.MemUsage}}" | grep -v "MEM" | awk -F'/' '{sum+=$1} END {print sum}' | sed 's/[^0-9.]//g')
    local available_memory=$(free -m | awk 'NR==2{printf "%.1f", $7/1024}')
    
    echo -e "${GREEN}✓${NC} Memory: ${total_memory}GB used, ${available_memory}GB available"
}

# Main health check
echo "1. Container Status Check"
echo "------------------------"
check_container_running "laravel.test"
check_container_running "mariadb"
check_container_running "redis"

echo ""
echo "2. Health Check"
echo "---------------"
check_container_health "mariadb" || true
check_container_health "redis" || true

echo ""
echo "3. Service Connectivity"
echo "----------------------"
check_database || true
check_redis || true
check_laravel || true

echo ""
echo "4. Resource Usage"
echo "----------------"
check_disk_space || true
check_memory || true

echo ""
echo "5. Recent Logs (Last 10 lines)"
echo "------------------------------"
echo "Laravel Application:"
docker-compose logs --tail=5 laravel.test 2>/dev/null | tail -5 || echo "No logs available"

echo ""
echo "Database:"
docker-compose logs --tail=5 mariadb 2>/dev/null | tail -5 || echo "No logs available"

echo ""
echo "==================================="
echo "Health check completed at $(date)"
echo "==================================="

# Log the health check
echo "Health check completed at $(date)" >> "$LOG_FILE"