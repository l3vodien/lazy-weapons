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

echo "✔ User detected: $CPUSER"
echo "✔ Domain: $DOMAIN"
echo "✔ Maildir path: $MAILDIR"
echo

if [ ! -d "$MAILDIR" ]; then
    echo "❌ Mail directory not found."
    exit 1
fi

# Get valid email usernames
VALID_USERS=$(uapi --user=$CPUSER Email list_pops \
    | jq -r '.result.data[].email' \
    | sed "s/@$DOMAIN//")

echo "=== Valid Email Users ==="
echo "$VALID_USERS"
echo

declare -a GHOSTS=()

for DIR in "$MAILDIR"/*; do
    [ -d "$DIR" ] || continue

    USERNAME=$(basename "$DIR")

    # Skip system dirs
    case "$USERNAME" in
        cur|new|tmp) continue ;;
    esac

    # Check if USERNAME is a valid email account
    if ! echo "$VALID_USERS" | grep -q "^$USERNAME$"; then
        GHOSTS+=("$USERNAME")
    fi
done

if [ ${#GHOSTS[@]} -eq 0 ]; then
    echo "✅ No ghost maildirs found."
    exit 0
fi

echo "=== GHOST MAILDIRS DETECTED ==="
printf '%s\n' "${GHOSTS[@]}"
echo

read -p "Delete these ghost maildirs? (y/N): " CONFIRM

if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    for GHOST in "${GHOSTS[@]}"; do
        echo "🗑 Deleting: $MAILDIR/$GHOST"
        rm -rf "$MAILDIR/$GHOST"
    done

    echo
    echo "✔ Fixing quotas for real users…"

    for USER in $VALID_USERS; do
        EMAIL="$USER@$DOMAIN"
        doveadm quota recalc -u "$EMAIL" 2>/dev/null
    done

    echo "✅ Cleanup complete!"
else
    echo "❌ Aborted."
fi
