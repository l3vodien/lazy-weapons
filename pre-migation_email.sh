#!/bin/bash

# Prompt for domain
read -p "Enter domain: " DOMAIN

# Detect cPanel username
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

# Loop over each email account
for EMAIL in "$MAILDIR"/*; do
    [ -d "$EMAIL" ] || continue
    EMAILUSER=$(basename "$EMAIL")
    FULL_EMAIL="$EMAILUSER@$DOMAIN"

    echo "=== $FULL_EMAIL ==="

    # List all mailboxes via doveadm
    doveadm mailbox list -u "$FULL_EMAIL" 2>/dev/null | while read FOLDER; do
        # Get size in bytes
        SIZE_BYTES=$(doveadm mailbox status -u "$FULL_EMAIL" sizes "$FOLDER" 2>/dev/null | awk '{print $1}')
        # Convert to human readable
        SIZE_HR=$(numfmt --to=iec --suffix=B ${SIZE_BYTES:-0})
        echo "$SIZE_HR    /home/$CPUSER/mail/$DOMAIN/$EMAILUSER/$FOLDER"
    done

    # Optional: total mailbox size
    TOTAL_SIZE=$(du -sh "$EMAIL" 2>/dev/null | awk '{print $1}')
    echo "Total: $TOTAL_SIZE"
    echo
done
