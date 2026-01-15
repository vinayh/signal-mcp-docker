#!/bin/bash
set -e

ACCOUNT_FILE="/data/.signal-account"

# Check if already linked
if [ -f "$ACCOUNT_FILE" ]; then
    PHONE_NUMBER=$(cat "$ACCOUNT_FILE")
    echo "Signal account linked: $PHONE_NUMBER"
    exec python3 -m signal_mcp.main --user-id "$PHONE_NUMBER" --transport sse
fi

echo "No linked account found. Starting device linking..."
echo "Scan the QR code with Signal (Settings > Linked Devices)"
echo ""

# signal-cli link outputs the URI first, then the phone number on success
# Use process substitution to avoid subshell variable scope issues
while read -r line; do
    if [[ "$line" =~ ^sgnl:// ]]; then
        qrencode -t ANSIUTF8 "$line"
        echo ""
        echo "Waiting for you to scan..."
    elif [[ "$line" =~ ^\+[0-9]+ ]]; then
        echo "$line" > "$ACCOUNT_FILE"
        echo "Linked as: $line"
    fi
done < <(signal-cli link --name "signal-mcp-docker" 2>&1)

# Start the MCP server
if [ -f "$ACCOUNT_FILE" ]; then
    PHONE_NUMBER=$(cat "$ACCOUNT_FILE")
    exec python3 -m signal_mcp.main --user-id "$PHONE_NUMBER" --transport sse
else
    echo "Linking failed - no account file created"
    echo "You must link your Signal account before deploying."
    echo "Run locally first: docker run -it -v signal-data:/data signal-mcp"
    exit 1
fi
