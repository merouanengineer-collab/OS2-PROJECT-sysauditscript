#!/usr/bin/env bash
# =============================================================================
# email.sh — Email Transmission Module
# Project : Linux System Audit & Monitoring
# Author  : Merouane Ben Boucherit — NSCS 2025/2026
# =============================================================================
# Sends audit reports via msmtp (SMTP client).
# Configuration: /etc/msmtprc or ~/.msmtprc (see README for setup guide)
#
# Functions:
#   send_report_email(recipient, report_type)
#   send_alert_email(subject, body)
# =============================================================================

# ── Check for mail sending tool ───────────────────────────────────────────────
_get_mailer() {
    if command -v msmtp &>/dev/null; then
        echo "msmtp"
    elif command -v sendmail &>/dev/null; then
        echo "sendmail"
    elif command -v mail &>/dev/null; then
        echo "mail"
    else
        echo ""
    fi
}

# ── Core email sender (msmtp-based) ──────────────────────────────────────────
_send_mail() {
    local to="$1"
    local subject="$2"
    local body="$3"
    shift 3                             # All remaining arguments are attachments
    local attachments=("$@")
    local mailer; mailer="$(_get_mailer)"

    if [[ -z "${mailer}" ]]; then
        echo -e "  ${RED}[ERROR]${RESET} No mail client found. Install msmtp: sudo apt install msmtp" >&2
        return 1
    fi

    local msmtp_cfg=""
    # Pre-flight check for msmtp configuration
    if [[ "${mailer}" == "msmtp" ]]; then
        # Priority 1: Project config directory (Most reliable for sudo/root)
        if [[ -f "${SCRIPT_DIR}/config/.msmtprc" ]]; then
            msmtp_cfg="-C ${SCRIPT_DIR}/config/.msmtprc"
        # Priority 2: Current user's home directory
        elif [[ -f "${HOME}/.msmtprc" ]]; then
            msmtp_cfg="-C ${HOME}/.msmtprc"
        # Priority 3: Original user's home (if running via sudo)
        elif [[ -n "${SUDO_USER:-}" ]] && [[ -f "/home/${SUDO_USER}/.msmtprc" ]]; then
            msmtp_cfg="-C /home/${SUDO_USER}/.msmtprc"
        # Priority 4: System-wide config
        elif [[ -f "/etc/msmtprc" ]]; then
            msmtp_cfg=""  # Use default system config
        else
        
            log_error "msmtp configuration not found. Checked:"
            log_error "  - ${HOME}/.msmtprc"
            log_error "  - ${SCRIPT_DIR}/config/.msmtprc"
            log_error "  - /etc/msmtprc"
            return 1
        fi
    fi

    # Pre-verify attachments to avoid malformed MIME structures
    local valid_attachments=()
    for att in "${attachments[@]}"; do
        [[ -n "$att" && -f "$att" ]] && valid_attachments+=("$att")
    done
    local has_attachments=${#valid_attachments[@]}

    case "${mailer}" in
        msmtp)
            # Build MIME message manually for attachment support
            local boundary="BOUNDARY_$(date +%s)"
            {
                echo "From: ${EMAIL_FROM}"
                echo "To: ${to}"
                echo "Subject: ${EMAIL_SUBJECT_PREFIX} ${subject}"
                echo "MIME-Version: 1.0"
                if [[ $has_attachments -gt 0 ]]; then
                    echo "Content-Type: multipart/mixed; boundary=\"${boundary}\""
                    echo
                    echo "--${boundary}"
                    echo "Content-Type: text/plain; charset=utf-8"
                    echo "Content-Transfer-Encoding: 7bit"
                    echo
                    echo "${body}"
                    echo
                    for attachment in "${valid_attachments[@]}"; do
                        local filename=$(basename "${attachment}")
                        local mimetype="application/octet-stream"
                        [[ "${filename}" == *.pdf ]] && mimetype="application/pdf"
                        [[ "${filename}" == *.txt ]] && mimetype="text/plain"
                        
                        echo "--${boundary}"
                        echo "Content-Type: ${mimetype}; name=\"${filename}\""
                        echo "Content-Transfer-Encoding: base64"
                        echo "Content-Disposition: attachment; filename=\"${filename}\""
                        echo
                        base64 "${attachment}"
                        echo
                    done
                    echo "--${boundary}--"
                else
                    echo "Content-Type: text/plain; charset=utf-8"
                    echo
                    echo "${body}"
                fi
            } | msmtp ${msmtp_cfg} -a gmail -t
            ;;

        sendmail)
            {
                echo "To: ${to}"
                echo "Subject: ${EMAIL_SUBJECT_PREFIX} ${subject}"
                echo
                echo "${body}"
                for att in "${valid_attachments[@]}"; do
                    cat "$att"
                done
            } | sendmail -t
            ;;

        mail)
            local mail_args=("-s" "${EMAIL_SUBJECT_PREFIX} ${subject}")
            for att in "${valid_attachments[@]}"; do
                mail_args+=("-a" "$att")
            done
            echo "${body}" | mail "${mail_args[@]}" "${to}"
            ;;
    esac
}

