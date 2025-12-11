#!/bin/bash

echo "=== Mail Gzip Fixer ==="

# Ask for cPanel user and domain
read -rp "Enter cPanel username: " CPUSER
read -rp "Enter domain name: " DOMAIN

# Detect home directory
HOMEDIR=$(eval echo "~$CPUSER")
if [ ! -d "$HOMEDIR" ]; then
    echo "User home directory not found: $HOMEDIR"
    exit 1
fi

# Create log directory
LOGDIR="$HOMEDIR/mailfix_logs"
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/mailfix_$(date +%F_%H%M%S).log"

echo "User: $CPUSER" | tee -a "$LOGFILE"
echo "Domain: $DOMAIN" | tee -a "$LOGFILE"

# Detect mail directory automatically
if [ -d "$HOMEDIR/mail/$DOMAIN" ]; then
    MAILDIR="$HOMEDIR/mail/$DOMAIN"
elif [ -d "$HOMEDIR/etc/$DOMAIN" ]; then
    MAILDIR="$HOMEDIR/etc/$DOMAIN"
else
    echo "Mail directory not found for $CPUSER/$DOMAIN" | tee -a "$LOGFILE"
    exit 1
fi

echo "Mail directory: $MAILDIR" | tee -a "$LOGFILE"

# Find gzip-compressed mail files (:2,SZ or :2,RSZ)
GZFILES=$(find "$MAILDIR" -type f -name '*:2,SZ' -o -name '*:2,RSZ')

if [ -z "$GZFILES" ]; then
    echo "No gzip-compressed emails found in $MAILDIR" | tee -a "$LOGFILE"
    exit 0
fi

# Process each file
for f in $GZFILES; do
    echo "Processing $f" | tee -a "$LOGFILE"

    # Backup original just in case
    cp -p "$f" "$f.bak" 2>>"$LOGFILE"

    # Uncompress the file in place
    gunzip -c "$f" > "${f%:2,SZ}" 2>>"$LOGFILE" || gunzip -c "$f" > "${f%:2,RSZ}" 2>>"$LOGFILE"

    # Remove the original gzipped file
    rm -f "$f"
done

echo "Finished processing $(echo "$GZFILES" | wc -l) files." | tee -a "$LOGFILE"
echo "Log file: $LOGFILE"
