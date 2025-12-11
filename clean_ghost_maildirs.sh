#!/bin/bash

echo "=== Ghost Maildir Cleaner ==="
read -p "Enter domain: " DOMAIN

# Detect cPanel user
CPUSER=$(/scripts/whoowns "$DOMAIN")
if [ -z "$CPUSER" ]; then
    echo "❌ Cannot detect cPanel user for $DOMAIN"
    exit 1
fi

MAILDIR="/home/$CPUSER/mail/$DOMAIN"

echo "User: $CPUSER"
echo "Domain: $DOMAIN"
echo "Maildir: $MAILDIR"

if [ ! -d "$MAILDIR" ]; then
    echo "❌ Mail directory not found: $MAILDIR"
    exit 1
fi

echo
echo "=== Checking for ghost maildirs… ==="

declare -a GHOSTS=()

# Loop through folders inside /mail/domain.com
for DIR in "$MAILDIR"/*; do
    if [ -d "$DIR" ]; then
        MAILUSER=$(basename "$DIR")

        # Skip system folders
        [[ "$MAILUSER" == "cur" || "$MAILUSER" == "new" || "$MAILUSER" == "tmp" ]] && continue

        # Check if email exists in cPanel
        EXISTS=$(uapi --user=$CPUSER Email list_pops \
            | jq -r '.result.data[].email' \
            | grep -w "${MAILUSER}@${DOMAIN}")

        if [ -z "$EXISTS" ]; then
            GHOSTS+=("$MAILUSER")
        fi
    fi
done

if [ ${#GHOSTS[@]} -eq 0 ]; then
    echo "✅ No ghost maildirs found."
    exit 0
fi

echo
echo "Ghost maildirs detected:"
printf '%s\n' "${GHOSTS[@]}"

echo
read -p "Delete these ghost maildirs? (y/N): " CONFIRM
if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    for GHOST in "${GHOSTS[@]}"; do
        echo "Deleting $MAILDIR/$GHOST ..."
        rm -rf "$MAILDIR/$GHOST"
    do
