#!/bin/bash

read -p "Enter domain: " DOMAIN

CPUSER=$(/scripts/whoowns "$DOMAIN")
if [ -z "$CPUSER" ]; then
    echo "Cannot detect cPanel username for $DOMAIN"
    exit 1
fi

MAILDIR="/home/$CPUSER/mail/$DOMAIN"
if [ ! -d "$MAILDIR" ]; then
    echo "Mail directory not found: $MAILDIR"
    exit 1
fi

echo "Detected cPanel user: $CPUSER"
echo

for EMAIL in "$MAILDIR"/*; do
    [ -d "$EMAIL" ] || continue
    EMAILUSER=$(basename "$EMAIL")
    FULL_EMAIL="$EMAILUSER@$DOMAIN"

    echo "=== $FULL_EMAIL ==="

    # List folders
    MAILBOXES=$(doveadm mailbox list -u "$FULL_EMAIL" 2>/dev/null)

    for FOLDER in $MAILBOXES; do
        # Correct doveadm usage with field "sizes"
        SIZE_BYTES=$(doveadm mailbox status -u "$FULL_EMAIL" sizes "$FOLDER" 2>/dev/null | awk '{print $1}')
        SIZE_BYTES=${SIZE_BYTES:-0}
        SIZE_HR=$(numfmt --to=iec --suffix=B "$SIZE_BYTES")
        echo "$SIZE_HR    /home/$CPUSER/mail/$DOMAIN/$EMAILUSER/$FOLDER"
    done

    TOTAL=$(du -sh "$EMAIL" 2>/dev/null | awk '{print $1}')
    echo "Total: $TOTAL"
    echo
done
