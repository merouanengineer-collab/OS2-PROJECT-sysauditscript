#!/usr/bin/env bash
# =============================================================================
# hw_audit.sh — Hardware Information Collection Module
# Project : Linux System Audit & Monitoring
# Author  : Merouane Ben Boucherit — NSCS 2025/2026
# =============================================================================
# Exports:
#   HW_DATA        — associative array holding all hardware data
#   collect_hardware()  — populates HW_DATA and writes hw_raw.txt
# =============================================================================

# Associative array to hold all hardware data
declare -A HW_DATA

# ── Helper: run a command safely, return "N/A" on failure ─────────────────────
hw_cmd() {
    local result
    result="$(eval "$*" 2>/dev/null)" && echo "${result}" || echo "N/A"
}

# ── Helper: check if a command exists ────────────────────────────────────────
cmd_exists() { command -v "$1" &>/dev/null; }

# ── CPU Information ───────────────────────────────────────────────────────────
collect_cpu() {
    HW_DATA[cpu_model]="$(hw_cmd "grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs")"
    HW_DATA[cpu_cores]="$(hw_cmd "nproc --all")"
    HW_DATA[cpu_threads]="$(hw_cmd "grep -c 'processor' /proc/cpuinfo")"
    HW_DATA[cpu_arch]="$(hw_cmd "uname -m")"
    HW_DATA[cpu_mhz]="$(hw_cmd "grep -m1 'cpu MHz' /proc/cpuinfo | cut -d: -f2 | xargs")"
    HW_DATA[cpu_cache]="$(hw_cmd "grep -m1 'cache size' /proc/cpuinfo | cut -d: -f2 | xargs")"
    HW_DATA[cpu_usage]="$(hw_cmd "top -bn1 | grep 'Cpu(s)' | awk '{print \$2}' | cut -d% -f1")"

    # Detailed CPU info via lscpu if available
    if cmd_exists lscpu; then
        HW_DATA[cpu_lscpu]="$(lscpu 2>/dev/null)"
    fi
}

# ── GPU Information ───────────────────────────────────────────────────────────
collect_gpu() {
    if cmd_exists lspci; then
        local gpu_info
        gpu_info="$(lspci 2>/dev/null | grep -iE 'VGA|3D|Display|GPU')"
        HW_DATA[gpu_info]="${gpu_info:-N/A}"
    else
        HW_DATA[gpu_info]="lspci not available"
    fi

    # NVIDIA-specific details
    if cmd_exists nvidia-smi; then
        HW_DATA[gpu_nvidia]="$(nvidia-smi --query-gpu=name,memory.total,temperature.gpu \
            --format=csv,noheader 2>/dev/null || echo 'N/A')"
    fi
}

# ── RAM Information ───────────────────────────────────────────────────────────
collect_ram() {
    # /proc/meminfo is always reliable
    HW_DATA[ram_total]="$(hw_cmd "grep MemTotal /proc/meminfo | awk '{printf \"%.1f GB\", \$2/1024/1024}'")"
    HW_DATA[ram_free]="$(hw_cmd "grep MemFree /proc/meminfo | awk '{printf \"%.1f GB\", \$2/1024/1024}'")"
    HW_DATA[ram_available]="$(hw_cmd "grep MemAvailable /proc/meminfo | awk '{printf \"%.1f GB\", \$2/1024/1024}'")"
    HW_DATA[ram_usage_pct]="$(hw_cmd "free | awk '/^Mem:/{printf \"%.0f\", (\$3/\$2)*100}'")"
    HW_DATA[ram_swap_total]="$(hw_cmd "grep SwapTotal /proc/meminfo | awk '{printf \"%.1f GB\", \$2/1024/1024}'")"
    HW_DATA[ram_swap_used]="$(hw_cmd "free | awk '/^Swap:/{printf \"%.1f GB\", \$3/1024/1024}'")"

    # Physical DIMM slots via dmidecode (requires root)
    if [[ "${EUID}" -eq 0 ]] && cmd_exists dmidecode; then
        HW_DATA[ram_dimm]="$(dmidecode -t memory 2>/dev/null | \
            grep -E 'Size:|Type:|Speed:|Locator:' | grep -v 'Error')"
    fi
}

