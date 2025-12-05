#!/bin/bash

RED='\033[0;31m'
NC='\033[0m' # No Color

read -p "Enter domain: " DOMAIN

# Detect cPanel user
CPUSER=$(/scripts/whoowns "$DOMAIN")
if [ -z "$CPUSER" ]; then
    echo "Cannot detect cPanel user for $DOMAIN"
    exit 1
fi

# Auto-detect home directory
HOMEDIR=$(eval echo "~$CPUSER")

if [ ! -d "$HOMEDIR" ]; then
    echo "Home directory not found for user $CPUSER"
    exit 1
fi

# Extract base home directory (e.g., /home, /home5)
BASEHOME=$(dirname "$HOMEDIR")

MAILDIR="$HOMEDIR/mail/$DOMAIN"

if [ ! -d "$MAILDIR" ]; then
    echo "Mail directory not found: $MAILDIR"
    exit 1
fi

# Detect UID and GID
USER_UID=$(id -u "$CPUSER")
USER_GID=$(id -g "$CPUSER")

echo "Detected cPanel user: $CPUSER"
echo "Full home directory: $HOMEDIR"
echo "Base home directory: $BASEHOME"
echo "User UID:GID = $USER_UID:$USER_GID"
echo

### GET MX RECORD ###
MX_RECORD=$(dig +short MX "$DOMAIN" | sort -n | head -1 | awk '{print $2}')

if [ -z "$MX_RECORD" ]; then
    echo -e "${RED}No MX record found for $DOMAIN${NC}"
else
    ### RESOLVE MX → A RECORD ###
    MX_IP=$(dig +short A "$MX_RECORD" | head -1)

    echo "=== MX RECORD INFORMATION ==="
    echo "MX Host : $MX_RECORD"
    echo "MX IP   : ${MX_IP:-No A record found}"
    echo "==============================="
fi

TOTAL_BYTES=0

# Loop through email accounts
for EMAILDIR in "$MAILDIR"/*; do
    [ -d "$EMAILDIR" ] || continue

    EMAILUSER=$(basename "$EMAILDIR")
    FULL_EMAIL="$EMAILUSER@$DOMAIN"

    SIZE_BYTES=$(du -sb "$EMAILDIR" 2>/dev/null | awk '{print $1}')
    SIZE_HR=$(du -sh "$EMAILDIR" 2>/dev/null | awk '{print $1}')
    TOTAL_BYTES=$((TOTAL_BYTES + SIZE_BYTES))

    SIZE_GB=$(awk -v b="$SIZE_BYTES" 'BEGIN { printf "%.2f", b/1024/1024/1024 }')

    # Flash entire email in red if >10GB
    if (( $(echo "$SIZE_GB > 10" | bc -l) )); then
        echo -e "=== ${RED}$FULL_EMAIL  <-- WARNING: Exceeds 10GB!${NC} ==="
        echo -e "Total: ${RED}$SIZE_HR${NC}"
    else
        echo "=== $FULL_EMAIL ==="
        echo "Total: $SIZE_HR"
    fi
    echo
done

# Convert total bytes to human-readable GB
TOTAL_GB=$(awk -v b="$TOTAL_BYTES" 'BEGIN { printf "%.2f", b/1024/1024/1024 }')

echo "==============================="
echo "Total email size for $CPUSER - $TOTAL_GB GB"
echo "==============================="


# Detect server IP dynamically
SERVER_IP=$(hostname -I | awk '{print $1}')

# Print migration path

echo "==============================="
echo -e "Email migration path: ${SERVER_IP}:${MAILDIR}/"
echo "==============================="
