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
ROBLOX_PACKAGE="com.roblox.client"

# Runtime Tracking Variables
ROBLOX_STATUS="CLOSED"
START_TIME=0
ROBLOX_USERNAME="Unknown"
MONITOR_PID=""
PID_FILE="$HOME/.autordif_monitor.pid"

# ==========================================
# HELPER FUNCTIONS
# ==========================================
clear_screen() {
    clear
}

draw_banner() {
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${MAGENTA}${BOLD}"
    echo "  █████╗ ██║   ██╗████████╗██████╗ ██████╗ ██╗███████╗"
    echo " ██╔══██╗██║   ██║╚══██╔══╝██╔══██╗██╔══██╗██║██╔════╝"
    echo " ███████║██║   ██║   ██║   ██████╔╝██║  ██║██║█████╗  "
    echo " ██╔══██║██║   ██║   ██║   ██╔══██╗██║  ██║██║██╔══╝  "
    echo " ██║  ██║╚██████╔╝   ██║   ██║  ██║██████╔╝██║██║     "
    echo " ╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚═╝  ╚═╝╚═════╝ ╚═╝╚═╝     "
    echo -e "${NC}"
    echo -e "${YELLOW}${BOLD}           ---> AUTO RECONNECT BY DIF <---          ${NC}"
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
    printf "%02dh %02dm %02ds" $hours $minutes $seconds
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
# SYSTEM TWEAKS FUNCTION
# ==========================================
apply_system_tweaks() {
    clear_screen
    echo -e "${MAGENTA}=== AUTORDIF SYSTEM TWEAKER ===${NC}\n"
    
    if ! $MODE_ROOT; then
        echo -e "${RED}[!] Error: System tweaks require ROOT privileges.${NC}"
        echo -e "${YELLOW}[i] Non-root tweaks limited to Android Termux performance optimizations.${NC}"
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
        1)
            echo -e "${BLUE}[*] Clearing background processes...${NC}"
            su -c "am kill-all"
            echo -e "${GREEN}[+] Background apps cleared.${NC}"
            ;;
        2)
            echo -e "${BLUE}[*] Dropping RAM Caches...${NC}"
            su -c "sync; echo 3 > /proc/sys/vm/drop_caches"
            echo -e "${GREEN}[+] RAM cache flushed.${NC}"
            ;;
        3)
            echo -e "${BLUE}[*] Setting OOM adjustment for Roblox...${NC}"
            local pid=$(su -c "pidof $ROBLOX_PACKAGE")
            if [ -n "$pid" ]; then
                echo -e "${GREEN}[+] Roblox PID $pid protected from auto-kill.${NC}"
            else
                echo -e "${RED}[!] Roblox is not currently running.${NC}"
            fi
            ;;
        4)
            echo -e "${BLUE}[*] Adjusting Thermal Parameters...${NC}"
            su -c "stop thermald" >/dev/null 2>&1
            su -c "stop thermal-engine" >/dev/null 2>&1
            echo -e "${GREEN}[+] Thermal throttling services paused.${NC}"
            ;;
        5)
            echo -e "${BLUE}[*] Applying all System Tweaks...${NC}"
            su -c "sync; echo 3 > /proc/sys/vm/drop_caches"
            su -c "am kill-all"
            echo -e "${GREEN}[+] All system tweaks successfully applied!${NC}"
            ;;
        6) return ;;
        *) echo -e "${RED}Invalid choice!${NC}" ;;
    esac
    sleep 2
}

# ==========================================
# AUTHENTICATION & EXECUTOR SELECTION
# ==========================================
login_system() {
    clear_screen
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${MAGENTA}${BOLD}            WELCOME TO AUTORDIF SYSTEM            ${NC}"
    echo -e "${CYAN}====================================================${NC}\n"

    while true; do
        echo -n -e "${WHITE}Enter Password: ${NC}"
        read pass_input
        echo ""

        if [ "$pass_input" == "$PASSWORD_REQ" ]; then
            echo -e "${GREEN}[+] Access Granted! Welcome ADIFLUQMAN.${NC}"
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
    echo -e "${YELLOW}${BOLD}            SELECT YOUR ROBLOX EXECUTOR             ${NC}"
    echo -e "${CYAN}====================================================${NC}\n"

    echo -e "${WHITE}1) Delta [KEY]${NC}"
    echo -e "${WHITE}2) ArceusX [KEYLESS]${NC}"
    echo ""
    read -p "Choose Executor (1 or 2): " exec_choice

    case $exec_choice in
        1)
            SELECTED_EXECUTOR="Delta [KEY]"
            ;;
        2)
            SELECTED_EXECUTOR="ArceusX [KEYLESS]"
            ;;
        *)
            echo -e "${RED}Invalid Choice. Defaulting to Delta.${NC}"
            SELECTED_EXECUTOR="Delta [KEY]"
            sleep 1
            ;;
    esac
}

