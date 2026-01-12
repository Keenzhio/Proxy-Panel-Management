#!/bin/bash

# Configuration
CONFIG_FILE="/etc/xray/config.json"
DOMAIN_FILE="/etc/v2ray/domain"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Check Root
if [ "${EUID}" -ne 0 ]; then
		echo -e "${RED}Please run as root${NC}"
		exit 1
fi

get_domain() {
    if [ -f "$DOMAIN_FILE" ]; then
        cat "$DOMAIN_FILE"
    else
        echo "IP-Address"
    fi
}

show_header() {
    clear
    local domain=$(get_domain)
    local ip_vps=$(curl -s ifconfig.me)
    local ram_used=$(free -m | grep Mem: | awk '{print $3}')
    local ram_total=$(free -m | grep Mem: | awk '{print $2}')
    local core=$(nproc)
    local os=$(lsb_release -d 2>/dev/null | awk -F"\t" '{print $2}')
    [ -z "$os" ] && os=$(grep PRETTY_NAME /etc/os-release | cut -d '"' -f 2)
    local date_now=$(date +%d-%m-%Y)
    local time_now=$(date +%H-%M-%S)
    local uptime_sys=$(uptime -p | sed 's/up //')
    # Simple CPU usage estimate
    local cpu_usage=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage}' | cut -d. -f1)

    echo -e "${BLUE}==================================================${NC}"
    echo -e "${RED}           PREMIUM TUNNEL SCRIPT v1.0             ${NC}"
    echo -e "${BLUE}==================================================${NC}"
    echo -e "${RED}●${NC} SYSTEM OS    = ${CYAN}$os${NC}"
    echo -e "${RED}●${NC} SYSTEM CORE  = ${CYAN}$core${NC}"
    echo -e "${RED}●${NC} SERVER RAM   = ${CYAN}$ram_used / $ram_total MB${NC}"
    echo -e "${RED}●${NC} LOADCPU      = ${CYAN}$cpu_usage %${NC}"
    echo -e "${RED}●${NC} DATE         = ${CYAN}$date_now${NC}"
    echo -e "${RED}●${NC} TIME         = ${CYAN}$time_now${NC}"
    echo -e "${RED}●${NC} UPTIME       = ${CYAN}$uptime_sys${NC}"
    echo -e "${RED}●${NC} IP VPS       = ${CYAN}$ip_vps${NC}"
    echo -e "${RED}●${NC} DOMAIN       = ${CYAN}$domain${NC}"
    echo -e "${BLUE}==================================================${NC}"
}

menu_ssh() {
    clear
    echo -e "${BLUE}=== WASSH / SSH MENU ===${NC}"
    echo -e "1. Create SSH User"
    echo -e "2. Delete SSH User"
    echo -e "3. Renew SSH User"
    echo -e "0. Back to Main Menu"
    read -p "Select Option: " opt
    case $opt in
        1) 
            read -p "Username: " user
            read -p "Password: " pass
            read -p "Days: " days
            useradd -e `date -d "$days days" +"%Y-%m-%d"` -s /bin/bash -m $user
            echo -e "$pass\n$pass\n" | passwd $user
            echo -e "User $user created!"
            sleep 2
            ;;
        2)
            read -p "Username to delete: " user
            userdel -f $user
            echo "User $user deleted"
            sleep 2
            ;;
        *) menu ;;
    esac
    menu
}

menu_vmess() {
    # Placeholder for Vmess logic using jq
    clear
    echo -e "${BLUE}=== VMESS MENU ===${NC}"
    echo -e "1. Add Vmess User"
    echo -e "2. Delete Vmess User"
    echo -e "0. Back"
    read -p "Select: " opt
    case $opt in
        1)
            read -p "Username: " user
            uuid=$(cat /proc/sys/kernel/random/uuid)
            # Add to Inbound 1 (Vmess)
            jq --arg user "$user" --arg uuid "$uuid" \
               '.inbounds[1].settings.clients += [{"id": $uuid, "alterId": 0, "email": $user}]' \
               $CONFIG_FILE > tmp.json && mv tmp.json $CONFIG_FILE
            
            systemctl restart xray
            echo -e "Vmess User Created!"
            echo -e "UUID: $uuid"
            sleep 3
            ;;
        *) menu ;;
    esac
    menu
}

