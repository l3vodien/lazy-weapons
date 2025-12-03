#!/bin/bash

read -p "Enter domain: " DOMAIN

# Detect cPanel user
CPUSER=$(/scripts/whoowns "$DOMAIN")
if [ -z "$CPUSER" ]; then
    echo "Cannot detect cPanel user for $DOMAIN"
    exit 1
fi

# Auto-detect home directory like "cd ~user"
HOMEDIR=$(eval echo "~$CPUSER")

# Validate home directory
if [ ! -d "$HOMEDIR" ]; then
    echo "Home directory not found for user $CPUSER"
    exit 1
fi

MAILDIR="$HOMEDIR/mail/$DOMAIN"

# Validate mail directory
if [ ! -d "$MAILDIR" ]; then
    echo "Mail directory not found: $MAILDIR"
    exit 1
fi

echo "Detected cPanel user: $CPUSER"
echo "Home directory: $HOMEDIR"
echo

# Track total size in bytes
TOTAL_BYTES=0

# Loop through email accounts
for EMAILDIR in "$MAILDIR"/*; do
    [ -d "$EMAILDIR" ] || continue

    EMAILUSER=$(basename "$EMAILDIR")
    FULL_EMAIL="$EMAILUSER@$DOMAIN"

    # Get size in bytes
    SIZE_BYTES=$(du -sb "$EMAILDIR" 2>/dev/null | awk '{print $1}')
    TOTAL_BYTES=$((TOTAL_BYTES + SIZE_BYTES))

    # Human readable per-email
    SIZE_HR=$(du -sh "$EMAILDIR" 2>/dev/null | awk '{print $1}')

    echo "=== $FULL_EMAIL ==="
    echo "Total: $SIZE_HR"
    echo
done

# Convert total bytes manually
if (( TOTAL_BYTES >= 1073741824 )); then
    TOTAL_HR=$(awk "BEGIN {printf \"%.2f GB\", $TOTAL_BYTES/1073741824}")
elif (( TOTAL_BYTES >= 1048576 )); then
    TOTAL_HR=$(awk "BEGIN {printf \"%.2f MB\", $TOTAL_BYTES/1048576}")
elif (( TOTAL_BYTES >= 1024 )); then
    TOTAL_HR=$(awk "BEGIN {printf \"%.2f KB\", $TOTAL_BYTES/1024}")
else
    TOTAL_HR="$TOTAL_BYTES Bytes"
fi

echo "==============================="
echo "Total email size for $CPUSER - $TOTAL_HR"
echo "==============================="
