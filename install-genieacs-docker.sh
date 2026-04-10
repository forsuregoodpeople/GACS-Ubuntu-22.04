#!/bin/bash

# GenieACS Docker Installer
# Compatible with Ubuntu 18.04 - 24.04
# Features: Auto Docker installation, native network (bridge), no ZeroTier
# Version: 2.0

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration variables
INSTALL_DIR="/opt/genieacs-docker"
DATA_DIR="/opt/genieacs-docker/data"
LOG_FILE="/var/log/genieacs-docker-install.log"

# Function to display spinner
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "${CYAN} [%c]  ${NC}" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Function to run command with progress
run_command() {
    local cmd="$1"
    local msg="$2"
    printf "${YELLOW}%-60s${NC}" "$msg..."

    # Execute command with better error handling
    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        echo -e "${GREEN}Done${NC}"
        return 0
    else
        local exit_code=$?
        echo -e "${RED}Failed${NC}"
        echo -e "${RED}Command failed with exit code: $exit_code${NC}"

        # Show last few lines of log for debugging
        if [ -f "$LOG_FILE" ]; then
            echo -e "${YELLOW}Last few lines from log:${NC}"
            tail -n 5 "$LOG_FILE" 2>/dev/null || echo "Could not read log file"
            echo -e "${RED}Full log available at: $LOG_FILE${NC}"
        fi

        exit 1
    fi
}

# Print banner
print_banner() {
    echo -e "${BLUE}${BOLD}"
    echo "   ____            _        ____            _     _        "
    echo "  / ___|  ___ _ __(_) ___  |  _ \  ___   ___| | __(_)_ __   "
    echo " | |  _  / _ \ '__| |/ _ \ | | | |/ _ \ / __| |/ /| | '_ \  "
    echo " | |_| ||  __/ |  | |  __/ | |_| | (_) | (__|   < | | |_) | "
    echo "  \____| \___|_|  |_|\___| |____/ \___/ \___|_|\_\|_| .__/  "
    echo "                                                   |_|     "
    echo ""
    echo "              GenieACS Docker Installer"
    echo "                  Ubuntu 18.04 - 24.04"
    echo -e "${NC}"
}

# Check for root access and system requirements
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}This script must be run as root${NC}"
        echo -e "${YELLOW}Please run: sudo $0${NC}"
        exit 1
    fi

    # Check if we can write to common directories
    for dir in "/var/log" "/opt" "/usr/local/bin"; do
        if [ ! -w "$dir" ]; then
            echo -e "${RED}Cannot write to $dir - permission issue${NC}"
            exit 1
        fi
    done
}

# Detect OS and version
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        echo -e "${RED}Cannot detect OS version${NC}"
        exit 1
    fi

    echo -e "${CYAN}Detected OS: $OS $VER${NC}"

    case $OS in
        ubuntu|debian)
            PACKAGE_MANAGER="apt-get"
            ;;
        centos|rhel|fedora)
            PACKAGE_MANAGER="yum"
            ;;
        *)
            echo -e "${YELLOW}Warning: Untested OS. Proceeding with apt-get...${NC}"
            PACKAGE_MANAGER="apt-get"
            ;;
    esac
}

# Install Docker and Docker Compose
install_docker() {
    if command -v docker > /dev/null 2>&1 && command -v docker-compose > /dev/null 2>&1; then
        echo -e "${GREEN}Docker and Docker Compose already installed${NC}"
        return
    fi

    case $PACKAGE_MANAGER in
        apt-get)
            run_command "$PACKAGE_MANAGER update -y" "Updating package list"
            run_command "$PACKAGE_MANAGER install -y apt-transport-https ca-certificates curl gnupg lsb-release" "Installing dependencies"
            run_command "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg" "Adding Docker GPG key"
            run_command "echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null" "Adding Docker repository"
            run_command "$PACKAGE_MANAGER update -y" "Updating package list"
            run_command "$PACKAGE_MANAGER install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin" "Installing Docker"
            ;;
        yum)
            run_command "$PACKAGE_MANAGER update -y" "Updating package list"
            run_command "$PACKAGE_MANAGER install -y yum-utils" "Installing yum-utils"
            run_command "yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo" "Adding Docker repository"
            run_command "$PACKAGE_MANAGER install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin" "Installing Docker"
            ;;
    esac

    run_command "systemctl start docker" "Starting Docker service"
    run_command "systemctl enable docker" "Enabling Docker service"

    # Install docker-compose if not available
    # docker-compose-plugin provides 'docker compose' (with space); create a shim if the hyphenated form is missing
    if ! command -v docker-compose > /dev/null 2>&1; then
        if docker compose version > /dev/null 2>&1; then
            # Plugin is available — create a wrapper shim
            cat > /usr/local/bin/docker-compose << 'SHIM'
