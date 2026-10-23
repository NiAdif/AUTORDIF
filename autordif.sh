#!/data/data/com.termux/files/usr/bin/bash

# ==========================================
# CONSTANTS & CONFIGURATIONS
# ==========================================
PASSWORD_REQ="adifluqman"
CONFIG_FILE="$HOME/.autordif_config"
HIPHUB_KEY="HIPHUB-MONITORING-DA7B-91C9"
HIPHUB_CONF_DIR="$HOME/.cache/log"
HIPHUB_CONF_FILE="$HIPHUB_CONF_DIR/hiphub_config.json"

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
DISCORD_WEBHOOK=""
CHECK_INTERVAL=15
MODE_ROOT=false

# Multi-Package List & Tracking Arrays
ROBLOX_PACKAGES=()
declare -A PKG_STATUSES
declare -A PKG_LAUNCH_TIMES

# Per-Package Server Settings (Associative Arrays)
declare -A PKG_JOIN_MODES
declare -A PKG_GAME_IDS
declare -A PKG_SERVER_LINKS

# Default Global Fallbacks
DEFAULT_GAME_ID="1537690962"

# Force Close / Rejoin Settings
FORCE_CLOSE_ENABLED="ON"
FORCE_CLOSE_INTERVAL=5400 # 5400 seconds = 1.5 hours
STUCK_TIMEOUT=30          # Timeout for stuck/opening state

# Runtime Tracking Variables
START_TIME=0
ROBLOX_USERNAME="Unknown"
PID_FILE="$HOME/.autordif_monitor.pid"
HIPHUB_PID_FILE="$HOME/.autordif_hiphub.pid"
STATUS_FILE="$HOME/.autordif_status"

# ==========================================
# HELPER FUNCTIONS
# ==========================================
clear_screen() {
    clear
}

