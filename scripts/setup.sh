#!/bin/bash

# Herobot Setup Script - Dependency Checker and Installer
# This script checks and installs required dependencies for Herobot

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}======================================${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get OS information
get_os_info() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
}

# Function to install Docker
install_docker() {
    print_status "Installing Docker..."
    
    # Update package index
    apt-get update
    
    # Install packages to allow apt to use a repository over HTTPS
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up the repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    print_status "Docker installed successfully!"
}

# Function to install Docker Compose standalone
install_docker_compose() {
    print_status "Installing Docker Compose..."
    
    # Download and install Docker Compose
    DOCKER_COMPOSE_VERSION="v2.23.0"
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Create symlink for compatibility
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    print_status "Docker Compose installed successfully!"
}

# Function to check Docker installation
check_docker() {
    if command_exists docker; then
        print_status "Docker is installed: $(docker --version)"
        
        # Check if Docker is running
        if systemctl is-active --quiet docker; then
            print_status "Docker service is running"
        else
            print_warning "Docker service is not running. Starting..."
            systemctl start docker
        fi
    else
        print_error "Docker is not installed"
        return 1
    fi
}

# Function to check Docker Compose installation
check_docker_compose() {
    if command_exists docker-compose; then
        print_status "Docker Compose is installed: $(docker-compose --version)"
    elif docker compose version >/dev/null 2>&1; then
        print_status "Docker Compose (plugin) is installed: $(docker compose version)"
        # Create alias for compatibility
        if [ ! -f /usr/local/bin/docker-compose ]; then
            echo '#!/bin/bash' > /usr/local/bin/docker-compose
            echo 'docker compose "$@"' >> /usr/local/bin/docker-compose
            chmod +x /usr/local/bin/docker-compose
        fi
    else
        print_error "Docker Compose is not installed"
        return 1
    fi
}

# Function to install other dependencies
install_dependencies() {
    print_status "Installing other dependencies..."
    
    apt-get update
    apt-get install -y \
        curl \
        wget \
        git \
        unzip \
        make \
        nano \
        htop \
        net-tools
    
    print_status "Dependencies installed successfully!"
}

# Function to setup Herobot environment
setup_herobot() {
    print_status "Setting up Herobot environment..."
    
    # Copy environment file if it doesn't exist
    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            cp .env.example .env
            print_status "Environment file created from .env.example"
        else
            print_error ".env.example file not found"
            return 1
        fi
    else
        print_status "Environment file already exists"
    fi
    
    # Create data directories
    mkdir -p data/mysql data/redis
    
    # Set proper permissions
    chown -R 1000:1000 data/
    
    print_status "Herobot environment setup completed!"
}

# Function to start services
start_services() {
    print_status "Starting Herobot services..."
    
    # Use docker compose or docker-compose based on availability
    if command_exists docker-compose; then
        docker-compose up -d
    elif docker compose version >/dev/null 2>&1; then
        docker compose up -d
    else
        print_error "Neither docker-compose nor docker compose plugin is available"
        return 1
    fi
    
    print_status "Services started successfully!"
    
    # Wait a bit for services to start
    sleep 10
    
    # Show status
    print_status "Checking service status..."
    if command_exists docker-compose; then
        docker-compose ps
    else
        docker compose ps
    fi
}

# Main function
main() {
    print_header "Herobot Dependency Checker and Setup"
    
    # Get OS info
    get_os_info
    print_status "Detected OS: $OS $VER"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run this script as root (use sudo)"
        exit 1
    fi
    
    # Check and install dependencies
    print_header "Checking Dependencies"
    
    # Check Docker
    if ! check_docker; then
        print_warning "Installing Docker..."
        install_docker
    fi
    
    # Check Docker Compose
    if ! check_docker_compose; then
        print_warning "Installing Docker Compose..."
        install_docker_compose
    fi
    
    # Install other dependencies
    if ! command_exists make; then
        print_warning "Installing additional dependencies..."
        install_dependencies
    fi
    
    # Setup environment
    print_header "Setting up Herobot"
    setup_herobot
    
    # Start services
    print_header "Starting Services"
    start_services
    
    print_header "Setup Complete!"
    print_status "Herobot has been set up successfully!"
    print_status "You can now use the following commands:"
    echo ""
    echo "  make help           - Show all available commands"
    echo "  make logs           - View service logs"
    echo "  make shell          - Access application shell"
    echo "  make health         - Check service health"
    echo ""
    print_status "Access your application at: http://$(hostname -I | awk '{print $1}'):8080"
}

# Run main function
main "$@"