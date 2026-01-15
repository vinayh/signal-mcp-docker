FROM python:3.13-slim-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    qrencode \
    git \
    && rm -rf /var/lib/apt/lists/*

ARG SIGNAL_CLI_VERSION=0.13.22
RUN curl -L -o /tmp/signal-cli.tar.gz \
    "https://github.com/AsamK/signal-cli/releases/download/v${SIGNAL_CLI_VERSION}/signal-cli-${SIGNAL_CLI_VERSION}-Linux-native.tar.gz" \
    && tar xf /tmp/signal-cli.tar.gz -C /usr/local/bin \
    && rm /tmp/signal-cli.tar.gz

RUN pip install --no-cache-dir git+https://github.com/rymurr/signal-mcp.git

ENV HOME=/data
ENV SIGNAL_CLI_CONFIG=/data/.config/signal-cli
ENV XDG_DATA_HOME=/data/.local/share
ENV FASTMCP_SERVER_PORT=8080
ENV FASTMCP_SERVER_HOST=0.0.0.0

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080
VOLUME ["/data"]
WORKDIR /data

ENTRYPOINT ["/entrypoint.sh"]
