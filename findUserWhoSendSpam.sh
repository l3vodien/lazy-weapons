#!/bin/bash
 
export PATH="/bin:/sbin:/usr/bin:/usr/sbin:$PATH"
export MAILARCHIVESLOGFILE="/var/log/exim_mainlog"
echo ''
 
export RED=`echo -e "\e[91m"`
export REDBACK=`echo -e "\e[41m"`
export RED_BLINK=`echo -e "\e[5m"`
export GREEN=`echo -e "\e[32m"`
export BLUE=`echo -e "\e[96m"`
export LBLUE=`echo -e "\e[36m"`
export CLOSE=`echo -e "\e[00m"`
 
repeateString(){
printf "%.${1}d" 0 | sed 's/0/-/g'; echo
}
 
repeateString 26
echo -en $BLUE`hostname`$CLOSE "|"
echo
 
repeateString 110
echo $GREEN"-> The log file - $MAILARCHIVESLOGFILE have data [ Time From: `cat /var/log/maillog | \
head -1 | \
awk '{ print $1" "$2" "$3 }'` ] <-> [ Time to: `cat /var/log/exim_mainlog | \
tail -1 | \
awk '{ print $1" "$2" "$3 }'` ]"$CLOSE
 
repeateString 110
echo $RED"FOUND USERS:"$CLOSE
repeateString 110
echo
 
usrName="`sudo cat $MAILARCHIVESLOGFILE | \
grep -E "max defers" | \
grep -v cpanel | \
grep @ | \
awk '{ print $14" "$13 }' | \
sed -e 's/Domain//g' | \
sed -e 's/has//g' | \
sed -e 's/<//g' | \
sed -e 's/>//g' | \
sed -e 's/://g' | \
awk '{ print $1 }' | \
sort | \
grep -v "R=" | \
uniq -c | \
awk '{ print $1" "$2 }' | \
grep -E "[0-9][0-9][0-9][0-9]" | \
awk '{ print $2 }'`"
 
for name in `echo $usrName`;
do echo -en $GREEN $RED_BLINK" -> : "$CLOSE;
sudo grep -r "$name" /etc/userdomains ;
done
 
echo
repeateString 110
echo $RED"DOMAINS CHECK:"$CLOSE ;
repeateString 110
echo
 
sudo cat $MAILARCHIVESLOGFILE | \
grep -E "max defers" | \
grep -v cpanel | \
grep @ | \
awk '{ print $14" "$13 }' | \
sed -e 's/Domain//g' | \
sed -e 's/has//g' | \
sed -e 's/<//g' | \
sed -e 's/>//g' | \
sed -e 's/\://g' | \
awk '{ print $1 }' | \
sort | \
grep -v "R=" | \
uniq -c | \
awk -v RED_BLINK=$RED_BLINK \
-v REDBACK=$REDBACK \
-v CLOSE=$CLOSE \
-v RED=$RED \
-v LBLUE=$LBLUE \
'{ print LBLUE "DOMAIN: " CLOSE $2 RED RED_BLINK " -> " CLOSE "MAX DEFER: " RED_BLINK REDBACK $1 CLOSE }' | \
grep -v @ | \
grep -E "[0-9][0-9][0-9][0-9]"
 
spamip=`sudo cat $MAILARCHIVESLOGFILE | \
grep -E "max defers" | \
grep -v cpanel | \
grep @ | \
awk '{ print $14" "$13 }' | \
sed -e 's/Domain//g' | \
sed -e 's/has//g' | \
sed -e 's/<//g' | \
sed -e 's/>//g' | \
sed -e 's/\://g' | \
awk '{ print $1 }' | \
sort | \
grep -v "R=" | \
uniq -c | \
awk '{ print $1" "$2 }' | \
grep -v @ | \
grep -E "[0-9][0-9][0-9][0-9]" | \
awk '{ print $2 }'`
 
echo
repeateString 110
echo $RED"MAILBOX CHECK:"$CLOSE
repeateString 110
echo
 
for checkmbx in `echo $spamip`; do
echo ""; echo $LBLUE"MBOX FOR:$CLOSE "$checkmbx ; echo ;
sudo whmapi1 get_mailbox_status account=_mainaccount@$checkmbx | \
grep @ | \
sed -e 's/INBOX.//g' | \
grep $checkmbx | \
awk \
-v GREEN=$GREEN \
-v CLOSE=$CLOSE \
-v BLINK=$RED_BLINK '{ print GREEN BLINK" -> "CLOSE $0 }' | \
sed -e 's/\_/\./g' | \
sed -e 's/\://g'; done
 
echo
repeateString 110
echo $RED"SUCCESSFUL LOGIN:"$CLOSE
repeateString 110
echo
 
for i in `echo $spamip`; do echo ; echo $LBLUE"DOMAIN:$CLOSE "$i; echo ;
sudo cat $MAILARCHIVESLOGFILE | \
grep Login | \
grep $i | \
grep rip | \
grep -E "rip=" | \
awk '{ print $10 }' | \
sort | \
sed -e 's/rip=//g' | \
sed -e 's/\,//g' | \
awk '{ printf("%10s\t", $1); system("geoiplookup " $1 " | cut -d : -f2 | head -1") }' | \
uniq -c ; done | \
grep -v Domain | \
grep -v has
echo
repeateString 110