# ── Disk Information ──────────────────────────────────────────────────────────
collect_disk() {
    # Partition table and sizes
    HW_DATA[disk_lsblk]="$(hw_cmd "lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL")"

    # Disk usage per mounted filesystem
    HW_DATA[disk_df]="$(hw_cmd "df -hT -x tmpfs -x devtmpfs -x squashfs")"

    # Physical disk details (root only)
    if [[ "${EUID}" -eq 0 ]] && cmd_exists hdparm; then
        # Get all non-loop block devices
        local disks
        disks="$(lsblk -dn -o NAME,TYPE 2>/dev/null | awk '$2=="disk"{print $1}')"
        local hdparm_out=""
        while IFS= read -r disk; do
            hdparm_out+="=== /dev/${disk} ===\n"
            hdparm_out+="$(hdparm -I "/dev/${disk}" 2>/dev/null | grep -E 'Model|Serial|firmware|capacity' || echo 'N/A')\n"
        done <<< "${disks}"
        HW_DATA[disk_hdparm]="${hdparm_out}"
    fi

    # IO stats
    HW_DATA[disk_iostat]="$(hw_cmd "iostat -d 2>/dev/null | head -20")"
}

# ── Network Interfaces ────────────────────────────────────────────────────────
collect_network() {
    HW_DATA[net_interfaces]="$(hw_cmd "ip -br link show")"
    HW_DATA[net_ip_addresses]="$(hw_cmd "ip -br addr show")"
    HW_DATA[net_ip4]="$(hw_cmd "ip -4 addr show | grep inet | awk '{print \$NF, \$2}'")"
    HW_DATA[net_ip6]="$(hw_cmd "ip -6 addr show | grep inet6 | awk '{print \$NF, \$2}' | head -10")"
    HW_DATA[net_mac]="$(hw_cmd "ip link show | grep 'link/ether' | awk '{print \$2}' | paste -sd, -")"
    HW_DATA[net_routing]="$(hw_cmd "ip route show")"
    HW_DATA[net_dns]="$(hw_cmd "grep nameserver /etc/resolv.conf | awk '{print \$2}' | paste -sd, -")"

    # Wireless info if available
    if cmd_exists iwconfig; then
        HW_DATA[net_wireless]="$(iwconfig 2>/dev/null | grep -v '^$' | head -20)"
    fi
}

# ── Motherboard & BIOS ────────────────────────────────────────────────────────
collect_motherboard() {
    if [[ "${EUID}" -eq 0 ]] && cmd_exists dmidecode; then
        HW_DATA[mb_manufacturer]="$(hw_cmd "dmidecode -s baseboard-manufacturer")"
        HW_DATA[mb_product]="$(hw_cmd "dmidecode -s baseboard-product-name")"
        HW_DATA[mb_version]="$(hw_cmd "dmidecode -s baseboard-version")"
        HW_DATA[bios_vendor]="$(hw_cmd "dmidecode -s bios-vendor")"
        HW_DATA[bios_version]="$(hw_cmd "dmidecode -s bios-version")"
        HW_DATA[bios_date]="$(hw_cmd "dmidecode -s bios-release-date")"
        HW_DATA[sys_manufacturer]="$(hw_cmd "dmidecode -s system-manufacturer")"
        HW_DATA[sys_product]="$(hw_cmd "dmidecode -s system-product-name")"
        HW_DATA[sys_serial]="$(hw_cmd "dmidecode -s system-serial-number")"
    else
        # Non-root fallback via /sys
        HW_DATA[mb_manufacturer]="$(hw_cmd "cat /sys/class/dmi/id/board_vendor")"
        HW_DATA[mb_product]="$(hw_cmd "cat /sys/class/dmi/id/board_name")"
        HW_DATA[bios_vendor]="$(hw_cmd "cat /sys/class/dmi/id/bios_vendor")"
        HW_DATA[bios_version]="$(hw_cmd "cat /sys/class/dmi/id/bios_version")"
        HW_DATA[sys_manufacturer]="$(hw_cmd "cat /sys/class/dmi/id/sys_vendor")"
        HW_DATA[sys_product]="$(hw_cmd "cat /sys/class/dmi/id/product_name")"
    fi
}

# ── USB Devices ───────────────────────────────────────────────────────────────
collect_usb() {
    if cmd_exists lsusb; then
        HW_DATA[usb_devices]="$(hw_cmd "lsusb")"
        HW_DATA[usb_tree]="$(hw_cmd "lsusb -t")"
    else
        HW_DATA[usb_devices]="$(hw_cmd "ls /sys/bus/usb/devices/")"
    fi
}

