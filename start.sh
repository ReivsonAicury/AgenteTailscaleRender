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
tailscale up --authkey="${TAILSCALE_AUTHKEY}" --hostname="${HOSTNAME}" --accept-dns=false --accept-routes

# Aguardar conexão estabilizar
sleep 3

# Configurar para usar a VM como exit node (opcional, para testes)
echo "Configurando exit node para 100.83.21.97..."
tailscale set --exit-node=100.83.21.97 || echo "Falha ao configurar exit node (tentaremos sem)"

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
echo "=== Status do Tailscale ==="
tailscale status
echo ""

echo "=== IP do container na rede Tailscale ==="
tailscale ip -4
echo ""

echo "=== Testando conectividade básica ==="
echo "Ping para 100.83.21.97 (pode falhar por restrições ICMP):"
timeout 5 ping -c 2 100.83.21.97 || echo "Ping falhou (normal em alguns ambientes)"
echo ""

echo "=== Testando conectividade TCP geral ==="
echo "Testando porta 22 (SSH) em 100.83.21.97:"
timeout 10 nc -zv 100.83.21.97 22 || echo "Conexão SSH direta falhou"
echo ""
echo "Testando porta 5433 (PostgreSQL) em 100.83.21.97:"
timeout 10 nc -zv 100.83.21.97 5433 || echo "Conexão PostgreSQL direta falhou"
echo ""

echo "=== Verificando proxy SOCKS5 ==="
echo "Verificando se o proxy SOCKS5 está rodando:"
netstat -tlnp | grep 1055 || echo "Proxy SOCKS5 não está ouvindo na porta 1055"
echo ""

echo "=== Testando via proxy SOCKS5 ==="
echo "Testando SSH via proxy SOCKS5:"
timeout 10 curl -x socks5h://localhost:1055 --connect-timeout 5 -v telnet://100.83.21.97:22 || echo "SSH via proxy falhou"
echo ""
echo "Testando PostgreSQL via proxy SOCKS5:"
timeout 10 curl -x socks5h://localhost:1055 --connect-timeout 5 -v telnet://100.83.21.97:5433 || echo "PostgreSQL via proxy falhou"
echo ""

echo "=== Testando com proxychains (se disponível) ==="
if command -v proxychains4 >/dev/null 2>&1; then
    echo "host 127.0.0.1" > /tmp/proxychains.conf
    echo "port 1055" >> /tmp/proxychains.conf
    echo "socks5 127.0.0.1 1055" >> /tmp/proxychains.conf
    timeout 10 proxychains4 -f /tmp/proxychains.conf nc -zv 100.83.21.97 5433 || echo "Proxychains falhou"
else
    echo "proxychains4 não disponível"
fi
echo ""

echo "=== Testando PostgreSQL com variáveis de proxy ==="
echo "Testando pg_isready com variáveis de ambiente:"
timeout 10 pg_isready -h 100.83.21.97 -p 5433 -U postgres || echo "pg_isready falhou (pode não respeitar proxy)"
echo ""

echo "=== Informações de rede do container ==="
echo "Interfaces de rede:"
ip addr show
echo ""
echo "Rota padrão:"
ip route show
echo ""
echo "Tabela de roteamento Tailscale:"
tailscale netcheck || echo "tailscale netcheck falhou"
echo ""

echo "=== Testando conectividade Tailscale básica ==="
echo "Testando ping para coordinate server (pode falhar por ICMP):"
timeout 5 ping -c 2 controlplane.tailscale.com || echo "Ping externo falhou (normal em alguns ambientes)"
echo ""

echo "=== Verificando se outros dispositivos Tailscale são visíveis ==="
echo "Lista de dispositivos na rede:"
tailscale status --peers
echo ""

echo "=== Testando conectividade interna Tailscale ==="
# Pegar o próprio IP Tailscale para testar loopback
TAILSCALE_IP=$(tailscale ip -4 | head -1)
echo "IP Tailscale deste container: ${TAILSCALE_IP}"
if [ -n "${TAILSCALE_IP}" ]; then
    echo "Testando conectividade para o próprio IP via Tailscale:"
    timeout 5 nc -zv ${TAILSCALE_IP} 22 2>/dev/null || echo "Auto-conectividade falhou (normal)"
fi
echo ""

echo "Tailscale configurado com sucesso!"
echo "O contentor está rodando. Use o Shell do Render para interagir."
echo "Todas as conexões de saída serão roteadas através do Tailscale."

# Manter o contentor ativo
tail -f /dev/null