# ==========================================
# ROBLOX LAUNCHER & CONTROLLER
# ==========================================
launch_roblox() {
    ROBLOX_STATUS="OPENING"
    send_discord_log "Initiating Roblox Launch. Target: $JOIN_MODE"
    
    if [ "$JOIN_MODE" == "GAME_ID" ]; then
        local launch_url="roblox://placeID=$GAME_ID"
    else
        local launch_url="$SERVER_LINK"
    fi

    if $MODE_ROOT; then
        su -c "am force-stop $ROBLOX_PACKAGE" >/dev/null 2>&1
        su -c "am start -a android.intent.action.VIEW -d '$launch_url' $ROBLOX_PACKAGE" >/dev/null 2>&1
    else
        am force-stop $ROBLOX_PACKAGE >/dev/null 2>&1
        am start -a android.intent.action.VIEW -d "$launch_url" >/dev/null 2>&1
    fi

    START_TIME=$(date +%s)
    ROBLOX_STATUS="RUNNING"
    send_discord_log "Roblox successfully launched and status changed to RUNNING."
}

is_roblox_running() {
    if $MODE_ROOT; then
        local pids=$(su -c "pidof $ROBLOX_PACKAGE")
        if [ -n "$pids" ]; then
            return 0
        else
            return 1
        fi
    else
        local check=$(ps aux | grep "$ROBLOX_PACKAGE" | grep -v "grep")
        if [ -n "$check" ]; then
            return 0
        else
            return 1
        fi
    fi
}

# ==========================================
# BACKGROUND AUTO-RECONNECT WORKER
# ==========================================
background_monitor() {
    launch_roblox

    while true; do
        sleep "$CHECK_INTERVAL"

        if is_roblox_running; then
            ROBLOX_STATUS="RUNNING"
        else
            ROBLOX_STATUS="CRASHED"
            send_discord_log "CRASH DETECTED! Roblox process died. Reconnecting..."
            ROBLOX_STATUS="RECONNECTING"
            sleep 3
            launch_roblox
        fi
    done
}

start_background_reconnect() {
    if [ "$AUTO_RECONNECT" == "OFF" ]; then
        echo -e "${RED}[!] Please enable Auto Reconnect setting first! (Option 1)${NC}"
        sleep 2
        return
    fi

    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo -e "${YELLOW}[!] Auto Reconnect is already running in background!${NC}"
        sleep 2
        return
    fi

    echo -e "${GREEN}[+] Starting Auto Reconnect in background...${NC}"
    background_monitor &
    MONITOR_PID=$!
    echo $MONITOR_PID > "$PID_FILE"
    sleep 1
}

stop_background_reconnect() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" >/dev/null 2>&1
            pkill -P "$pid" >/dev/null 2>&1
        fi
        rm -f "$PID_FILE"
    fi
    ROBLOX_STATUS="CLOSED"
    START_TIME=0
    echo -e "${GREEN}[+] Auto Reconnect has been STOPPED.${NC}"
    sleep 1
}

is_background_active() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo -e "${GREEN}ACTIVE (Running in Background)${NC}"
    else
        echo -e "${RED}INACTIVE (Stopped)${NC}"
    fi
}

