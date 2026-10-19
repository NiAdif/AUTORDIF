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
SELECTED_EXECUTOR="Delta [KEY]"
AUTO_RECONNECT="OFF"
JOIN_MODE="GAME_ID" # GAME_ID or PRIVATE_SERVER
GAME_ID="1537690962" # Default Bee Swarm Simulator ID
SERVER_LINK=""
DISCORD_WEBHOOK=""
CHECK_INTERVAL=15
AUTOEXE_SCRIPT=""
MODE_ROOT=false
ROBLOX_PACKAGE="com.roblox.client"

# New Settings for Periodic/Idle Force Reconnect
FORCE_REFRESH_ENABLED="OFF"
FORCE_REFRESH_MINUTES=5

# Runtime Tracking Variables
ROBLOX_STATUS="CLOSED"
START_TIME=0
ROBLOX_USERNAME="Unknown"
MONITOR_PID=""

# ==========================================
# SAVE & LOAD CONFIGURATION FUNCTIONS
# ==========================================
save_config() {
    cat <<EOF > "$CONFIG_FILE"
SELECTED_EXECUTOR="$SELECTED_EXECUTOR"
JOIN_MODE="$JOIN_MODE"
GAME_ID="$GAME_ID"
SERVER_LINK="$SERVER_LINK"
DISCORD_WEBHOOK="$DISCORD_WEBHOOK"
CHECK_INTERVAL=$CHECK_INTERVAL
AUTOEXE_SCRIPT="$AUTOEXE_SCRIPT"
ROBLOX_USERNAME="$ROBLOX_USERNAME"
ROBLOX_PACKAGE="$ROBLOX_PACKAGE"
FORCE_REFRESH_ENABLED="$FORCE_REFRESH_ENABLED"
FORCE_REFRESH_MINUTES=$FORCE_REFRESH_MINUTES
EOF
}

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}

enable_wake_lock() {
    if command -v termux-wake-lock >/dev/null 2>&1; then
        termux-wake-lock
    fi
}

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

