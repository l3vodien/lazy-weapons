#!/bin/bash

EMAIL="corey@versewealth.com.au"
USER=$(echo "$EMAIL" | cut -d@ -f1)
DOMAIN=$(echo "$EMAIL" | cut -d@ -f2)

START="2025-12-01"
END="2025-12-11"

LOGOUT="/root/email_audit_${USER}_${DOMAIN}.log"
> "$LOGOUT"

echo "=== Email Audit for $EMAIL ===" | tee -a "$LOGOUT"
echo "Date range: $START to $END" | tee -a "$LOGOUT"
echo "" | tee -a "$LOGOUT"

############################
# Function: filter by date #
############################
within_range() {
    log_date=$(date -d "$1" +%s)
    start_date=$(date -d "$START" +%s)
    end_date=$(date -d "$END 23:59:59" +%s)

    [[ $log_date -ge $start_date && $log_date -le $end_date ]]
}

###################################
# 1. DOVECOT IMAP/POP AUTH LOGS   #
###################################
echo "=== Dovecot IMAP/POP Logins ===" | tee -a "$LOGOUT"

grep -Ei "dovecot.*(imap|pop|auth)" /var/log/maillog* /var/log/messages* | grep -i "$EMAIL" | \
while read -r line; do
    # Extract timestamp
    TS="$(echo "$line" | awk '{print $1" "$2" "$3}')"
    # Convert for filtering
    if within_range "$TS"; then
        IP=$(echo "$line" | grep -oP 'rip=\K[\d\.]+')
        STATUS=$(echo "$line" | grep -q "Login: " && echo SUCCESS || echo FAILED)

        echo "$TS | IMAP/POP | $IP | $STATUS | $LINE" >> "$LOGOUT"
    fi
done

###################################
# 2. EXIM AUTH (SMTP Auth logins) #
###################################
echo "" | tee -a "$LOGOUT"
echo "=== Exim Auth Logins (SMTP) ===" | tee -a "$LOGOUT"

grep -Ei "authenticator.*login" /var/log/exim_mainlog* | grep -i "$EMAIL" | \
while read -r line; do
    TS=$(echo "$line" | awk '{print $1" "$2" "$3}')
    if within_range "$TS"; then
        IP=$(echo "$line" | grep -oP '\[\K[\d\.]+')
        STATUS=$(echo "$line" | grep -q "A=" && echo SUCCESS || echo FAILED)
        echo "$TS | SMTP-AUTH | $IP | $STATUS | $line" >> "$LOGOUT"
    fi
done

#############################################
# 3. CPANEL WEBMAIL LOGS (webmail access)   #
#############################################
echo "" | tee -a "$LOGOUT"
echo "=== Webmail Logins ===" | tee -a "$LOGOUT"

grep -Ei "$EMAIL" /usr/local/cpanel/logs/login_log | \
while read -r line; do
    TS=$(echo "$line" | awk '{print $1" "$2" "$3}')
    if within_range "$TS"; then
        IP=$(echo "$line" | awk '{print $8}')
        STATUS=$(echo "$line" | grep -q "SUCCESS" && echo SUCCESS || echo FAILED)
        echo "$TS | WEBMAIL | $IP | $STATUS | $line" >> "$LOGOUT"
    fi
done

echo "" | tee -a "$LOGOUT"
echo "=== Audit Complete ===" | tee -a "$LOGOUT"
echo "Saved to: $LOGOUT"
