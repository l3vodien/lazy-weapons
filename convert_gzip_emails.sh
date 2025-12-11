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

# Detect mail directory
MAILDIR="$HOMEDIR/mail/$DOMAIN"
if [ ! -d "$MAILDIR" ]; then
    echo "Mail directory not found for $CPUSER/$DOMAIN" | tee -a "$LOGFILE"
    exit 1
fi

echo "Mail directory: $MAILDIR" | tee -a "$LOGFILE"

# Remove all .bak files
find "$MAILDIR" -type f -name '*.bak' -exec rm -f {} \; -print | tee -a "$LOGFILE"

# Find gzip-compressed mail files (:2,Z, :2,SZ, :2,RSZ)
GZFILES=$(find "$MAILDIR" -type f \( -name '*:2,Z' -o -name '*:2,SZ' -o -name '*:2,RSZ' \))

if [ -z "$GZFILES" ]; then
    echo "No gzip-compressed emails found in $MAILDIR" | tee -a "$LOGFILE"
    exit 0
fi

# Process each file
for f in $GZFILES; do
    echo "Processing $f" | tee -a "$LOGFILE"
    # Determine new filename (remove the compression suffix)
    NEWFILE="${f%:2,Z}"
    NEWFILE="${NEWFILE%:2,SZ}"
    NEWFILE="${NEWFILE%:2,RSZ}"

    # Uncompress in place
    gunzip -c "$f" > "$NEWFILE" 2>>"$LOGFILE"

    # Remove original compressed file
    rm -f "$f"
done

echo "Finished processing $(echo "$GZFILES" | wc -l) files." | tee -a "$LOGFILE"
echo "Log file: $LOGFILE"
