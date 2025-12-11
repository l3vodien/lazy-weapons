#!/bin/bash
# Interactive Ghost Maildir / Compressed Email Fixer

echo "=== Ghost Maildir / Dovecot Mail Fixer ==="

# Ask for cPanel username and domain
read -p "Enter cPanel username: " CPUSER
read -p "Enter domain name: " DOMAIN

MAILDIR="/home/$CPUSER/mail/$DOMAIN"
LOGFILE="/home/$CPUSER/fix_mail_$(date +%F_%H%M%S).log"

echo "User: $CPUSER" | tee -a "$LOGFILE"
echo "Domain: $DOMAIN" | tee -a "$LOGFILE"
echo "Mail directory: $MAILDIR" | tee -a "$LOGFILE"

if [ ! -d "$MAILDIR" ]; then
    echo "Mail directory not found: $MAILDIR" | tee -a "$LOGFILE"
    exit 1
fi

# Backup compressed files
echo "Backing up .SZ and .RSZ files..." | tee -a "$LOGFILE"
find "$MAILDIR" -type f \( -name '*:2,SZ' -o -name '*:2,RSZ' \) -exec cp {} {}.bak \; 2>>"$LOGFILE"

# Decompress files
echo "Decompressing files..." | tee -a "$LOGFILE"
find "$MAILDIR" -type f \( -name '*:2,SZ' -o -name '*:2,RSZ' \) | while read f; do
    echo "Decompressing: $f" | tee -a "$LOGFILE"
    gzip -d "$f" 2>>"$LOGFILE"
done

# Fix permissions
echo "Fixing permissions..." | tee -a "$LOGFILE"
chown -R "$CPUSER:$CPUSER" "$MAILDIR"
find "$MAILDIR" -type d -exec chmod 700 {} \;
find "$MAILDIR" -type f -exec chmod 600 {} \;

# Recalculate quota
echo "Recalculating quota..." | tee -a "$LOGFILE"
doveadm quota recalc -u "$CPUSER@$DOMAIN" 2>>"$LOGFILE"

echo "=== Mail Fix Complete ===" | tee -a "$LOGFILE"
echo "Log file: $LOGFILE"
