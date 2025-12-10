#!/bin/bash

DOMAINS=(
icube-events.com
l2-broadcast.com.sg
l2-broadcast.com
spectrade.com.sg
acesgroup.com.sg
admiralty.com.sg
condocoaches.sg
pharmline.com.sg
reinbiotech.com
rovingstudios.sg
pethouse.com.sg
admiralty.com.sg
ar-esr-reit.com.sg
)

MAX_JOBS=10
TMPFILE=$(mktemp)

check_domain() {
    domain=$1

    # Try HTTPS first
    result=$(curl -o /dev/null -s --max-time 2 -w "%{http_code} %{time_total}" https://$domain)
    code=$(echo $result | awk '{print $1}')
    time=$(echo $result | awk '{print $2}')

    if [[ "$code" == "000" ]]; then
        # fallback to HTTP
        result=$(curl -o /dev/null -s --max-time 2 -w "%{http_code} %{time_total}" http://$domain)
        code=$(echo $result | awk '{print $1}')
        time=$(echo $result | awk '{print $2}')
        scheme="http"
    else
        scheme="https"
    fi

    echo -e "$domain\t$scheme\t$code\t${time}s" >> "$TMPFILE"
}

export -f check_domain
export TMPFILE

printf "\nRunning %d parallel checks…\n\n" "$MAX_JOBS"

# Print header BEFORE running
echo -e "DOMAIN\tPROTOCOL\tHTTP\tTIME"
echo -e "----------------------------------------------"

# Run checks in parallel, collecting into TMPFILE
printf "%s\n" "${DOMAINS[@]}" | xargs -n1 -P $MAX_JOBS -I{} bash -c 'check_domain "$@"' _ {}

# Print final sorted results
sort "$TMPFILE"

rm -f "$TMPFILE"
