# Dockerfile for Signal MCP Server
# Combines signal-cli and signal-mcp for AI agent Signal messaging
#
# Build: docker build -t signal-mcp .
# Run:   docker run -it -p 8080:8080 -v signal-data:/data signal-mcp
#
# On first run, you'll be prompted to link your Signal account.
# Scan the QR code or use the URI with your Signal mobile app.

FROM python:3.13-slim-bookworm AS base

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    qrencode \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install signal-cli native binary (no Java required)
ARG SIGNAL_CLI_VERSION=0.13.22
RUN curl -L -o /tmp/signal-cli.tar.gz \
    "https://github.com/AsamK/signal-cli/releases/download/v${SIGNAL_CLI_VERSION}/signal-cli-${SIGNAL_CLI_VERSION}-Linux-native.tar.gz" \
    && tar xf /tmp/signal-cli.tar.gz -C /usr/local/bin \
    && rm /tmp/signal-cli.tar.gz

# Install signal-mcp
RUN pip install --no-cache-dir \
    git+https://github.com/rymurr/signal-mcp.git

# Create data directory for persistent storage
RUN mkdir -p /data/.config/signal-cli /data/.local/share/signal-cli

# Environment variables
ENV HOME=/data
ENV SIGNAL_CLI_CONFIG=/data/.config/signal-cli
ENV XDG_DATA_HOME=/data/.local/share
# FastMCP server configuration (SSE transport)
ENV FASTMCP_SERVER_PORT=8080
ENV FASTMCP_SERVER_HOST=0.0.0.0

# Create entrypoint script
RUN cat > /entrypoint.sh << 'EOF'
#!/bin/bash
set -e

DATA_DIR="/data"
LINKED_FILE="$DATA_DIR/.signal-linked"

# Check if already linked
if [ -f "$LINKED_FILE" ] && [ -n "$(ls -A $DATA_DIR/.local/share/signal-cli/data 2>/dev/null)" ]; then
    # Read the stored phone number
    PHONE_NUMBER=$(cat "$LINKED_FILE")
    echo "Signal account already linked: $PHONE_NUMBER"
    echo "Starting MCP server on port 8080..."
    exec python3 -m signal_mcp.main --user-id "$PHONE_NUMBER" --transport sse
fi

echo "============================================"
echo "  Signal Device Linking Setup"
echo "============================================"
echo ""
echo "No linked Signal account found."
echo "Starting device linking process..."
echo ""
echo "Generating link URI. Please scan the QR code"
echo "with your Signal app (Settings > Linked Devices)"
echo ""
echo "============================================"

# Create a named pipe to capture the link URI while the command runs
PIPE_FILE=$(mktemp -u)
mkfifo "$PIPE_FILE"

# Run signal-cli link in background, output to pipe
signal-cli link --name "signal-mcp-docker" > "$PIPE_FILE" 2>&1 &
LINK_PID=$!

# Read the first line (the URI) from the pipe
read -r LINK_URI < "$PIPE_FILE" || true

# Clean up pipe
rm -f "$PIPE_FILE"

if [ -z "$LINK_URI" ] || [[ ! "$LINK_URI" =~ ^sgnl:// ]]; then
    echo "Error: Could not generate link URI"
    echo "Output was: $LINK_URI"
    kill $LINK_PID 2>/dev/null || true
    exit 1
fi

echo ""
echo "Link URI:"
echo "$LINK_URI"
echo ""
echo "QR Code (scan with Signal app):"
echo ""
qrencode -t ANSIUTF8 "$LINK_URI"
echo ""
echo "============================================"
echo "Waiting for you to scan the QR code..."
echo "Press Ctrl+C to cancel"
echo "============================================"

# Wait for the link command to complete
wait $LINK_PID
LINK_EXIT=$?

if [ $LINK_EXIT -ne 0 ]; then
    echo "Linking failed or was cancelled"
    exit 1
fi

# After linking, we need to get the account number
echo ""
echo "Checking linked accounts..."

# List accounts to find the linked one
ACCOUNTS=$(signal-cli listAccounts 2>/dev/null || echo "")

if [ -z "$ACCOUNTS" ]; then
    echo ""
    echo "Please enter your Signal phone number (e.g., +1234567890):"
    read -r PHONE_NUMBER
else
    PHONE_NUMBER=$(echo "$ACCOUNTS" | head -1)
    echo "Found account: $PHONE_NUMBER"
fi

# Validate phone number format
if [[ ! "$PHONE_NUMBER" =~ ^\+[0-9]+$ ]]; then
    echo "Error: Invalid phone number format. Must be in international format (e.g., +1234567890)"
    exit 1
fi

# Store the phone number for future runs
echo "$PHONE_NUMBER" > "$LINKED_FILE"

echo ""
echo "============================================"
echo "  Setup Complete!"
echo "============================================"
echo ""
echo "Account linked: $PHONE_NUMBER"
echo "Starting MCP server on port 8080..."
echo ""

exec python3 -m signal_mcp.main --user-id "$PHONE_NUMBER" --transport sse
EOF

RUN chmod +x /entrypoint.sh

# Expose the MCP server port
EXPOSE 8080

# Volume for persistent data
VOLUME ["/data"]

WORKDIR /data

ENTRYPOINT ["/entrypoint.sh"]
