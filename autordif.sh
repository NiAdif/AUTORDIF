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
JOIN_MODE="GAME_ID"
GAME_ID="1537690962"
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

check_root_and_package() {
    echo -e "${BLUE}[*] Checking Root status...${NC}"
    if su -c "id" >/dev/null 2>&1; then
        MODE_ROOT=true
        echo -e "${GREEN}[+] Root Access Granted!${NC}"
    else
        MODE_ROOT=false
        echo -e "${YELLOW}[!] Root Access Not Detected (Running in Non-Root mode).${NC}"
    fi

    echo -e "${BLUE}[*] Auto-scanning all packages starting with 'com.roblox.'...${NC}"
    
    local scanned_pkgs=""
    if $MODE_ROOT; then
        scanned_pkgs=$(su -c "pm list packages" | grep "com.roblox." | sed 's/package://g' | tr -d '\r')
    else
        scanned_pkgs=$(pm list packages 2>/dev/null | grep "com.roblox." | sed 's/package://g' | tr -d '\r')
    fi

    if [ -n "$scanned_pkgs" ]; then
        ROBLOX_PACKAGES=()
        while IFS= read -r pkg; do
            [ -n "$pkg" ] && ROBLOX_PACKAGES+=("$pkg")
        done <<< "$scanned_pkgs"
        
        echo -e "${GREEN}[+] Berjaya dikesan ${#ROBLOX_PACKAGES[@]} pakej Roblox/Executor:${NC}"
        for pkg in "${ROBLOX_PACKAGES[@]}"; do
            echo -e "    ${CYAN}- $pkg${NC}"
            set_pkg_status "$pkg" "STANDBY"
        done
    else
        echo -e "${YELLOW}[!] Tiada pakej com.roblox.* dikesan secara automatik. Menggunakan default (com.roblox.client).${NC}"
        ROBLOX_PACKAGES=("com.roblox.client")
        set_pkg_status "com.roblox.client" "STANDBY"
    fi
    sleep 3
}

manage_packages_menu() {
    while true; do
        clear_screen
        echo -e "${CYAN}=== MULTI-PACKAGE MANAGER ===${NC}\n"
        echo -e "Senarai Pakej Semasa:"
        local idx=1
        for pkg in "${ROBLOX_PACKAGES[@]}"; do
            echo -e " ${YELLOW}[$idx]${NC} $pkg"
            ((idx++))
        done
        echo ""
        echo -e "1) Auto-Scan Semula Pakej (com.roblox.*)"
        echo -e "2) Tambah Pakej Secara Manual"
        echo -e "3) Buang / Remove Pakej (ikut Nombor)"
        echo -e "4) Kembali"
        echo ""
        read -p "Pilih pilihan [1-4]: " m_opt

        case $m_opt in
            1) check_root_and_package ;;
            2)
                read -p "Masukkan nama pakej baru (contoh: com.roblox.delta): " new_p
                if [ -n "$new_p" ]; then
                    ROBLOX_PACKAGES+=("$new_p")
                    set_pkg_status "$new_p" "STANDBY"
                    echo -e "${GREEN}[+] Pakej berjaya ditambah!${NC}"
                fi
                sleep 1
                ;;
            3)
                read -p "Masukkan nombor pakej yang hendak dibuang: " del_idx
                if [[ "$del_idx" =~ ^[0-9]+$ ]] && [ "$del_idx" -ge 1 ] && [ "$del_idx" -le "${#ROBLOX_PACKAGES[@]}" ]; then
                    local target_pkg="${ROBLOX_PACKAGES[del_idx-1]}"
                    unset 'ROBLOX_PACKAGES[del_idx-1]'
                    ROBLOX_PACKAGES=("${ROBLOX_PACKAGES[@]}")
                    unset 'PKG_STATUSES[$target_pkg]'
                    unset 'PKG_LAUNCH_TIMES[$target_pkg]'
                    echo -e "${GREEN}[+] Pakej $target_pkg berjaya dibuang!${NC}"
                else
                    echo -e "${RED}[!] Nombor tidak sah.${NC}"
                fi
                sleep 1
                ;;
            4) break ;;
            *) echo -e "${RED}Pilihan tidak sah!${NC}"; sleep 1 ;;
        esac
    done
}