# ── Send audit report via email ───────────────────────────────────────────────
send_report_email() {
    local recipient="${1:-${EMAIL_RECIPIENT}}"
    local report_type="${2:-${DEFAULT_REPORT_TYPE}}"   # short | full

    # Select the right report file
    local primary_report_file=""
    local timestamp_from_report=""

    # First, find the latest text report of the requested type to get its timestamp
    local latest_txt_report=""
    if [[ "${report_type}" == "full" ]]; then
        latest_txt_report=$(find "${OUTPUT_DIR}" -maxdepth 3 -name "full_report_*.txt" -printf "%T@ %p\n" | sort -rn | head -1 | cut -d' ' -f2-)
    else # short or default
        latest_txt_report=$(find "${OUTPUT_DIR}" -maxdepth 3 -name "short_report_*.txt" -printf "%T@ %p\n" | sort -rn | head -1 | cut -d' ' -f2-)
    fi

    if [[ -n "${latest_txt_report}" ]]; then
        # Extract timestamp from filename (e.g., full_report_YYYYMMDD_HHMMSS.txt)
        timestamp_from_report=$(basename "${latest_txt_report}" | grep -oE '[0-9]{8}_[0-9]{6}')
        local report_dir=$(dirname "${latest_txt_report}")
        local pdf_candidate=""
        [[ -n "${timestamp_from_report}" ]] && pdf_candidate="${report_dir}/report_${timestamp_from_report}.pdf"
        if [[ -f "${pdf_candidate}" ]]; then
            primary_report_file="${pdf_candidate}" # Prefer PDF if it exists for this timestamp
        else
            primary_report_file="${latest_txt_report}" # Fallback to text report
        fi
    fi

    local report_file="${primary_report_file}"
    local attachment_list=()
    [[ -f "${latest_txt_report}" ]] && attachment_list+=("${latest_txt_report}")
    
    if [[ -n "${latest_txt_report}" && -n "${timestamp_from_report}" ]]; then
        # If the primary isn't the PDF but a PDF exists, add it to the list
        local actual_pdf="$(dirname "${latest_txt_report}")/report_${timestamp_from_report}.pdf"
        [[ -f "${actual_pdf}" && "${actual_pdf}" != "${latest_txt_report}" ]] && attachment_list+=("${actual_pdf}")
    fi

    local subject="${report_type^^} Audit Report — ${REPORT_HOSTNAME} — $(date '+%Y-%m-%d')"
    local cpu_usage="${HW_DATA[cpu_usage]:-0}"
    local ram_usage="${HW_DATA[ram_usage_pct]:-0}"

    local body
    body="$(cat << EOF
╔══════════════════════════════════════════════════════════╗
║          🛡️  SYSTEM AUDIT REPORT — OFFICIAL           ║
╚══════════════════════════════════════════════════════════╝

Dear System Administrator,

This is an automated notification regarding the completion of a 
comprehensive system audit on your infrastructure.

╭────────────────────────────────────────────────────────────╮
│  � AUDIT INFORMATION                                     │
╰────────────────────────────────────────────────────────────╯
  • Report Type     : ${report_type^^} Audit Report
  • System Hostname : ${REPORT_HOSTNAME}
  • Generated On    : ${REPORT_DATE}
  • Report Format   : $(basename "${report_file}")
  • Author          : ${REPORT_AUTHOR}

╭────────────────────────────────────────────────────────────╮
│  ⚡ CURRENT SYSTEM STATUS                                 │
╰────────────────────────────────────────────────────────────╯
  • CPU Load        : ${cpu_usage}%
  • Memory Usage    : ${ram_usage}%
  • System Uptime   : ${SW_DATA[uptime]:-N/A}
  • Operating System: ${SW_DATA[os_name]:-N/A}
  • Kernel Version  : ${SW_DATA[kernel_version]:-N/A}

╭────────────────────────────────────────────────────────────╮
│  📎 ATTACHED DOCUMENTS                                    │
╰────────────────────────────────────────────────────────────╯
  The complete system audit report is attached in $(if [[ "${report_file}" == *.pdf ]]; then echo "PDF format"; else echo "text format"; fi).
  This document contains detailed hardware inventory, software 
  configuration, security assessment, and performance metrics.

╭────────────────────────────────────────────────────────────╮
│  ⚠️  ACTION REQUIRED                                      │
╰────────────────────────────────────────────────────────────╯
  Please review the attached report for:
  • Security vulnerabilities and failed services
  • Resource utilization and performance bottlenecks
  • System configuration compliance
  • Recommendations for system optimization

────────────────────────────────────────────────────────────
This is an automated report generated by sys_audit
${REPORT_INSTITUTION}
${REPORT_COURSE}

For technical support or questions, please contact the 
system administration team.
────────────────────────────────────────────────────────────
EOF
)"

    echo -e "  ${CYAN}[*]${RESET} Sending ${report_type} report to ${recipient}..."
    if _send_mail "${recipient}" "${subject}" "${body}" "${attachment_list[@]}"; then
        echo -e "  ${GREEN}[✓]${RESET} Email sent successfully to ${recipient}"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Email sent to ${recipient} (${report_type})" \
            >> "${LOG_FILE}" 2>/dev/null || true
    else
        echo -e "  ${RED}[✗]${RESET} Email failed. Check msmtp config (see README)."
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] Email failed to ${recipient}" \
            >> "${LOG_FILE}" 2>/dev/null || true
        return 1
    fi
}

