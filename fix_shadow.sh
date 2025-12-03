#!/bin/bash

echo "==== cPanel Email Ownership Migration Tool ===="
read -p "Old cPanel user: " OLDUSER
read -p "New cPanel user: " NEWUSER
read -p "Domain (example: domain.com): " DOMAIN
echo

# Detect home dirs
OLDHOME=$(eval echo "~$OLDUSER")
NEWHOME=$(eval echo "~$NEWUSER")

if [ ! -d "$OLDHOME" ]; then
    echo "Old home directory not found: $OLDHOME"
    exit 1
fi

if [ ! -d "$NEWHOME" ]; then
    echo "New home directory not found: $NEWHOME"
    exit 1
fi

# Detect UID:GID
OLD_ID=$(id -u "$OLDUSER")
OLD_GID=$(id -g "$OLDUSER")

NEW_ID=$(id -u "$NEWUSER")
NEW_GID=$(id -g "$NEWUSER")

echo "Old user UID:GID = $OLD_ID:$OLD_GID"
echo "New user UID:GID = $NEW_ID:$NEW_GID"
echo
echo "Old home = $OLDHOME"
echo "New home = $NEWHOME"
echo

EMAIL_ETC="$NEWHOME/etc/$DOMAIN"
EMAIL_MAIL="$NEWHOME/mail/$DOMAIN"

echo "Fixing ownership for mail and etc directories..."
chown -R ${NEWUSER}:${NEWUSER} "$NEWHOME/mail"
chown -R ${NEWUSER}: "$NEWHOME/etc"
chown ${NEWUSER}:mail "$NEWHOME/etc"
chown ${NEWUSER}:mail "$EMAIL_ETC"
chown ${NEWUSER}:mail "$EMAIL_ETC/passwd"
chown ${NEWUSER}:mail "$EMAIL_ETC/quota"
chown ${NEWUSER}:mail "$EMAIL_ETC/shadow"
chown ${NEWUSER}:mail "$EMAIL_ETC/_privs.json"
chown -R ${NEWUSER}: "$EMAIL_ETC/@pwcache"

echo "Fixing UID:GID inside passwd..."
sed -i "s/$OLD_ID:$OLD_GID/$NEW_ID:$NEW_GID/g" "$EMAIL_ETC/passwd"

echo "Fixing home directory references inside passwd..."
sed -i "s#/$OLDUSER/#/$NEWUSER/#g" "$EMAIL_ETC/passwd"
sed -i "s#/$OLDUSER\$#/$NEWUSER#g" "$EMAIL_ETC/passwd"

echo "Fixing home path (e.g., /home -> /home5)..."
OLDHOMEPATH=$(echo "$OLDHOME" | sed 's/\/$//')
NEWHOMEPATH=$(echo "$NEWHOME" | sed 's/\/$//')

sed -i "s#$OLDHOMEPATH#$NEWHOMEPATH#g" "$EMAIL_ETC/passwd"

echo
echo "=== Updated passwd file ==="
cat "$EMAIL_ETC/passwd"
echo
echo "=== Task complete ==="
