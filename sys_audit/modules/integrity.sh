#!/usr/bin/env bash
# =============================================================================
# integrity.sh — Report Integrity Verification
# Project : Linux System Audit & Monitoring
# Author  : [MEROUANE BEN BOUCHERIT] — NSCS 2025/2026
# =============================================================================

# ═══════════════════════════════════════════════════════════════════
# verify_report_integrity — Check sha256 hashes of all report files
# ═══════════════════════════════════════════════════════════════════
verify_report_integrity() {
    local report_dir="${REPORT_DIR:-${OUTPUT_DIR:-/tmp/sys_audit}}"
    log_section "[ Report Integrity Verification ]"
    local pass=0 fail=0

    local hash_files=0
    while IFS= read -r hashfile; do
        (( hash_files++ )) || true
        local report_file="${hashfile%.sha256}"
        if [[ -f "${report_file}" ]]; then
            if sha256sum -c "${hashfile}" &>/dev/null; then
                echo -e "  ${GREEN}✔${RESET} $(basename "${report_file}")"
                (( pass++ )) || true
            else
                echo -e "  ${RED}✘ TAMPERED${RESET} $(basename "${report_file}")"
                (( fail++ )) || true
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] INTEGRITY FAIL: ${report_file}" \
                    >> "${LOG_FILE:-${report_dir}/audit.log}" 2>/dev/null || true
            fi
        fi
    done < <(find "${report_dir}" -name '*.sha256' 2>/dev/null)

    if [[ "${hash_files}" -eq 0 ]]; then
        echo -e "  ${YELLOW}[!]${RESET} No .sha256 files found. Run a full audit first to generate hashes."
    else
        echo -e "\n  ${BOLD}Results:${RESET} ${GREEN}${pass} passed${RESET} | ${RED}${fail} failed${RESET}"
    fi
}