# ── Generic send_email wrapper (called from _email_menu in audit.sh) ───────────────
send_email() {
    local recipient="${1:-${EMAIL_RECIPIENT}}"
    local subject="${2:-Audit Report}"
    local file="${3:-}"
    local attachment_list=()
    [[ -f "${file}" ]] && attachment_list+=("${file}")

    # If a text report is provided, check for a corresponding PDF
    if [[ -n "${file}" && "${file}" == *.txt ]]; then
        # Extract timestamp from the text filename (e.g., full_report_YYYYMMDD_HHMMSS.txt)
        local timestamp_from_filename=$(basename "${file}" | grep -oE '[0-9]{8}_[0-9]{6}')
        local report_dir=$(dirname "${file}")
        local pdf_candidate=""
        [[ -n "${timestamp_from_filename}" ]] && pdf_candidate="${report_dir}/report_${timestamp_from_filename}.pdf"

        if [[ -f "${pdf_candidate}" ]]; then
            attachment_list+=("${pdf_candidate}")
        fi
    fi

    local body
    body="$(cat << EOF
╔══════════════════════════════════════════════════════════╗
║          🛡️  SYSTEM AUDIT REPORT — MANUAL SHARE       ║
╚══════════════════════════════════════════════════════════╝

Dear Recipient,

A system audit report has been manually shared with you for 
review and analysis.

╭────────────────────────────────────────────────────────────╮
│  📂 REPORT DETAILS                                        │
╰────────────────────────────────────────────────────────────╯
  • Source Hostname : $(hostname)
  • Shared On       : $(date '+%Y-%m-%d %H:%M:%S')
  • Document Name   : $(basename "${file}")
  • File Format     : $(if [[ "${file}" == *.pdf ]]; then echo "PDF (Portable Document Format)"; elif [[ "${file}" == *.txt ]]; then echo "Plain Text"; else echo "$(basename "${file}" | sed 's/.*\.//')"; fi)

╭────────────────────────────────────────────────────────────╮
│  📎 ATTACHED DOCUMENTS                                    │
╰────────────────────────────────────────────────────────────╯
  The complete system audit report is attached to this email.
  Please review the document for comprehensive system analysis,
  including hardware inventory, software configuration, and
  security assessment.

────────────────────────────────────────────────────────────
This report was generated by sys_audit
${REPORT_INSTITUTION:-National School of Cyber Security}
${REPORT_COURSE:-OS2 — Operating Systems 2}

For questions regarding this report, please contact the
system administrator who shared it with you.
────────────────────────────────────────────────────────────
EOF
)"
    _send_mail "${recipient}" "${subject}" "${body}" "${attachment_list[@]}"
}

