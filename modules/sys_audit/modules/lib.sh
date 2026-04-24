#!/usr/bin/env bash
# =============================================================================
# lib.sh — Shared Library: Colors, Logging, Banner
# Project : Linux System Audit & Monitoring
# Author  : [MEROUANE BEN BOUCHERIT] — NSCS 2025/2026
# =============================================================================

# ── ANSI Color / Formatting Codes ─────────────────────────────────────────────
if [[ -t 1 ]]; then
    RESET="\033[0m"
    BOLD="\033[1m"
    DIM="\033[2m"
    RED="\033[0;31m"
    GREEN="\033[0;32m"
    YELLOW="\033[0;33m"
    BLUE="\033[0;34m"
    CYAN="\033[0;36m"
    WHITE="\033[1;37m"
    MAGENTA="\033[0;35m"
else
    RESET="" BOLD="" DIM="" RED="" GREEN="" YELLOW=""
    BLUE="" CYAN="" WHITE="" MAGENTA=""
fi

THIN_SEP="────────────────────────────────────────────────────────────────────"
THICK_SEP="════════════════════════════════════════════════════════════════════"

# ── Logging ───────────────────────────────────────────────────────────────────
log_info() {
    local ts; ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${GREEN}[INFO]${RESET}  $*"
    echo "[${ts}] [INFO]  $*" >> "${LOG_FILE:-/tmp/sys_audit/audit.log}" 2>/dev/null || true
}

log_warn() {
    local ts; ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${YELLOW}[WARN]${RESET}  $*"
    echo "[${ts}] [WARN]  $*" >> "${LOG_FILE:-/tmp/sys_audit/audit.log}" 2>/dev/null || true
}

log_error() {
    local ts; ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${RED}[ERROR]${RESET} $*" >&2
    echo "[${ts}] [ERROR] $*" >> "${LOG_FILE:-/tmp/sys_audit/audit.log}" 2>/dev/null || true
}

log_debug() {
    if [[ "${DEBUG_MODE:-false}" != "true" ]]; then return; fi

    local ts; ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${DIM}[DEBUG]${RESET} $*" >&2
    echo "[${ts}] [DEBUG] $*" >> "${LOG_FILE:-/tmp/sys_audit/audit.log}" 2>/dev/null || true
}

log_debug_multiline() {
    if [[ "${DEBUG_MODE:-false}" != "true" ]]; then cat > /dev/null; return; fi

    local ts; ts="$(date '+%Y-%m-%d %H:%M:%S')"
    while IFS= read -r line; do
        echo -e "${DIM}[DEBUG]${RESET} $line" >&2
        echo "[${ts}] [DEBUG] $line" >> "${LOG_FILE:-/tmp/sys_audit/audit.log}" 2>/dev/null || true
    done
}


show_progress() {
    local current="$1"
    local total="$2"
    local width=40
    local percent=$(( current * 100 / total ))
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))
    printf "\r${CYAN}${BOLD}[${RESET}"
    for ((i=0; i<filled; i++)); do printf "█"; done
    for ((i=0; i<empty; i++)); do printf "░"; done
    printf "${CYAN}${BOLD}]${RESET} %3d%% Complete" "$percent"
}

# ── Banner ────────────────────────────────────────────────────────────────────
print_banner() {
    clear 2>/dev/null || true
    echo -e "${CYAN}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════════════════╗"
    echo "  ║          SYS-AUDIT v1.0 — Linux Audit & Monitoring           ║"
    echo "  ║student dev : MEROUANE BEN BOUCHERIT | Prof: Dr. Bentrad Sassi║"
    echo "  ╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}