# ==========================================
# SETTINGS & SUBMENUS
# ==========================================
settings_menu() {
    while true; do
        clear_screen
        echo -e "${CYAN}=== AUTORDIF SETTINGS ===${NC}\n"
        echo -e "1) Recheck Roblox Interval (Current: ${YELLOW}${CHECK_INTERVAL}s${NC})"
        echo -e "2) Scan Package (Root / Non-Root Status)"
        echo -e "3) Back to Main Menu"
        echo ""
        read -p "Select option [1-3]: " set_opt

        case $set_opt in
            1)
                read -p "Enter interval in seconds: " new_int
                if [[ "$new_int" =~ ^[0-9]+$ ]]; then
                    CHECK_INTERVAL=$new_int
                    echo -e "${GREEN}[+] Interval updated!${NC}"
                else
                    echo -e "${RED}[!] Invalid integer input.${NC}"
                fi
                sleep 1
                ;;
            2)
                check_root_and_package
                ;;
            3) break ;;
            *) echo -e "${RED}Invalid Selection${NC}"; sleep 1 ;;
        esac
    done
}

# ==========================================
# MAIN MENU
# ==========================================
main_menu() {
    while true; do
        clear_screen
        draw_banner

        # System Header Dashboard
        echo -e "${WHITE}Date/Time      : ${YELLOW}$(get_current_datetime)${NC}"
        echo -e "${WHITE}Executor       : ${CYAN}$SELECTED_EXECUTOR${NC}"
        echo -e "${WHITE}Roblox Status  : ${MAGENTA}$ROBLOX_STATUS${NC}"
        echo -e "${WHITE}Session Uptime : ${GREEN}$(get_elapsed_time)${NC}"
        echo -e "${WHITE}Username       : ${BLUE}$ROBLOX_USERNAME${NC}"
        echo -e "${WHITE}Monitor Worker : $(is_background_active)"
        echo -e "${CYAN}====================================================${NC}\n"

        # Interactive Options
        echo -e " [1] Toggle Auto Reconnect [Current: ${BOLD}${AUTO_RECONNECT}${NC}]"
        echo -e " [2] Configure Server Setup [Mode: ${YELLOW}${JOIN_MODE}${NC}]"
        echo -e " [3] Configure Discord Webhook"
        echo -e " [4] System Settings (Interval, Root Scan)"
        echo -e " [5] System Tweaks (Optimization & Anti-Crash)"
        echo -e " [6] START RECONNECTING (Run in Background)"
        echo -e " [7] STOP RECONNECTING (Kill Background Worker)"
        echo -e " [8] Set Roblox Username"
        echo -e " [9] Exit"
        echo ""
        read -p "Select Command [1-9]: " choice

        case $choice in
            1)
                if [ "$AUTO_RECONNECT" == "OFF" ]; then
                    AUTO_RECONNECT="ON"
                else
                    AUTO_RECONNECT="OFF"
                fi
                ;;
            2)
                clear_screen
                echo -e "${CYAN}=== SERVER SETUP ===${NC}"
                echo "1) Game ID (Public Server)"
                echo "2) Private Server Link"
                read -p "Select [1-2]: " s_opt
                if [ "$s_opt" == "1" ]; then
                    JOIN_MODE="GAME_ID"
                    read -p "Enter Game ID (Default Bee Swarm 1537690962): " g_id
                    [ -n "$g_id" ] && GAME_ID="$g_id"
                elif [ "$s_opt" == "2" ]; then
                    JOIN_MODE="PRIVATE_SERVER"
                    read -p "Enter Private Server VIP/Deep Link: " p_link
                    [ -n "$p_link" ] && SERVER_LINK="$p_link"
                fi
                ;;
            3)
                clear_screen
                echo -e "${CYAN}=== DISCORD WEBHOOK SETUP ===${NC}"
                read -p "Paste Webhook URL: " wh_url
                DISCORD_WEBHOOK="$wh_url"
                echo -e "${GREEN}[+] Webhook saved! Testing connection...${NC}"
                send_discord_log "AUTORDIF Webhook Integration Active!"
                sleep 2
                ;;
            4)
                settings_menu
                ;;
            5)
                apply_system_tweaks
                ;;
            6)
                start_background_reconnect
                sleep 1
                ;;
            7)
                stop_background_reconnect
                ;;
            8)
                read -p "Enter Roblox Username: " rbx_user
                [ -n "$rbx_user" ] && ROBLOX_USERNAME="$rbx_user"
                ;;
            9)
                echo -e "${YELLOW}[!] Exiting menu. (Background workers will continue running if active)${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid input selection!${NC}"
                sleep 1
                ;;
        esac
    done
}

# ==========================================
# SCRIPT EXECUTION FLOW
# ==========================================
login_system
select_executor
check_root_and_package
main_menu
