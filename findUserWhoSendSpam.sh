#!/bin/bash

LOG="/var/log/exim_mainlog"
TODAY=$(date +"%b[ ]*%e")   # flexible for single-digit days

# Sending limits
MAX_PER_HOUR=350
MAX_QUEUE=80
GMAIL_LIMIT=15
YAHOO_LIMIT=5
MS_LIMIT=5

echo ""
echo "------------------------------------------------------------"
echo "Outbound report for all cPanel users"
echo "Log file: $LOG"
echo "------------------------------------------------------------"
echo ""

# Get all cPanel users dynamically
CPUSERS=$(ls /var/cpanel/users 2>/dev/null)
if [ -z "$CPUSERS" ]; then
    echo "No cPanel users found on this server."
    exit 0
fi

# Temporary file for today's logs
TODAY_LOG=$(mktemp)
grep -E "$TODAY" "$LOG" > "$TODAY_LOG"

for CPUSER in $CPUSERS; do
    HOMEDIR=$(getent passwd "$CPUSER" | cut -d: -f6)
    [ -z "$HOMEDIR" ] && continue
    USER_MAIL_DIR="$HOMEDIR/mail"
    [ ! -d "$USER_MAIL_DIR" ] && continue

    # Find all email addresses
    EMAILS=$(find "$USER_MAIL_DIR" -mindepth 2 -maxdepth 2 -type d | awk -F/ '{print $(NF-1)"@"$NF}')
    [ -z "$EMAILS" ] && continue

    # Collect all log lines for this user's emails
    USER_LINES=""
    for email in $EMAILS; do
        matches=$(grep -E "(F=<${email}>|<${email}>)" "$TODAY_LOG")
        [ -n "$matches" ] && USER_LINES="$USER_LINES"$'\n'"$matches"
    done

    [ -z "$USER_LINES" ] && continue

    echo "User: $CPUSER"
    echo "--------------------------------------"

# Extract recipient domains (POSIX-safe)
RECIPIENT_DOMAINS=$(echo "$USER_LINES" \
    | sed -n 's/.* to=<\([^>]*\)>.*/\1/p' \
    | awk -F@ '{print $2}' \
    | sort -u)

    for dom in $RECIPIENT_DOMAINS; do
        count=$(echo "$USER_LINES" | grep -i "$dom" | wc -l)
        flag=""

        [ "$count" -gt "$MAX_PER_HOUR" ] && flag+=" [EXCEEDS HOURLY MAX $MAX_PER_HOUR]"
        [ "$count" -gt "$MAX_QUEUE" ] && flag+=" [EXCEEDS QUEUE LIMIT $MAX_QUEUE]"
        [[ "$dom" =~ gmail\.com$ ]] && [ "$count" -gt "$GMAIL_LIMIT" ] && flag+=" [EXCEEDS GMAIL RATE $GMAIL_LIMIT/80s]"
        [[ "$dom" =~ yahoo\.com$ ]] && [ "$count" -gt "$YAHOO_LIMIT" ] && flag+=" [EXCEEDS YAHOO RATE $YAHOO_LIMIT/80s]"
        [[ "$dom" =~ (hotmail\.com|live\.com|outlook\.com|microsoft\.com)$ ]] && [ "$count" -gt "$MS_LIMIT" ] && flag+=" [EXCEEDS MS RATE $MS_LIMIT/80s]"

        echo "DOMAIN: $dom -> MAX DEFER: $count$flag"
    done
    echo ""
done

rm -f "$TODAY_LOG"
echo "------------------------------------------------------------"
echo "Report completed."
echo ""
