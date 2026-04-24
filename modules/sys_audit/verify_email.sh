#!/usr/bin/env bash
# =============================================================================
# verify_email.sh — Automated Email Configuration Tester
# Project : Linux System Audit & Monitoring
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config/config.cfg"
source "${SCRIPT_DIR}/modules/lib.sh"
source "${SCRIPT_DIR}/modules/email.sh"

echo "[*] Checking email configuration for ${EMAIL_FROM}..."

# 1. Check for msmtprc in multiple locations
MSMTPRC_PATH=""
if [[ -f ~/.msmtprc ]]; then
    MSMTPRC_PATH=~/.msmtprc
    echo "  [✓] Found msmtprc at: ~/.msmtprc"
elif [[ -f "${SCRIPT_DIR}/config/.msmtprc" ]]; then
    MSMTPRC_PATH="${SCRIPT_DIR}/config/.msmtprc"
    echo "  [✓] Found msmtprc at: ${SCRIPT_DIR}/config/.msmtprc"
    echo "  [INFO] Recommended: Copy to ~/.msmtprc for system-wide use"
    echo "         Run: cp ${SCRIPT_DIR}/config/.msmtprc ~/.msmtprc && chmod 600 ~/.msmtprc"
elif [[ -f /etc/msmtprc ]]; then
    MSMTPRC_PATH=/etc/msmtprc
    echo "  [✓] Found msmtprc at: /etc/msmtprc"
else
    echo "  [FAIL] msmtprc not found in any location:"
    echo "         - ~/.msmtprc"
    echo "         - ${SCRIPT_DIR}/config/.msmtprc"
    echo "         - /etc/msmtprc"
    echo "  [ACTION] Copy from config folder:"
    echo "           cp ${SCRIPT_DIR}/config/.msmtprc ~/.msmtprc && chmod 600 ~/.msmtprc"
    exit 1
fi

# 2. Check permissions
PERM=$(stat -c "%a" "$MSMTPRC_PATH")
if [[ "$PERM" != "600" ]] && [[ "$MSMTPRC_PATH" != "/etc/msmtprc" ]]; then
    echo "  [WARNING] Incorrect permissions on $MSMTPRC_PATH (Current: $PERM, Required: 600)."
    echo "            Run: chmod 600 $MSMTPRC_PATH"
    if [[ "$MSMTPRC_PATH" == ~/.msmtprc ]]; then
        echo "  [!] Attempting to fix permissions..."
        chmod 600 "$MSMTPRC_PATH" && echo "  [✓] Permissions fixed!" || echo "  [FAIL] Could not fix permissions."
    fi
else
    echo "  [✓] Permissions correct: $PERM"
fi

# 3. Test send
echo "[*] Sending automated test email to ${EMAIL_RECIPIENT}..."
MSMTP_CMD="msmtp"
if [[ "$MSMTPRC_PATH" != "/etc/msmtprc" ]]; then
    MSMTP_CMD="msmtp -C $MSMTPRC_PATH"
fi

{
    echo "To: ${EMAIL_RECIPIENT}"
    echo "Subject: [SYS-AUDIT] Email Configuration Test"
    echo "From: ${EMAIL_FROM}"
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║          ✅ EMAIL CONFIGURATION TEST                   ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "Dear Administrator,"
    echo ""
    echo "This is an automated test email from your SysAudit system."
    echo "If you are reading this, your email configuration is working"
    echo "correctly and the system can send audit reports."
    echo ""
    echo "╭────────────────────────────────────────────────────────────╮"
    echo "│  CONFIGURATION DETAILS                                    │"
    echo "╰────────────────────────────────────────────────────────────╯"
    echo "  • Config File     : $MSMTPRC_PATH"
    echo "  • Sender Email    : ${EMAIL_FROM}"
    echo "  • Recipient Email : ${EMAIL_RECIPIENT}"
    echo "  • Test Timestamp  : $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "  • Hostname        : $(hostname)"
    echo ""
    echo "────────────────────────────────────────────────────────────"
    echo "System Audit Tool — ${REPORT_INSTITUTION:-NSCS}"
    echo "────────────────────────────────────────────────────────────"
} | $MSMTP_CMD -a gmail -t 2>/dev/null

if [ $? -eq 0 ]; then
    echo "  [SUCCESS] ✓ Email sent successfully to ${EMAIL_RECIPIENT}!"
    echo "  [INFO] Check your inbox to confirm receipt."
    exit 0
else
    echo "  [FAIL] ✗ msmtp failed to send email."
    echo "  [DEBUG] Checking log file..."
    if [[ -f ~/.msmtp.log ]]; then
        echo "  [LOG] Last 5 lines from ~/.msmtp.log:"
        tail -5 ~/.msmtp.log | sed 's/^/         /'
    else
        echo "  [INFO] No log file found at ~/.msmtp.log"
    fi
    echo ""
    echo "  [TROUBLESHOOTING]"
    echo "    1. Verify your Gmail App Password is correct in $MSMTPRC_PATH"
    echo "    2. Ensure 2-Step Verification is enabled on your Google Account"
    echo "    3. Generate a new App Password at: https://myaccount.google.com/apppasswords"
    echo "    4. Check internet connectivity: ping -c 3 smtp.gmail.com"
    exit 1
fi