#!/bin/sh
exec docker compose "$@"
SHIM
            chmod +x /usr/local/bin/docker-compose
            echo -e "${GREEN}docker-compose shim created (uses docker compose plugin)${NC}"
        else
            run_command "curl -L \"https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose" "Installing Docker Compose"
            run_command "chmod +x /usr/local/bin/docker-compose" "Setting Docker Compose permissions"
        fi
    fi
}

# Setup directories
setup_directories() {
    run_command "mkdir -p $INSTALL_DIR" "Creating installation directory"
    run_command "mkdir -p $DATA_DIR/{mongodb,logs,ext}" "Creating data directories"
    run_command "chmod -R 755 $INSTALL_DIR" "Setting directory permissions"
}

# Configure system settings
configure_system() {
    echo -e "\n${MAGENTA}${BOLD}System Configuration${NC}"

    # Data directory - use default automatically
    echo -e "${CYAN}Data directory: ${GREEN}$DATA_DIR${NC} ${YELLOW}(using recommended default)${NC}"

    # Timezone - use default automatically
    TZ="Asia/Jakarta"
    echo -e "${CYAN}Timezone: ${GREEN}$TZ${NC} ${YELLOW}(using recommended default)${NC}"

    # GenieACS Interface bindings - bind to all interfaces
    GENIEACS_CWMP_INTERFACE="0.0.0.0"
    GENIEACS_NBI_INTERFACE="0.0.0.0"
    GENIEACS_FS_INTERFACE="0.0.0.0"
    GENIEACS_UI_INTERFACE="0.0.0.0"

    echo -e "\n${CYAN}GenieACS Interface Configuration:${NC}"
    echo -e "${CYAN}  CWMP Interface (TR-069): ${GREEN}$GENIEACS_CWMP_INTERFACE${NC} ${YELLOW}(all interfaces)${NC}"
    echo -e "${CYAN}  NBI Interface: ${GREEN}$GENIEACS_NBI_INTERFACE${NC} ${YELLOW}(all interfaces)${NC}"
    echo -e "${CYAN}  File Server Interface: ${GREEN}$GENIEACS_FS_INTERFACE${NC} ${YELLOW}(all interfaces)${NC}"
    echo -e "${CYAN}  Web UI Interface: ${GREEN}$GENIEACS_UI_INTERFACE${NC} ${YELLOW}(all interfaces)${NC}"
}

# Create configuration files
create_config() {
    # Create .env file
    cat > "$INSTALL_DIR/.env" << EOF
# Data directory
DATA_DIR=$DATA_DIR

# GenieACS Interface Configuration
GENIEACS_CWMP_INTERFACE=$GENIEACS_CWMP_INTERFACE
GENIEACS_NBI_INTERFACE=$GENIEACS_NBI_INTERFACE
GENIEACS_FS_INTERFACE=$GENIEACS_FS_INTERFACE
GENIEACS_UI_INTERFACE=$GENIEACS_UI_INTERFACE

# MongoDB Configuration
MONGO_DATA_DIR=/data/db

# Extensions directory on host
GENIEACS_EXT_HOST_DIR=$DATA_DIR/ext

# Timezone
TZ=$TZ
EOF

    echo -e "${GREEN}Configuration file created: $INSTALL_DIR/.env${NC}"
}

# Copy Docker files
copy_docker_files() {
    local source_dir=$(dirname "$(readlink -f "$0")")

    # Copy all necessary files
    for file in Dockerfile docker-compose.yml entrypoint.sh supervisord.conf; do
        if [ -f "$source_dir/$file" ]; then
            run_command "cp $source_dir/$file $INSTALL_DIR/" "Copying $file"
        else
            echo -e "${RED}Error: $file not found in $source_dir${NC}"
            exit 1
        fi
    done

    # Copy config directory
    if [ -d "$source_dir/config" ]; then
        run_command "cp -r $source_dir/config $INSTALL_DIR/" "Copying config directory"
    else
        echo -e "${RED}Error: config directory not found in $source_dir${NC}"
        exit 1
    fi

    run_command "chmod +x $INSTALL_DIR/entrypoint.sh" "Setting executable permissions"
}

