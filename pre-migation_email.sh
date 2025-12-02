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

for EMAILDIR in "$MAILDIR"/*; do
    [ -d "$EMAILDIR" ] || continue
    EMAILUSER=$(basename "$EMAILDIR")
    FULL_EMAIL="$EMAILUSER@$DOMAIN"

    echo "=== $FULL_EMAIL ==="

    # INBOX (main folder)
    INBOX_SIZE=$(du -sh "$EMAILDIR" 2>/dev/null | awk '{print $1}')
    echo "$INBOX_SIZE    $EMAILDIR/ (INBOX)"

    # Loop for extra folders starting with .
    for SUB in "$EMAILDIR"/.*; do
        BASENAME=$(basename "$SUB")

        [[ "$BASENAME" == "." || "$BASENAME" == ".." ]] && continue
        [[ ! -d "$SUB" ]] && continue

        # Convert ".Sent" → "INBOX.Sent"
        FRIENDLY="INBOX${BASENAME}"

        SIZE=$(du -sh "$SUB" 2>/dev/null | awk '{print $1}')
        echo "$SIZE    $SUB ($FRIENDLY)"
    done

    echo
done
