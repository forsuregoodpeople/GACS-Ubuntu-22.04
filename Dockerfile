FROM ubuntu:24.04

# Avoid interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Jakarta

# Install system dependencies
RUN apt-get update --allow-insecure-repositories -o Acquire::AllowInsecureRepositories=true \
    && apt-get install -y --allow-unauthenticated \
    curl \
    wget \
    gnupg \
    software-properties-common \
    iproute2 \
    iptables \
    net-tools \
    supervisor \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 18.x (LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y --allow-unauthenticated nodejs

# Install MongoDB 8.0 (compatible with Ubuntu 24.04 Noble)
RUN curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | \
    gpg --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg \
    && echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.0 multiverse" | \
    tee /etc/apt/sources.list.d/mongodb-org-8.0.list \
    && apt-get update --allow-insecure-repositories -o Acquire::AllowInsecureRepositories=true \
    && apt-get install -y --allow-unauthenticated mongodb-org

# Install GenieACS
RUN npm install -g genieacs@1.2.13

# Create genieacs user and directories
RUN useradd --system --no-create-home --user-group genieacs \
    && mkdir -p /opt/genieacs/ext \
    && mkdir -p /var/log/genieacs \
    && chown -R genieacs:genieacs /opt/genieacs \
    && chown -R genieacs:genieacs /var/log/genieacs

# Create data directories
RUN mkdir -p /data/db /data/logs /var/log/mongodb \
    && chown -R mongodb:mongodb /data/db /var/log/mongodb \
    && chown -R genieacs:genieacs /data/logs

# Copy configuration files
COPY config/ /opt/genieacs/
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /entrypoint.sh

# Make scripts executable
RUN chmod +x /entrypoint.sh

# Set proper permissions
RUN chown genieacs:genieacs /opt/genieacs/genieacs.env \
    && chmod 600 /opt/genieacs/genieacs.env

# Expose ports
EXPOSE 7547 7557 7567 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:3000 || exit 1

# Start services using supervisor
CMD ["/entrypoint.sh"]