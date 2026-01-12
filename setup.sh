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
    
    # Repo Config (Ganti INI dengan Username/Repo GitHub mu)
    # Contoh: REPO="https://raw.githubusercontent.com/username/repo/main/tunnel-script"
    REPO="https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/YOUR_REPO_NAME/main/tunnel-script"

    # Make Config Directory
    mkdir -p /etc/xray
    mkdir -p /etc/nginx/sites-available
    
    # 1. Auto-Create Xray Config (No need manual create)
    log "Creating Xray Config..."
    cat > /etc/xray/config.json <<EOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none",
        "fallbacks": [
          {
            "dest": 81
          },
          {
            "path": "/vmess",
            "dest": 10001
          },
          {
            "path": "/vless",
            "dest": 10002
          },
          {
            "path": "/trojan",
            "dest": 10003
          },
          {
            "path": "/ss",
            "dest": 10004
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/xray/xray.crt",
              "keyFile": "/etc/xray/xray.key"
            }
          ]
        }
      }
    },
    {
      "port": 10001,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vmess"
        }
      }
    },
    {
      "port": 10002,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vless"
        }
      }
    },
    {
      "port": 10003,
      "listen": "127.0.0.1",
      "protocol": "trojan",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/trojan"
        }
      }
    },
    {
      "port": 1080,
      "protocol": "socks",
      "settings": {
        "auth": "password",
        "accounts": [
          {
            "user": "admin",
            "pass": "admin"
          }
        ],
        "udp": true
      }
    },
    {
      "port": 8080,
      "protocol": "http",
      "settings": {
        "userLevel": 0
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ]
}
EOF

    # 2. Auto-Create Nginx Config
    log "Creating Nginx Config..."
    cat > /etc/nginx/sites-available/tunnel <<EOF
server {
    listen 81;
    server_name 127.0.0.1 localhost;

    access_log /var/log/nginx/vps-access.log;
    error_log /var/log/nginx/vps-error.log;

    root /var/www/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

    ln -s /etc/nginx/sites-available/tunnel /etc/nginx/sites-enabled/tunnel
    rm /etc/nginx/sites-enabled/default
    
    # 3. Download Menu from GitHub
    log "Downloading Menu..."
    wget -q -O /usr/bin/menu "${REPO}/menu.sh"
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