get_current_date() {
    date "+%Y-%m-%d"
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

get_detected_game_name() {
    if [ "$JOIN_MODE" == "GAME_ID" ]; then
        if [ "$GAME_ID" == "1537690962" ]; then
            echo "Bee Swarm Simulator (ID: $GAME_ID)"
        else
            echo "Public Game ID ($GAME_ID)"
        fi
    else
        echo "Private Server Link"
    fi
}

send_discord_log() {
    local message="$1"
    if [ -n "$DISCORD_WEBHOOK" ]; then
        local payload=$(cat <<EOF
{
  "username": "AUTORDIF Bot",
  "embeds": [
    {
      "title": "AUTORDIF Monitor Notification",
      "description": "$message",
      "color": 3447003,
      "footer": {
        "text": "Date: $(get_current_date)"
      }
    }
  ]
}
EOF
)
        curl -H "Content-Type: application/json" -X POST -d "$payload" "$DISCORD_WEBHOOK" > /dev/null 2>&1 &
    fi
}

check_root_and_package() {
    echo -e "${BLUE}[*] Checking Root status...${NC}"
    if su -c "id" >/dev/null 2>&1; then
        MODE_ROOT=true
        echo -e "${GREEN}[+] Root Access Granted!${NC}"
    else
        MODE_ROOT=false
        echo -e "${YELLOW}[!] Root Access Not Detected (Running in Non-Root mode).${NC}"
    fi

    echo -e "${BLUE}[*] Scanning Roblox Package ($ROBLOX_PACKAGE)...${NC}"
    if $MODE_ROOT; then
        if su -c "pm list packages" | grep -q "$ROBLOX_PACKAGE"; then
            echo -e "${GREEN}[+] Roblox Package Verified via Su.${NC}"
        else
            echo -e "${RED}[!] Roblox Package Not Found on Device!${NC}"
        fi
    else
        echo -e "${GRAY}[i] Non-Root package verification depends on direct launch test.${NC}"
    fi
    sleep 2
}

# ==========================================
# DELTA KEY ASSISTANT (DISCORD /BYPASS) - STABLE
# ==========================================
delta_key_assistant() {
    clear_screen
    echo -e "${CYAN}=== DELTA KEY ASSISTANT (/BYPASS) ===${NC}\n"
    echo -e "${WHITE}1. Buka Roblox & tekan butang${YELLOW}'Receive Key'${WHITE}.${NC}"
    echo -e "${WHITE}2. Salin (Copy) link checkpoint yang diberikan.${NC}"
    echo -e "${WHITE}3. Paste link di bawah, kemudian TEKAN ENTER.${NC}\n"
    
    echo -n -e "${YELLOW}Paste link sini >${NC}"
    read delta_link
    
    if [ -z "$delta_link" ] && command -v termux-clipboard-get >/dev/null 2>&1; then
        delta_link=$(termux-clipboard-get)
    fi
    
    if [ -n "$delta_link" ]; then
        local bypass_command="/bypass url:$delta_link"
        
        if command -v termux-clipboard-set >/dev/null 2>&1; then
            echo "$bypass_command" | termux-clipboard-set
            echo -e "\n${GREEN}[+] Berjaya! Arahan telah disalin ke clipboard.${NC}"
        else
            echo -e "\n${YELLOW}[i] Format arahan bot:${NC}"
            echo -e "${CYAN}$bypass_command${NC}"
        fi
        
        echo -e "\n${BLUE}[*] Membuka server Discord (bss-macro-ahh)...${NC}"
        am start -a android.intent.action.VIEW -d "https://discord.gg/9mPpefsyX" >/dev/null 2>&1
        sleep 2
    else
        echo -e "\n${RED}[!] Tiada link dikesan. Sila cuba salin semula.${NC}"
        sleep 2
    fi
    echo ""
    read -p "Tekan Enter untuk kembali ke Menu Utama..."
}

# ==========================================
# ADVANCED PACKAGE SCANNER (ROOT)
# ==========================================
scan_custom_package() {
    clear_screen
    echo -e "${CYAN}=== ROOT PACKAGE SCANNER ===${NC}\n"
    
    if ! $MODE_ROOT; then
        echo -e "${RED}[!] Fungsi imbasan penuh memerlukan akses ROOT.${NC}"
        read -p "Tekan Enter untuk kembali..."
        return
    fi

    read -p "Masukkan kata kunci carian (contoh: roblox / delta / arceus / clone): " keyword

    if [ -n "$keyword" ]; then
        echo -e "\n${BLUE}[*] Menganalisis peranti untuk: '$keyword'...${NC}\n"
        local results=$(su -c "pm list packages | grep -i '$keyword'")
        
        if [ -n "$results" ]; then
            echo -e "${GREEN}[+] Package dijumpai:${NC}"
            echo -e "${YELLOW}$results${NC}\n"
            read -p "Adakah anda mahu menukar Target Package ke salah satu pilihan di atas? (y/n): " set_pkg
            if [ "$set_pkg" == "y" ] \vert{}\vert{} [ "$set_pkg" == "Y" ]; then
                read -p "Salin & Tampal (Paste) nama package penuh: " new_pkg
                if [ -n "$new_pkg" ]; then
                    ROBLOX_PACKAGE="$new_pkg"
                    save_config
                    echo -e "${GREEN}[+] Targeted Package berjaya ditukar ke: $ROBLOX_PACKAGE${NC}"
                fi
            fi
        else
            echo -e "${RED}[!] Tiada package dijumpai dengan kata kunci '$keyword'.${NC}"
        fi
    fi
    echo ""
    read -p "Tekan Enter untuk kembali..."
}

# ==========================================
# SYSTEM TWEAKS FUNCTION
# ==========================================
apply_system_tweaks() {
    clear_screen
    echo -e "${MAGENTA}=== AUTORDIF SYSTEM TWEAKER ===${NC}\n"
    
    if ! $MODE_ROOT; then
        echo -e "${RED}[!] Error: System tweaks require ROOT privileges.${NC}"
        read -p "Press Enter to return..."
        return
    fi

    echo -e "${CYAN}[1] Force Stop Background Apps (Except Roblox & Termux)${NC}"
    echo -e "${CYAN}[2] Clear Cache Memory (RAM Optimization)${NC}"
    echo -e "${CYAN}[3] Apply Low Memory Killer (LMK) Protection for Roblox${NC}"
    echo -e "${CYAN}[4] Disable Thermal Throttling Mitigation (Advanced)${NC}"
    echo -e "${CYAN}[5] Execute All Tweaks${NC}"
    echo -e "${CYAN}[6] Back${NC}"
    echo ""
    read -p "Select option [1-6]: " tweak_opt

    case $tweak_opt in
        1) su -c "am kill-all"; echo -e "${GREEN}[+] Background apps cleared.${NC}" ;;
        2) su -c "sync; echo 3 > /proc/sys/vm/drop_caches"; echo -e "${GREEN}[+] RAM cache flushed.${NC}" ;;
        3) 
            local pid=$(su -c "pidof $ROBLOX_PACKAGE")
            [ -n "$pid" ] && su -c "echo -17 > /proc/$pid/oom_adj" && echo -e "${GREEN}[+] Protected.${NC}"
            ;;
        4) su -c "stop thermald" >/dev/null 2>&1; su -c "stop thermal-engine" >/dev/null 2>&1 ;;
        5) 
            su -c "sync; echo 3 > /proc/sys/vm/drop_caches"
            su -c "am kill-all"
            ;;
        6) return ;;
    esac
    sleep 2
}

