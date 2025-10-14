#!/bin/sh
# 'set -e' garante que o script sairá imediatamente se um comando falhar
set -e

# 1. Inicia o serviço do Tailscale (tailscaled) em segundo plano
# --tun=userspace-networking é necessário para ambientes de contentores sem privilégios como o Render
tailscaled --tun=userspace-networking &

# 2. Inicia o cliente Tailscale (tailscale up)
# --authkey=${TAILSCALE_AUTHKEY} utiliza a chave secreta para se juntar à sua rede
# --hostname=ubuntu-on-render define o nome que esta máquina terá no painel do Tailscale
# --accept-dns=false impede que o Tailscale altere o DNS interno do Render
tailscale up --authkey=${TAILSCALE_AUTHKEY} --hostname=ubuntu-on-render --accept-dns=false

# 3. Aguarda alguns segundos para garantir que a conexão Tailscale está estável
echo "Aguardando a conexão Tailscale..."
sleep 5
echo "Conexão estabelecida."

# 4. Comando para manter o contentor a correr indefinidamente
# Como este é um 'Background Worker', ele precisa de um processo que não termine.
# 'tail -f /dev/null' é um truque comum para manter um contentor vivo.
echo "O contentor está a correr. Use o 'Shell' do Render para interagir."
tail -f /dev/null
