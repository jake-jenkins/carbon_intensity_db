#!/bin/bash

# Setup automated backups using cron
# This script adds a cron job to run backups automatically

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get the absolute path to the backup script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SCRIPT="${SCRIPT_DIR}/backup.sh"

# Make backup script executable
chmod +x "${BACKUP_SCRIPT}"

echo -e "${YELLOW}Automated Backup Setup${NC}"
echo ""
echo "This will add a cron job to automatically backup your database."
echo ""
echo "Available schedules:"
echo "  1) Daily at 2:00 AM"
echo "  2) Daily at 3:00 AM (recommended - after daily totals job)"
echo "  3) Twice daily (2:00 AM and 2:00 PM)"
echo "  4) Every 6 hours"
echo "  5) Custom cron expression"
echo ""
echo -e "${YELLOW}Select option (1-5):${NC}"
read OPTION

case ${OPTION} in
    1)
        CRON_SCHEDULE="0 2 * * *"
        DESCRIPTION="Daily at 2:00 AM"
        ;;
    2)
        CRON_SCHEDULE="0 3 * * *"
        DESCRIPTION="Daily at 3:00 AM"
        ;;
    3)
        CRON_SCHEDULE="0 2,14 * * *"
        DESCRIPTION="Twice daily (2:00 AM and 2:00 PM)"
        ;;
    4)
        CRON_SCHEDULE="0 */6 * * *"
        DESCRIPTION="Every 6 hours"
        ;;
    5)
        echo -e "${YELLOW}Enter custom cron expression (e.g., '0 3 * * *'):${NC}"
        read CRON_SCHEDULE
        DESCRIPTION="Custom schedule: ${CRON_SCHEDULE}"
        ;;
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

# Create cron job entry
CRON_JOB="${CRON_SCHEDULE} cd ${SCRIPT_DIR} && ${BACKUP_SCRIPT} >> ${SCRIPT_DIR}/backup.log 2>&1"

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "${BACKUP_SCRIPT}"; then
    echo -e "${YELLOW}Removing existing backup cron job...${NC}"
    crontab -l 2>/dev/null | grep -v "${BACKUP_SCRIPT}" | crontab -
fi

# Add new cron job
echo "Adding cron job..."
(crontab -l 2>/dev/null; echo "${CRON_JOB}") | crontab -

echo -e "${GREEN}✓ Automated backup configured successfully${NC}"
echo ""
echo "Schedule: ${DESCRIPTION}"
echo "Script: ${BACKUP_SCRIPT}"
echo "Logs: ${SCRIPT_DIR}/backup.log"
echo ""
echo "To view current cron jobs:"
echo "  crontab -l"
echo ""
echo "To remove this cron job:"
echo "  crontab -e"
echo "  (then delete the line containing '${BACKUP_SCRIPT}')"
echo ""
echo -e "${GREEN}First backup will run at the scheduled time.${NC}"
echo "You can test it now by running: ${BACKUP_SCRIPT}"