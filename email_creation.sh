#!/bin/bash

echo "Enter domain:"
read DOMAIN

# Detect cPanel user that owns the domain
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
    echo -n "Enter email username (or 'exit' to stop): "
    read USERNAME

    [[ "$USERNAME" == "exit" ]] && break

    # Check if email already exists
    EXISTS=$(uapi --user="$CPUSER" Email list_pops \
        | grep -E "\"email\": \"$USERNAME@$DOMAIN\"" )

    if [[ -n "$EXISTS" ]]; then
        echo "⚠ Email $USERNAME@$DOMAIN already exists! Skipping..."
        continue
    fi

    # Ask for password
    echo -n "Enter password for $USERNAME@$DOMAIN: "
    read -s PASSWORD
    echo ""

    # Create the email
    RESULT=$(uapi --user="$CPUSER" Email add_pop \
        email="$USERNAME" \
        password="$PASSWORD" \
        domain="$DOMAIN" \
        quota=1024 2>&1)

    if echo "$RESULT" | grep -q '"status": 1'; then
        echo "✅ Created: $USERNAME@$DOMAIN"
    else
        echo "❌ ERROR creating $USERNAME@$DOMAIN"
        echo "$RESULT"
    fi

    echo "-------------------------------------"
done

echo "Done!"
