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

###Get Server hostname ###
SERVER_NAME=$(hostname)

echo
echo "=== SERVER INFORMATION ==="
echo "Server Name: $SERVER_NAME"
echo "=========================="
echo ""

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
if (( SIZE_BYTES > 10*1024*1024*1024 )); then
    echo "=== $FULL_EMAIL  <-- WARNING: Exceeds 10GB! ==="
    echo "Total: $SIZE_HR"
else
    echo "=== $FULL_EMAIL ==="
    echo "Total: $SIZE_HR"
fi
    echo
done

# Convert total bytes to human-readable GB
TOTAL_GB=$(awk -v b="$TOTAL_BYTES" 'BEGIN { printf "%.2f", b/1024/1024/1024 }')

echo "=============================================="
echo "Total email size for $CPUSER - $TOTAL_GB GB"
echo "=============================================="

### Userdata directory (MUST come first)
USERDATA_DIR="/var/cpanel/userdata/$CPUSER"

[ -d "$USERDATA_DIR" ] || {
    echo "Userdata directory not found: $USERDATA_DIR"
    exit 1
}

echo
echo "======== DOMAIN INFORMATION + STATUS ========"

USERDATA_DIR="/var/cpanel/userdata/$CPUSER"
[ -d "$USERDATA_DIR" ] || { echo "Userdata directory not found: $USERDATA_DIR"; exit 1; }