# ── Battery (laptops) ─────────────────────────────────────────────────────────
collect_battery() {
    local bat_dir="/sys/class/power_supply"
    if [[ -d "${bat_dir}" ]]; then
        local bat_info=""
        for bat in "${bat_dir}"/BAT*; do
            [[ -d "${bat}" ]] || continue
            local name; name="$(basename "${bat}")"
            local status; status="$(cat "${bat}/status" 2>/dev/null || echo 'N/A')"
            local capacity; capacity="$(cat "${bat}/capacity" 2>/dev/null || echo 'N/A')"
            bat_info+="${name}: ${capacity}% (${status})\n"
        done
        HW_DATA[battery]="${bat_info:-N/A}"
    fi
}

# ── Alias used by audit.sh _run_full_audit ───────────────────────────────────
collect_all_hardware() { collect_hardware; }

print_hardware_short() {
    echo -e "\n${BOLD}${CYAN}── Hardware Summary ────────────────────────────${RESET}"
    echo -e "  CPU   : ${HW_DATA[cpu_model]:-N/A} (${HW_DATA[cpu_cores]:-?} cores / ${HW_DATA[cpu_threads]:-?} threads)"
    echo -e "  RAM   : ${HW_DATA[ram_total]:-N/A} total | ${HW_DATA[ram_available]:-N/A} free | ${HW_DATA[ram_usage_pct]:-?}% used"
    echo -e "  Disk  : $(echo "${HW_DATA[disk_df]:-}" | awk 'NR>1 && $7!="" {printf "%s(%s) ", $7, $6}' | head -c 80)"
    echo -e "  Net   : ${HW_DATA[net_ip4]:-N/A}"
}

print_hardware_full() {
    log_section "[ DETAILED HARDWARE AUDIT ]"
    echo -e "${BOLD}CPU Model:${RESET}     ${HW_DATA[cpu_model]:-N/A}"
    echo -e "${BOLD}Topology:${RESET}      ${HW_DATA[cpu_cores]:-?} Cores / ${HW_DATA[cpu_threads]:-?} Threads @ ${HW_DATA[cpu_mhz]:-?} MHz"
    echo -e "${BOLD}RAM Total:${RESET}     ${HW_DATA[ram_total]:-N/A} (Available: ${HW_DATA[ram_available]:-N/A})"
    echo -e "${BOLD}Usage:${RESET}         ${HW_DATA[ram_usage_pct]:-0}%"
    echo -e "\n${BOLD}Disk Partitioning (lsblk):${RESET}\n${HW_DATA[disk_lsblk]:-N/A}"
    echo -e "\n${BOLD}Filesystem Usage (df):${RESET}\n${HW_DATA[disk_df]:-N/A}"
    echo -e "\n${BOLD}Network Interfaces:${RESET}\n${HW_DATA[net_interfaces]:-N/A}"
}

# ── Main collector ────────────────────────────────────────────────────────────────
collect_hardware() {
    ((AUDIT_CURRENT_STEP++)); show_progress "$AUDIT_CURRENT_STEP" "$AUDIT_TOTAL_STEPS"; collect_cpu
    ((AUDIT_CURRENT_STEP++)); show_progress "$AUDIT_CURRENT_STEP" "$AUDIT_TOTAL_STEPS"; collect_gpu
    ((AUDIT_CURRENT_STEP++)); show_progress "$AUDIT_CURRENT_STEP" "$AUDIT_TOTAL_STEPS"; collect_ram
    ((AUDIT_CURRENT_STEP++)); show_progress "$AUDIT_CURRENT_STEP" "$AUDIT_TOTAL_STEPS"; collect_disk
    ((AUDIT_CURRENT_STEP++)); show_progress "$AUDIT_CURRENT_STEP" "$AUDIT_TOTAL_STEPS"; collect_network
    ((AUDIT_CURRENT_STEP++)); show_progress "$AUDIT_CURRENT_STEP" "$AUDIT_TOTAL_STEPS"; collect_motherboard
    ((AUDIT_CURRENT_STEP++)); show_progress "$AUDIT_CURRENT_STEP" "$AUDIT_TOTAL_STEPS"; collect_usb
    ((AUDIT_CURRENT_STEP++)); show_progress "$AUDIT_CURRENT_STEP" "$AUDIT_TOTAL_STEPS"; collect_battery

    # Write raw hardware dump for reference
    {
        echo "=== RAW HARDWARE DUMP — $(date) ==="
        echo "--- CPU ---"
        cat /proc/cpuinfo 2>/dev/null
        echo "--- MEMORY ---"
        cat /proc/meminfo 2>/dev/null
        echo "--- BLOCK DEVICES ---"
        lsblk -a 2>/dev/null
    } > "${OUTPUT_DIR}/hw_raw.txt" 2>/dev/null || true
}