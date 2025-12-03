#!/bin/bash

# Carbon Intensity Database Restore Script
# This script restores a database backup

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DIR="./backups"

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

# List available backups
echo -e "${YELLOW}Available backups:${NC}"
echo ""
ls -lh "${BACKUP_DIR}"/carbon_intensity_*.sql.gz 2>/dev/null || {
    echo -e "${RED}No backups found in ${BACKUP_DIR}${NC}"
    exit 1
}
echo ""

# Prompt for backup file
if [ -z "$1" ]; then
    echo -e "${YELLOW}Enter the backup filename (or 'latest' for most recent):${NC}"
    read BACKUP_INPUT
else
    BACKUP_INPUT="$1"
fi

# Handle 'latest' keyword
if [ "${BACKUP_INPUT}" = "latest" ]; then
    BACKUP_FILE="${BACKUP_DIR}/latest.sql.gz"
    if [ ! -L "${BACKUP_FILE}" ]; then
        echo -e "${RED}No 'latest' backup found${NC}"
        exit 1
    fi
else
    # Check if full path was provided
    if [[ "${BACKUP_INPUT}" == *"/"* ]]; then
        BACKUP_FILE="${BACKUP_INPUT}"
    else
        BACKUP_FILE="${BACKUP_DIR}/${BACKUP_INPUT}"
    fi
fi

# Verify backup file exists
if [ ! -f "${BACKUP_FILE}" ]; then
    echo -e "${RED}Error: Backup file not found: ${BACKUP_FILE}${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}WARNING: This will overwrite the current database!${NC}"
echo "Database: ${DB_NAME}"
echo "Host: ${DB_HOST}"
echo "Backup file: ${BACKUP_FILE}"
echo ""
echo -e "${RED}Type 'yes' to continue:${NC}"
read CONFIRM

if [ "${CONFIRM}" != "yes" ]; then
    echo "Restore cancelled"
    exit 0
fi

echo -e "${YELLOW}Starting restore at $(date)${NC}"

# Create a safety backup before restore
SAFETY_BACKUP="${BACKUP_DIR}/pre_restore_$(date +"%Y%m%d_%H%M%S").sql.gz"
echo "Creating safety backup first..."
PGPASSWORD="${DB_PASSWORD}" pg_dump \
    -h "${DB_HOST}" \
    -p "${DB_PORT:-5432}" \
    -U "${DB_USER}" \
    -d "${DB_NAME}" \
    --format=plain \
    --no-owner \
    --no-acl \
    | gzip > "${SAFETY_BACKUP}"
echo -e "${GREEN}✓ Safety backup created: ${SAFETY_BACKUP}${NC}"

# Decompress backup to temp file
TEMP_SQL="/tmp/restore_${RANDOM}.sql"
echo "Decompressing backup..."
gunzip -c "${BACKUP_FILE}" > "${TEMP_SQL}"

# Drop existing tables (to avoid conflicts)
echo "Dropping existing tables..."
PGPASSWORD="${DB_PASSWORD}" psql \
    -h "${DB_HOST}" \
    -p "${DB_PORT:-5432}" \
    -U "${DB_USER}" \
    -d "${DB_NAME}" \
    <<-EOSQL
    DROP TABLE IF EXISTS public.live CASCADE;
    DROP TABLE IF EXISTS public.day CASCADE;
EOSQL

# Restore backup
echo "Restoring database..."
PGPASSWORD="${DB_PASSWORD}" psql \
    -h "${DB_HOST}" \
    -p "${DB_PORT:-5432}" \
    -U "${DB_USER}" \
    -d "${DB_NAME}" \
    < "${TEMP_SQL}"

# Clean up temp file
rm "${TEMP_SQL}"

# Verify restore
echo "Verifying restore..."
LIVE_COUNT=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT:-5432}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "SELECT COUNT(*) FROM public.live;" | xargs)
DAY_COUNT=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT:-5432}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "SELECT COUNT(*) FROM public.day;" | xargs)

echo -e "${GREEN}✓ Restore completed successfully${NC}"
echo "Records in 'live' table: ${LIVE_COUNT}"
echo "Records in 'day' table: ${DAY_COUNT}"
echo -e "${GREEN}Restore process completed at $(date)${NC}"
echo ""
echo -e "${YELLOW}Safety backup saved at: ${SAFETY_BACKUP}${NC}"