#!/bin/bash

echo "======================================="
echo "      EMAIL LOGIN AUDIT (Interactive)"
echo "======================================="

# Ask for email
read -p "Enter email address: " EMAIL
if [[ -z "$EMAIL" ]]; then
    echo "Email cannot be empty."
    exit 1
fi

# Ask for date range
read -p "Enter START date (YYYY-MM-DD): " START
read -p "Enter END date   (YYYY-MM-DD): " END

USER=$(echo "$EMAIL" | cut -d@ -f1)
DOMAIN=$(echo "$EMAIL" | cut -d@ -f2)

echo ""
echo "=== Email Audit for $EMAIL ==="
echo "Range: $START to $END"
echo ""

# Convert dates to timestamps
START_TS=$(date -d "$START" +%s)
END_TS=$(date -d "$END 23:59:59" +%s)

within_range() {
    local log_ts
    log_ts=$(date -d "$1" +%s 2>/dev/null)
    [[ $log_ts -ge $START_TS && $log_ts -le $END_TS ]]
}

# ===============================
# DOVECOT (IMAP/POP LOGINS)
# ===============================
echo "=== Dovecot IMAP/POP Logins ==="

grep -Ei "dovecot.*(imap|pop|auth)" /var/log/maillog* /var/log/messages* 2>/dev/null \
| grep -i "$EMAIL" | while read -r line; do
    TS=$(echo "$line" | awk '{print $1" "$2" "$3}')
    if within_range "$TS"; then
        IP=$(echo "$line" | grep -oP 'rip=\K[\d\.]+')
        STATUS=$(echo "$line" | grep -q "Login:" && echo SUCCESS || echo FAILED)
        echo "$TS | IMAP/POP | $IP | $STATUS"
    fi
done

# ===============================
# EXIM SMTP AUTH
# ===============================
echo ""
echo "=== Exim SMTP Auth Logins ==="

grep -Ei "authenticator.*login" /var/log/exim_mainlog* 2>/dev/null \
| grep -i "$EMAIL" | while read -r line; do
    TS=$(echo "$line" | awk '{print $1" "$2" "$3}')
    if within_range "$TS"; then
        IP=$(echo "$line" | grep -oP '\[\K[\d\.]+')
        STATUS=$(echo "$line" | grep -q "A=" && echo SUCCESS || echo FAILED)
        echo "$TS | SMTP-AUTH | $IP | $STATUS"
    fi
done

# ===============================
# CPANEL WEBMAIL LOGINS
# ===============================
echo ""
echo "=== Webmail Logins ==="

grep -Ei "$EMAIL" /usr/local/cpanel/logs/login_log 2>/dev/null \
| while read -r line; do
    TS=$(echo "$line" | awk '{print $1" "$2" "$3}')
    if within_range "$TS"; then
        IP=$(echo "$line" | awk '{print $8}')
        STATUS=$(echo "$line" | grep -q "SUCCESS" && echo SUCCESS || echo FAILED)
        echo "$TS | WEBMAIL | $IP | $STATUS"
    fi
done

echo ""
echo "=== Audit Complete ==="
