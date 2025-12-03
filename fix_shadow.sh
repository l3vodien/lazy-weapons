#!/bin/bash

echo "==== cPanel Email Ownership Migration Tool ===="
read -p "Old UID:GID (example 2433:2433): " OLD_UIDGID
read -p "New cPanel user: " NEWUSER
read -p "Domain (example: domain.com): " DOMAIN
echo

# Split UID:GID
OLD_ID=$(echo "$OLD_UIDGID" | cut -d: -f1)
OLD_GID=$(echo "$OLD_UIDGID" | cut -d: -f2)

# Detect new user home
NEWHOME=$(eval echo "~$NEWUSER")

if [ ! -d "$NEWHOME" ]; then
    echo "New home directory not found: $NEWHOME"
    exit 1
fi

# Detect NEW UID:GID automatically
NEW_ID=$(id -u "$NEWUSER")
NEW_GID=$(id -g "$NEWUSER")

echo "Old UID:GID = $OLD_ID:$OLD_GID"
echo "New UID:GID = $NEW_ID:$NEW_GID"
echo
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

echo "Fixing username path references inside passwd..."
# Replace only directory references, not UID/GID
sed -i "s#/$OLD_ID/#/$NEWUSER/#g" "$EMAIL_ETC/passwd"

echo "Fixing home path (/homeX → /homeY)..."
NEWHOMEPATH=$(echo "$NEWHOME" | sed 's/\/$//')

# Replace old /home path with new one
sed -i "s#/home[^/]*/#$NEWHOMEPATH/#g" "$EMAIL_ETC/passwd"

echo
echo "=== Updated passwd file ==="
cat "$EMAIL_ETC/passwd"
echo
echo "=== Task complete ==="
