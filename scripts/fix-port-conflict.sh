#!/bin/bash

# Port Conflict Resolver Script
# This script helps resolve port conflicts and provides alternatives

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Port Conflict Resolver${NC}"

# Function to check what's using a port
check_port_usage() {
    local port=$1
    echo -e "${YELLOW}Checking what's using port $port...${NC}"
    
    # Check with different tools based on availability
    if command -v ss > /dev/null 2>&1; then
        echo "Using ss command:"
        ss -tlnp | grep ":$port " || echo "Port $port appears to be free"
    elif command -v netstat > /dev/null 2>&1; then
        echo "Using netstat command:"
        netstat -tlnp | grep ":$port " || echo "Port $port appears to be free"
    elif command -v lsof > /dev/null 2>&1; then
        echo "Using lsof command:"
        lsof -i :$port || echo "Port $port appears to be free"
    else
        echo "No port checking tools available. Install ss, netstat, or lsof"
    fi
}

# Function to kill process on port
kill_port_process() {
    local port=$1
    echo -e "${YELLOW}Attempting to free port $port...${NC}"
    
    if command -v fuser > /dev/null 2>&1; then
        echo "Using fuser to kill process on port $port..."
        fuser -k ${port}/tcp 2>/dev/null || echo "No process found on port $port"
    elif command -v lsof > /dev/null 2>&1; then
        echo "Using lsof to find and kill process on port $port..."
        PID=$(lsof -ti :$port)
        if [ ! -z "$PID" ]; then
            kill -9 $PID
            echo "Killed process $PID on port $port"
        else
            echo "No process found on port $port"
        fi
    else
        echo "Cannot kill process automatically. Please install fuser or lsof"
        echo "Or manually find and kill the process using port $port"
    fi
}

# Function to suggest alternative ports
suggest_alternative_ports() {
    echo -e "${YELLOW}Suggesting alternative ports...${NC}"
    
    local alternative_ports=(8081 8082 8083 8084 8085 3000 3001 9000 9001)
    
    for port in "${alternative_ports[@]}"; do
        if command -v ss > /dev/null 2>&1; then
            if ! ss -tlnp | grep -q ":$port "; then
                echo -e "${GREEN}✅ Port $port is available${NC}"
                return 0
            fi
        elif command -v netstat > /dev/null 2>&1; then
            if ! netstat -tlnp | grep -q ":$port "; then
                echo -e "${GREEN}✅ Port $port is available${NC}"
                return 0
            fi
        else
            echo "Port $port (check manually)"
        fi
    done
}

# Function to update configuration with new port
update_port_config() {
    local new_port=$1
    echo -e "${YELLOW}Updating configuration to use port $new_port...${NC}"
    
    # Update .env file if it exists
    if [ -f .env ]; then
        sed -i "s/APP_PORT=.*/APP_PORT=$new_port/" .env
        echo "Updated .env file"
    fi
    
    # Update .env.example
    if [ -f .env.example ]; then
        sed -i "s/APP_PORT=.*/APP_PORT=$new_port/" .env.example
        echo "Updated .env.example file"
    fi
    
    echo -e "${GREEN}Configuration updated to use port $new_port${NC}"
    echo "You can now access the application at: http://localhost:$new_port"
}

# Main execution
echo "==================================="
echo "  Port Conflict Analysis"
echo "==================================="

# Check current port usage
echo ""
echo "1. Checking port 8080 (current app port):"
check_port_usage 8080

echo ""
echo "2. Checking port 8081 (Reverb port):"
check_port_usage 8081

echo ""
echo "3. Checking port 3000 (WhatsApp server port):"
check_port_usage 3000

echo ""
echo "==================================="
echo "  Resolution Options"
echo "==================================="

echo ""
echo "Option 1: Kill existing process on port 8080"
read -p "Do you want to kill the process using port 8080? (y/N): " kill_confirm
if [[ $kill_confirm =~ ^[Yy]$ ]]; then
    kill_port_process 8080
    echo "Now try starting the containers again: make up"
else
    echo "Skipping process termination"
fi

echo ""
echo "Option 2: Use alternative port"
echo "Available alternative ports:"
suggest_alternative_ports

echo ""
read -p "Enter a new port number to use instead of 8080 (or press Enter to skip): " new_port
if [ ! -z "$new_port" ]; then
    # Validate port number
    if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge 1024 ] && [ "$new_port" -le 65535 ]; then
        update_port_config $new_port
        echo ""
        echo -e "${GREEN}✅ Configuration updated!${NC}"
        echo "Now run: make down && make up"
    else
        echo -e "${RED}❌ Invalid port number. Must be between 1024-65535${NC}"
    fi
fi

echo ""
echo "==================================="
echo "  Additional Troubleshooting"
echo "==================================="
echo ""
echo "If issues persist:"
echo "1. Check for other Docker containers: docker ps -a"
echo "2. Check for system services: systemctl list-units --type=service --state=running"
echo "3. Restart Docker service: sudo systemctl restart docker"
echo "4. Use different port range: 9000-9999"
echo ""
echo "Manual port checking commands:"
echo "- ss -tlnp | grep :8080"
echo "- netstat -tlnp | grep :8080"
echo "- lsof -i :8080"
echo "- fuser -v 8080/tcp"