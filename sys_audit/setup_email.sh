#!/usr/bin/env bash
# =============================================================================
# setup_email.sh — Email Configuration Setup Helper
# Project : Linux System Audit & Monitoring
# Author  : Merouane Ben Boucherit — NSCS 2025/2026
# =============================================================================
# This script helps you set up msmtp for email notifications
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_MSMTPRC="${SCRIPT_DIR}/config/.msmtprc"
HOME_MSMTPRC="${HOME}/.msmtprc"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║     📧 SYS-AUDIT EMAIL CONFIGURATION SETUP            ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Step 1: Check if msmtp is installed
echo -e "${CYAN}[1/5]${RESET} Checking for msmtp..."
if command -v msmtp &>/dev/null; then
    echo -e "  ${GREEN}[✓]${RESET} msmtp is installed: $(command -v msmtp)"
    echo -e "      Version: $(msmtp --version | head -1)"
else
    echo -e "  ${RED}[✗]${RESET} msmtp is not installed!"
    echo -e "  ${YELLOW}[ACTION]${RESET} Installing msmtp..."
    if command -v apt &>/dev/null; then
        sudo apt update && sudo apt install -y msmtp msmtp-mta ca-certificates
        echo -e "  ${GREEN}[✓]${RESET} msmtp installed successfully!"
    elif command -v yum &>/dev/null; then
        sudo yum install -y msmtp ca-certificates
        echo -e "  ${GREEN}[✓]${RESET} msmtp installed successfully!"
    else
        echo -e "  ${RED}[ERROR]${RESET} Could not install msmtp automatically."
        echo -e "           Please install manually: sudo apt install msmtp msmtp-mta"
        exit 1
    fi
fi
echo ""

# Step 2: Copy configuration file
echo -e "${CYAN}[2/5]${RESET} Setting up configuration file..."
if [[ -f "$HOME_MSMTPRC" ]]; then
    echo -e "  ${YELLOW}[!]${RESET} $HOME_MSMTPRC already exists."
    echo -n "      Do you want to overwrite it? (y/N): "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        cp "$CONFIG_MSMTPRC" "$HOME_MSMTPRC"
        echo -e "  ${GREEN}[✓]${RESET} Configuration file updated!"
    else
        echo -e "  ${BLUE}[INFO]${RESET} Keeping existing configuration."
    fi
else
    cp "$CONFIG_MSMTPRC" "$HOME_MSMTPRC"
    echo -e "  ${GREEN}[✓]${RESET} Configuration file copied to: $HOME_MSMTPRC"
fi
echo ""

# Step 3: Set permissions
echo -e "${CYAN}[3/5]${RESET} Setting correct permissions..."
chmod 600 "$HOME_MSMTPRC"
PERM=$(stat -c "%a" "$HOME_MSMTPRC")
if [[ "$PERM" == "600" ]]; then
    echo -e "  ${GREEN}[✓]${RESET} Permissions set correctly: $PERM"
else
    echo -e "  ${RED}[✗]${RESET} Warning: Permissions are $PERM (should be 600)"
fi
echo ""

# Step 4: Verify configuration
echo -e "${CYAN}[4/5]${RESET} Verifying configuration..."
echo -e "  ${BLUE}[INFO]${RESET} Current email configuration:"
grep "^from" "$HOME_MSMTPRC" | sed 's/^/      /' || echo "      (not configured)"
grep "^user" "$HOME_MSMTPRC" | sed 's/^/      /' || echo "      (not configured)"
echo ""
echo -e "  ${YELLOW}[IMPORTANT]${RESET} Make sure you have:"
echo -e "      1. Enabled 2-Step Verification on your Google Account"
echo -e "      2. Generated a 16-character App Password"
echo -e "      3. Updated the password in: $HOME_MSMTPRC"
echo ""
echo -e "  ${BLUE}[LINK]${RESET} Generate App Password at:"
echo -e "      ${CYAN}https://myaccount.google.com/apppasswords${RESET}"
echo ""

# Step 5: Test connection
echo -e "${CYAN}[5/5]${RESET} Testing email connection..."
echo -n "      Do you want to send a test email now? (Y/n): "
read -r test_response
if [[ ! "$test_response" =~ ^[Nn]$ ]]; then
    echo -e "  ${BLUE}[INFO]${RESET} Running email verification test..."
    if bash "${SCRIPT_DIR}/verify_email.sh"; then
        echo ""
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${GREEN}║          ✅ EMAIL SETUP COMPLETE!                      ║${RESET}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${RESET}"
        echo -e "  Your SysAudit system is now configured to send emails!"
        echo -e "  Check your inbox for the test email."
    else
        echo ""
        echo -e "${YELLOW}╔══════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${YELLOW}║          ⚠️  EMAIL TEST FAILED                         ║${RESET}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════════════╝${RESET}"
        echo -e ""
        echo -e "${YELLOW}[TROUBLESHOOTING STEPS]${RESET}"
        echo -e "  1. Verify your App Password in: $HOME_MSMTPRC"
        echo -e "  2. Check the log file: ~/.msmtp.log"
        echo -e "  3. Ensure your email is correct in: ${SCRIPT_DIR}/config/config.cfg"
        echo -e "  4. Test connectivity: ping -c 3 smtp.gmail.com"
        echo -e "  5. Re-generate App Password if needed"
    fi
else
    echo -e "  ${BLUE}[INFO]${RESET} Skipping test. You can run it later with:"
    echo -e "      ${CYAN}bash ${SCRIPT_DIR}/verify_email.sh${RESET}"
fi

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
echo -e "  For more help, see: ${CYAN}${SCRIPT_DIR}/README.md${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
