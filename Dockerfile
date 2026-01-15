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

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose the MCP server port
EXPOSE 8080

# Volume for persistent data
VOLUME ["/data"]

WORKDIR /data

ENTRYPOINT ["/entrypoint.sh"]
