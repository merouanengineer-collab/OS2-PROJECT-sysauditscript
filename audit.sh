#!/usr/bin/env bash
# ============================================================
# audit.sh — SysAudit Main Entry Point
# Interactive menu-driven Linux audit & monitoring system
# Author: MEROUANE BEN BOUCHERIT | Prof: Dr. Bentrad Sassi
#
# Usage:
#   ./audit.sh                    # Interactive menu
#   ./audit.sh --full             # Run full audit silently
#   ./audit.sh --short            # Run short audit silently
#   ./audit.sh --monitor          # Real-time monitor
#   ./audit.sh --remote           # Remote quick status
#   ./audit.sh --verify           # Integrity check
#   ./audit.sh --compare          # Compare latest two reports
#   ./audit.sh --help             # Show usage
# ============================================================

# Individual module functions handle their own errors gracefully
# (pipefail removed: find|head pipelines in modules trigger SIGPIPE with it)

# ── Project root ─────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Load config ──────────────────────────────────────────────────────────────
CONFIG_FILE="$SCRIPT_DIR/config/config.cfg"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: config/config.cfg not found!" >&2
    exit 1
fi
source "$CONFIG_FILE"

# ── Enable debug mode if flag is present anywhere in arguments ───────────────
for arg in "$@"; do
    if [[ "$arg" == "--debug" ]]; then DEBUG_MODE="true"; break; fi
done

# ── Ensure output directory is writable ──────────────────────────────────────
if [[ ! -w "$(dirname "${OUTPUT_DIR}")" ]] && [[ ! -d "${OUTPUT_DIR}" ]]; then
    echo -e "${YELLOW}⚠ Warning: ${OUTPUT_DIR} not writable. Falling back to ~/.sys_audit${RESET}"
    OUTPUT_DIR="${HOME}/sys_audit_reports"
    LOG_FILE="${OUTPUT_DIR}/audit.log"
fi
mkdir -p "${OUTPUT_DIR}" 2>/dev/null
REPORT_DIR="${OUTPUT_DIR}"

# ── Load all modules ─────────────────────────────────────────────────────────
source "$SCRIPT_DIR/modules/lib.sh"
source "$SCRIPT_DIR/modules/hw_audit.sh"
source "$SCRIPT_DIR/modules/sw_audit.sh"
source "$SCRIPT_DIR/modules/report.sh"
source "$SCRIPT_DIR/modules/email.sh"
source "$SCRIPT_DIR/modules/alerts.sh"
source "$SCRIPT_DIR/modules/diff_reports.sh"
source "$SCRIPT_DIR/modules/remote_mon.sh"
source "$SCRIPT_DIR/modules/log_rotate.sh"
source "$SCRIPT_DIR/modules/integrity.sh"

# ════════════════════════════════════════════════════════════
# _run_full_audit — Collect all data + generate all reports
# ════════════════════════════════════════════════════════════
_run_full_audit() {
    local mode="${1:-full}"
    log_info "Starting ${mode} audit on $(hostname)..."

    collect_all_hardware
    collect_all_software
    print_hardware_short
    print_software_short
    generate_all_reports "$mode"
    check_resources
}

# ════════════════════════════════════════════════════════════
# _show_help
# ════════════════════════════════════════════════════════════
_show_help() {
    cat <<HELP
${BOLD}SysAudit v1.0${RESET} — Linux Audit & Monitoring System

${BOLD}Usage:${RESET}
  ./audit.sh [option]

${BOLD}Options:${RESET}
  --full          Run complete audit (hardware + software)
  --short         Run quick summary audit
  --monitor       Start real-time resource monitor
  --remote        Quick status of remote machine (SSH)
  --remote-audit  Full audit on remote machine (SSH)
  --compare       Compare two latest audit reports
  --verify        Verify report integrity (sha256)
  --rotate        Run log rotation
  --stats         Show report archive statistics
  --setup-email   Configure email (msmtp/Gmail)
  --setup-ssh     Configure SSH key for remote access
  --test-email    Test SMTP connection and exit
  --help          Show this help
  --test-ssh      Test SSH connection to remote host
  --debug         Enable verbose debug logging

${BOLD}Examples:${RESET}
  sudo ./audit.sh               # Interactive menu (recommended)
  sudo ./audit.sh --full        # Full audit, generate all reports
  sudo ./audit.sh --monitor     # Watch live resource usage
  sudo ./audit.sh --compare     # Diff the two latest reports

${BOLD}Cron setup:${RESET}
  sudo crontab -e
  Then add: 0 4 * * * ${SCRIPT_DIR}/cron/cron_runner.sh

${BOLD}Reports saved to:${RESET} ${REPORT_DIR}
HELP
}