apply_system_tweaks() {
    clear_screen
    echo -e "${MAGENTA}=== AUTORDIF SYSTEM TWEAKER ===${NC}\n"
    
    if ! $MODE_ROOT; then
        echo -e "${RED}[!] Error: System tweaks require ROOT privileges.${NC}"
        read -p "Press Enter to return..."
        return
    fi

    echo -e "${CYAN}[1] Force Stop Background Apps${NC}"
    echo -e "${CYAN}[2] Clear Cache Memory (RAM Optimization)${NC}"
    echo -e "${CYAN}[3] Apply LMK Protection for All Roblox Packages${NC}"
    echo -e "${CYAN}[4] Back${NC}"
    echo ""
    read -p "Select option [1-4]: " tweak_opt

    case $tweak_opt in
        1) su -c "am kill-all"; echo -e "${GREEN}[+] Background apps cleared.${NC}" ;;
        2) su -c "sync; echo 3 > /proc/sys/vm/drop_caches"; echo -e "${GREEN}[+] RAM cache flushed.${NC}" ;;
        3)
            for pkg in "${ROBLOX_PACKAGES[@]}"; do
                local pid=$(su -c "pidof $pkg")
                if [ -n "$pid" ]; then
                    su -c "echo -17 > /proc/$pid/oom_adj"
                    echo -e "${GREEN}[+] Process $pkg (PID $pid) protected.${NC}"
                else
                    echo -e "${YELLOW}[!] Package $pkg tidak aktif.${NC}"
                fi
            done
            sleep 2
            ;;
        4) return ;;
        *) echo -e "${RED}Invalid choice!${NC}" ;;
    esac
    sleep 2
}

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
        1) SELECTED_EXECUTOR="Delta [KEY]" ;;
        2) SELECTED_EXECUTOR="ArceusX [KEYLESS]" ;;
        *) SELECTED_EXECUTOR="Delta [KEY]" ;;
    esac
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
    set_pkg_status "$pkg" "OPENING ROBLOX"
    PKG_LAUNCH_TIMES["$pkg"]=$(date +%s)
    send_discord_log "Launching specific package: $pkg"
    
    if [ "$JOIN_MODE" == "GAME_ID" ]; then
        local launch_url="roblox://placeID=$GAME_ID"
    else
        local launch_url="$SERVER_LINK"
    fi

    if $MODE_ROOT; then
        su -c "am start -a android.intent.action.VIEW -d '$launch_url' $pkg" >/dev/null 2>&1
    else
        am start -a android.intent.action.VIEW -d "$launch_url" "$pkg" >/dev/null 2>&1
    fi
}

launch_all_packages() {
    set_status "RECONNECTING"
    send_discord_log "Initiating launch for all ${#ROBLOX_PACKAGES[@]} targeted packages."
    
    for pkg in "${ROBLOX_PACKAGES[@]}"; do
        set_pkg_status "$pkg" "RECONNECTING"
        if $MODE_ROOT; then
            su -c "am force-stop $pkg" >/dev/null 2>&1
        else
            am force-stop "$pkg" >/dev/null 2>&1
        fi
        sleep 1
        launch_specific_pkg "$pkg"
        sleep 2
    done

    START_TIME=$(date +%s)
    set_status "RUNNING"
    send_discord_log "All packages have been deployed."
}

