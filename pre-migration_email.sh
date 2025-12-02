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

# Loop through email accounts
for EMAILDIR in "$MAILDIR"/*; do
    [ -d "$EMAILDIR" ] || continue

    EMAILUSER=$(basename "$EMAILDIR")
    FULL_EMAIL="$EMAILUSER@$DOMAIN"

    TOTAL=$(du -sh "$EMAILDIR" 2>/dev/null | awk '{print $1}')

    echo "=== $FULL_EMAIL ==="
    echo "Total: $TOTAL"
    echo
done
