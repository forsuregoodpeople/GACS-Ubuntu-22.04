FROM ubuntu:20.04

# Avoid interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Jakarta

# Install system dependencies + MongoDB from Ubuntu repo (no AVX required)
# Using 'mongodb' package from Ubuntu 20.04 repo (v4.4 compatible, QEMU-safe)
RUN apt-get update \
    && apt-get install -y \
    curl \
    wget \
    gnupg \
    software-properties-common \
    iproute2 \
    iptables \
    net-tools \
    supervisor \
    ca-certificates \
    mongodb \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 18.x (LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs

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
    && chmod -R 755 /data/db /var/log/mongodb \
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