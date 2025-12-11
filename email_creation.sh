#!/bin/bash

echo "Enter domain:"
read DOMAIN

CPUSER=$(/scripts/whoowns "$DOMAIN")

if [[ -z "$CPUSER" ]]; then
    echo "Error: Cannot detect cPanel user for domain $DOMAIN"
    exit 1
fi

echo "Detected cPanel user: $CPUSER"
echo "-------------------------------------"
echo "Start creating emails for $DOMAIN"
echo "Type 'exit' as username to quit"
echo "-------------------------------------"

while true; do
    echo -n "Enter email username (or 'exit' to stop) e.i. info: "
    read USERNAME

    [[ "$USERNAME" == "exit" ]] && break

    # Check existing email
    EXISTS=$(uapi --user="$CPUSER" Email list_pops \
        | grep -E "\"email\": \"$USERNAME@$DOMAIN\"" )

    if [[ -n "$EXISTS" ]]; then
        echo "⚠ Email $USERNAME@$DOMAIN already exists! Skipping..."
        continue
    fi

    echo -n "Enter password for $USERNAME@$DOMAIN: "
    read -s PASSWORD
    echo ""

    # Create mailbox (quota 0 = unlimited)
    RESULT=$(uapi --user="$CPUSER" Email add_pop \
        email="$USERNAME" \
        password="$PASSWORD" \
        domain="$DOMAIN" \
        quota=0 )

    STATUS=$(echo "$RESULT" | grep -m1 "status:" | awk '{print $2}')

    if [[ "$STATUS" == "1" ]]; then
        echo "✅ SUCCESS: Created $USERNAME@$DOMAIN (UNLIMITED)"
    else
        echo "❌ ERROR creating $USERNAME@$DOMAIN"
        echo "-----"
        echo "$RESULT"
    fi

    echo "-------------------------------------"
done

echo "Done!"