# ════════════════════════════════════════════════════════════
# _email_menu — Sub-menu for email actions
# ════════════════════════════════════════════════════════════
_email_menu() {
    echo -e "\n${BOLD}Email Options:${RESET}"
    local eopts=("Send latest full report" "Send latest short report"
                 "Send custom report file" "Test SMTP Connection" "Back")
    PS3=$'\n'"$(echo -e "${CYAN}→ Choice: ${RESET}")"
    select ec in "${eopts[@]}"; do
        case "$REPLY" in
            1|2|3|4|5)
                if [[ "$REPLY" -eq 5 ]]; then
                    return
                fi
                if [[ "$REPLY" -eq 4 ]]; then
                    test_smtp_connection
                    return
                fi

                read -rp "Recipient email [Default: $EMAIL_RECIPIENT]: " custom_email
                local target="${custom_email:-$EMAIL_RECIPIENT}"
                local r=""

                case "$REPLY" in
                    1) # Find latest full report (including archive subfolder)
                       r=$(find "${REPORT_DIR}" -maxdepth 3 -name "full_report_*.txt" -printf "%T@ %p\n" | sort -rn | head -1 | cut -d' ' -f2-)
                       log_debug "Email menu: Found full report candidate: '$r'"
                       if [[ -n "$r" && -f "$r" ]]; then
                           send_email "$target" "Full Report" "$r" || log_error "Failed to send Full Report email to $target"
                       else
                           log_error "No full report file found in ${REPORT_DIR} (Check if you ran a full audit)"
                       fi ;;
                    2) # Find latest short report (including archive subfolder)
                       r=$(find "${REPORT_DIR}" -maxdepth 3 -name "short_report_*.txt" -printf "%T@ %p\n" | sort -rn | head -1 | cut -d' ' -f2-)
                       log_debug "Email menu: Found short report candidate: '$r'"
                       if [[ -n "$r" && -f "$r" ]]; then
                           send_email "$target" "Short Report" "$r" || log_error "Failed to send Short Report email to $target"
                       else
                           log_error "No short report file found in ${REPORT_DIR} (Check if you ran a short audit)"
                       fi ;;
                    3) # Custom path
                       read -rp "Enter full path to report file: " custom_path
                       if [[ -f "$custom_path" ]]; then
                           send_email "$target" "Custom Report" "$custom_path" || log_error "Failed to send custom email"
                       else
                           log_error "File not found: $custom_path"
                       fi ;;
                esac
                ;;
            4) return ;;
        esac
        break
    done
}

# ════════════════════════════════════════════════════════════
# _interactive_menu — Select-based menu (bonus feature)
# ════════════════════════════════════════════════════════════
_interactive_menu() {
    print_banner

    echo -e "${BOLD}${WHITE}System:${RESET} $(hostname) | $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME") | Kernel $(uname -r)"
    echo -e "${BOLD}${WHITE}Date:${RESET}   $(date '+%A, %d %B %Y — %H:%M:%S')"
    echo -e "${BOLD}${WHITE}User:${RESET}   $(whoami) (UID=$EUID)\n"

    [[ "$EUID" -ne 0 ]] && \
        echo -e "${YELLOW}⚠ Running without root — some data (dmidecode, firewall) may be limited.${RESET}\n"

    local options=(
        "Full Audit (Hardware + Software) — All Formats"
        "Short Audit (Summary View)"
        "Real-Time Resource Monitor"
        "Check Resource Alerts"
        "Send Report via Email"
        "Remote Quick Status (SSH)"
        "Full Remote Audit (SSH)"
        "Centralize Reports from Multiple Hosts"
        "Setup SSH Keys for Remote Monitoring"
        "Test SSH Connection"
        "Configure Email (msmtp)"
        "Compare Two Reports (Diff)"
        "Verify Report Integrity (sha256)"
        "Log Rotation & Archive Management"
        "Report Archive Statistics"
        "Help"
        "Exit (q)"
    )

    echo -e "${CYAN}${BOLD}Select an action:${RESET}"
    PS3=$'\nEnter number: '

    select choice in "${options[@]}"; do
        case "$REPLY" in
            1)  _run_full_audit "full" ;;
            2)  _run_full_audit "short" ;;
            3)  monitor_loop 3 ;;
            4)  check_resources ;;
            5)  _email_menu ;;
            6)  remote_quick_status ;;
            7)  remote_run_audit ;;
            8)  centralize_reports ;;
            9)  setup_ssh_keys ;;
            10) test_ssh_connection ;;
            11) setup_msmtp_config ;;
            12) select_and_compare ;;
            13) verify_report_integrity ;;
            14) rotate_logs ;;
            15) show_report_stats ;;
            16) _show_help ;;
            17|q|exit) echo -e "${GREEN}Goodbye!${RESET}"; exit 0 ;;
            *)  echo -e "${RED}Invalid choice. Enter 1-17.${RESET}" ;;
        esac

        echo -e "\n${DIM}Press Enter to return to menu...${RESET}"
        read -r
        print_banner
        echo -e "${CYAN}${BOLD}Select an action:${RESET}"
    done
}

# ════════════════════════════════════════════════════════════
# CLI argument parsing
# ════════════════════════════════════════════════════════════
case "${1:-}" in
    --full)         print_banner; _run_full_audit "full" ;;
    --short)        print_banner; _run_full_audit "short" ;;
    --monitor)      print_banner; monitor_loop ;;
    --remote)       print_banner; remote_quick_status ;;
    --remote-audit) print_banner; remote_run_audit ;;
    --compare)      print_banner; compare_latest_two "full" ;;
    --verify)       print_banner; verify_report_integrity ;;
    --rotate)       print_banner; rotate_logs ;;
    --stats)        print_banner; show_report_stats ;;
    --setup-email)  print_banner; setup_msmtp_config ;;
    --test-email)   print_banner; test_smtp_connection ;;
    --setup-ssh)    print_banner; setup_ssh_keys ;;
    --test-ssh)     print_banner; test_ssh_connection ;;
    --help|-h)      _show_help ;;
    "")             _interactive_menu ;;
    *)  echo -e "Unknown option: $1 — Run ./audit.sh --help" >&2; exit 1 ;;
esac