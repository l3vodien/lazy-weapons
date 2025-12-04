#!/bin/bash

RED='\033[0;31m'
NC='\033[0m' # No Color

echo "==== Email & Mailbox Config Backup Tool ===="
read -p "Enter domain: " DOMAIN

# Detect cPanel user
CPUSER=$(/scripts/whoowns "$DOMAIN")
if [ -z "$CPUSER" ]; then
    echo "Cannot detect cPanel user for $DOMAIN"
    exit 1
fi

# Detect home directory
HOMEDIR=$(eval echo "~$CPUSER")
if [ ! -d "$HOMEDIR" ]; then
    echo "Home directory not found for user $CPUSER"
    exit 1
fi

MAILDIR="$HOMEDIR/mail/$DOMAIN"
ETCDIR="$HOMEDIR/etc/$DOMAIN"

# Check directories
if [ ! -d "$MAILDIR" ]; then
    echo "Mail directory not found: $MAILDIR"
    exit 1
fi

if [ ! -d "$ETCDIR" ]; then
    echo "Etc directory not found: $ETCDIR"
    exit 1
fi

# Detect UID and GID
USER_UID=$(id -u "$CPUSER")
USER_GID=$(id -g "$CPUSER")

echo "Detected cPanel user: $CPUSER"
echo "Full home directory: $HOMEDIR"
echo "User UID:GID = $USER_UID:$USER_GID"
echo

# Calculate total email size
TOTAL_BYTES=0
for EMAILDIR in "$MAILDIR"/*; do
    [ -d "$EMAILDIR" ] || continue
    SIZE_BYTES=$(du -sb "$EMAILDIR" 2>/dev/null | awk '{print $1}')
    TOTAL_BYTES=$((TOTAL_BYTES + SIZE_BYTES))
done
TOTAL_GB=$(awk -v b="$TOTAL_BYTES" 'BEGIN { printf "%.2f", b/1024/1024/1024 }')
echo "==============================="
echo "Total email size for $CPUSER - $TOTAL_GB GB"
echo "==============================="

# Detect server IP dynamically
SERVER_IP=$(hostname -I | awk '{print $1}')

# Prepare backup
BACKUP_DIR="/var/www/html"
BACKUP_FILE="${BACKUP_DIR}/${DOMAIN}-mail-etc-$(date +%Y-%m-%d).zip"

echo "Zipping emails and etc for $DOMAIN..."
zip -r "$BACKUP_FILE" "$MAILDIR" "$ETCDIR" > /dev/null 2>&1

if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}Failed to create backup. Exiting.${NC}"
    exit 1
fi

echo "Backup file created: $BACKUP_FILE"
echo
echo "==============================="
echo "Download on destination server:"
echo "1. Make sure to cd to the cPanel directories:"
echo "   cd /home/DESTUSER/"
echo "2. Download the backup using wget:"
echo "   wget http://${SERVER_IP}/$(basename $BACKUP_FILE)"
echo "3. Extract the backup:"
echo "   unzip $(basename $BACKUP_FILE) -d /home/DESTUSER/"
echo "4. After verifying on destination, remove the backup from source:"
echo "   rm -f $BACKUP_FILE"
echo "==============================="