draw_banner() {
    echo -e "${CYAN}==================================${NC}"
    echo -e "${MAGENTA}${BOLD}"
    echo "  █████╗ ██║   ██║████████╗██████╗"
    echo " ██╔══██╗██║   ██║╚══██╔══╝██╔══██╗"
    echo " ███████║██║   ██║   ██║   ██████╔╝"
    echo " ██╔══██║██║   ██║   ██║   ██╔══██╗"
    echo " ██║  ██║╚██████╔╝   ██║   ██║  ██║"
    echo " ╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚═╝  ╚═╝"
    echo -e "${NC}"
    echo -e "${YELLOW}${BOLD}   AUTO RECONNECT + HIPHUB MONITOR ${NC}"
    echo -e "${CYAN}==================================${NC}"
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

setup_hiphub_dependencies() {
    if ! command -v lua5.4 >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
        pkg update -y && pkg install curl lua54 python -y >/dev/null 2>&1
    fi
    mkdir -p "$HIPHUB_CONF_DIR"
    echo "{\"license_key\":\"$HIPHUB_KEY\"}" > "$HIPHUB_CONF_FILE"
}

start_hiphub_background() {
    setup_hiphub_dependencies
    if [ -f "$HIPHUB_PID_FILE" ] && kill -0 $(cat "$HIPHUB_PID_FILE") 2>/dev/null; then
        return
    fi
    (curl -s "https://hiphub.cloud/api/monitoring/hiphub?key=$HIPHUB_KEY" | lua5.4 >/dev/null 2>&1) &
    echo $! > "$HIPHUB_PID_FILE"
}

stop_hiphub_background() {
    if [ -f "$HIPHUB_PID_FILE" ]; then
        local h_pid=$(cat "$HIPHUB_PID_FILE")
        if kill -0 "$h_pid" 2>/dev/null; then
            kill "$h_pid" >/dev/null 2>&1
            pkill -P "$h_pid" >/dev/null 2>&1
        fi
        rm -f "$HIPHUB_PID_FILE"
    fi
}

check_root_and_package() {
    echo -e "${BLUE}[*] Checking Root status...${NC}"
    if su -c "id" >/dev/null 2>&1; then
        MODE_ROOT=true
        echo -e "${GREEN}[+] Root Access Granted!${NC}"
    else
        MODE_ROOT=false
        echo -e "${YELLOW}[!] Root Access Not Detected (Non-Root mode).${NC}"
    fi

    echo -e "${BLUE}[*] Auto-scanning packages 'com.roblox.'...${NC}"
    local scanned_pkgs=""
    if $MODE_ROOT; then
        scanned_pkgs=$(su -c "pm list packages" | grep "com.roblox." | sed 's/package://g' | tr -d '\r')
    else
        scanned_pkgs=$(pm list packages 2>/dev/null | grep "com.roblox." | sed 's/package://g' | tr -d '\r')
    fi

    if [ -n "$scanned_pkgs" ]; then
        ROBLOX_PACKAGES=()
        while IFS= read -r pkg; do
            if [ -n "$pkg" ]; then
                ROBLOX_PACKAGES+=("$pkg")
                set_pkg_status "$pkg" "STANDBY"
                [ -z "${PKG_JOIN_MODES[$pkg]}" ] && PKG_JOIN_MODES["$pkg"]="GAME_ID"
                [ -z "${PKG_GAME_IDS[$pkg]}" ] && PKG_GAME_IDS["$pkg"]="$DEFAULT_GAME_ID"
            fi
        done <<< "$scanned_pkgs"
        echo -e "${GREEN}[+] Detected ${#ROBLOX_PACKAGES[@]} package(s).${NC}"
    else
        echo -e "${YELLOW}[!] Using default package (com.roblox.client).${NC}"
        ROBLOX_PACKAGES=("com.roblox.client")
        set_pkg_status "com.roblox.client" "STANDBY"
        PKG_JOIN_MODES["com.roblox.client"]="GAME_ID"
        PKG_GAME_IDS["com.roblox.client"]="$DEFAULT_GAME_ID"
    fi
    sleep 2
}

configure_package_server() {
    while true; do
        clear_screen
        echo -e "${CYAN}=== PER-PACKAGE SERVER CONFIG ===${NC}\n"
        local idx=1
        for pkg in "${ROBLOX_PACKAGES[@]}"; do
            local mode="${PKG_JOIN_MODES[$pkg]:-GAME_ID}"
            local target=""
            if [ "$mode" == "GAME_ID" ]; then
                target="GID: ${PKG_GAME_IDS[$pkg]:-$DEFAULT_GAME_ID}"
            else
                target="VIP Link Set"
            fi
            echo -e " ${YELLOW}[$idx]${NC} ${CYAN}$pkg${NC}"
            echo -e "     -> Mode: ${MAGENTA}$mode${NC} | $target"
            ((idx++))
        done
        echo ""
        echo -e "1) Configure Specific Package"
        echo -e "2) Apply Same Game ID to ALL"
        echo -e "3) Apply Same VIP Link to ALL"
        echo -e "4) Back"
        echo ""
        read -p "Select [1-4]: " cfg_opt

        case $cfg_opt in
            1)
                read -p "Enter package number [1-${#ROBLOX_PACKAGES[@]}]: " p_num
                if [[ "$p_num" =~ ^[0-9]+$ ]] && [ "$p_num" -ge 1 ] && [ "$p_num" -le "${#ROBLOX_PACKAGES[@]}" ]; then
                    local selected_pkg="${ROBLOX_PACKAGES[p_num-1]}"
                    echo -e "\n${YELLOW}Config: $selected_pkg${NC}"
                    echo "1) Game ID"
                    echo "2) Private Server Link"
                    read -p "Select Mode [1-2]: " mode_choice
                    if [ "$mode_choice" == "1" ]; then
                        PKG_JOIN_MODES["$selected_pkg"]="GAME_ID"
                        read -p "Enter Game ID: " g_id
                        [ -n "$g_id" ] && PKG_GAME_IDS["$selected_pkg"]="$g_id"
                    elif [ "$mode_choice" == "2" ]; then
                        PKG_JOIN_MODES["$selected_pkg"]="PRIVATE_SERVER"
                        read -p "Enter VIP Link: " p_link
                        [ -n "$p_link" ] && PKG_SERVER_LINKS["$selected_pkg"]="$p_link"
                    fi
                    echo -e "${GREEN}[+] Saved!${NC}"
                else
                    echo -e "${RED}[!] Invalid number.${NC}"
                fi
                sleep 2
                ;;
            2)
                read -p "Enter Game ID for ALL: " all_gid
                if [ -n "$all_gid" ]; then
                    for pkg in "${ROBLOX_PACKAGES[@]}"; do
                        PKG_JOIN_MODES["$pkg"]="GAME_ID"
                        PKG_GAME_IDS["$pkg"]="$all_gid"
                    done
                    echo -e "${GREEN}[+] Updated for all!${NC}"
                fi
                sleep 2
                ;;
            3)
                read -p "Enter VIP Link for ALL: " all_link
                if [ -n "$all_link" ]; then
                    for pkg in "${ROBLOX_PACKAGES[@]}"; do
                        PKG_JOIN_MODES["$pkg"]="PRIVATE_SERVER"
                        PKG_SERVER_LINKS["$pkg"]="$all_link"
                    done
                    echo -e "${GREEN}[+] Updated for all!${NC}"
                fi
                sleep 2
                ;;
            4) break ;;
            *) echo -e "${RED}Invalid!${NC}"; sleep 1 ;;
        esac
    done
}

