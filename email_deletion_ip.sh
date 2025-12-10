read -p "Enter email address: " EMAIL

zgrep "$EMAIL" /var/log/maillog* \
  | grep "expunge" \
  | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
  | sort \
  | uniq -c
