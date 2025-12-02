# Detect cPanel user
CPUSER=$(/scripts/whoowns "$DOMAIN")
if [ -z "$CPUSER" ]; then
    echo "Cannot detect cPanel user for $DOMAIN"
    exit 1
fi

# Resolve correct home directory using tilde expansion
HOMEDIR=$(eval echo "~$CPUSER")

if [ ! -d "$HOMEDIR" ]; then
    echo "ERROR: Home directory not found for user $CPUSER"
    exit 1
fi

MAILDIR="$HOMEDIR/mail/$DOMAIN"

if [ ! -d "$MAILDIR" ]; then
    echo "Mail directory not found: $MAILDIR"
    exit 1
fi
