#!/bin/bash

echo "IMAPSYNC Interactive - Single User Migration"
echo "--------------------------------------------"

echo "DO NOT USE EXCLAMATION MARK (!) FOR THE PASS"
echo "--------------------------------------------"

read -p "Enter SOURCE IMAP host (Hostname/IP address): " host1
read -p "Enter SOURCE email address: " user1
read -s -p "Enter SOURCE email password: " pass1
echo ""

read -p "Enter DESTINATION IMAP host (Hostname/IP address): " host2
read -p "Enter DESTINATION email address: " user2
read -s -p "Enter DESTINATION email password: " pass2
echo ""

# Create the log directory if it doesn't exist
mkdir -p /scripts/LOG_imapsync/

# Create a timestamped log filename
logfile="/scripts/LOG_imapsync/imapsync_${user1}_to_${user2}_$(date +%Y%m%d_%H%M%S).log"

echo ""
echo "Running imapsync for $user1 -> $user2 ..."
echo "Log file: $logfile"
echo ""

imapsync --skipcrossduplicates --automap --buffersize 8192000 \
  --useuid --syncinternaldates --nofoldersizes --maxsize 50000000 \
  --host1 "$host1" -ssl2 --user1 "$user1" --password1 "$pass1" --timeout1 130 \
  --host2 "$host2" -ssl2 --user2 "$user2" --password2 "$pass2" --timeout2 130 \
  --noabletosearch --errorsmax 10000 --regexmess 's,(.{9900}),$1\r\n,g' \
  --reconnectretry1 5 --reconnectretry2 5 \
  --useheader "Message-ID" \
  --delete2duplicates \
  &> "$logfile"

echo ""
echo "Migration complete for $user1 -> $user2"
echo "See log: $logfile"