# Function: get authoritative A record
get_a_record() {
    local DOMAIN=$1
    local FOUND=0

    # Direct zone
    ZONE_FILE="/var/named/${DOMAIN}.db"
    if [ -f "$ZONE_FILE" ]; then
        A_REC=$(awk '
            BEGIN { IGNORECASE=1 }
            /^[^;].*[[:space:]]A[[:space:]]/ {
                if ($1=="@" || $1=="'"$DOMAIN"'." || $1=="'"$DOMAIN"'") print $NF
            }
        ' "$ZONE_FILE" | sort -u | tr '\n' ' ')
        [ -n "$A_REC" ] && { echo "$A_REC"; return 0; }
    fi

    # Subdomain lookup (parent zone)
    for Z in /var/named/*.db; do
        ZONENAME=$(basename "$Z" .db)
        if [[ "$DOMAIN" == *".${ZONENAME}" ]]; then
            SUB=${DOMAIN%%.$ZONENAME}
            A_REC=$(awk '
                BEGIN { IGNORECASE=1 }
                /^[^;].*[[:space:]]A[[:space:]]/ {
                    if ($1=="'"$SUB"'" || $1=="'"$SUB"'." ) print $NF
                }
            ' "$Z" | sort -u | tr '\n' ' ')
            [ -n "$A_REC" ] && { echo "$A_REC"; return 0; }
        fi
    done

    echo "No A record (not local or CNAME)"
}

# Function: check HTTP status
get_http_status() {
    local DOMAIN=$1
    curl -o /dev/null -s -w "%{http_code}" "http://$DOMAIN"
}

# --- Main domain ---
MAIN_DOMAIN=$(awk '/^main_domain:/ {print $2}' "$USERDATA_DIR/main" 2>/dev/null)
MAIN_IP=$(get_a_record "$MAIN_DOMAIN")
MAIN_STATUS=$(get_http_status "$MAIN_DOMAIN")
echo "Main domain: $MAIN_DOMAIN - $MAIN_IP - HTTP $MAIN_STATUS"

# --- Addon domains ---
ADDON_DOMAINS=$(awk '/addon:/ {print $2}' "$USERDATA_DIR"/* 2>/dev/null | sort -u)
echo
echo "Addon domains:"
if [ -n "$ADDON_DOMAINS" ]; then
    for D in $ADDON_DOMAINS; do
        IP=$(get_a_record "$D")
        STATUS=$(get_http_status "$D")
        echo "$D - $IP - HTTP $STATUS"
    done
else
    echo "None"
fi

# --- Parked / Aliases ---
PARKED_DOMAINS=$(awk '/parked:/ {print $2}' "$USERDATA_DIR"/* 2>/dev/null | sort -u)
echo
echo "Parked / Aliases:"
if [ -n "$PARKED_DOMAINS" ]; then
    for D in $PARKED_DOMAINS; do
        IP=$(get_a_record "$D")
        STATUS=$(get_http_status "$D")
        echo "$D - $IP - HTTP $STATUS"
    done
else
    echo "None"
fi

echo "============================================"

echo ""
echo "======== DISK USAGE PER DOMAIN ========"

# Function to get folder size in human-readable form
get_size() {
    local DIR=$1
    [ -d "$DIR" ] || { echo "0"; return; }
    du -sh "$DIR" 2>/dev/null | awk '{print $1}'
}

# --- Main domain ---
MAIN_DOCROOT="$HOMEDIR/public_html"
MAIN_SIZE=$(get_size "$MAIN_DOCROOT")
echo "Main domain: $MAIN_DOMAIN - $MAIN_SIZE"

# --- Addon domains ---
if [ -n "$ADDON_DOMAINS" ]; then
    for D in $ADDON_DOMAINS; do
        # Default addon docroot pattern in cPanel: /home/user/addon_domain
        ADDON_DOCROOT=$(grep -R "^documentroot:" "$USERDATA_DIR"/* 2>/dev/null \
            | grep "$D" | awk '{print $2}' | head -1)
        [ -z "$ADDON_DOCROOT" ] && ADDON_DOCROOT="$HOMEDIR/$D/public_html"
        SIZE=$(get_size "$ADDON_DOCROOT")
        echo "Addon domain: $D - $SIZE"
    done
else
    echo "Addon domains: None"
fi

# --- Parked / Aliases ---
if [ -n "$PARKED_DOMAINS" ]; then
    for D in $PARKED_DOMAINS; do
        # Parked domains usually point to main domain docroot
        SIZE=$(get_size "$MAIN_DOCROOT")
        echo "Parked / Alias: $D - $SIZE"
    done
else
    echo "Parked / Aliases: None"
fi

echo "======================================="

### MySQL databases + sizes ####

echo
echo "========== MYSQL DATABASE USAGE =========="

DB_LIST=$(mysql -N -e "SHOW DATABASES;" | grep "^${CPUSER}_")

if [ -z "$DB_LIST" ]; then
    echo "No databases found"
else
    for DB in $DB_LIST; do
        SIZE_MB=$(mysql -N -e "
            SELECT ROUND(SUM(data_length+index_length)/1024/1024,2)
            FROM information_schema.tables
            WHERE table_schema='$DB';
        ")
        SIZE_MB=${SIZE_MB:-0}
        echo "Database: $DB - ${SIZE_MB} MB"
    done
fi


echo "======================================="

### CMS / CRM detection (WordPress, Joomla, Laravel, etc.) ####

echo
echo "======= CMS / CRM DETECTION ======="

DOCROOT="$HOMEDIR/public_html"

# WORDPRESS
if [ -f "$DOCROOT/wp-config.php" ]; then
    WP_VERSION=$(grep -E "wp_version\s*=" "$DOCROOT/wp-includes/version.php" 2>/dev/null \
        | head -1 | awk -F"'" '{print $2}')

    echo "Detected CMS: WordPress"
    echo "Version     : ${WP_VERSION:-Unknown}"
    
# JOOMLA
elif [ -f "$DOCROOT/configuration.php" ]; then
    JOOMLA_VERSION=$(grep "public \$RELEASE" "$DOCROOT/libraries/src/Version.php" 2>/dev/null \
        | awk -F"'" '{print $2}')
    echo "Detected CMS: Joomla"
    echo "Version     : ${JOOMLA_VERSION:-Unknown}"

# MAGENTO
elif [ -f "$DOCROOT/app/etc/env.php" ]; then
    MAGENTO_VERSION=$(grep "'version'" "$DOCROOT/composer.json" 2>/dev/null \
        | head -1 | awk -F'"' '{print $4}')
    echo "Detected CMS: Magento"
    echo "Version     : ${MAGENTO_VERSION:-Unknown}"

# LARAVEL
elif [ -f "$DOCROOT/artisan" ]; then
    LARAVEL_VERSION=$(grep '"laravel/framework"' "$DOCROOT/composer.lock" 2>/dev/null \
        | head -1 | awk -F'"' '{print $4}')
    echo "Detected Framework: Laravel"
    echo "Version          : ${LARAVEL_VERSION:-Unknown}"

# DRUPAL 7
elif [ -f "$DOCROOT/includes/bootstrap.inc" ]; then
    DRUPAL_VERSION=$(grep "define('VERSION'" "$DOCROOT/includes/bootstrap.inc" 2>/dev/null \
        | awk -F"'" '{print $4}')
    echo "Detected CMS: Drupal"
    echo "Version     : ${DRUPAL_VERSION:-Unknown}"

# DRUPAL 8+
elif [ -f "$DOCROOT/core/lib/Drupal.php" ]; then
    DRUPAL_VERSION=$(grep "const VERSION" "$DOCROOT/core/lib/Drupal.php" 2>/dev/null \
        | awk -F"'" '{print $2}')
    echo "Detected CMS: Drupal"
    echo "Version     : ${DRUPAL_VERSION:-Unknown}"

else
    echo "CMS/CRM: Not detected (custom or static)"
fi

echo "===================================="

# Detect server IP dynamically
SERVER_IP=$(hostname -I | awk '{print $1}')

# Print migration path
echo ""
echo "==============================================================================="
echo -e "Email migration path: ${SERVER_IP}:${HOMEDIR}/mail/"
echo -e "Shadow and passwd migration path: ${SERVER_IP}:${HOMEDIR}/etc/"
echo -e "Webfiles migration path: ${SERVER_IP}:${HOMEDIR}/public_html/"
echo "==============================================================================="
