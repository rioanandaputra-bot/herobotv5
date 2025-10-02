# 🚀 Herobot Quick Setup Guide

## Prerequisites Installation (Ubuntu/Debian)

If you encounter the error: `docker-compose: No such file or directory`, follow this guide:

### Option 1: Automated Setup (Recommended)
```bash
# Run the automated setup script
chmod +x ./scripts/setup.sh
sudo ./scripts/setup.sh
```

### Option 2: Manual Installation

#### Step 1: Install Docker
```bash
# Update package index
sudo apt update

# Install required packages
sudo apt install -y ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Add current user to docker group (optional, to run without sudo)
sudo usermod -aG docker $USER
```

#### Step 2: Install Docker Compose
```bash
# Install Docker Compose standalone
sudo curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Create symlink for compatibility
sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Verify installation
docker-compose --version
```

#### Step 3: Install Additional Dependencies
```bash
sudo apt install -y make curl wget git unzip nano htop net-tools
```

## 🎯 Herobot Setup

### Quick Start
```bash
# Copy environment file
cp .env.example .env

# Run automated setup
make dev-setup
```

### Manual Setup (if automated fails)
```bash
# 1. Create environment file
cp .env.example .env

# 2. Create data directories
mkdir -p data/mysql data/redis
sudo chown -R 1000:1000 data/

# 3. Start services
make up

# 4. Wait for services to be ready (about 1-2 minutes)
make health

# 5. Check logs if needed
make logs
```

## 🔧 Common Commands

```bash
# Check all available commands
make help

# View service status
make health

# View logs
make logs

# Access application shell
make shell

# Stop all services
make down

# Restart services
make restart

# Clean up and restart fresh
make clean && make up
```

## 🚨 Troubleshooting

### Docker Compose not found
```bash
# Use the setup script
sudo ./scripts/setup.sh

# Or install manually (see Step 2 above)
```

### Permission denied errors
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Logout and login again, or run:
newgrp docker
```

### Services not starting
```bash
# Check system resources
free -h
df -h

# Check Docker status
sudo systemctl status docker

# Check specific service logs
make logs-app
make logs-db
```

### Port already in use
```bash
# Check what's using the ports
sudo netstat -tlnp | grep -E ':8082|:3306|:6379'

# Kill processes using the ports if needed
sudo fuser -k 8082/tcp
sudo fuser -k 3306/tcp
sudo fuser -k 6379/tcp
```

### Database connection issues
```bash
# Wait for database to be ready
sleep 30

# Check database logs
make logs-db

# Reset database
make down
make up
```

## 📊 System Requirements

### Minimum Requirements:
- **CPU**: 2 cores
- **RAM**: 4GB
- **Storage**: 20GB free space
- **OS**: Ubuntu 20.04+ / Debian 11+

### Recommended:
- **CPU**: 4+ cores
- **RAM**: 8GB+
- **Storage**: 50GB+ SSD
- **Network**: Stable internet connection

## 🔗 Useful URLs

After successful setup:
- **Application**: http://your-server-ip:8082
- **Database**: your-server-ip:3306
- **Redis**: your-server-ip:6379

## 📞 Need Help?

1. **Check logs**: `make logs`
2. **Health check**: `make health`
3. **Run diagnostics**: `./scripts/health-check.sh`
4. **Clean restart**: `make clean && make up`

---

**Note**: Always run setup commands as root or with sudo privileges.