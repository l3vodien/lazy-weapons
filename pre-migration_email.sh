#!/bin/bash

read -p "Enter domain: " DOMAIN

# Detect cPanel user
CPUSER=$(/scripts/whoowns "$DOMAIN")
if [ -z "$CPUSER" ]; then
    echo "Cannot detect cPanel user for $DOMAIN"
    exit 1
fi

# Detect correct home path
HOMEDIR=""
for H in /home /home1 /home2 /home3 /home*; do
    if [ -d "$H/$CPUSER" ]; then
        HOMEDIR="$H/$CPUSER"
        break
    fi
done

if [ -z "$HOMEDIR" ]; then
    echo "ERROR: Could not find home directory for $CPUSER"
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
