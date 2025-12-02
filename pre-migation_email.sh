#!/bin/bash

# Prompt for username and domain
read -p "Enter cPanel username: " CPUSER
read -p "Enter domain: " DOMAIN

MAILDIR="/home/$CPUSER/mail/$DOMAIN"

if [ ! -d "$MAILDIR" ]; then
    echo "Mail directory $MAILDIR not found!"
    exit 1
fi

echo "Scanning: $MAILDIR"
echo

# List each mailbox folder size
du -shc "$MAILDIR"/* 2>/dev/null
