#!/bin/bash

# Carbon Intensity Database Backup Script
# This script creates timestamped backups of the PostgreSQL database

set -e  # Exit on error

# Configuration
BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/carbon_intensity_${TIMESTAMP}.sql"
RETENTION_DAYS=30  # Keep backups for 30 days

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

# Verify required environment variables
if [ -z "$DB_HOST" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
    echo -e "${RED}Error: Missing required environment variables (DB_HOST, DB_NAME, DB_USER, DB_PASSWORD)${NC}"
    exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p "${BACKUP_DIR}"

echo -e "${YELLOW}Starting backup at $(date)${NC}"
echo "Database: ${DB_NAME}"
echo "Host: ${DB_HOST}"

# Create backup using pg_dump
echo "Creating backup..."
PGPASSWORD="${DB_PASSWORD}" pg_dump \
    -h "${DB_HOST}" \
    -p "${DB_PORT:-5432}" \
    -U "${DB_USER}" \
    -d "${DB_NAME}" \
    --format=plain \
    --no-owner \
    --no-acl \
    > "${BACKUP_FILE}"

# Compress backup
echo "Compressing backup..."
gzip "${BACKUP_FILE}"
BACKUP_FILE="${BACKUP_FILE}.gz"

# Get backup file size
BACKUP_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)

echo -e "${GREEN}✓ Backup completed successfully${NC}"
echo "File: ${BACKUP_FILE}"
echo "Size: ${BACKUP_SIZE}"

# Clean up old backups
echo "Cleaning up old backups (older than ${RETENTION_DAYS} days)..."
find "${BACKUP_DIR}" -name "carbon_intensity_*.sql.gz" -type f -mtime +${RETENTION_DAYS} -delete

# Count remaining backups
BACKUP_COUNT=$(ls -1 "${BACKUP_DIR}"/carbon_intensity_*.sql.gz 2>/dev/null | wc -l)
echo -e "${GREEN}Current backups: ${BACKUP_COUNT}${NC}"

# Optional: Create a "latest" symlink
ln -sf "$(basename ${BACKUP_FILE})" "${BACKUP_DIR}/latest.sql.gz"

echo -e "${GREEN}Backup process completed at $(date)${NC}"