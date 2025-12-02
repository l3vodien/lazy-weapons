#!/bin/bash

# Prompt for domain
read -p "Enter domain: " DOMAIN

# Get cPanel user
CPUSER=$(/scripts/whoowns "$DOMAIN" 2>/dev/null)
if [ -z "$CPUSER" ]; then
    echo "Unable to detect cPanel user for domain $DOMAIN"
    exit 1
fi

MAILDIR="/home/$CPUSER/mail/$DOMAIN"
if [ ! -d "$MAILDIR" ]; then
    echo "Mail directory not found: $MAILDIR"
    exit 1
fi

echo "Detected cPanel user: $CPUSER"
echo "Scanning mailboxes for domain: $DOMAIN"
echo

# Loop over each email account in the domain
for EMAIL in "$MAILDIR"/*; do
    [ -d "$EMAIL" ] || continue
    EMAILUSER=$(basename "$EMAIL")
    FULL_EMAIL="$EMAILUSER@$DOMAIN"

    echo "=== $FULL_EMAIL ==="

    # List all Dovecot mailboxes/folders for this user
    doveadm mailbox list -u "$FULL_EMAIL" 2>/dev/null | while read FOLDER; do
        # Get mailbox size in bytes
        SIZE_BYTES=$(doveadm mailbox status -u "$FULL_EMAIL" sizes | grep "^$FOLDER " | awk '{print $2}')
        
        # Convert to human readable
        if [ -n "$SIZE_BYTES" ]; then
            SIZE_HR=$(numfmt --to=iec --suffix=B "$SIZE_BYTES")
        else
            SIZE_HR="0B"
        fi

        echo "$SIZE_HR    /home/$CPUSER/mail/$DOMAIN/$EMAILUSER/$FOLDER"
    done

    # Optional: total mailbox size using du
    TOTAL_SIZE=$(du -sh "$EMAIL" 2>/dev/null | awk '{print $1}')
    echo "Total: $TOTAL_SIZE"
    echo
done