# Fix Docker registry authentication issues with comprehensive fallbacks
fix_docker_registry() {
    echo -e "\n${MAGENTA}${BOLD}Resolving Docker Registry Issues...${NC}"

    # Step 1: Restart Docker daemon to clear cache
    echo -e "${CYAN}Restarting Docker service to clear cache...${NC}"
    run_command "systemctl restart docker" "Restarting Docker service"
    sleep 5

    # Step 2: Clear any existing authentication
    echo -e "${CYAN}Clearing Docker authentication...${NC}"
    docker logout > /dev/null 2>&1 || true

    # Step 3: Configure Docker daemon for better registry handling
    echo -e "${CYAN}Optimizing Docker daemon configuration...${NC}"
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << 'EOF'
{
    "registry-mirrors": [
        "https://mirror.gcr.io"
    ],
    "max-concurrent-downloads": 3,
    "max-concurrent-uploads": 3,
    "max-download-attempts": 5,
    "storage-driver": "overlay2"
}
EOF

    run_command "systemctl restart docker" "Applying Docker daemon configuration"
    sleep 5

    # Step 4: Comprehensive base image pulling with multiple fallbacks
    echo -e "${CYAN}Pulling Ubuntu 24.04 base image with fallback registries...${NC}"

    # List of registries to try in order
    local registries=(
        "ubuntu:24.04"                                    # Docker Hub (primary)
        "public.ecr.aws/ubuntu/ubuntu:24.04"             # AWS ECR Public
        "mcr.microsoft.com/mirror/docker/library/ubuntu:24.04"  # Microsoft Container Registry
    )

    local registry_names=(
        "Docker Hub"
        "AWS ECR Public"
        "Microsoft Container Registry"
    )

    local success=false
    local primary_failed=false

    for i in "${!registries[@]}"; do
        local registry="${registries[$i]}"
        local name="${registry_names[$i]}"

        echo -e "${YELLOW}Trying $name: $registry${NC}"

        # Try pulling with timeout
        if timeout 180 docker pull "$registry" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Successfully pulled from $name${NC}"

            # If not the primary registry, tag it as ubuntu:24.04
            if [ "$registry" != "ubuntu:24.04" ]; then
                docker tag "$registry" ubuntu:24.04
                echo -e "${GREEN}Tagged as ubuntu:24.04 for build compatibility${NC}"
            fi

            success=true
            break
        else
            echo -e "${RED}❌ Failed to pull from $name${NC}"
            if [ $i -eq 0 ]; then
                primary_failed=true
            fi
        fi

        # Small delay between attempts
        sleep 2
    done

    if [ "$success" = false ]; then
        echo -e "${RED}${BOLD}ERROR: Failed to pull Ubuntu 24.04 from all registries${NC}"
        echo -e "${YELLOW}This could be due to:${NC}"
        echo -e "  1. Internet connectivity issues"
        echo -e "  2. Docker registry rate limiting"
        echo -e "  3. Temporary registry outages"
        echo -e "${YELLOW}Please try running the installer again in a few minutes.${NC}"
        return 1
    fi

    # Step 5: Verify image is available
    echo -e "${CYAN}Verifying base image availability...${NC}"
    if docker image inspect ubuntu:24.04 > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Ubuntu 24.04 base image ready for build${NC}"

        if [ "$primary_failed" = true ]; then
            echo -e "${YELLOW}Note: Using alternative registry due to Docker Hub issues${NC}"
        fi

        return 0
    else
        echo -e "${RED}❌ Base image verification failed${NC}"
        return 1
    fi
}

# Build and start containers
build_and_start() {
    cd "$INSTALL_DIR"

    # Fix Docker registry issues first
    if ! fix_docker_registry; then
        echo -e "${RED}Failed to resolve Docker registry issues${NC}"
        exit 1
    fi

    run_command "docker-compose build --no-cache" "Building Docker image"
    run_command "docker-compose up -d" "Starting GenieACS container"

    echo -e "\n${CYAN}Waiting for services to be ready...${NC}"
    sleep 10
}

