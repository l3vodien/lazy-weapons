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

MAX_JOBS=10   # how many checks run in parallel

check_domain() {
    domain=$1

    # First try HTTPS
    result=$(curl -o /dev/null -s --max-time 2 \
        -w "%{http_code} %{time_total}" https://$domain)

    http_code=$(echo $result | awk '{print $1}')
    time_total=$(echo $result | awk '{print $2}')

    if [[ "$http_code" == "000" ]]; then
        # fallback to HTTP
        result=$(curl -o /dev/null -s --max-time 2 \
            -w "%{http_code} %{time_total}" http://$domain)

        http_code=$(echo $result | awk '{print $1}')
        time_total=$(echo $result | awk '{print $2}')
        scheme="http"
    else
        scheme="https"
    fi

    echo -e "$domain\t$scheme\t$http_code\t${time_total}s"
}

export -f check_domain

printf "\nChecking %d domains with %d parallel jobs…\n\n" "${#DOMAINS[@]}" "$MAX_JOBS"

printf "DOMAIN\tPROTOCOL\tHTTP\tTIME\n"
printf "----------------------------------------------\n"

printf "%s\n" "${DOMAINS[@]}" | xargs -n1 -P $MAX_JOBS -I{} bash -c 'check_domain "$@"' _ {}
