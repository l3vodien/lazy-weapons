#!/bin/bash

echo "=== Ghost Maildir Cleaner ==="

read -p "Enter domain: " DOMAIN

# Detect cPanel user
CPUSER=$(/scripts/whoowns "$DOMAIN")

if [ -z "$CPUSER" ]; then
    echo "❌ Could not detect cPanel user for $DOMAIN"
    exit 1
fi

MAILDIR="/home/$CPUSER/mail/$DOMAIN"

echo "User: $CPUSER"
echo "Domain: $DOMAIN"
echo "Mail directory: $MAILDIR"
echo

if [ ! -d "$MAILDIR" ]; then
    echo "❌ Mail directory not found: $MAILDIR"
    exit 1
fi

# List valid email users
VALID_USERS=$(uapi --user=$CPUSER Email list_pops \
    | jq -r '.result.data[].email' \
    | cut -d@ -f1)

echo "=== Valid Email Accounts ==="
echo "$VALID_USERS"
echo

echo "=== Backend Maildirs ==="
BACKEND_DIRS=$(ls -1 "$MAILDIR")
echo "$BACKEND_DIRS"
echo

echo "=== Detecting Ghost Directories ==="

GHOSTS=()

for DIR in $BACKEND_DIRS; do
    if ! echo "$VALID_USERS" | grep -qx "$DIR"; then
        GHOSTS+=("$DIR")
    fi
done

if [ ${#GHOSTS[@]} -eq 0 ]; then
    echo "✅ No ghost maildirs found."
    exit 0
fi

echo
echo "=== GHOST MAILDIRS FOUND ==="
printf "%s\n" "${GHOSTS[@]}"
echo

read -p "Delete these ghost maildirs? (y/N): " YESNO

if [[ "$YESNO" =~ ^[Yy]$ ]]; then
    for DIR in "${GHOSTS[@]}"; do
        echo "🗑 Removing: $MAILDIR/$DIR"
        rm -rf "$MAILDIR/$DIR"
    done
    echo "✔ Cleanup done."
else
    echo "❌ Aborted."
fi