# ==========================================
# AUTHENTICATION & EXECUTOR SELECTION
# ==========================================
login_system() {
    clear_screen
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${MAGENTA}${BOLD}            WELCOME TO AUTORDIF${NC}"
    echo -e "${CYAN}====================================================${NC}\n"

    while true; do
        echo -n -e "${WHITE}Enter Password:${NC}"
        read pass_input
        echo ""

        if [ "$pass_input" == "$PASSWORD_REQ" ]; then
            echo -e "${GREEN}WELCOME TO AUTORDIF${NC}"
            sleep 1
            break
        else
            echo -e "${RED}[!] Incorrect Password. Access Denied.${NC}"
        fi
    done
}

select_executor() {
    clear_screen
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${YELLOW}${BOLD}            SELECT YOUR ROBLOX EXECUTOR${NC}"
    echo -e "${CYAN}====================================================${NC}\n"

    echo -e "${WHITE}1) Delta [KEY]${NC}"
    echo -e "${WHITE}2) ArceusX [KEYLESS]${NC}"
    echo ""
    read -p "Choose Executor (1 or 2): " exec_choice

    case $exec_choice in
        1) SELECTED_EXECUTOR="Delta [KEY]" ;;
        2) SELECTED_EXECUTOR="ArceusX [KEYLESS]" ;;
        *) SELECTED_EXECUTOR="Delta [KEY]" ;;
    esac
    save_config
}

# ==========================================
# ROBLOX LAUNCHER & CONTROLLER
# ==========================================
force_close_roblox() {
    if $MODE_ROOT; then
        su -c "am force-stop $ROBLOX_PACKAGE" >/dev/null 2>&1
    else
        am force-stop "$ROBLOX_PACKAGE" >/dev/null 2>&1
    fi
}

launch_roblox() {
    ROBLOX_STATUS="OPENING"
    send_discord_log "Initiating Roblox Launch. Target: $JOIN_MODE"
    force_close_roblox
    sleep 2

    if [ "$JOIN_MODE" == "GAME_ID" ]; then
        local launch_url="roblox://placeID=$GAME_ID"
    else
        local launch_url="$SERVER_LINK"
    fi

    echo -e "${BLUE}[*] Launching Roblox via Intent URL...${NC}"
    if $MODE_
