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

### A records for all domains ####
echo
echo "=== DNS A RECORDS ==="

ALL_DOMAINS=$(grep -R "domain:" "$USERDATA_DIR" | awk '{print $2}' | sort -u)

for D in $ALL_DOMAINS; do
    A_REC=$(dig +short A "$D" | tr '\n' ' ')
    echo "$D → ${A_REC:-No A record}"
done

echo "======================="

### Get Domains: main, addon, parked, aliases ####
echo
echo "=== DOMAIN INFORMATION ==="

USERDATA_DIR="/var/cpanel/userdata/$CPUSER"

MAIN_DOMAIN=$(grep '^main_domain:' "$USERDATA_DIR/main" 2>/dev/null | awk '{print $2}')

echo "Main domain: $MAIN_DOMAIN"

echo
echo "Addon domains:"
grep -R "addon: " "$USERDATA_DIR" | awk '{print $2}' | sort -u || echo "None"

echo
echo "Parked / Aliases:"
grep -R "parked: " "$USERDATA_DIR" | awk '{print $2}' | sort -u || echo "None"

echo "=========================="

### Quick HTTP status check (200 / 301 / 403 / 500) ###
echo
echo "=== QUICK DOMAIN STATUS CHECK ==="

for D in $ALL_DOMAINS; do
    STATUS=$(curl -o /dev/null -s -w "%{http_code}" "http://$D")
    echo "$D → HTTP $STATUS"
done

echo "================================="

### MySQL databases + sizes ####

echo
echo "=== MYSQL DATABASE USAGE ==="

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
echo "=== CMS / CRM DETECTION ==="

DOCROOT="$HOMEDIR/public_html"

# WORDPRESS
if [ -f "$DOCROOT/wp-config.php" ]; then
    WP_VERSION=$(grep "\$wp_version" "$DOCROOT/wp-includes/version.php" 2>/dev/null \
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

echo "======================================="


# Detect server IP dynamically
SERVER_IP=$(hostname -I | awk '{print $1}')

# Print migration path
echo "==============================================================================="
echo -e "Email migration path: ${SERVER_IP}:${HOMEDIR}/mail/"
echo -e "Shadow and passwd migration path: ${SERVER_IP}:${HOMEDIR}/etc/"
echo -e "Webfiles migration path: ${SERVER_IP}:${HOMEDIR}/public_html/"
echo "==============================================================================="