manage_packages_menu() {
    while true; do
        clear_screen
        echo -e "${CYAN}=== MULTI-PACKAGE MANAGER ===${NC}\n"
        local idx=1
        for pkg in "${ROBLOX_PACKAGES[@]}"; do
            echo -e " ${YELLOW}[$idx]${NC} $pkg"
            ((idx++))
        done
        echo ""
        echo -e "1) Re-scan Packages"
        echo -e "2) Add Package Manually"
        echo -e "3) Remove Package"
        echo -e "4) Back"
        echo ""
        read -p "Select [1-4]: " m_opt

        case $m_opt in
            1) check_root_and_package ;;
            2)
                read -p "Enter package name: " new_p
                if [ -n "$new_p" ]; then
                    ROBLOX_PACKAGES+=("$new_p")
                    set_pkg_status "$new_p" "STANDBY"
                    PKG_JOIN_MODES["$new_p"]="GAME_ID"
                    PKG_GAME_IDS["$new_p"]="$DEFAULT_GAME_ID"
                    echo -e "${GREEN}[+] Added!${NC}"
                fi
                sleep 1
                ;;
            3)
                read -p "Enter number to remove: " del_idx
                if [[ "$del_idx" =~ ^[0-9]+$ ]] && [ "$del_idx" -ge 1 ] && [ "$del_idx" -le "${#ROBLOX_PACKAGES[@]}" ]; then
                    local target_pkg="${ROBLOX_PACKAGES[del_idx-1]}"
                    unset 'ROBLOX_PACKAGES[del_idx-1]'
                    ROBLOX_PACKAGES=("${ROBLOX_PACKAGES[@]}")
                    unset 'PKG_STATUSES[$target_pkg]'
                    unset 'PKG_LAUNCH_TIMES[$target_pkg]'
                    unset 'PKG_JOIN_MODES[$target_pkg]'
                    unset 'PKG_GAME_IDS[$target_pkg]'
                    unset 'PKG_SERVER_LINKS[$target_pkg]'
                    echo -e "${GREEN}[+] Removed!${NC}"
                else
                    echo -e "${RED}[!] Invalid.${NC}"
                fi
                sleep 1
                ;;
            4) break ;;
            *) echo -e "${RED}Invalid!${NC}"; sleep 1 ;;
        esac
    done
}

apply_system_tweaks() {
    clear_screen
    echo -e "${MAGENTA}=== SYSTEM TWEAKER ===${NC}\n"
    if ! $MODE_ROOT; then
        echo -e "${RED}[!] Requires ROOT privileges.${NC}"
        read -p "Press Enter..."
        return
    fi

    echo -e "${CYAN}[1] Force Stop Background Apps${NC}"
    echo -e "${CYAN}[2] Clear Cache Memory${NC}"
    echo -e "${CYAN}[3] Apply LMK Protection${NC}"
    echo -e "${CYAN}[4] Back${NC}"
    echo ""
    read -p "Select [1-4]: " tweak_opt

    case $tweak_opt in
        1) su -c "am kill-all"; echo -e "${GREEN}[+] Cleared.${NC}" ;;
        2) su -c "sync; echo 3 > /proc/sys/vm/drop_caches"; echo -e "${GREEN}[+] Cache flushed.${NC}" ;;
        3)
            for pkg in "${ROBLOX_PACKAGES[@]}"; do
                local pid=$(su -c "pidof $pkg")
                [ -n "$pid" ] && su -c "echo -17 > /proc/$pid/oom_adj"
            done
            echo -e "${GREEN}[+] LMK applied.${NC}"
            sleep 2
            ;;
        4) return ;;
        *) echo -e "${RED}[!] Invalid choice.${NC}" ;;
    esac
    sleep 2
}

