#!/bin/bash

# Herobot Automated Backup Script
# This script creates automated backups of database and application files

set -e

# Configuration
BACKUP_DIR="/tmp/herobot-backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo -e "${GREEN}Starting Herobot backup process...${NC}"
echo "Backup directory: $BACKUP_DIR"
echo "Timestamp: $DATE"

# Function to log messages
log_message() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# Function to handle errors
handle_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Database backup
log_message "Creating database backup..."
if docker-compose ps -q mariadb > /dev/null 2>&1; then
    # Get database credentials from .env file
    if [ -f .env ]; then
        DB_NAME=$(grep "^DB_DATABASE=" .env | cut -d '=' -f2)
        DB_USER=$(grep "^DB_USERNAME=" .env | cut -d '=' -f2)
        DB_PASS=$(grep "^DB_PASSWORD=" .env | cut -d '=' -f2)
        
        # Create database backup
        docker-compose exec -T mariadb mysqldump \
            -u "$DB_USER" \
            -p"$DB_PASS" \
            --single-transaction \
            --routines \
            --triggers \
            "$DB_NAME" > "$BACKUP_DIR/database_$DATE.sql"
        
        log_message "Database backup completed: database_$DATE.sql"
    else
        handle_error ".env file not found"
    fi
else
    handle_error "MariaDB container is not running"
fi

# Application files backup (excluding unnecessary files)
log_message "Creating application files backup..."
tar --exclude='./node_modules' \
    --exclude='./vendor' \
    --exclude='./storage/logs/*' \
    --exclude='./storage/framework/cache/*' \
    --exclude='./storage/framework/sessions/*' \
    --exclude='./storage/framework/views/*' \
    --exclude='./data' \
    --exclude='./.git' \
    -czf "$BACKUP_DIR/application_$DATE.tar.gz" .

log_message "Application files backup completed: application_$DATE.tar.gz"

# Storage files backup
log_message "Creating storage backup..."
if [ -d "./storage/app" ]; then
    tar -czf "$BACKUP_DIR/storage_$DATE.tar.gz" ./storage/app
    log_message "Storage backup completed: storage_$DATE.tar.gz"
fi

# Configuration backup
log_message "Creating configuration backup..."
tar -czf "$BACKUP_DIR/config_$DATE.tar.gz" \
    .env.example \
    docker-compose.yml \
    docker-compose.override.yml \
    Makefile \
    ./docker/ \
    ./config/ 2>/dev/null || true

log_message "Configuration backup completed: config_$DATE.tar.gz"

# Cleanup old backups
log_message "Cleaning up old backups (keeping last $RETENTION_DAYS days)..."
find "$BACKUP_DIR" -name "*.sql" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete

# Generate backup report
log_message "Generating backup report..."
echo "========================" > "$BACKUP_DIR/backup_report_$DATE.txt"
echo "Herobot Backup Report" >> "$BACKUP_DIR/backup_report_$DATE.txt"
echo "Date: $(date)" >> "$BACKUP_DIR/backup_report_$DATE.txt"
echo "========================" >> "$BACKUP_DIR/backup_report_$DATE.txt"
echo "" >> "$BACKUP_DIR/backup_report_$DATE.txt"
echo "Files created:" >> "$BACKUP_DIR/backup_report_$DATE.txt"
ls -lh "$BACKUP_DIR"/*_$DATE.* >> "$BACKUP_DIR/backup_report_$DATE.txt" 2>/dev/null || true
echo "" >> "$BACKUP_DIR/backup_report_$DATE.txt"
echo "Total backup size:" >> "$BACKUP_DIR/backup_report_$DATE.txt"
du -sh "$BACKUP_DIR" >> "$BACKUP_DIR/backup_report_$DATE.txt"

# Display backup summary
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}   Backup Process Completed     ${NC}"
echo -e "${GREEN}================================${NC}"
echo "Backup location: $BACKUP_DIR"
echo "Files created:"
ls -1 "$BACKUP_DIR"/*_$DATE.* 2>/dev/null || echo "No files created"
echo ""
echo -e "${YELLOW}Total backup size:${NC}"
du -sh "$BACKUP_DIR"
echo ""
echo -e "${GREEN}Backup completed successfully!${NC}"