background_monitor() {
    termux-wake-lock >/dev/null 2>&1
    launch_all_packages

    local last_rejoin_time=$(date +%s)

    while true; do
        sleep "$CHECK_INTERVAL"
        local current_time=$(date +%s)

        if [ "$FORCE_CLOSE_ENABLED" == "ON" ]; then
            local time_diff=$((current_time - last_rejoin_time))
            if [ "$time_diff" -ge "$FORCE_CLOSE_INTERVAL" ]; then
                set_status "FORCE CLOSING (STUCK)"
                send_discord_log "Scheduled Force Close triggered. Restarting all accounts..."
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
                if [ "$current_p_stat" == "OPENING ROBLOX" ] || [ "$current_p_stat" == "RECONNECTING" ]; then
                    local launch_t="${PKG_LAUNCH_TIMES[$pkg]:-$current_time}"
                    local elapsed_launch=$((current_time - launch_t))
                    if [ "$elapsed_launch" -ge "$STUCK_TIMEOUT" ]; then
                        set_pkg_status "$pkg" "STUCK (RE-OPEN)"
                        send_discord_log "STUCK DETECTED on package $pkg! Force-closing and re-opening..."
                        if $MODE_ROOT; then
                            su -c "am force-stop $pkg" >/dev/null 2>&1
                        else
                            am force-stop "$pkg" >/dev/null 2>&1
                        fi
                        sleep 1
                        launch_specific_pkg "$pkg"
                        any_action_taken=true
                        continue
                    fi
                fi

                all_crashed=false
                set_pkg_status "$pkg" "RUNNING"
            else
                set_pkg_status "$pkg" "CRASHED"
                send_discord_log "CRASH DETECTED on package: $pkg. Reconnecting this specific account..."
                launch_specific_pkg "$pkg"
                any_action_taken=true
                sleep 2
            fi
        done

        if "$all_crashed"; then
            set_status "ALL CRASHED"
            send_discord_log "All packages crashed! Re-launching everything..."
            launch_all_packages
            last_rejoin_time=$(date +%s)
        elif ! "$any_action_taken"; then
            set_status="RUNNING"
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
        echo -e "${YELLOW}[!] Auto Reconnect is already running!${NC}"
        sleep 2
        return
    fi

    termux-wake-lock >/dev/null 2>&1
    echo -e "${GREEN}[+] Starting Multi-Account Auto Reconnect & Wake Lock...${NC}"
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
    termux-wake-unlock >/dev/null 2>&1
    set_status "CLOSED"
    for pkg in "${ROBLOX_PACKAGES[@]}"; do
        set_pkg_status "$pkg" "CLOSED"
    done
    START_TIME=0
    echo -e "${GREEN}[+] Auto Reconnect has been STOPPED & Wake Lock released.${NC}"
    sleep 1
}

is_background_active() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo -e "${GREEN}ACTIVE (WakeLock Protected)${NC}"
    else
        echo -e "${RED}INACTIVE (Stopped)${NC}"
    fi
}

