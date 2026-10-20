#!/data/data/com.termux/files/usr/bin/bash

# ==========================================
# CONSTANTS & CONFIGURATIONS
# ==========================================
PASSWORD_REQ="adifluqman"
CONFIG_FILE="$HOME/.autordif_config"

# Colors (ANSI Escape Codes)
NC='\033[0m'
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'

# Default States
SELECTED_EXECUTOR=""
AUTO_RECONNECT="OFF"
JOIN_MODE="GAME_ID" # GAME_ID or PRIVATE_SERVER
GAME_ID="1537690962" # Default Bee Swarm Simulator ID
SERVER_LINK=""
DISCORD_WEBHOOK=""
CHECK_INTERVAL=15
MODE_ROOT=false

# Multi-Package List & Status Tracking Array
ROBLOX_PACKAGES=()
declare -A PKG_STATUSES
declare -A PKG_LAUNCH_TIMES

# Force Close / Rejoin Settings
FORCE_CLOSE_ENABLED="OFF"
FORCE_CLOSE_INTERVAL=1800
STUCK_TIMEOUT=45

# Runtime Tracking Variables
START_TIME=0
ROBLOX_USERNAME="Unknown"
PID_FILE="$HOME/.autordif_monitor.pid"
STATUS_FILE="$HOME/.autordif_status"

# ==========================================
# HELPER FUNCTIONS
# ==========================================
clear_screen() {
    clear
}

draw_banner() {
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${MAGENTA}${BOLD}"
    echo "  █████╗ ██║   ██║████████╗██████╗ ██████╗ ██╗███████╗"
    echo " ██╔══██╗██║   ██║╚══██╔══╝██╔══██╗██╔══██╗██║██╔════╝"
    echo " ███████║██║   ██║   ██║   ██████╔╝██║  ██║██║█████╗  "
    echo " ██╔══██║██║   ██║   ██║   ██╔══██╗██║  ██║██║██╔══╝  "
    echo " ██║  ██║╚██████╔╝   ██║   ██║  ██║██████╔╝██║██║     "
    echo " ╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚═╝  ╚═╝╚═════╝ ╚═╝╚═╝     "
    echo -e "${NC}"
    echo -e "${YELLOW}${BOLD}           ---> AUTO RECONNECT BY DIF <---${NC}"
    echo -e "${CYAN}====================================================${NC}"
    echo ""
}

get_current_datetime() {
    date "+%Y-%m-%d %H:%M:%S"
}

get_elapsed_time() {
    if [ "$START_TIME" -eq 0 ]; then
        echo "00h 00m 00s"
        return
    fi
    local now=$(date +%s)
    local diff=$((now - START_TIME))
    local hours=$((diff / 3600))
    local minutes=$(( (diff % 3600) / 60 ))
    local seconds=$((diff % 60))
    printf "%02dh %02dm %02ds" $hours $minutes$seconds
}

set_status() {
    echo "$1" > "$STATUS_FILE"
}

get_status() {
    if [ -f "$STATUS_FILE" ]; then
        cat "$STATUS_FILE"
    else
        echo "CLOSED"
    fi
}

set_pkg_status() {
    local pkg="$1"
    local stat="$2"
    PKG_STATUSES["$pkg"]="$stat"
}

send_discord_log() {
    local message="$1"
    if [ -n "$DISCORD_WEBHOOK" ]; then
        local payload=$(cat <<EOF
{
  "username": "AUTORDIF Multi-Bot",
  "embeds": [
    {
      "title": "Multi-Account Notification",
      "description": "$message",
      "color": 3447003,
      "footer": {
        "text": "Timestamp: $(get_current_datetime)"
      }
    }
  ]
}
EOF
)
        curl -H "Content-Type: application/json" -X POST -d "$payload" "$DISCORD_WEBHOOK" > /dev/null 2>&1 &
    fi
}

# ==========================================
# AUTO-SCAN ALL PACKAGES (com.roblox.____)
# ==========================================
check_root_and_package() {
    echo -e "${BLUE}[*] Checking Root status...${NC}"
    if su -c "id" >/dev/null 2>&1; then
        MODE_ROOT=true
        echo -e "${GREEN}[+] Root Access Granted!${NC}"
    else
        MODE_ROOT=false
        echo -e "${YELLOW}[!] Root Access Not Detected (Running in Non-Root mode).${NC}"
