#!/bin/bash

RED='\033[0;31m'
NC='\033[0m' # No Color

read -p "Enter domain: " DOMAIN

# Detect cPanel user
CPUSER=$(/scripts/whoowns "$DOMAIN")
if [ -z "$CPUSER" ]; then
    echo "❌ Cannot detect cPanel user for $DOMAIN"
    exit 1
fi

# Auto-detect home directory
HOMEDIR=$(eval echo "~$CPUSER")
if [ ! -d "$HOMEDIR" ]; then
    echo "❌ Home directory not found for user $CPUSER"
    exit 1
fi

BASEHOME=$(dirname "$HOMEDIR")
MAILDIR="$HOMEDIR/mail/$DOMAIN"
if [ ! -d "$MAILDIR" ]; then
    echo "❌ Mail directory not found: $MAILDIR"
    exit 1
fi

USER_UID=$(id -u "$CPUSER")
USER_GID=$(id -g "$CPUSER")
SERVER_NAME=$(hostname)

echo
echo "====== SERVER INFORMATION ======"
echo "Server Name: $SERVER_NAME"
echo "================================"
echo "Detected cPanel user: $CPUSER"
echo "Full home directory: $HOMEDIR"
echo "Base home directory: $BASEHOME"
echo "User UID:GID = $USER_UID:$USER_GID"
echo

# MX record
MX_RECORD=$(dig +short MX "$DOMAIN" | sort -n | head -1 | awk '{print $2}')
if [ -z "$MX_RECORD" ]; then
    echo -e "${RED}No MX record found for $DOMAIN${NC}"
else
    MX_IP=$(dig +short A "$MX_RECORD" | head -1)
    echo "=== MX RECORD INFORMATION ==="
    echo "MX Host : $MX_RECORD"
    echo "MX IP   : ${MX_IP:-No A record found}"
    echo "==============================="
    echo
fi

