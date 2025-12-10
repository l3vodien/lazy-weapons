#!/bin/bash

domains=(
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

echo "Domain Status Check"
echo "-------------------"

for domain in "${domains[@]}"; do
    echo "Checking: $domain"

    # DNS resolution
    ip=$(dig +short $domain | head -n 1)
    if [[ -z "$ip" ]]; then
        echo "  DNS: FAIL (No A record)"
    else
        echo "  DNS: $ip"
    fi

    # Ping test
    ping -c 1 -W 1 $domain &> /dev/null
    if [[ $? -eq 0 ]]; then
        echo "  Ping: OK"
    else
        echo "  Ping: FAIL"
    fi

    # HTTP status code (prefer HTTPS)
    http_code=$(curl -o /dev/null -s -w "%{http_code}" https://$domain)
    if [[ "$http_code" == "000" ]]; then
        http_code=$(curl -o /dev/null -s -w "%{http_code}" http://$domain)
        scheme="http"
    else
        scheme="https"
    fi
    echo "  HTTP: $http_code ($scheme)"

    # Uptime check – HTTP response time in seconds
    uptime=$(curl -o /dev/null -s -w "%{time_total}" $scheme://$domain)
    if [[ "$uptime" == "0.000" ]]; then
        echo "  Uptime: DOWN"
    else
        echo "  Uptime: ${uptime}s"
    fi

    echo ""
done
