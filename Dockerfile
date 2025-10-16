FROM debian:stable-slim

# Instalar dependências básicas
RUN apt-get -qq update && apt-get -qq install --no-install-recommends -y \
    ca-certificates \
    wget \
    curl \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Instalar Tailscale userspace
ARG TAILSCALE_VERSION
ENV TAILSCALE_VERSION=${TAILSCALE_VERSION:-1.64.0}
RUN wget -q "https://pkgs.tailscale.com/stable/tailscale_${TAILSCALE_VERSION}_amd64.tgz" \
 && tar xzf tailscale_${TAILSCALE_VERSION}_amd64.tgz --strip-components=1 \
 && mv tailscale tailscaled /usr/local/bin/ \
 && rm tailscale_${TAILSCALE_VERSION}_amd64.tgz

# Copiar script de inicialização
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

CMD ["/app/start.sh"]