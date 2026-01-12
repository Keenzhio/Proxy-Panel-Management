#!/bin/bash

# Global Variables
DATE=$(date +%Y-%m-%d)
DOMAIN_FILE="/etc/v2ray/domain"
CONFIG_DIR="/etc/xray"
LOG_FILE="/var/log/setup_tunnel.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check Root
if [ "${EUID}" -ne 0 ]; then
		echo -e "${RED}Error: This script must be run as root${NC}"
		exit 1
fi

# Helper Functions
log() {
    echo -e "${GREEN}[${DATE}] $1${NC}"
    echo "[${DATE}] $1" >> "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    echo "[ERROR] $1" >> "$LOG_FILE"
}

install_dependencies() {
    log "Updating system and installing dependencies..."
    apt-get update && apt-get upgrade -y
    apt-get install -y curl wget git socat jq unzip zip net-tools gnupg2 dnsutils lsb-release
    
    # Set timezone to Asia/Jakarta (Common for ID users based on request language)
    ln -sf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
}

install_xray() {
    log "Installing Xray Core..."
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
}

install_nginx() {
    log "Installing Nginx..."
    apt-get install -y nginx
    systemctl stop nginx
}

setup_domain() {
    log "Setting up Domain..."
    mkdir -p /etc/v2ray
    echo -e "${YELLOW}Please enter your domain/subdomain:${NC}"
    read -p "Domain: " domain
    echo "$domain" > "$DOMAIN_FILE"
    
    log "Domain set to: $domain"
    
    # ACME SSL
    log "Installing SSL for $domain..."
    mkdir -p /var/lib/premium-script/ipvps.conf
    curl https://get.acme.sh | sh
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    ~/.acme.sh/acme.sh --register-account -m "admin@$domain"
    ~/.acme.sh/acme.sh --issue -d "$domain" --standalone
    ~/.acme.sh/acme.sh --installcert -d "$domain" \
        --key-file /etc/xray/xray.key \
        --fullchain-file /etc/xray/xray.crt
}

main() {
    clear
    echo -e "${BLUE}==================================================${NC}"
    echo -e "${BLUE}       TUNNEL PROXY INSTALLER SCRIPT              ${NC}"
    echo -e "${BLUE}==================================================${NC}"
    echo ""
    
    install_dependencies
    install_xray
    install_nginx
    setup_domain
    
    # Copy Configurations
    log "Copying configurations..."
    mkdir -p /etc/xray
    cp xray_config.json /etc/xray/config.json
    
    # Nginx Config
    lb_conf="/etc/nginx/sites-available/tunnel"
    cp nginx.conf "$lb_conf"
    ln -s "$lb_conf" /etc/nginx/sites-enabled/tunnel
    rm /etc/nginx/sites-enabled/default
    
    # Install Menu
    log "Installing Menu..."
    cp menu.sh /usr/bin/menu
    chmod +x /usr/bin/menu
    
    # Enable Services
    systemctl enable xray
    systemctl restart xray
    systemctl restart nginx
    
    log "Installation Complete!"
    echo -e "${GREEN}Script Installed Successfully!${NC}"
    echo -e "Type ${YELLOW}menu${NC} to access the panel."
}

main
