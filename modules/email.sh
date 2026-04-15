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
    local attachment="${4:-}"           # optional attachment path
    local mailer; mailer="$(_get_mailer)"

    if [[ -z "${mailer}" ]]; then
        echo -e "  ${RED}[ERROR]${RESET} No mail client found. Install msmtp: sudo apt install msmtp" >&2
        return 1
    fi

    local msmtp_cfg=""
    # Pre-flight check for msmtp configuration
    if [[ "${mailer}" == "msmtp" ]]; then
        if [[ -f "${HOME}/.msmtprc" ]]; then
            msmtp_cfg="-C ${HOME}/.msmtprc"
        elif [[ ! -f "/etc/msmtprc" ]]; then
            log_error "msmtp configuration not found in ${HOME}/.msmtprc or /etc/msmtprc"
            return 1
        fi
    fi

    case "${mailer}" in
        msmtp)
            # Build MIME message manually for attachment support
            local boundary="BOUNDARY_$(date +%s)"
            {
                echo "From: ${EMAIL_FROM}"
                echo "To: ${to}"
                echo "Subject: ${EMAIL_SUBJECT_PREFIX} ${subject}"
                echo "MIME-Version: 1.0"
                if [[ -n "${attachment}" && -f "${attachment}" ]]; then
                    echo "Content-Type: multipart/mixed; boundary=\"${boundary}\""
                    echo
                    echo "--${boundary}"
                    echo "Content-Type: text/plain; charset=utf-8"
                    echo
                    echo "${body}"
                    echo
                    echo "--${boundary}"
                    echo "Content-Type: text/plain; name=\"$(basename "${attachment}")\""
                    echo "Content-Disposition: attachment; filename=\"$(basename "${attachment}")\""
                    echo
                    cat "${attachment}"
                    echo
                    echo "--${boundary}--"
                else
                    echo "Content-Type: text/plain; charset=utf-8"
                    echo
                    echo "${body}"
                fi
            } | msmtp ${msmtp_cfg} -t
            ;;

        sendmail)
            {
                echo "To: ${to}"
                echo "Subject: ${EMAIL_SUBJECT_PREFIX} ${subject}"
                echo
                echo "${body}"
                [[ -n "${attachment}" && -f "${attachment}" ]] && cat "${attachment}"
            } | sendmail -t
            ;;

        mail)
            if [[ -n "${attachment}" && -f "${attachment}" ]]; then
                echo "${body}" | mail -s "${EMAIL_SUBJECT_PREFIX} ${subject}" \
                    -a "${attachment}" "${to}"
            else
                echo "${body}" | mail -s "${EMAIL_SUBJECT_PREFIX} ${subject}" "${to}"
            fi
            ;;
    esac
}

# ── Send audit report via email ───────────────────────────────────────────────
send_report_email() {
    local recipient="${1:-${EMAIL_RECIPIENT}}"
    local report_type="${2:-${DEFAULT_REPORT_TYPE}}"   # short | full

    # Select the right report file
    local report_file
    case "${report_type}" in
        full)    report_file=$(find "${OUTPUT_DIR}" -maxdepth 3 -name "full_report_*.txt" -printf "%T@ %p\n" | sort -rn | head -1 | cut -d' ' -f2-)
                 log_debug "Email module: Found full report candidate: '$report_file'" ;;
        short|*) report_file=$(find "${OUTPUT_DIR}" -maxdepth 3 -name "short_report_*.txt" -printf "%T@ %p\n" | sort -rn | head -1 | cut -d' ' -f2-)
                 log_debug "Email module: Found short report candidate: '$report_file'" ;;
    esac

    if [[ ! -f "${report_file}" ]]; then
        echo -e "  ${RED}[ERROR]${RESET} Report file not found: ${report_file}" >&2
        echo -e "  Run the audit first."
        return 1
    fi

    local subject="${report_type^^} Audit Report — ${REPORT_HOSTNAME} — $(date '+%Y-%m-%d')"
    local body
    body="$(cat << EOF
SYS-AUDIT Automated Report
===========================
Host      : ${REPORT_HOSTNAME}
Date      : ${REPORT_DATE}
Report    : ${report_type} audit
Institution: ${REPORT_INSTITUTION}

Please find the ${report_type} audit report attached.
Generated by sys_audit — ${REPORT_COURSE}
EOF
)"

    echo -e "  ${CYAN}[*]${RESET} Sending ${report_type} report to ${recipient}..."
    if _send_mail "${recipient}" "${subject}" "${body}" "${report_file}"; then
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
    local body="SYS-AUDIT report from $(hostname) generated $(date '+%Y-%m-%d %H:%M')"
    _send_mail "${recipient}" "${subject}" "${body}" "${file}"
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