login_system() {
    clear_screen
    echo -e "${CYAN}==================================${NC}"
    echo -e "${MAGENTA}${BOLD}     WELCOME TO AUTORDIF SYSTEM   ${NC}"
    echo -e "${CYAN}==================================${NC}\n"
    while true; do
        echo -n -e "${WHITE}Enter Password: ${NC}"
        read pass_input
        echo ""
        if [ "$pass_input" == "$PASSWORD_REQ" ]; then
            echo -e "${GREEN}[+] Access Granted!${NC}"
            sleep 1
            break
        else
            echo -e "${RED}[!] Incorrect Password.${NC}"
        fi
    done
}

select_executor() {
    clear_screen
    echo -e "${CYAN}==================================${NC}"
    echo -e "${YELLOW}${BOLD}       SELECT YOUR EXECUTOR       ${NC}"
    echo -e "${CYAN}==================================${NC}\n"
    echo -e "${WHITE}1) Delta [KEY]${NC}"
    echo -e "${WHITE}2) ArceusX [KEYLESS]${NC}"
    echo ""
    read -p "Choose [1-2]: " exec_choice
    case $exec_choice in
        1) SELECTED_EXECUTOR="Delta [KEY]" ;;
        2) SELECTED_EXECUTOR="ArceusX [KEYLESS]" ;;
        *) SELECTED_EXECUTOR="Delta [KEY]" ;;
    esac
}

kill_package_hard() {
    local pkg="$1"
    if $MODE_ROOT; then
        su -c "am force-stop $pkg" >/dev/null 2>&1
        su -c "pkill -9 -f $pkg" >/dev/null 2>&1
    else
        am force-stop "$pkg" >/dev/null 2>&1
        pkill -9 -f "$pkg" >/dev/null 2>&1
    fi
}

is_pkg_running() {
    local pkg="$1"
    if $MODE_ROOT; then
        local pids=$(su -c "pidof $pkg")
        [ -n "$pids" ] && return 0 || return 1
    else
        if pidof "$pkg" >/dev/null 2>&1 || pgrep -f "$pkg" >/dev/null 2>&1; then
            return 0
        fi
        if dumpsys window 2>/dev/null | grep -E "mCurrentFocus|mFocusedApp" | grep -q "$pkg"; then
            return 0
        fi
        local ps_check=$(ps -ef 2>/dev/null | grep "$pkg" | grep -v "grep")
        [ -n "$ps_check" ] && return 0 || return 1
    fi
}

launch_specific_pkg() {
    local pkg="$1"
    kill_package_hard "$pkg"
    sleep 1
    
    set_pkg_status "$pkg" "OPENING"
    PKG_LAUNCH_TIMES["$pkg"]=$(date +%s)
    
    local mode="${PKG_JOIN_MODES[$pkg]:-GAME_ID}"
    local launch_url=""
    
    if [ "$mode" == "GAME_ID" ]; then
        local gid="${PKG_GAME_IDS[$pkg]:-$DEFAULT_GAME_ID}"
        launch_url="roblox://placeID=$gid"
        send_discord_log "Relaunching: $pkg (ID: $gid)"
    else
        launch_url="${PKG_SERVER_LINKS[$pkg]}"
        send_discord_log "Relaunching: $pkg (VIP Link)"
    fi

    if $MODE_ROOT; then
        su -c "am start -a android.intent.action.VIEW -d '$launch_url' $pkg" >/dev/null 2>&1
    else
        am start -a android.intent.action.VIEW -d "$launch_url" "$pkg" >/dev/null 2>&1
    fi
}

launch_all_packages() {
    set_status "RECONNECTING"
    START_TIME=$(date +%s)
    send_discord_log "Launching all ${#ROBLOX_PACKAGES[@]} package(s)."
    for pkg in "${ROBLOX_PACKAGES[@]}"; do
        set_pkg_status "$pkg" "RECONNECTING"
        launch_specific_pkg "$pkg"
        sleep 3
    done
    set_status "RUNNING"
    send_discord_log "All packages deployed."
}

