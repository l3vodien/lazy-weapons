#!/bin/bash

# Ask for domain name
read -p "Enter domain (example: perfectvalves.in): " DOMAIN

# Detect cPanel user
CPUSER=$(/scripts/whoowns "$DOMAIN")
if [ -z "$CPUSER" ]; then
    echo "Cannot detect cPanel user for $DOMAIN"
    exit 1
fi

HOMEDIR=$(eval echo "~$CPUSER")
MAILDIR="$HOMEDIR/mail/$DOMAIN"
LOGFILE="$HOMEDIR/gzip_mail_log.txt"

echo "=== Scanning mail for domain: $DOMAIN ==="
echo "cPanel user: $CPUSER"
echo "Maildir: $MAILDIR"
echo "Log file: $LOGFILE"

if [ ! -d "$MAILDIR" ]; then
    echo "Mail directory not found: $MAILDIR"
    exit 1
fi

# Clear previous log
> "$LOGFILE"

# Find all gzip-compressed mail files
find "$MAILDIR" -type f | while read -r FILE; do
    TYPE=$(file "$FILE")
    if echo "$TYPE" | grep -q "gzip compressed data"; then
        echo "$FILE : $TYPE" >> "$LOGFILE"
    fi
done

COUNT=$(wc -l < "$LOGFILE")
echo "Found $COUNT gzip-compressed emails."
echo "Log saved at $LOGFILE"

# Ask if user wants to decompress
if [ "$COUNT" -gt 0 ]; then
    read -p "Do you want to decompress these emails? (Y/N): " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        while IFS= read -r FILELINE; do
            FILE=$(echo "$FILELINE" | cut -d: -f1)
            echo "Decompressing $FILE"
            cp "$FILE" "$FILE.bak.gz"    # backup first
            gzip -d "$FILE"
        done < "$LOGFILE"
        echo "Decompression completed. Backups are *.bak.gz"
    fi
fi

echo "=== Done ==="
