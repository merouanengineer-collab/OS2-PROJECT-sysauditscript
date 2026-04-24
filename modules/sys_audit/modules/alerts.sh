#!/usr/bin/env bash
# ============================================================
# modules/alerts.sh — Resource Alert System (BONUS FEATURE)
# Monitors CPU/RAM/Disk usage and sends alerts if thresholds
# are exceeded. Color-coded terminal output included.
# ============================================================

# Alert state tracking (prevents spam)
ALERT_LOG="${REPORT_DIR:-/var/log/sys_audit}/alerts.log"

# ════════════════════════════════════════════════════════════
# get_cpu_usage — Returns current CPU usage percentage (int)
# ════════════════════════════════════════════════════════════
get_cpu_usage() {
    # Method 1: /proc/stat (accurate, 1-sec average)
    local cpu1 cpu2 idle1 idle2 total1 total2
    read -ra cpu1 < /proc/stat
    sleep 1
    read -ra cpu2 < /proc/stat

    local total1=$(( cpu1[1]+cpu1[2]+cpu1[3]+cpu1[4]+cpu1[5]+cpu1[6]+cpu1[7] ))
    local idle1=${cpu1[4]}
    local total2=$(( cpu2[1]+cpu2[2]+cpu2[3]+cpu2[4]+cpu2[5]+cpu2[6]+cpu2[7] ))
    local idle2=${cpu2[4]}

    local delta_total=$(( total2 - total1 ))
    local delta_idle=$(( idle2 - idle1 ))
    local usage=$(( (delta_total - delta_idle) * 100 / delta_total ))
    echo "$usage"
}

# ════════════════════════════════════════════════════════════
# get_ram_usage — Returns RAM usage percentage (int)
# ════════════════════════════════════════════════════════════
get_ram_usage() {
    free | awk '/^Mem:/{printf "%.0f", ($3/$2)*100}'
}

# ════════════════════════════════════════════════════════════
# get_disk_usage — Returns highest disk partition usage (int)
# ════════════════════════════════════════════════════════════
get_disk_usage() {
    df -h | grep -vE '^Filesystem|tmpfs|devtmpfs|udev' \
           | awk '{gsub(/%/, "", $5); print $5}' \
           | sort -n | tail -1
}

# ════════════════════════════════════════════════════════════
# _color_usage — Color-code a percentage value
# ════════════════════════════════════════════════════════════
_color_usage() {
    local pct="$1"
    if   [[ "$pct" -ge 90 ]]; then echo -e "${RED}${pct}%${RESET}"
    elif [[ "$pct" -ge 70 ]]; then echo -e "${YELLOW}${pct}%${RESET}"
    else                            echo -e "${GREEN}${pct}%${RESET}"
    fi
}

# ════════════════════════════════════════════════════════════
# _progress_bar — ASCII progress bar for resource usage
# ════════════════════════════════════════════════════════════
_progress_bar() {
    local pct="$1"
    local width=40
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local bar=""

    # Color selection
    local color
    if   [[ "$pct" -ge 90 ]]; then color="$RED"
    elif [[ "$pct" -ge 70 ]]; then color="$YELLOW"
    else                            color="$GREEN"
    fi

    bar+="${color}["
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty;  i++)); do bar+="░"; done
    bar+="]${RESET} ${pct}%"
    echo -e "$bar"
}