background_monitor() {
    termux-wake-lock >/dev/null 2>&1
    start_hiphub_background
    launch_all_packages

    local last_rejoin_time=$(date +%s)

    while true; do
        sleep "$CHECK_INTERVAL"
        local current_time=$(date +%s)

        if [ "$FORCE_CLOSE_ENABLED" == "ON" ]; then
            local time_diff=$((current_time - last_rejoin_time))
            if [ "$time_diff" -ge "$FORCE_CLOSE_INTERVAL" ]; then
                set_status "FORCE CLOSING"
                START_TIME=$(date +%s)
                send_discord_log "Scheduled Force Close triggered. Restarting..."
                sleep 2
                launch_all_packages
                last_rejoin_time=$(date +%s)
                continue
            fi
        fi

        local all_crashed=true
        local any_action_taken=false

        for pkg in "${ROBLOX_PACKAGES[@]}"; do
            if is_pkg_running "$pkg"; then
                local current_p_stat="${PKG_STATUSES[$pkg]:-STANDBY}"
                local launch_t="${PKG_LAUNCH_TIMES[$pkg]:-$current_time}"
                local elapsed_launch=$((current_time - launch_t))
                
                if [ "$elapsed_launch" -ge "$STUCK_TIMEOUT" ] && [ "$current_p_stat" != "RUNNING" ]; then
                    set_pkg_status "$pkg" "FREEZE/REOPEN"
                    START_TIME=$(date +%s)
                    send_discord_log "FREEZE on $pkg! Reopening..."
                    launch_specific_pkg "$pkg"
                    any_action_taken=true
                    continue
                fi

                all_crashed=false
                set_pkg_status "$pkg" "RUNNING"
            else
                set_pkg_status "$pkg" "CRASHED"
                send_discord_log "CRASH on $pkg! Reconnecting..."
                launch_specific_pkg "$pkg"
                any_action_taken=true
                sleep 2
            fi
        done

        if "$all_crashed"; then
            set_status "ALL CRASHED"
            START_TIME=$(date +%s)
            send_discord_log "All crashed! Restarting..."
            launch_all_packages
            last_rejoin_time=$(date +%s)
        elif ! "$any_action_taken"; then
            set_status "RUNNING"
        fi
    done
}

start_background_reconnect() {
    if [ "$AUTO_RECONNECT" == "OFF" ]; then
        echo -e "${RED}[!] Enable Auto Reconnect first! (Option 1)${NC}"
        sleep 2
        return
    fi

    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo -e "${YELLOW}[!] Already running in background!${NC}"
        sleep 2
        return
    fi

    termux-wake-lock >/dev/null 2>&1
    echo -e "${GREEN}[+] Starting Dual-Engine & Wake Lock...${NC}"
    background_monitor &
    echo $! > "$PID_FILE"
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
    stop_hiphub_background
    termux-wake-unlock >/dev/null 2>&1
    set_status "CLOSED"
    for pkg in "${ROBLOX_PACKAGES[@]}"; do
        set_pkg_status "$pkg" "CLOSED"
    done
    START_TIME=0
    echo -e "${GREEN}[+] Stopped & Wake Lock released.${NC}"
    sleep 1
}

is_background_active() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo -e "${GREEN}ACTIVE (Dual-Engine)${NC}"
    else
        echo -e "${RED}INACTIVE${NC}"
    fi
}

settings_menu() {
    while true; do
        clear_screen
        echo -e "${CYAN}=== SETTINGS ===${NC}\n"
        echo -e "1) Check Interval (${CHECK_INTERVAL}s)"
        echo -e "2) Manage Multi-Packages"
        echo -e "3) Freeze Timeout (${STUCK_TIMEOUT}s)"
        echo -e "4) Toggle Wake Lock (ON/OFF)"
        echo -e "5) Auto-Scan Packages"
        echo -e "6) Back"
        echo ""
        read -p "Select [1-6]: " set_opt

        case $set_opt in
            1)
                read -p "Enter interval (s): " new_int
                [[ "$new_int" =~ ^[0-9]+$ ]] && CHECK_INTERVAL=$new_int
                sleep 1
                ;;
            2) manage_packages_menu ;;
            3)
                read -p "Enter timeout (s): " st_int
                [[ "$st_int" =~ ^[0-9]+$ ]] && STUCK_TIMEOUT=$st_int
                sleep 1
                ;;
            4)
                echo -e "1) ON\n2) OFF"
                read -p "Choice [1-2]: " wl_choice
                if [ "$wl_choice" == "1" ]; then
                    termux-wake-lock >/dev/null 2>&1
                    echo -e "${GREEN}[+] Wake Lock ON${NC}"
                else
                    termux-wake-unlock >/dev/null 2>&1
                    echo -e "${YELLOW}[!] Wake Lock OFF${NC}"
                fi
                sleep 1
                ;;
            5) check_root_and_package ;;
            6) break ;;
        esac
    done
}