# ── Interactive msmtp setup guide ───────────────────────────────────────────────
setup_msmtp_config() {
    echo -e "\n${BOLD}Email Configuration (msmtp / Gmail)${RESET}"
    echo -e "${CYAN}${THIN_SEP}${RESET}"

    if ! command -v msmtp &>/dev/null; then
        echo -e "  ${YELLOW}[!]${RESET} msmtp is not installed."
        echo -e "      Install with: sudo apt install msmtp msmtp-mta"
    else
        echo -e "  ${GREEN}[✓]${RESET} msmtp is installed: $(command -v msmtp)"
    fi

    echo -e "\n  ${BOLD}Current settings (config.cfg):${RESET}"
    echo -e "    Recipient : ${EMAIL_RECIPIENT}"
    echo -e "    From      : ${EMAIL_FROM}"
    echo -e "    Prefix    : ${EMAIL_SUBJECT_PREFIX}"

    echo -e "\n  ${BOLD}Recommended /etc/msmtprc for System-wide use:${RESET}"
    cat <<'MSMTP'
  defaults
    auth           on
    tls            on
    tls_trust_file /etc/ssl/certs/ca-certificates.crt
    logfile        ~/.msmtp.log

  account gmail
    host     smtp.gmail.com
    port     587
    from     merouanengineer@gmail.com
    user     merouanengineer@gmail.com
    password YOUR_16_CHARACTER_GMAIL_APP_PASSWORD
    # Note: Generate at https://myaccount.google.com/apppasswords

  account default : gmail
MSMTP
    echo -e "  ${YELLOW}[!]${RESET} Instructions:"
    echo -e "    1. Use a 16-character Gmail App Password (NOT your login password)."
    echo -e "    2. If using /etc/msmtprc, run: ${CYAN}sudo chmod 644 /etc/msmtprc${RESET}"
    echo -e "    3. If using ~/.msmtprc, run: ${CYAN}chmod 600 ~/.msmtprc${RESET}"
    echo -e "    - When prompted for 'App name', use 'SysAudit'."
    echo -e "    4. Link: ${CYAN}https://myaccount.google.com/apppasswords${RESET}"
    echo -e "\n  ${YELLOW}Note:${RESET} If 'App Passwords' is missing:"
    echo -e "    - Ensure ${BOLD}2-Step Verification${RESET} is enabled first."
    echo -e "    - Use the search bar in your Google Account for 'App Passwords'."
}

test_smtp_connection() {
    log_section "[ SMTP Connection Test ]"
    local target="${EMAIL_RECIPIENT}"
    echo "Testing connection to Gmail..."
    {
        echo "To: ${target}"
        echo "Subject: SysAudit SMTP Test"
        echo
        echo "This is a test email to verify your SysAudit configuration."
        echo "If you received this, your App Password and SMTP settings are correct."
    } | {
        if [[ -f "${HOME}/.msmtprc" ]]; then
            msmtp -C "${HOME}/.msmtprc" -a gmail -t
        else
            msmtp -a gmail -t
        fi
    } \
        && echo -e "  ${GREEN}[✓]${RESET} Connection successful! Check your inbox." \
        || { echo -e "  ${RED}[✗]${RESET} Connection failed."; 
             echo -e "  ${YELLOW}Tip:${RESET} Ensure you are using a 16-char App Password and ~/.msmtprc has 'chmod 600' permissions."; }
}

# ── Send alert email (used by alerts.sh) ───────────────────────────────────────────
send_alert_email() {
    local subject="$1"
    local body="${2:-Alert triggered}"
    _send_mail "${ALERT_EMAIL}" "${subject}" "${body}"
}
