#!/bin/bash
echo "=== Mail Gzip Fixer ==="

read -p "Enter cPanel username: " CPUSER
read -p "Enter domain name: " DOMAIN

# Detect mail directory
if [ -d "/home/$CPUSER/mail/$DOMAIN" ]; then
    MAILDIR="/home/$CPUSER/mail/$DOMAIN"
elif [ -d "/home/$CPUSER/etc/$DOMAIN" ]; then
    MAILDIR="/home/$CPUSER/etc/$DOMAIN"
else
    echo "Mail directory not found for $CPUSER/$DOMAIN"
    exit 1
fi

# Ensure log directory exists
LOGDIR="/home/$CPUSER/logs"
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/mailfix_$(date +%F_%H%M%S).log"

echo "User: $CPUSER" | tee -a "$LOGFILE"
echo "Domain: $DOMAIN" | tee -a "$LOGFILE"
echo "Mail directory: $MAILDIR" | tee -a "$LOGFILE"

FILES=$(find "$MAILDIR" -type f \( -name '*:2,SZ' -o -name '*:2,RSZ' \))
if [ -z "$FILES" ]; then
    echo "No compressed mail files found." | tee -a "$LOGFILE"
    exit 0
fi

echo "Found $(echo "$FILES" | wc -l) compressed mail files." | tee -a "$LOGFILE"

echo "$FILES" | while read -r f; do
    echo "Processing: $f" | tee -a "$LOGFILE"
    BACKUP="$f.bak"
    cp "$f" "$BACKUP"
    gzip -d "$f" && echo "Decompressed: $f" | tee -a "$LOGFILE" || echo "Failed: $f" | tee -a "$LOGFILE"
done

chown -R "$CPUSER:$CPUSER" "$MAILDIR"
find "$MAILDIR" -type d -exec chmod 700 {} \;
find "$MAILDIR" -type f -exec chmod 600 {} \;

echo "=== Mail Gzip Fixing Completed ===" | tee -a "$LOGFILE"
echo "Log saved at $LOGFILE"
