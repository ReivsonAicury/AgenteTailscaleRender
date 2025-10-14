# 1. Utilizar a imagem base do Ubuntu mais recente
FROM ubuntu:latest

# 2. Definir o diretório de trabalho
WORKDIR /app

# 3. Atualizar pacotes e instalar as dependências necessárias
# - curl: para descarregar o script de instalação
# - ca-certificates: para ligações https seguras
# - iputils-ping: para podermos testar a conectividade com 'ping'
RUN apt-get update && \
    apt-get install -y curl ca-certificates iputils-ping && \
    rm -rf /var/lib/apt/lists/*

# 4. Descarregar e executar o script de instalação oficial do Tailscale
RUN curl -fsSL https://tailscale.com/install.sh | sh

# 5. Copiar o nosso script de arranque para dentro da imagem
COPY start.sh /app/start.sh

# 6. Dar permissão de execução ao script de arranque
RUN chmod +x /app/start.sh

# 7. Definir o script de arranque como o comando a ser executado quando o contentor iniciar
CMD ["/app/start.sh"]