#!/bin/bash
# ==========================================================
# cPanel-like Track Delivery Tool (Bash)
# Features:
# - Sender / Recipient filter
# - Status filter
# - Date range filter
# - Error reason column
# - Interactive menu
# ==========================================================

LOG_FILE="/var/log/exim_mainlog"
MAX_LINES=50000

if [ ! -f "$LOG_FILE" ]; then
    echo "Exim log not found: $LOG_FILE"
    exit 1
fi

clear
echo "=============================="
echo "     Track Delivery Tool"
echo "=============================="
echo

read -p "Sender email (optional): " SENDER
read -p "Recipient email (optional): " RECIPIENT
read -p "Status [all/accepted/failed/deferred] (default: all): " STATUS
STATUS=${STATUS:-all}

echo
echo "Date range filter"
read -p "Start date (YYYY-MM-DD) or blank: " START_DATE
read -p "End date   (YYYY-MM-DD) or blank: " END_DATE

echo
echo "Searching Exim logs..."
echo

printf "%-20s %-28s %-28s %-10s %-40s\n" \
"Sent Time" "From" "Recipient" "Result" "Reason"
echo "---------------------------------------------------------------------------------------------------------------"

tail -n $MAX_LINES "$LOG_FILE" | while read -r LINE; do

    # Only delivery related lines
    [[ "$LINE" =~ "<=" || "$LINE" =~ "=>" || "$LINE" =~ "==" || "$LINE" =~ "\*\*" ]] || continue

    # Sender filter
    [[ -n "$SENDER" && "$LINE" != *"$SENDER"* ]] && continue

    # Recipient filter
    [[ -n "$RECIPIENT" && "$LINE" != *"$RECIPIENT"* ]] && continue

    # Extract time
    LOG_TIME=$(echo "$LINE" | cut -c1-16)

    # Convert date for range comparison
    LOG_DATE=$(echo "$LOG_TIME" | awk '{print $1"-"$2"-"$3}')

    if [[ -n "$START_DATE" && "$LOG_DATE" < "$START_DATE" ]]; then continue; fi
    if [[ -n "$END_DATE" && "$LOG_DATE" > "$END_DATE" ]]; then continue; fi

    FROM=$(echo "$LINE" | sed -n 's/.*<= \([^ ]*\).*/\1/p')
    TO=$(echo "$LINE" | grep -oE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' | head -n1)

    RESULT="In Progress"
    REASON="-"

    if [[ "$LINE" == *"=>"* ]]; then
        RESULT="Accepted"
    elif [[ "$LINE" == *"defer"* ]]; then
        RESULT="Deferred"
        REASON=$(echo "$LINE" | sed -n 's/.*defer (\(.*\)).*/\1/p')
    elif [[ "$LINE" == *"**"* ]]; then
        RESULT="Failed"
        REASON=$(echo "$LINE" | sed -n 's/.*\*\*.*: \(.*\)/\1/p')
    fi

    # Status filter
    if [ "$STATUS" != "all" ]; then
        [[ "${RESULT,,}" != "$STATUS" ]] && continue
    fi

    printf "%-20s %-28s %-28s %-10s %-40s\n" \
        "$LOG_TIME" "${FROM:-"-"}" "${TO:-"-"}" "$RESULT" "${REASON:0:38}"

done

echo
echo "Done."
