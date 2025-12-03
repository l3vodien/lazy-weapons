#!/bin/bash

read -p "Enter domain: " DOMAIN

# Detect cPanel user
CPUSER=$(/scripts/whoowns "$DOMAIN")
if [ -z "$CPUSER" ]; then
    echo "Cannot detect cPanel user for $DOMAIN"
    exit 1
fi

# Auto-detect home directory
HOMEDIR=$(eval echo "~$CPUSER")

if [ ! -d "$HOMEDIR" ]; then
    echo "Home directory not found for user $CPUSER"
    exit 1
fi

# Extract base home directory (e.g., /home, /home5)
BASEHOME=$(dirname "$HOMEDIR")

MAILDIR="$HOMEDIR/mail/$DOMAIN"

if [ ! -d "$MAILDIR" ]; then
    echo "Mail directory not found: $MAILDIR"
    exit 1
fi

# Detect UID and GID
USER_UID=$(id -u "$CPUSER")
USER_GID=$(id -g "$CPUSER")

echo "Detected cPanel user: $CPUSER"
echo "Full home directory: $HOMEDIR"
echo "Base home directory: $BASEHOME"
echo "User UID:GID = $USER_UID:$USER_GID"
echo

TOTAL_BYTES=0

# Loop through email accounts
for EMAILDIR in "$MAILDIR"/*; do
    [ -d "$EMAILDIR" ] || continue

    EMAILUSER=$(basename "$EMAILDIR")
    FULL_EMAIL="$EMAILUSER@$DOMAIN"

    SIZE=$(du -sb "$EMAILDIR" 2>/dev/null | awk '{print $1}')
    TOTAL_BYTES=$((TOTAL_BYTES + SIZE))

    HSIZE=$(du -sh "$EMAILDIR" 2>/dev/null | awk '{print $1}')

    echo "=== $FULL_EMAIL ==="
    echo "Total: $HSIZE"
    echo
done

# Convert total bytes to human-readable GB
TOTAL_GB=$(awk -v b="$TOTAL_BYTES" 'BEGIN { printf "%.2f", b/1024/1024/1024 }')

echo "==============================="
echo "Total email size for $CPUSER - $TOTAL_GB GB"
echo "==============================="
echo 
