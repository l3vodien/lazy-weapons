#!/bin/bash

read -p "Enter domain: " DOMAIN

# Get cPanel user
CPUSER=$(/scripts/whoowns "$DOMAIN")
if [ -z "$CPUSER" ]; then
    echo "Cannot detect cPanel user for $DOMAIN"
    exit 1
fi

# Search possible home directories
HOMEDIR=""
for PATH in /home /home1 /home2 /home3 /home*; do
    if [ -d "$PATH/$CPUSER" ]; then
        HOMEDIR="$PATH/$CPUSER"
        break
    fi
done

if [ -z "$HOMEDIR" ]; then
    echo "Cannot find home directory for user $CPUSER"
    exit 1
fi

MAILDIR="$HOMEDIR/mail/$DOMAIN"
if [ ! -d "$MAILDIR" ]; then
    echo "Mail directory not found: $MAILDIR"
    exit 1
fi

echo "Detected cPanel user: $CPUSER"
echo "Home directory: $HOMEDIR"
echo

# Loop through each email folder
for EMAILDIR in "$MAILDIR"/*; do
    [ -d "$EMAILDIR" ] || continue

    EMAILUSER=$(basename "$EMAILDIR")
    FULL_EMAIL="$EMAILUSER@$DOMAIN"

    TOTAL=$(du -sh "$EMAILDIR" 2>/dev/null | awk '{print $1}')

    echo "=== $FULL_EMAIL ==="
    echo "Total: $TOTAL"
    echo
done
