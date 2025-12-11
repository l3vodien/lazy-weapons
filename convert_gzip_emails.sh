#!/bin/bash
# Universal Mail Gzip Fixer for Roundcube
# Converts gzip-compressed mail files to readable format

echo "=== Mail Gzip Fixer ==="

# Ask for cPanel username and domain
read -p "Enter cPanel username: " CPUSER
read -p "Enter domain name: " DOMAIN

MAILDIR="/home/$CPUSER/mail/$DOMAIN"
LOGFILE="/home/$CPUSER/mailfix_$(date +%F_%H%M%S).log"

echo "User: $CPUSER" | tee -a "$LOGFILE"
echo "Domain: $DOMAIN" | tee -a "$LOGFILE"
echo "Mail directory: $MAILDIR" | tee -a "$LOGFILE"

# Check if mail directory exists
if [ ! -d "$MAILDIR" ]; then
    echo "Mail directory not found: $MAILDIR" | tee -a "$LOGFILE"
    exit 1
fi

# Find gzip-compressed mail files
FILES=$(find "$MAILDIR" -type f \( -name '*:2,SZ' -o -name '*:2,RSZ' \))

if [ -z "$FILES" ]; then
    echo "No compressed mail files found." | tee -a "$LOGFILE"
    exit 0
fi

echo "Found $(echo "$FILES" | wc -l) compressed mail files." | tee -a "$LOGFILE"

# Process each file
echo "$FILES" | while read -r f; do
    echo "Processing: $f" | tee -a "$LOGFILE"
    BACKUP="$f.bak"
    
    # Backup the original
    cp "$f" "$BACKUP"
    echo "Backup created: $BACKUP" | tee -a "$LOGFILE"
    
    # Decompress
    gzip -d "$f"
    
    if [ $? -eq 0 ]; then
        echo "Decompressed successfully: $f" | tee -a "$LOGFILE"
    else
        echo "Failed to decompress: $f" | tee -a "$LOGFILE"
    fi
done

# Fix permissions
chown -R "$CPUSER:$CPUSER" "$MAILDIR"
find "$MAILDIR" -type d -exec chmod 700 {} \;
find "$MAILDIR" -type f -exec chmod 600 {} \;

echo "=== Mail Gzip Fixing Completed ===" | tee -a "$LOGFILE"
echo "Affected files logged in: $LOGFILE"
