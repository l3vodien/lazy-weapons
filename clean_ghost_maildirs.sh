#!/bin/bash

### CONFIG ###
CPUSER="USERNAME_HERE"
DOMAIN="DOMAIN_HERE"


MAILDIR="/home/$CPUSER/mail/$DOMAIN"
PASSFILE="/home/$CPUSER/etc/$DOMAIN/passwd"

echo ""
echo "=== Ghost Maildir Cleaner ==="
echo "User: $CPUSER"
echo "Domain: $DOMAIN"
echo ""

# Check files exist
if [[ ! -d "$MAILDIR" ]]; then
    echo "Mail directory not found: $MAILDIR"
    exit 1
fi

if [[ ! -f "$PASSFILE" ]]; then
    echo "Passwd file not found: $PASSFILE"
    exit 1
fi

echo "Scanning for ghost maildirs..."
echo ""

ghosts=()

for d in "$MAILDIR"/*/; do
    base=$(basename "$d" /)

    # Skip system folders
    [[ "$base" == "cur" || "$base" == "new" || "$base" == "tmp" ]] && continue

    if ! grep -qE "^$base:" "$PASSFILE"; then
        ghosts+=("$base")
    fi
done

if [[ ${#ghosts[@]} -eq 0 ]]; then
    echo "No ghost maildirs found. Everything looks healthy."
    exit 0
fi

echo "Found ${#ghosts[@]} ghost maildirs:"
printf '%s\n' "${ghosts[@]}"
echo ""

read -p "Proceed with deletion (Y/N)? " confirm
if [[ "$confirm" != "Y" && "$confirm" != "y" ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Starting deletion..."
echo ""

for user in "${ghosts[@]}"; do
    read -p "Delete maildir for $user ? (Y/N): " ans
    if [[ "$ans" == "Y" || "$ans" == "y" ]]; then
        rm -rf "$MAILDIR/$user"
        echo "Deleted: $MAILDIR/$user"
    else
        echo "Skipped: $user"
    fi
done

echo ""
echo "=== Fixing Dovecot Quotas ==="
echo ""

for user in $(grep -oE '^[^:]+' "$PASSFILE"); do
    echo "Recalculating quota for: $user@$DOMAIN"
    doveadm quota recalc -u "$user@$DOMAIN" >/dev/null 2>&1
done

echo ""
echo "Cleanup complete!"
echo "Dovecot quota recalculated for valid accounts."
echo ""