menu_vless() {
    clear
    echo -e "${BLUE}=== VLESS MENU ===${NC}"
    echo -e "1. Add Vless User"
    echo -e "2. Delete Vless User"
    echo -e "0. Back"
    read -p "Select: " opt
    case $opt in
        1)
            read -p "Username: " user
            uuid=$(cat /proc/sys/kernel/random/uuid)
            jq --arg user "$user" --arg uuid "$uuid" \
               '.inbounds[2].settings.clients += [{"id": $uuid, "email": $user}]' \
               $CONFIG_FILE > tmp.json && mv tmp.json $CONFIG_FILE
            systemctl restart xray
            echo -e "Vless User Created!"
            echo -e "UUID: $uuid"
            sleep 3
            ;;
        2)
            # Simple deletion by filtering (requires more complex jq, simplifying for prototype)
             read -p "Username to delete: " user
             jq --arg user "$user" 'del(.inbounds[2].settings.clients[] | select(.email == $user))' \
                $CONFIG_FILE > tmp.json && mv tmp.json $CONFIG_FILE
             systemctl restart xray
             echo "User deleted."
             sleep 2
             ;;
        *) menu ;;
    esac
    menu
}

menu_trojan() {
    clear
    echo -e "${BLUE}=== TROJAN MENU ===${NC}"
    echo -e "1. Add Trojan User"
    echo -e "2. Delete Trojan User"
    echo -e "0. Back"
    read -p "Select: " opt
    case $opt in
        1)
            read -p "Username: " user
            read -p "Password: " pass
            jq --arg user "$user" --arg pass "$pass" \
               '.inbounds[3].settings.clients += [{"password": $pass, "email": $user}]' \
               $CONFIG_FILE > tmp.json && mv tmp.json $CONFIG_FILE
            systemctl restart xray
            echo -e "Trojan User Created!"
            sleep 3
            ;;
         2)
             read -p "Username to delete: " user
             jq --arg user "$user" 'del(.inbounds[3].settings.clients[] | select(.email == $user))' \
                $CONFIG_FILE > tmp.json && mv tmp.json $CONFIG_FILE
             systemctl restart xray
             echo "User deleted."
             sleep 2
             ;;
        *) menu ;;
    esac
    menu
}

menu_socks() {
    clear
    echo -e "${BLUE}=== SOCKS5 MENU ===${NC}"
    echo -e "1. Add Socks5 User"
    echo -e "2. Delete Socks5 User"
    echo -e "0. Back"
    read -p "Select: " opt
    case $opt in
        1)
            read -p "Username: " user
            read -p "Password: " pass
            jq --arg user "$user" --arg pass "$pass" \
               '.inbounds[4].settings.accounts += [{"user": $user, "pass": $pass}]' \
               $CONFIG_FILE > tmp.json && mv tmp.json $CONFIG_FILE
            systemctl restart xray
            echo -e "Socks User Created!"
            sleep 3
            ;;
        *) menu ;;
    esac
    menu
}

menu_settings() {
    clear
    echo -e "${BLUE}=== SETTINGS MENU ===${NC}"
    echo -e "1. Change Socks5 Port"
    echo -e "2. Change HTTP Port"
    echo -e "0. Back"
    read -p "Select: " opt
    case $opt in
        1)
            read -p "New Socks5 Port: " port
            jq --argjson port $port '.inbounds[4].port = $port' $CONFIG_FILE > tmp.json && mv tmp.json $CONFIG_FILE
            systemctl restart xray
            echo "Port changed to $port"
            sleep 2
            ;;
        2)
            read -p "New HTTP Port: " port
            jq --argjson port $port '.inbounds[5].port = $port' $CONFIG_FILE > tmp.json && mv tmp.json $CONFIG_FILE
            systemctl restart xray
            echo "Port changed to $port"
            sleep 2
            ;;
        *) menu ;;
    esac
    menu
}

menu() {
    show_header
    echo -e "[01] SSH MENU"
    echo -e "[02] VMESS MENU"
    echo -e "[03] VLESS MENU"
    echo -e "[04] TROJAN MENU"
    echo -e "[05] SOCKS5 SETTINGS"
    echo -e "[06] CHANGE PORTS"
    echo -e "[07] RESTART SERVICES"
    echo -e "[00] EXIT"
    echo -e ""
    read -p "Select Menu [1-7]: " opt
    
    case $opt in
        1) menu_ssh ;;
        2) menu_vmess ;;
        3) menu_vless ;;
        4) menu_trojan ;;
        5) menu_socks ;;
        6) menu_settings ;;
        7) systemctl restart xray nginx ; echo "Services Restarted" ; sleep 2 ; menu ;;
        0) exit 0 ;;
        *) echo "Invalid Option" ; sleep 1 ; menu ;;
    esac
}

menu
