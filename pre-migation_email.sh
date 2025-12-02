#!/bin/bash

# Ask for domain only
read -p "Enter domain: " DOMAIN

# Find the cPanel user who owns the domain
CPUSER=$(/scripts/whoowns "$DOMAIN" 2>/dev/null)

# Validate
if [ -z "$CPUSER" ]; then
    echo "Unable to determine cPanel username for domain: $DOMAIN"
    exit 1
fi

MAILDIR="/home/$CPUSER/mail/$DOMAIN"

if [ ! -d "$MAILDIR" ]; then
    echo "Mail directory not found: $MAILDIR"
    exit 1
fi

echo "Detected cPanel user: $CPUSER"
echo "Scanning mailbox: $MAILDIR"
echo

# Output sizes just like du -shc
du -shc "$MAILDIR"/* 2>/dev/null