settings_menu() {
    while true; do
        clear_screen
        echo -e "${CYAN}=== AUTORDIF SETTINGS ===${NC}\n"
        echo -e "1) Recheck Interval (Current: ${YELLOW}${CHECK_INTERVAL}s${NC})"
        echo -e "2) Manage Multi-Packages (Jumlah: ${YELLOW}$([[ ${#ROBLOX_PACKAGES[@]} ]] && echo ${#ROBLOX_PACKAGES[@]})${NC})"
        echo -e "3) Toggle Scheduled Force Close [Current: ${BOLD}${FORCE_CLOSE_ENABLED}${NC}]"
        echo -e "4) Set Force Close Interval (Current: ${YELLOW}${FORCE_CLOSE_INTERVAL}s${NC})"
        echo -e "5) Set Stuck Loading Timeout (Current: ${YELLOW}${STUCK_TIMEOUT}s${NC})"
        echo -e "6) Manual Toggle Termux Wake Lock (ON/OFF)"
        echo -e "7) Auto-Scan / Refresh Pakej Roblox"
        echo -e "8) Back to Main Menu"
        echo ""
        read -p "Select option [1-8]: " set_opt

        case $set_opt in
            1)
                read -p "Enter interval in seconds: " new_int
                [[ "$new_int" =~ ^[0-9]+$ ]] && CHECK_INTERVAL=$new_int
                sleep 1
                ;;
            2) manage_packages_menu ;;
            3)
                if [ "$FORCE_CLOSE_ENABLED" == "OFF" ]; then
                    FORCE_CLOSE_ENABLED="ON"
                else
                    FORCE_CLOSE_ENABLED="OFF"
                fi
                sleep 1
                ;;
            4)
                read -p "Enter Force Close Interval in seconds: " fc_int
                [[ "$fc_int" =~ ^[0-9]+$ ]] && FORCE_CLOSE_INTERVAL=$fc_int
                sleep 1
                ;;
            5)
                read -p "Enter Stuck Timeout in seconds (e.g., 45): " st_int
                [[ "$st_int" =~ ^[0-9]+$ ]] && STUCK_TIMEOUT=$st_int
                sleep 1
                ;;
            6)
                echo -e "${CYAN}1) Turn ON Wake Lock${NC}"
                echo -e "${CYAN}2) Turn OFF Wake Lock${NC}"
                read -p "Pilihan [1-2]: " wl_choice
                if [ "$wl_choice" == "1" ]; then
                    termux-wake-lock >/dev/null 2>&1
                    echo -e "${GREEN}[+] Termux Wake Lock ACTIVATED manually!${NC}"
                elif [ "$wl_choice" == "2" ]; then
                    termux-wake-unlock >/dev/null 2>&1
                    echo -e "${YELLOW}[!] Termux Wake Lock RELEASED manually!${NC}"
                fi
                sleep 1
                ;;
            7) check_root_and_package ;;
            8) break ;;
            *) echo -e "${RED}Invalid Selection${NC}"; sleep 1 ;;
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
                    if [ "$current_p_stat" != "OPENING ROBLOX" ] && [ "$current_p_stat" != "RECONNECTING" ] && [[ "$current_p_stat" != *"STUCK"* ]]; then
                        set_pkg_status "$pkg" "RUNNING"
                    fi
                else
                    set_pkg_status "$pkg" "CRASHED"
                fi
            done
        fi

        local current_status=$(get_status)

        echo -e "${WHITE}Date/Time       : ${YELLOW}$(get_current_datetime)${NC}"
        echo -e "${WHITE}Executor        : ${CYAN}$SELECTED_EXECUTOR${NC}"
        echo -e "${WHITE}Active Accounts : ${MAGENTA}$([[ ${#ROBLOX_PACKAGES[@]} ]] && echo ${#ROBLOX_PACKAGES[@]})${NC}"
        
        if [ "$current_status" == "RUNNING" ]; then
            echo -e "${WHITE}Roblox Status   : ${GREEN}$current_status${NC}"
        elif [[ "$current_status" == *"CRASHED"* ]]; then
            echo -e "${WHITE}Roblox Status   : ${RED}$current_status${NC}"
        else
            echo -e "${WHITE}Roblox Status   : ${YELLOW}$current_status${NC}"
        fi

        echo -e "${WHITE}Session Uptime  : ${GREEN}$(get_elapsed_time)${NC}"
        echo -e "${WHITE}Username        : ${BLUE}$ROBLOX_USERNAME${NC}"
        echo -e "${WHITE}Monitor Worker  : $(is_background_active)"
        echo -e "${CYAN}====================================================${NC}"

        echo -e "${YELLOW}${BOLD}┌──────────────── LIVE PACKAGE STATUS ──────────────┐${NC}"
        for pkg in "${ROBLOX_PACKAGES[@]}"; do
            local p_stat="${PKG_STATUSES[$pkg]:-STANDBY}"
            local color_stat="${GREEN}"
            if [ "$p_stat" == "CRASHED" ] || [[ "$p_stat" == *"STUCK"* ]]; then
                color_stat="${RED}"
            elif [ "$p_stat" == "RECONNECTING" ] || [ "$p_stat" == "OPENING ROBLOX" ]; then
                color_stat="${YELLOW}"
            fi
            printf "${YELLOW}│${NC} %-30s : ${color_stat}%-14s${NC} ${YELLOW}│${NC}\n" "$pkg" "$p_stat"
        done
        echo -e "${YELLOW}${BOLD}└───────────────────────────────────────────────────┘${NC}\n"

        echo -e " [1] Toggle Auto Reconnect [Current: ${BOLD}${AUTO_RECONNECT}${NC}]"
        echo -e " [2] Configure Server Setup [Mode: ${YELLOW}${JOIN_MODE}${NC}]"
        echo -e " [3] Configure Discord Webhook"
        echo -e " [4] System Settings (Interval, Multi-Packages, Auto-Scan)"
        echo -e " [5] System Tweaks (Optimization)"
        echo -e " [6] START RECONNECTING (Run in Background)"
        echo -e " [7] STOP RECONNECTING (Kill Background Worker)"
        echo -e " [8] Set Roblox Username"
        echo -e " [9] Exit"
        echo ""
        
        read -t 3 -p "Select Command [1-9]: " choice
        
        if [ $? -ne 0 ]; then
            continue
        fi

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
                echo -e "${GREEN}[+] Webhook saved!${NC}"
                send_discord_log "AUTORDIF Multi-Account Webhook Active!"
                sleep 2
                ;;
            4) settings_menu ;;
            5) apply_system_tweaks ;;
            6) start_background_reconnect; sleep 1 ;;
            7) stop_background_reconnect ;;
            8)
                read -p "Enter Roblox Username: " rbx_user
                [ -n "$rbx_user" ] && ROBLOX_USERNAME="$rbx_user"
                ;;
            9)
                echo -e "${YELLOW}[!] Exiting menu.${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid input selection!${NC}"
                sleep 1
                ;;
        esac
    done
}

login_system
select_executor
check_root_and_package
main_menu
