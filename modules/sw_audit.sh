#!/usr/bin/env bash
# =============================================================================
# sw_audit.sh — Software & OS Information Collection Module
# Project : Linux System Audit & Monitoring
# Author  : [Merouane] — NSCS 2025/2026
# =============================================================================
# Exports:
#   SW_DATA        — associative array holding all software data
#   collect_software()  — populates SW_DATA
# =============================================================================
 
 declare -A SW_DATA
 #helper-safe execution
sw_cmd() { eval "$*" 2>/dev/null || echo "N/A"; }
 #OS IDENDITY
 collect_os_info() {
    SW_DATA[os_name]="$(sw_cmd "grep '^PRETTY_NAME' /etc/os-release | cut -d= -f2 | tr -d '\"'")"
    SW_DATA[os_id]="$(sw_cmd "grep '^ID=' /etc/os-release | cut -d= -f2")"
    SW_DATA[os_version]="$(sw_cmd "grep '^VERSION=' /etc/os-release | cut -d= -f2 | tr -d '\"'")"
    SW_DATA[os_codename]="$(sw_cmd "grep '^VERSION_CODENAME' /etc/os-release | cut -d= -f2")"
    SW_DATA[kernel_version]="$(uname -r)"
    SW_DATA[kernel_full]="$(uname -a)"
    SW_DATA[architecture]="$(uname -m)"
    SW_DATA[hostname]="$(hostname -f 2>/dev/null || hostname)"
    SW_DATA[uptime]="$(uptime -p 2>/dev/null || uptime)"
    SW_DATA[uptime_since]="$(uptime -s 2>/dev/null || echo 'N/A')"
    SW_DATA[timezone]="$(timedatectl show --property=Timezone --value 2>/dev/null || \
                         cat /etc/timezone 2>/dev/null || echo 'N/A')"
    SW_DATA[locale]="$(locale | grep LANG= | cut -d= -f2)"
}

# ── Installed Packages ────────────────────────────────────────────────────────
collect_packages() {
    # Detect package manager and count/list packages
    if command -v dpkg &>/dev/null; then
        SW_DATA[pkg_manager]="dpkg/apt"
        SW_DATA[pkg_count]="$(dpkg -l 2>/dev/null | grep -c '^ii')"
        SW_DATA[pkg_list]="$(dpkg -l 2>/dev/null | awk '/^ii/{print $2, $3}' | head -100)"
        SW_DATA[pkg_recently_installed]="$(grep 'install ' /var/log/dpkg.log 2>/dev/null | \
            tail -20 || echo 'N/A')"
    elif command -v rpm &>/dev/null; then
        SW_DATA[pkg_manager]="rpm/dnf"
        SW_DATA[pkg_count]="$(rpm -qa 2>/dev/null | wc -l)"
        SW_DATA[pkg_list]="$(rpm -qa --qf '%{NAME} %{VERSION}\n' 2>/dev/null | head -100)"
    elif command -v pacman &>/dev/null; then
        SW_DATA[pkg_manager]="pacman"
        SW_DATA[pkg_count]="$(pacman -Qq 2>/dev/null | wc -l)"
        SW_DATA[pkg_list]="$(pacman -Q 2>/dev/null | head -100)"
    else
        SW_DATA[pkg_manager]="unknown"
        SW_DATA[pkg_count]="N/A"
    fi
 
    # Snap packages
    if command -v snap &>/dev/null; then
        SW_DATA[snap_packages]="$(snap list 2>/dev/null || echo 'N/A')"
    fi
 
    # Flatpak
    if command -v flatpak &>/dev/null; then
        SW_DATA[flatpak_packages]="$(flatpak list --app 2>/dev/null || echo 'N/A')"
    fi
}
# ── Logged-in Users ───────────────────────────────────────────────────────────
collect_users() {
    SW_DATA[current_user]="$(whoami)"
    SW_DATA[logged_in_users]="$(who 2>/dev/null)"
    SW_DATA[all_users]="$(getent passwd | awk -F: '$3>=1000 && $3<65534 {print $1, "UID:"$3, $6}' 2>/dev/null)"
    SW_DATA[last_logins]="$(last -n 15 2>/dev/null)"
    SW_DATA[failed_logins]="$(lastb -n 10 2>/dev/null || echo 'N/A (requires root)')"
    SW_DATA[sudo_users]="$(getent group sudo 2>/dev/null || getent group wheel 2>/dev/null || echo 'N/A')"
}
 
# ── Running Services ──────────────────────────────────────────────────────────
collect_services() {
    if command -v systemctl &>/dev/null; then
        SW_DATA[services_running]="$(systemctl list-units --type=service --state=running \
            --no-pager --no-legend 2>/dev/null | awk '{print $1, $4}')"
        SW_DATA[services_failed]="$(systemctl list-units --type=service --state=failed \
            --no-pager --no-legend 2>/dev/null)"
        SW_DATA[services_enabled]="$(systemctl list-unit-files --type=service --state=enabled \
            --no-pager --no-legend 2>/dev/null | awk '{print $1}')"
    elif command -v service &>/dev/null; then
        SW_DATA[services_running]="$(service --status-all 2>/dev/null | grep '\[ + \]')"
    fi
}
 # ── Active Processes ──────────────────────────────────────────────────────────
collect_processes() {
    # Top 15 processes by CPU usage
    SW_DATA[proc_top_cpu]="$(ps aux --sort=-%cpu 2>/dev/null | head -16)"
    # Top 15 processes by memory usage
    SW_DATA[proc_top_mem]="$(ps aux --sort=-%mem 2>/dev/null | head -16)"
    SW_DATA[proc_count]="$(ps aux 2>/dev/null | wc -l)"
    # Process tree
    SW_DATA[proc_tree]="$(pstree -p 2>/dev/null | head -40 || ps f 2>/dev/null | head -40)"
}
 
