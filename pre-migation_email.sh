#!/bin/bash

read -p "Enter domain: " DOMAIN

CPUSER=$(/scripts/whoowns "$DOMAIN")
if [ -z "$CPUSER" ]; then
    echo "Cannot detect cPanel user for $DOMAIN"
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

    # Fetch mailbox list silently
    MAILBOXES=$(doveadm mailbox list -u "$FULL_EMAIL" 2>/dev/null)

    # Loop through each mailbox
    while IFS= read -r FOLDER; do
        [ -z "$FOLDER" ] && continue

        # Get mailbox size using Dovecot
        BYTES=$(doveadm mailbox status -u "$FULL_EMAIL" bytes "$FOLDER" 2>/dev/null | awk '{print $1}')
        BYTES=${BYTES:-0}

        # Convert to human readable
        HR=$(numfmt --to=iec --suffix=B <<< "$BYTES")

        echo "$HR    $EMAIL/$FOLDER"

    done <<< "$MAILBOXES"

    # Total physical size from disk
    TOTAL=$(du -sh "$EMAIL" 2>/dev/null | awk '{print $1}')
    echo "Total: $TOTAL"
    echo
done