# Create management script
create_management_script() {
    cat > "$INSTALL_DIR/manage.sh" << 'EOF'
#!/bin/bash

INSTALL_DIR="/opt/genieacs-docker"
cd "$INSTALL_DIR"

case "$1" in
    start)
        echo "Starting GenieACS..."
        docker-compose up -d
        ;;
    stop)
        echo "Stopping GenieACS..."
        docker-compose down
        ;;
    restart)
        echo "Restarting GenieACS..."
        docker-compose restart
        ;;
    status)
        echo "GenieACS Status:"
        docker-compose ps
        ;;
    logs)
        docker-compose logs -f --tail=100
        ;;
    shell)
        docker-compose exec genieacs bash
        ;;
    update)
        echo "Updating GenieACS..."
        docker-compose pull
        docker-compose up -d
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|shell|update}"
        echo ""
        echo "Commands:"
        echo "  start   - Start GenieACS services"
        echo "  stop    - Stop GenieACS services"
        echo "  restart - Restart GenieACS services"
        echo "  status  - Show container status"
        echo "  logs    - Show logs (follow mode)"
        echo "  shell   - Access container shell"
        echo "  update  - Update and restart containers"
        exit 1
        ;;
esac
EOF

    chmod +x "$INSTALL_DIR/manage.sh"
    ln -sf "$INSTALL_DIR/manage.sh" /usr/local/bin/genieacs
    echo -e "${GREEN}Management script created: $INSTALL_DIR/manage.sh${NC}"
    echo -e "${GREEN}Symlink created: /usr/local/bin/genieacs${NC}"
}

# Show final information
show_final_info() {
    # Detect server IP address
    SERVER_IP=$(hostname -I | awk '{print $1}')

    echo -e "\n${GREEN}${BOLD}Installation completed successfully!${NC}\n"

    echo -e "${CYAN}Service Information:${NC}"
    echo -e "  Installation Directory: $INSTALL_DIR"
    echo -e "  Data Directory: $DATA_DIR"
    echo -e "  Configuration: $INSTALL_DIR/.env"

    echo -e "\n${CYAN}Access URLs (listening on ALL interfaces - 0.0.0.0):${NC}"
    echo -e "  Web UI:           http://$SERVER_IP:3000"
    echo -e "  CWMP (TR-069):    http://$SERVER_IP:7547"
    echo -e "  NBI API:          http://$SERVER_IP:7557"
    echo -e "  File Server:      http://$SERVER_IP:7567"
    echo -e "\n${YELLOW}  Note: Services accessible from ANY IP on this host${NC}"
    echo -e "${YELLOW}  (Tailscale, VPN, port forwarding, semua IP akan bekerja)${NC}"

    echo -e "\n${CYAN}Management Commands:${NC}"
    echo -e "  genieacs start   - Start services"
    echo -e "  genieacs stop    - Stop services"
    echo -e "  genieacs restart - Restart services"
    echo -e "  genieacs status  - Show status"
    echo -e "  genieacs logs    - Show logs"

    echo -e "\n${YELLOW}Important Notes:${NC}"
    echo -e "  1. Configure ONUs to use ACS URL: http://<TAILSCALE-IP>:7547 atau http://$SERVER_IP:7547"
    echo -e "  2. Open ports 7547, 7557, 7567, 3000 in your firewall if needed"
    echo -e "  3. Check logs with: genieacs logs"
    echo -e "  4. Services bind ke 0.0.0.0 — bisa diakses dari semua interface (Tailscale, VPN, dll)"
}

# Initialize log file with proper permissions
init_log() {
    # Create log file with proper permissions
    if ! touch "$LOG_FILE" 2>/dev/null; then
        # Fallback to user's home directory if /var/log is not writable
        LOG_FILE="$HOME/genieacs-docker-install.log"
        touch "$LOG_FILE" 2>/dev/null || {
            # Final fallback to current directory
            LOG_FILE="./genieacs-docker-install.log"
            touch "$LOG_FILE"
        }
    fi

    # Initialize log
    echo "GenieACS Docker Installation Log - $(date)" > "$LOG_FILE"
    chmod 644 "$LOG_FILE" 2>/dev/null
}

# Main installation process
main() {
    init_log

    print_banner
    check_root
    detect_os

    echo -e "\n${MAGENTA}${BOLD}Starting GenieACS Docker Installation${NC}\n"

    install_docker
    setup_directories
    configure_system
    create_config
    copy_docker_files
    build_and_start
    create_management_script
    show_final_info

    echo -e "\n${GREEN}${BOLD}Installation log saved to: $LOG_FILE${NC}"
}

# Run main function
main "$@"