# ── Open Ports & Network Connections ─────────────────────────────────────────
collect_ports() {
    if command -v ss &>/dev/null; then
        SW_DATA[ports_listening]="$(ss -tlunp 2>/dev/null)"
        SW_DATA[ports_all]="$(ss -tunp 2>/dev/null)"
    elif command -v netstat &>/dev/null; then
        SW_DATA[ports_listening]="$(netstat -tlunp 2>/dev/null)"
        SW_DATA[ports_all]="$(netstat -tunp 2>/dev/null)"
    fi
 
    # Firewall status
    if command -v ufw &>/dev/null; then
        SW_DATA[firewall]="$(ufw status verbose 2>/dev/null || echo 'N/A')"
    elif command -v firewall-cmd &>/dev/null; then
        SW_DATA[firewall]="$(firewall-cmd --state 2>/dev/null; \
                             firewall-cmd --list-all 2>/dev/null)"
    elif command -v iptables &>/dev/null; then
        SW_DATA[firewall]="$(iptables -L -n 2>/dev/null || echo 'N/A (requires root)')"
    fi
}
# ── Security & System Integrity ───────────────────────────────────────────────
collect_security() {
    # SUID/SGID files — skip virtual/remote filesystems to avoid hangs
    local _find_opts=( -not -path "/proc/*" -not -path "/sys/*"
                       -not -path "/dev/*"  -not -path "/run/*" )
    SW_DATA[suid_files]="$(timeout 10 find / -perm -4000 -type f \
        "${_find_opts[@]}" 2>/dev/null | head -30 || echo 'N/A')"
    SW_DATA[sgid_files]="$(timeout 10 find / -perm -2000 -type f \
        "${_find_opts[@]}" 2>/dev/null | head -20 || echo 'N/A')"

    # World-writable files in key dirs
    SW_DATA[world_writable]="$(timeout 8 find /etc /usr /bin /sbin \
        -perm -0002 -type f 2>/dev/null | head -20 || echo 'N/A')"
 
    # AppArmor / SELinux
    if command -v aa-status &>/dev/null; then
        SW_DATA[apparmor]="$(aa-status 2>/dev/null || echo 'N/A')"
    fi
    if command -v getenforce &>/dev/null; then
        SW_DATA[selinux]="$(getenforce 2>/dev/null || echo 'N/A')"
    fi
 
    # Scheduled tasks
    SW_DATA[crontabs]="$(for u in $(cut -f1 -d: /etc/passwd 2>/dev/null); do \
        crontab -l -u "${u}" 2>/dev/null && echo "# user: ${u}"; done)"
    SW_DATA[cron_system]="$(ls /etc/cron.* 2>/dev/null | head -20)"
 
    # Loaded kernel modules
    SW_DATA[kernel_modules]="$(lsmod 2>/dev/null | head -40)"
 
    # Boot parameters
    SW_DATA[boot_params]="$(cat /proc/cmdline 2>/dev/null)"
}
 

 #── Environment & Shell ───────────────────────────────────────────────────────
collect_environment() {
    SW_DATA[shell]="$(echo "${SHELL}")"
    SW_DATA[path]="$(echo "${PATH}")"
    SW_DATA[env_vars]="$(env 2>/dev/null | sort)"
    SW_DATA[loaded_modules]="$(lsmod 2>/dev/null | wc -l) modules loaded"
 
    # Active mount points
    SW_DATA[mounts]="$(mount | grep -v "type\(proc\|sys\|dev\|run\|snap\)" | \
                       grep -vE '^(proc|sys|dev|run|tmpfs|cgroup|udev)' | head -20)"
 
    # /tmp usage
    SW_DATA[tmp_usage]="$(du -sh /tmp 2>/dev/null || echo 'N/A')"
    SW_DATA[tmp_files]="$(ls -lAt /tmp 2>/dev/null | head -10)"
}


# ── Alias used by audit.sh _run_full_audit ───────────────────────────────────
collect_all_software() { collect_software; }

print_software_short() {
    echo -e "\n${BOLD}${CYAN}── Software Summary ────────────────────────────${RESET}"
    echo -e "  OS      : ${SW_DATA[os_name]:-N/A}"
    echo -e "  Kernel  : ${SW_DATA[kernel_version]:-N/A}"
    echo -e "  Uptime  : ${SW_DATA[uptime]:-N/A}"
    echo -e "  Packages: ${SW_DATA[pkg_count]:-N/A} installed (${SW_DATA[pkg_manager]:-unknown})"
    echo -e "  Users   : $(echo "${SW_DATA[logged_in_users]:-none}" | wc -l) logged in"
}

# ── Main collector ────────────────────────────────────────────────────────────────
collect_software() {
    echo -e "    ${DIM}→ OS info...${RESET}"       && collect_os_info
    echo -e "    ${DIM}→ Packages...${RESET}"      && collect_packages
    echo -e "    ${DIM}→ Users...${RESET}"         && collect_users
    echo -e "    ${DIM}→ Services...${RESET}"      && collect_services
    echo -e "    ${DIM}→ Processes...${RESET}"     && collect_processes
    echo -e "    ${DIM}→ Ports...${RESET}"         && collect_ports
    echo -e "    ${DIM}→ Security...${RESET}"      && collect_security
    echo -e "    ${DIM}→ Environment...${RESET}"   && collect_environment
}
 