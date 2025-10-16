#!/usr/bin/env bash
set -euxo pipefail

echo "Iniciando Tailscale em modo userspace com proxies..."

# Verificar se a variável TAILSCALE_AUTHKEY está definida
if [ -z "${TAILSCALE_AUTHKEY:-}" ]; then
    echo "ERRO: A variável de ambiente TAILSCALE_AUTHKEY não está definida!"
    echo "Configure-a no painel do Render em Environment Variables."
    exit 1
fi

echo "Auth key encontrada, continuando..."

# Iniciar Tailscale userspace com proxies SOCKS5 e HTTP para egress
tailscaled --tun=userspace-networking \
  --socks5-server=localhost:1055 \
  --outbound-http-proxy-listen=localhost:1055 &

# Aguardar um momento para o tailscaled inicializar
sleep 2

# Conectar à rede Tailscale
# Usar o nome do serviço do Render como hostname se disponível
HOSTNAME=${RENDER_SERVICE_NAME:-"ubuntu-on-render"}
echo "Conectando com hostname: ${HOSTNAME}"
tailscale up --authkey="${TAILSCALE_AUTHKEY}" --hostname="${HOSTNAME}" --accept-dns=false

echo "Tailscale conectado com hostname: ${HOSTNAME}"

# Configurar variáveis de ambiente para roteamento via proxies Tailscale
# socks5h resolve DNS através do proxy (útil para MagicDNS)
export ALL_PROXY="socks5h://localhost:1055"
export HTTP_PROXY="http://localhost:1055"
export HTTPS_PROXY="http://localhost:1055"

echo "Proxies configurados:"
echo "  ALL_PROXY: ${ALL_PROXY}"
echo "  HTTP_PROXY: ${HTTP_PROXY}"
echo "  HTTPS_PROXY: ${HTTPS_PROXY}"

# Verificar status da conexão
tailscale status

echo "Tailscale configurado com sucesso!"
echo "O contentor está rodando. Use o Shell do Render para interagir."
echo "Todas as conexões de saída serão roteadas através do Tailscale."

# Manter o contentor ativo
tail -f /dev/null