main_menu() {
    while true; do
        clear_screen
        draw_banner

        if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
            for pkg in "${ROBLOX_PACKAGES[@]}"; do
                if is_pkg_running "$pkg"; then
                    local current_p_stat="${PKG_STATUSES[$pkg]:-STANDBY}"
                    if [ "$current_p_stat" != "OPENING" ] && [ "$current_p_stat" != "RECONNECTING" ] && [[ "$current_p_stat" != *"FREEZE"* ]]; then
                        set_pkg_status "$pkg" "RUNNING"
                    fi
                else
                    set_pkg_status "$pkg" "CRASHED"
                fi
            done
        fi

        local current_status=$(get_status)

        echo -e "${WHITE}Time    : ${YELLOW}$(get_current_datetime)${NC}"
        echo -e "${WHITE}Executor: ${CYAN}$SELECTED_EXECUTOR${NC}"
        echo -e "${WHITE}Accounts: ${MAGENTA}$([[ ${#ROBLOX_PACKAGES[@]} ]] && echo ${#ROBLOX_PACKAGES[@]})${NC}"
        echo -e "${WHITE}Status  : ${GREEN}$current_status${NC}"
        echo -e "${WHITE}Uptime  : ${GREEN}$(get_elapsed_time)${NC}"
        echo -e "${WHITE}Worker  : $(is_background_active)"
        echo -e "${CYAN}----------------------------------${NC}"

        echo -e "${YELLOW}${BOLD}       LIVE PACKAGE STATUS        ${NC}"
        for pkg in "${ROBLOX_PACKAGES[@]}"; do
            local p_stat="${PKG_STATUSES[$pkg]:-STANDBY}"
            local color_stat="${GREEN}"
            if [ "$p_stat" == "CRASHED" ] || [[ "$p_stat" == *"FREEZE"* ]]; then
                color_stat="${RED}"
            elif [ "$p_stat" == "RECONNECTING" ] || [ "$p_stat" == "OPENING" ]; then
                color_stat="${YELLOW}"
            fi
            local short_name=$(echo "$pkg" | sed 's/com.roblox.//g')
            printf " ${CYAN}%-15s${NC} : ${color_stat}%-10s${NC}\n" "$short_name" "$p_stat"
        done
        echo -e "${CYAN}----------------------------------${NC}\n"

        echo -e " [1] Auto Reconnect [${BOLD}${AUTO_RECONNECT}${NC}]"
        echo -e " [2] Scheduled Force Close [${BOLD}${FORCE_CLOSE_ENABLED}${NC}]"
        echo -e " [3] Set FC Interval (${YELLOW}${FORCE_CLOSE_INTERVAL}s${NC})"
        echo -e " [4] Per-Package Server Setup"
        echo -e " [5] Configure Discord Webhook"
        echo -e " [6] System Settings"
        echo -e " [7] System Tweaks"
        echo -e " [8] START RECONNECTING (Background)"
        echo -e " [9] STOP RECONNECTING"
        echo -e " [10] Set Username"
        echo -e " [11] Exit"
        echo ""
        
        read -t 3 -p "Select Command [1-11]: " choice
        
        if [ $? -ne 0 ]; then
            continue
        fi

        case $choice in
            1)
                [ "$AUTO_RECONNECT" == "OFF" ] && AUTO_RECONNECT="ON" || AUTO_RECONNECT="OFF"
                ;;
            2)
                [ "$FORCE_CLOSE_ENABLED" == "OFF" ] && FORCE_CLOSE_ENABLED="ON" || FORCE_CLOSE_ENABLED="OFF"
                ;;
            3)
                clear_screen
                read -p "Enter FC interval (seconds): " fc_sec
                [[ "$fc_sec" =~ ^[0-9]+$ ]] && FORCE_CLOSE_INTERVAL=$fc_sec
                sleep 1
                ;;
            4) configure_package_server ;;
            5)
                clear_screen
                read -p "Paste Webhook URL: " wh_url
                DISCORD_WEBHOOK="$wh_url"
                echo -e "${GREEN}[+] Saved!${NC}"
                send_discord_log "AUTORDIF Webhook Active!"
                sleep 2
                ;;
            6) settings_menu ;;
            7) apply_system_tweaks ;;
            8) start_background_reconnect; sleep 1 ;;
            9) stop_background_reconnect ;;
            10)
                read -p "Enter Roblox Username: " rbx_user
                [ -n "$rbx_user" ] && ROBLOX_USERNAME="$rbx_user"
                ;;
            11)
                echo -e "${YELLOW}[!] Exiting...${NC}"
                exit 0
                ;;
        esac
    done
}

login_system
select_executor
check_root_and_package
main_menu
