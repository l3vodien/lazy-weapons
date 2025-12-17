#!/bin/bash

# -----------------------------
# Change PHP Version per Domain
# -----------------------------

# Ask for domain
read -rp "Enter domain: " DOMAIN

if [ -z "$DOMAIN" ]; then
    echo "❌ Domain cannot be empty"
    exit 1
fi

echo
echo "🔍 Checking current PHP version for: $DOMAIN"
echo "-------------------------------------------"

# Get current PHP version
CURRENT_PHP=$(whmapi1 php_get_vhost_versions \
    | awk -v d="$DOMAIN" '
        $1=="domain:" && $2==d {found=1}
        found && $1=="version:" {print $2; exit}
    ')

if [ -z "$CURRENT_PHP" ]; then
    echo "❌ Domain not found in PHP vhost list"
    exit 1
fi

echo "✅ Current PHP version: $CURRENT_PHP"
echo

# Get installed PHP versions
echo "📦 Installed PHP versions:"
echo "--------------------------"

mapfile -t PHP_VERSIONS < <(whmapi1 php_get_installed_versions \
    | awk '/- (alt|ea)-php/ {print $2}')

if [ "${#PHP_VERSIONS[@]}" -eq 0 ]; then
    echo "❌ No PHP versions detected"
    exit 1
fi

# Display numbered list
i=1
for php in "${PHP_VERSIONS[@]}"; do
    echo "$i - $php"
    ((i++))
done

echo
read -rp "Select number for PHP version: " CHOICE

# Validate input
if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt "${#PHP_VERSIONS[@]}" ]; then
    echo "❌ Invalid selection"
    exit 1
fi

NEW_PHP="${PHP_VERSIONS[$((CHOICE-1))]}"

echo
echo "⚙️  Changing PHP version for $DOMAIN"
echo "    From: $CURRENT_PHP"
echo "    To:   $NEW_PHP"
echo

# Apply change
whmapi1 php_set_vhost_versions domain="$DOMAIN" version="$NEW_PHP" >/dev/null

if [ $? -ne 0 ]; then
    echo "❌ Failed to change PHP version"
    exit 1
fi

echo "✅ PHP version successfully updated"

# Verify
echo
echo "🔎 Verifying change..."
NEW_CURRENT=$(whmapi1 php_get_vhost_versions \
    | awk -v d="$DOMAIN" '
        $1=="domain:" && $2==d {found=1}
        found && $1=="version:" {print $2; exit}
    ')

echo "📌 Current PHP version for $DOMAIN: $NEW_CURRENT"