# ════════════════════════════════════════════════════════════
# check_resources — Single resource snapshot with alerting
# ════════════════════════════════════════════════════════════
check_resources() {
    local cpu_pct ram_pct disk_pct
    local alert_triggered=0

    echo -e "\n${BOLD}${BLUE}[ RESOURCE MONITOR ]${RESET} $(date '+%H:%M:%S')"
    echo -e "${CYAN}${THIN_SEP}${RESET}"

    # CPU
    echo -ne "${BOLD}CPU Usage   ${RESET}"
    cpu_pct=$(get_cpu_usage)
    _progress_bar "$cpu_pct"

    # RAM
    echo -ne "${BOLD}RAM Usage   ${RESET}"
    ram_pct=$(get_ram_usage)
    _progress_bar "$ram_pct"

    # Disk
    echo -ne "${BOLD}Disk Usage  ${RESET}"
    disk_pct=$(get_disk_usage)
    _progress_bar "$disk_pct"

    echo -e "${CYAN}${THIN_SEP}${RESET}"

    # ── Alert checks ───────────────────────────────────────
    local alert_msg=""

    if [[ "$cpu_pct" -ge "${CPU_ALERT_THRESHOLD:-80}" ]]; then
        alert_triggered=1
        log_warn "CPU alert: ${cpu_pct}% ≥ threshold ${CPU_ALERT_THRESHOLD}%"
        alert_msg+="[CPU: ${cpu_pct}%] "
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] CPU ALERT: ${cpu_pct}%" >> "$ALERT_LOG"
    fi

    if [[ "$ram_pct" -ge "${RAM_ALERT_THRESHOLD:-85}" ]]; then
        alert_triggered=1
        log_warn "RAM alert: ${ram_pct}% ≥ threshold ${RAM_ALERT_THRESHOLD}%"
        alert_msg+="[RAM: ${ram_pct}%] "
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] RAM ALERT: ${ram_pct}%" >> "$ALERT_LOG"
    fi

    if [[ "$disk_pct" -ge "${DISK_ALERT_THRESHOLD:-90}" ]]; then
        alert_triggered=1
        log_warn "Disk alert: ${disk_pct}% ≥ threshold ${DISK_ALERT_THRESHOLD}%"
        alert_msg+="[DISK: ${disk_pct}%] "
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] DISK ALERT: ${disk_pct}%" >> "$ALERT_LOG"
    fi

    # Send alert email if any threshold exceeded
    if [[ "$alert_triggered" -eq 1 ]]; then
        echo -e "${RED}${BOLD}⚠ ALERT triggered! Sending notification email...${RESET}"
        # Source email module and send
        send_alert_email "Resources" "$alert_msg"
    else
        echo -e "${GREEN}All resources within normal limits.${RESET}"
    fi
}

# ════════════════════════════════════════════════════════════
# monitor_loop — Continuous monitoring (real-time dashboard)
# ════════════════════════════════════════════════════════════
monitor_loop() {
    local interval="${1:-5}"  # seconds between checks
    local max_runs="${2:-0}"  # 0 = infinite
    local run_count=0

    echo -e "${CYAN}${BOLD}Starting real-time monitor (Ctrl+C to stop)...${RESET}"
    echo -e "Refresh every ${interval}s | CPU threshold: ${CPU_ALERT_THRESHOLD}% | RAM: ${RAM_ALERT_THRESHOLD}% | Disk: ${DISK_ALERT_THRESHOLD}%\n"

    while true; do
        clear 2>/dev/null || echo -e "\n\n"
        print_banner 2>/dev/null

        # System load
        echo -e "${BOLD}Load Average:${RESET} $(cat /proc/loadavg 2>/dev/null | awk '{print $1, $2, $3}')"
        echo -e "${BOLD}Uptime:${RESET}       $(uptime -p 2>/dev/null)"
        echo -e "${BOLD}Processes:${RESET}    $(ps aux --no-header | wc -l)"

        check_resources

        # Recent connections
        echo -e "\n${BOLD}Active Network Connections:${RESET}"
        ss -tnp 2>/dev/null | grep ESTAB | head -5 | awk '{print "  "$4, "→", $5}' || echo "  None"

        run_count=$(( run_count + 1 ))
        [[ "$max_runs" -gt 0 && "$run_count" -ge "$max_runs" ]] && break

        echo -e "\n${DIM}Next refresh in ${interval}s...${RESET}"
        sleep "$interval"
    done
}