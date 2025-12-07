#!/bin/bash

# List all available backups with details

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

BACKUP_DIR="./backups"

echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}         Carbon Intensity Database Backups            ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""

if [ ! -d "${BACKUP_DIR}" ] || [ -z "$(ls -A ${BACKUP_DIR}/carbon_intensity_*.sql.gz 2>/dev/null)" ]; then
    echo -e "${YELLOW}No backups found${NC}"
    exit 0
fi

# Show latest backup link
if [ -L "${BACKUP_DIR}/latest.sql.gz" ]; then
    LATEST=$(readlink "${BACKUP_DIR}/latest.sql.gz")
    echo -e "${GREEN}Latest backup: ${LATEST}${NC}"
    echo ""
fi

# List all backups with details
echo -e "${YELLOW}Available backups:${NC}"
echo ""
printf "%-25s %-12s %-20s\n" "FILENAME" "SIZE" "DATE"
echo "────────────────────────────────────────────────────────────"

ls -lh "${BACKUP_DIR}"/carbon_intensity_*.sql.gz 2>/dev/null | \
    awk '{print $9, $5, $6, $7, $8}' | \
    while read filepath size month day time; do
        filename=$(basename "$filepath")
        printf "%-25s %-12s %-20s\n" "$filename" "$size" "$month $day $time"
    done

echo ""

# Show total count and size
TOTAL_COUNT=$(ls -1 "${BACKUP_DIR}"/carbon_intensity_*.sql.gz 2>/dev/null | wc -l)
TOTAL_SIZE=$(du -sh "${BACKUP_DIR}" 2>/dev/null | cut -f1)

echo "────────────────────────────────────────────────────────────"
echo -e "Total backups: ${GREEN}${TOTAL_COUNT}${NC}"
echo -e "Total size: ${GREEN}${TOTAL_SIZE}${NC}"
echo ""

# Show quick restore command
echo -e "${CYAN}To restore a backup:${NC}"
echo "  ./restore.sh <filename>"
echo "  ./restore.sh latest"