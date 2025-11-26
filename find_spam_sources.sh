#!/bin/bash
#
#  find_spam_sources.sh
#  Detect compromised email accounts and malicious PHP scripts sending spam.
#

LOG="/var/log/exim_mainlog"

echo "------------------------------------------------------------"
echo " SPAM & COMPROMISE INVESTIGATION"
echo " Log file: $LOG"
echo "------------------------------------------------------------"
echo ""

###############################################
# 1. FIND EXTERNAL LOGINS (attacker using real mailbox)
###############################################
echo "=== 1. External Logins (SMTP Auth Compromise) ==="
echo ""

exigrep @ $LOG 2>/dev/null \
    | grep _login \
    | sed -n 's/.*_login:\(.*\)S=.*/\1/p' \
    | sort \
    | uniq -c \
    | sort -nr -k1

echo ""
echo "------------------------------------------------------------"
echo ""

###############################################
# 2. FIND WHICH CPANEL USER IS SENDING THE MOST MAIL
###############################################
echo "=== 2. Accounts Sending the Most Email (U=) ==="
echo ""

exigrep @ $LOG 2>/dev/null \
    | grep "U=" \
    | sed -n 's/.*U=\(.*\)S=.*/\1/p' \
    | sort \
    | uniq -c \
    | sort -nr -k1

echo ""
echo "------------------------------------------------------------"
echo ""

###############################################
# 3. FIND SUSPECT SCRIPT PATHS SENDING SPAM
###############################################
echo "=== 3. Possible Compromised PHP Scripts (cwd paths) ==="
echo ""

grep "cwd=" $LOG \
    | awk '{for(i=1;i<=10;i++){print $i}}' \
    | sort \
    | uniq -c \
    | grep cwd \
    | sort -n \
    | grep /home/ 

echo ""
echo "------------------------------------------------------------"
echo " Investigation Complete"
echo "------------------------------------------------------------"
