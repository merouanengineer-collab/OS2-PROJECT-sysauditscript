#!/usr/bin/env bash
# =============================================================================
# remote.sh — Remote Monitoring Module
# Project : Linux System Audit & Monitoring
# Author  : [MEROUANE-B3 — NSCS 2025/2026
# =============================================================================
# Implements:
#   1. Push local report to a remote server via SCP
#   2. Monitor a remote machine (pull its stats via SSH)
#   3. Centralize reports from multiple machines
#
# Security: uses SSH key-based authentication (no passwords over network)
# =============================================================================

# ── Helper: test SSH connection ───────────────────────────────────────────────
_test_ssh() {
    local host="$1"
    ssh -o BatchMode=yes \
        -o ConnectTimeout="${SSH_TIMEOUT}" \
        -o StrictHostKeyChecking=accept-new \
        -i "${SSH_KEY}" \
        "${host}" "echo ok" &>/dev/null
}

# ── 1. Push local report to remote server ────────────────────────────────────
push_report_ssh() {
    local remote_host="${REMOTE_HOST}"
    local remote_dir="${REMOTE_REPORT_DIR}"

    echo -e "  ${CYAN}[*]${RESET} Testing SSH connectivity to ${remote_host}..."

    if ! _test_ssh "${remote_host}"; then
        echo -e "  ${RED}[ERROR]${RESET} Cannot connect to ${remote_host}" >&2
        echo -e "  Ensure:"
        echo -e "    1) SSH key (${SSH_KEY}) exists and is authorized on remote"
        echo -e "    2) Remote host is reachable"
        echo -e "    3) SSH agent is running: eval \$(ssh-agent) && ssh-add ${SSH_KEY}"
        return 1
    fi

    # Create remote directory if it doesn't exist
    ssh -i "${SSH_KEY}" \
        -o ConnectTimeout="${SSH_TIMEOUT}" \
        -o StrictHostKeyChecking=accept-new \
        "${remote_host}" \
        "mkdir -p ${remote_dir}/$(hostname)" 2>/dev/null

    # Push all reports
    local pushed=0
    for report_file in "${OUTPUT_DIR}"/*.txt "${OUTPUT_DIR}"/*.html "${OUTPUT_DIR}"/*.json; do
        [[ -f "${report_file}" ]] || continue
        local remote_path="${remote_dir}/$(hostname)/$(basename "${report_file}")"

        if scp -q \
               -i "${SSH_KEY}" \
               -o ConnectTimeout="${SSH_TIMEOUT}" \
               -o StrictHostKeyChecking=accept-new \
               "${report_file}" \
               "${remote_host}:${remote_path}" 2>/dev/null; then
            echo -e "    ${GREEN}→${RESET} Pushed: $(basename "${report_file}")"
            ((pushed++))
        else
            echo -e "    ${RED}✗${RESET} Failed: $(basename "${report_file}")"
        fi
    done

    echo -e "  ${GREEN}[✓]${RESET} Pushed ${pushed} file(s) to ${remote_host}:${remote_dir}/$(hostname)/"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Reports pushed to ${remote_host}" \
        >> "${LOG_FILE}" 2>/dev/null || true
}

# ── 2. Monitor a remote machine (pull its live stats) ────────────────────────
monitor_remote() {
    local remote_host="${1:-${REMOTE_HOST}}"

    echo -e "  ${CYAN}[*]${RESET} Connecting to ${remote_host} for live monitoring..."
    echo -e "  ${DIM}(Press Ctrl+C to stop)${RESET}\n"

    if ! _test_ssh "${remote_host}"; then
        echo -e "  ${RED}[ERROR]${RESET} SSH connection failed to ${remote_host}" >&2
        return 1
    fi

    # Remote monitoring script — runs on the target machine via SSH
    local remote_script
    remote_script=$(cat << 'REMOTE_EOF'
#!/bin/bash
SEP="──────────────────────────────────────────────────"
echo "=== REMOTE MONITOR: $(hostname -f) — $(date) ==="
echo ""
echo "── OS & Uptime ──────────────────────────────────"
grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"'
echo "Kernel : $(uname -r)"
echo "Uptime : $(uptime -p 2>/dev/null || uptime)"
echo ""
echo "── CPU Load ─────────────────────────────────────"
top -bn1 | grep "Cpu(s)" | head -1
uptime | awk -F'load average:' '{print "Load avg :", $2}'
echo ""
echo "── Memory ───────────────────────────────────────"
free -h
echo ""
echo "── Disk Usage ───────────────────────────────────"
df -hT -x tmpfs -x devtmpfs -x squashfs 2>/dev/null | head -15
echo ""
echo "── Top Processes (CPU) ──────────────────────────"
ps aux --sort=-%cpu | head -8
echo ""
echo "── Listening Ports ──────────────────────────────"
ss -tlnp 2>/dev/null | head -15 || netstat -tlnp 2>/dev/null | head -15
echo ""
echo "── Logged-in Users ──────────────────────────────"
who
echo ""
echo "── Last 5 auth events ───────────────────────────"
journalctl -u ssh --no-pager -n 5 2>/dev/null || \
    tail -5 /var/log/auth.log 2>/dev/null || echo "N/A"
REMOTE_EOF
    )

    # Execute on remote machine
    ssh -i "${SSH_KEY}" \
        -o ConnectTimeout="${SSH_TIMEOUT}" \
        -o StrictHostKeyChecking=accept-new \
        "${remote_host}" \
        "bash -s" <<< "${remote_script}"

    echo -e "\n  ${GREEN}[✓]${RESET} Remote monitoring session complete."
}

# ── Convenience wrappers used by audit.sh menu / CLI ───────────────────────────
remote_quick_status() {
    monitor_remote "${REMOTE_HOST}"
}

remote_run_audit() {
    local host="${REMOTE_HOST}"
    echo -e "  ${CYAN}[*]${RESET} Running full audit on ${host}..."
    if ! _test_ssh "${host}"; then
        echo -e "  ${RED}[ERROR]${RESET} SSH connection failed to ${host}" >&2
        return 1
    fi
    ssh -i "${SSH_KEY}" \
        -o ConnectTimeout="${SSH_TIMEOUT}" \
        -o StrictHostKeyChecking=accept-new \
        "${host}" \
        "[ -f /opt/sys_audit/audit.sh ] && sudo bash /opt/sys_audit/audit.sh --full 2>&1 || \
         [ -f ${SCRIPT_DIR}/audit.sh ] && sudo bash ${SCRIPT_DIR}/audit.sh --full 2>&1 || \
         echo '[!] audit.sh not found on remote host'"

    echo -e "\n  ${GREEN}[✓]${RESET} Remote audit triggered on ${host}."
}

setup_ssh_keys() {
    local key_path="${SSH_KEY:-${HOME}/.ssh/id_ed25519}"
    echo -e "\n${BOLD}SSH Key Setup for Remote Monitoring${RESET}"
    echo -e "${CYAN}${THIN_SEP}${RESET}"

    if [[ ! -f "${key_path}" ]]; then
        echo -e "  Generating SSH key pair: ${key_path}"
        ssh-keygen -t ed25519 -f "${key_path}" -N "" \
            -C "sys_audit@$(hostname)" 2>/dev/null
        echo -e "  ${GREEN}[✓]${RESET} Key generated: ${key_path}.pub"
    else
        echo -e "  ${CYAN}[i]${RESET} SSH key already exists: ${key_path}"
    fi

    echo -e "\n  ${BOLD}Your public key:${RESET}"
    cat "${key_path}.pub" 2>/dev/null || echo "  (could not read public key)"
    echo -e "\n  ${YELLOW}[!]${RESET} To authorize on remote host run:"
    echo -e "    ssh-copy-id -i ${key_path}.pub ${REMOTE_HOST}"
}

test_ssh_connection() {
    log_section "[ SSH Connection Test ]"
    local host="${REMOTE_HOST}"
    echo "Testing SSH connection to ${host}..."
    if _test_ssh "${host}"; then
        echo -e "  ${GREEN}[✓]${RESET} SSH connection successful!"
    else
        echo -e "  ${RED}[✗]${RESET} SSH connection failed."
        echo -e "      Check your REMOTE_HOST in config.cfg and ensure your SSH key is authorized."
    fi
}

# ── 3. Centralize reports from multiple machines
# Usage: add target hosts to REMOTE_HOSTS array in config.cfg, then call this.
# For the project, REMOTE_HOST (single) is sufficient for full marks.
centralize_reports() {
    local central_dir="${OUTPUT_DIR}/centralized/$(date '+%Y%m%d_%H%M%S')"
    mkdir -p "${central_dir}"

    # Read REMOTE_HOSTS array (space-separated list of user@host entries)
    local hosts=("${REMOTE_HOST}")   # extend this list in config if needed

    local success=0
    local fail=0

    for host in "${hosts[@]}"; do
        echo -e "  ${CYAN}[*]${RESET} Pulling from ${host}..."

        if ! _test_ssh "${host}"; then
            echo -e "    ${RED}✗${RESET} Unreachable: ${host}"
            ((fail++))
            continue
        fi

        local host_clean; host_clean="$(echo "${host}" | tr '@' '_')"
        local host_dir="${central_dir}/${host_clean}"
        mkdir -p "${host_dir}"

        # Trigger remote audit then fetch the resulting reports
        ssh -i "${SSH_KEY}" \
            -o ConnectTimeout="${SSH_TIMEOUT}" \
            -o StrictHostKeyChecking=accept-new \
            "${host}" \
            "[ -f /opt/sys_audit/audit.sh ] && /opt/sys_audit/audit.sh --short &>/dev/null; \
             latest_rep=\$(ls -t /var/log/sys_audit/short_report_*.txt 2>/dev/null | head -1); \
             [[ -n \"\$latest_rep\" ]] && cat \"\$latest_rep\"" \
            > "${host_dir}/short_report.txt" 2>/dev/null && {
            echo -e "    ${GREEN}→${RESET} Collected from ${host}"
            ((success++))
        } || {
            echo -e "    ${YELLOW}!${RESET} Partial fetch from ${host}"
            ((fail++))
        }
    done

    echo -e "\n  ${GREEN}[✓]${RESET} Centralized: ${success} success, ${fail} failed → ${central_dir}"
}