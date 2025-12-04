#!/bin/bash

echo "=== Email Archiver & Fallback Migration Tool ==="
read -p "Enter domain: " DOMAIN
echo ""

# Detect cPanel user
CPUSER=$(/scripts/whoowns "$DOMAIN")
if [ -z "$CPUSER" ]; then
    echo "❌ Cannot detect cPanel user for $DOMAIN"
    exit 1
fi

# Detect home directory
HOMEDIR=$(eval echo "~$CPUSER")

if [ ! -d "$HOMEDIR" ]; then
    echo "❌ Home directory not found: $HOMEDIR"
    exit 1
fi

MAILDIR="$HOMEDIR/mail/$DOMAIN"

if [ ! -d "$MAILDIR" ]; then
    echo "❌ Mail directory not found: $MAILDIR"
    exit 1
fi

echo "Detected cPanel user: $CPUSER"
echo "Mail directory: $MAILDIR"
echo ""

# Detect server public IP
SERVER_IP=$(hostname -I | tr ' ' '\n' | grep -Ev '^10\.|^192\.168\.|^172\.(1[6-9]|2[0-9]|3[0-1])\.' | head -n1)

if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(hostname -I | awk '{print $1}')
fi

# Create ZIP filename
TS=$(date +%Y%m%d_%H%M%S)
ZIPFILE="${DOMAIN}_email_backup_${TS}.zip"

echo "Creating archive: $ZIPFILE"
echo ""

# Zip email directory
zip -r "/var/www/html/$ZIPFILE" "$MAILDIR" >/dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "❌ Failed to create ZIP archive!"
    exit 1
fi

echo "✅ ZIP created successfully and moved to /var/www/html/"
echo ""

# Print final download path
echo "========================================="
echo "Email Archive Created:"
echo "/var/www/html/$ZIPFILE"
echo ""
echo "Download URL:"
echo "http://${SERVER_IP}/${ZIPFILE}"
echo "========================================="