# Email usage
TOTAL_BYTES=0
for EMAILDIR in "$MAILDIR"/*; do
    [ -d "$EMAILDIR" ] || continue
    EMAILUSER=$(basename "$EMAILDIR")
    FULL_EMAIL="$EMAILUSER@$DOMAIN"
    SIZE_BYTES=$(du -sb "$EMAILDIR" 2>/dev/null | awk '{print $1}')
    SIZE_HR=$(du -sh "$EMAILDIR" 2>/dev/null | awk '{print $1}')
    TOTAL_BYTES=$((TOTAL_BYTES + SIZE_BYTES))
    if (( SIZE_BYTES > 10*1024*1024*1024 )); then
        echo "=== $FULL_EMAIL  <-- WARNING: Exceeds 10GB! ==="
        echo "Total: $SIZE_HR"
    else
        echo "=== $FULL_EMAIL ==="
        echo "Total: $SIZE_HR"
    fi
    echo
done
TOTAL_GB=$(awk -v b="$TOTAL_BYTES" 'BEGIN { printf "%.2f", b/1024/1024/1024 }')
echo "=============================================="
echo "Total email size for $CPUSER - $TOTAL_GB GB"
echo "=============================================="

USERDATA_DIR="/var/cpanel/userdata/$CPUSER"
if [ ! -d "$USERDATA_DIR" ]; then
    echo "❌ Userdata directory not found: $USERDATA_DIR"
    exit 1
fi

echo
echo "======== DOMAIN INFORMATION + STATUS ========"

# Functions
get_a_record() {
    local DOMAIN=$1
    ZONE_FILE="/var/named/${DOMAIN}.db"
    if [ -f "$ZONE_FILE" ]; then
        A_REC=$(awk 'BEGIN {IGNORECASE=1} /^[^;].*[[:space:]]A[[:space:]]/ {if ($1=="@" || $1=="'"$DOMAIN"'." || $1=="'"$DOMAIN"'") print $NF}' "$ZONE_FILE" | sort -u | tr '\n' ' ')
        [ -n "$A_REC" ] && { echo "$A_REC"; return 0; }
    fi
    for Z in /var/named/*.db; do
        ZONENAME=$(basename "$Z" .db)
        if [[ "$DOMAIN" == *".${ZONENAME}" ]]; then
            SUB=${DOMAIN%%.$ZONENAME}
            A_REC=$(awk 'BEGIN {IGNORECASE=1} /^[^;].*[[:space:]]A[[:space:]]/ {if ($1=="'"$SUB"'" || $1=="'"$SUB"'." ) print $NF}' "$Z" | sort -u | tr '\n' ' ')
            [ -n "$A_REC" ] && { echo "$A_REC"; return 0; }
        fi
    done
    echo "No A record (not local or CNAME)"
}

get_http_status() {
    local DOMAIN=$1
    curl -o /dev/null -s -w "%{http_code}" "http://$DOMAIN"
}

MAIN_DOMAIN=$(awk '/^main_domain:/ {print $2}' "$USERDATA_DIR/main" 2>/dev/null)
MAIN_IP=$(get_a_record "$MAIN_DOMAIN")
MAIN_STATUS=$(get_http_status "$MAIN_DOMAIN")
echo "Main domain: $MAIN_DOMAIN - $MAIN_IP - HTTP $MAIN_STATUS"

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

# Disk usage per domain
get_size() {
    local DIR=$1
    [ -d "$DIR" ] || { echo "0"; return; }
    du -sh "$DIR" 2>/dev/null | awk '{print $1}'
}

echo
echo "======== DISK USAGE PER DOMAIN ========"
MAIN_DOCROOT="$HOMEDIR/public_html"
MAIN_SIZE=$(get_size "$MAIN_DOCROOT")
echo "Main domain: $MAIN_DOMAIN - $MAIN_SIZE"

if [ -n "$ADDON_DOMAINS" ]; then
    for D in $ADDON_DOMAINS; do
        ADDON_DOCROOT=$(grep -R "^documentroot:" "$USERDATA_DIR"/* 2>/dev/null | grep "$D" | awk '{print $2}' | head -1)
        [ -z "$ADDON_DOCROOT" ] && ADDON_DOCROOT="$HOMEDIR/$D/public_html"
        SIZE=$(get_size "$ADDON_DOCROOT")
        echo "Addon domain: $D - $SIZE"
    done
else
    echo "Addon domains: None"
fi

if [ -n "$PARKED_DOMAINS" ]; then
    for D in $PARKED_DOMAINS; do
        SIZE=$(get_size "$MAIN_DOCROOT")
        echo "Parked / Alias: $D - $SIZE"
    done
else
    echo "Parked / Aliases: None"
fi

echo "======================================="

# MySQL database sizes
echo
echo "========== MYSQL DATABASE USAGE =========="
DB_LIST=$(mysql -N -e "SHOW DATABASES;" | grep "^${CPUSER}_")
if [ -z "$DB_LIST" ]; then
    echo "No databases found"
else
    for DB in $DB_LIST; do
        SIZE_MB=$(mysql -N -e "SELECT ROUND(SUM(data_length+index_length)/1024/1024,2) FROM information_schema.tables WHERE table_schema='$DB';")
        SIZE_MB=${SIZE_MB:-0}
        echo "Database: $DB - ${SIZE_MB} MB"
    done
fi
echo "======================================="

# CMS / CRM detection
echo
echo "======= CMS / CRM DETECTION ======="
DOCROOT="$HOMEDIR/public_html"

if [ -f "$DOCROOT/wp-config.php" ]; then
    CMS="WordPress"
    VERSION=$(grep -E "wp_version\s*=" "$DOCROOT/wp-includes/version.php" 2>/dev/null | head -1 | awk -F"'" '{print $2}')
elif [ -f "$DOCROOT/configuration.php" ]; then
    CMS="Joomla"
    VERSION=$(grep "public \$RELEASE" "$DOCROOT/libraries/src/Version.php" 2>/dev/null | awk -F"'" '{print $2}')
elif [ -f "$DOCROOT/app/etc/env.php" ]; then
    CMS="Magento"
    VERSION=$(awk -F'"' '/magento\/product-community-edition/ { print $4 }' "$DOCROOT/composer.json" 2>/dev/null)
elif [ -f "$DOCROOT/artisan" ]; then
    CMS="Laravel"
    VERSION=$(grep '"laravel/framework"' "$DOCROOT/composer.lock" 2>/dev/null | head -1 | awk -F'"' '{print $4}')
elif [ -f "$DOCROOT/includes/bootstrap.inc" ]; then
    CMS="Drupal"
    VERSION=$(grep "define('VERSION'" "$DOCROOT/includes/bootstrap.inc" 2>/dev/null | awk -F"'" '{print $4}')
elif [ -f "$DOCROOT/core/lib/Drupal.php" ]; then
    CMS="Drupal"
    VERSION=$(grep "const VERSION" "$DOCROOT/core/lib/Drupal.php" 2>/dev/null | awk -F"'" '{print $2}')
else
    CMS="Not detected"
    VERSION="Unknown"
fi

echo "Detected CMS/Framework: $CMS"
echo "Version            : $VERSION"
echo "===================================="

# PHP vs CMS compatibility
php_to_num() {
    echo "$1" | sed 's/ea-php//' | awk '{printf "%d%02d\n",$1/10,$1%10}'
}

get_php_requirements() {
    case "$1" in
        WordPress) echo "704 803" ;;
        Joomla)    echo "800 803" ;;
        Magento)   echo "810 820" ;;
        Laravel)   echo "800 830" ;;
        Drupal)    echo "800 830" ;;
        *)         echo "" ;;
    esac
}

get_domain_php() {
    local D=$1
    PHPVER=$(whmapi1 php_get_vhost_versions 2>/dev/null | awk -v d="$D" '$1=="domain:" && $2==d {f=1} f && $1=="version:" {print $2; exit}')
    [ -z "$PHPVER" ] && PHPVER=$(whmapi1 php_get_vhost_versions 2>/dev/null | awk '$1=="domain:" && $2=="'"$MAIN_DOMAIN"'" {f=1} f && $1=="version:" {print $2; exit}')
    [ -z "$PHPVER" ] && PHPVER="system"
    echo "$PHPVER"
}

check_compat() {
    local CMS=$1
    local PHP=$2
    [ "$PHP" = "system" ] && { echo "UNKNOWN (system PHP)"; return; }
    REQ=$(get_php_requirements "$CMS")
    [ -z "$REQ" ] && { echo "UNKNOWN CMS"; return; }
    PHPNUM=$(php_to_num "$PHP")
    MIN=$(echo "$REQ" | awk '{print $1}')
    MAX=$(echo "$REQ" | awk '{print $2}')
    if (( PHPNUM < MIN )); then
        echo -e "${RED}MISMATCH (PHP too old)${NC}"
    elif (( PHPNUM > MAX )); then
        echo -e "${RED}MISMATCH (PHP too new)${NC}"
    else
        echo "OK"
    fi
}

# Main domain
MAIN_PHP=$(get_domain_php "$MAIN_DOMAIN")
MAIN_COMPAT=$(check_compat "$CMS" "$MAIN_PHP")
echo "Main domain : $MAIN_DOMAIN"
echo "CMS         : $CMS"
echo "PHP         : $MAIN_PHP"
echo "Result      : $MAIN_COMPAT"
echo "--------------------------------------"

# Addon domains
for D in $ADDON_DOMAINS; do
    PHPVER=$(get_domain_php "$D")
    RESULT=$(check_compat "$CMS" "$PHPVER")
    echo "Addon domain: $D"
    echo "PHP         : $PHPVER"
    echo "Result      : $RESULT"
    echo "--------------------------------------"
done

# Parked/alias domains (inherit main PHP)
for D in $PARKED_DOMAINS; do
    RESULT=$(check_compat "$CMS" "$MAIN_PHP")
    echo "Alias       : $D"
    echo "PHP         : $MAIN_PHP (inherited)"
    echo "Result      : $RESULT"
    echo "--------------------------------------"
done

# Migration paths
SERVER_IP=$(hostname -I | awk '{print $1}')
echo
echo "==============================================================================="
echo -e "Email migration path: ${SERVER_IP}:${HOMEDIR}/mail/"
echo -e "Shadow and passwd migration path: ${SERVER_IP}:${HOMEDIR}/etc/"
echo -e "Webfiles migration path: ${SERVER_IP}:${HOMEDIR}/public_html/"
echo "==============================================================================="
