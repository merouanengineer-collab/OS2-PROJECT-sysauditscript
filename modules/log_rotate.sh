#!/usr/bin/env bash
# =============================================================================
# log_rotate.sh — Log Rotation & Archive Management
# Project : Linux System Audit & Monitoring
# Author  : [MEROUANE BEN BOUCHERIT] — NSCS 2025/2026
# =============================================================================

# ════════════════════════════════════════════════════════════════════
# rotate_logs — Archive current reports and rotate the log file
# ════════════════════════════════════════════════════════════════════
rotate_logs() {
    local report_dir="${REPORT_DIR:-${OUTPUT_DIR:-/tmp/sys_audit}}"
    local log_file="${LOG_FILE:-${report_dir}/audit.log}"
    local max_size_mb="${MAX_LOG_SIZE_MB:-10}"
    local max_backups="${LOG_BACKUPS:-5}"

    log_section "[ Log Rotation ]"

    # ── Archive current reports ──────────────────────────────────────
    local archive_dir="${report_dir}/archive/$(date '+%Y%m%d_%H%M%S')"
    mkdir -p "${archive_dir}"

    local archived=0
    for f in "${report_dir}"/*.txt "${report_dir}"/*.html "${report_dir}"/*.json; do
        [[ -f "$f" ]] || continue
        mv "$f" "${archive_dir}/" 2>/dev/null && (( archived++ )) || true
    done

    if [[ "${archived}" -gt 0 ]]; then
        echo -e "  ${GREEN}[✓]${RESET} Archived ${archived} report(s) → ${archive_dir}"
    else
        echo -e "  ${YELLOW}[!]${RESET} No reports found to archive."
    fi

    # ── Rotate log file if oversized ─────────────────────────────────
    if [[ -f "${log_file}" ]]; then
        local size_mb
        size_mb=$(( $(stat -c%s "${log_file}" 2>/dev/null || echo 0) / 1048576 ))
        if [[ "${size_mb}" -ge "${max_size_mb}" ]]; then
            for (( i=max_backups-1; i>=1; i-- )); do
                [[ -f "${log_file}.${i}" ]] && \
                    mv "${log_file}.${i}" "${log_file}.$((i+1))" 2>/dev/null || true
            done
            cp "${log_file}" "${log_file}.1" 2>/dev/null || true
            > "${log_file}"
            echo -e "  ${GREEN}[✓]${RESET} Log rotated (was ${size_mb}MB → truncated)."
        else
            echo -e "  ${CYAN}[i]${RESET} Log size: ${size_mb}MB / ${max_size_mb}MB — no rotation needed."
        fi
    else
        echo -e "  ${CYAN}[i]${RESET} No log file found yet."
    fi

    # ── Prune old archives beyond max_backups ─────────────────────────
    local old_archives
    old_archives=$(ls -dt "${report_dir}"/archive/*/ 2>/dev/null | tail -n +$(( max_backups + 1 )))
    if [[ -n "${old_archives}" ]]; then
        while IFS= read -r d; do
            rm -rf "${d}" && \
                echo -e "  ${DIM}Removed old archive: $(basename "${d}")${RESET}" || true
        done <<< "${old_archives}"
    fi

    echo -e "\n  ${GREEN}Done.${RESET}"
}

# ════════════════════════════════════════════════════════════════════
# show_report_stats — Print archive statistics
# ════════════════════════════════════════════════════════════════════
show_report_stats() {
    local report_dir="${REPORT_DIR:-${OUTPUT_DIR:-/tmp/sys_audit}}"

    log_section "[ Report Archive Statistics ]"

    echo -e "  ${BOLD}Report directory:${RESET} ${report_dir}"
    echo

    # Current reports
    echo -e "  ${BOLD}Current reports:${RESET}"
    local total_reports=0
    for f in "${report_dir}"/*.txt "${report_dir}"/*.html "${report_dir}"/*.json; do
        [[ -f "$f" ]] || continue
        local size; size="$(du -sh "${f}" 2>/dev/null | cut -f1)"
        local mtime; mtime="$(date -r "${f}" '+%Y-%m-%d %H:%M' 2>/dev/null || echo '?')"
        echo -e "    ${CYAN}→${RESET} $(basename "${f}")  [${size}]  ${DIM}${mtime}${RESET}"
        (( total_reports++ )) || true
    done
    [[ "${total_reports}" -eq 0 ]] && \
        echo -e "    ${YELLOW}(no reports found — run an audit first)${RESET}"

    # Archives
    echo -e "\n  ${BOLD}Archives:${RESET}"
    local archive_count=0
    for d in "${report_dir}"/archive/*/; do
        [[ -d "$d" ]] || continue
        local dir_size; dir_size="$(du -sh "${d}" 2>/dev/null | cut -f1)"
        local dir_count; dir_count="$(find "${d}" -type f 2>/dev/null | wc -l)"
        echo -e "    ${CYAN}→${RESET} $(basename "${d}")  [${dir_size}, ${dir_count} files]"
        (( archive_count++ )) || true
    done
    [[ "${archive_count}" -eq 0 ]] && \
        echo -e "    ${YELLOW}(no archives found)${RESET}"

    # Log file
    local log_file="${LOG_FILE:-${report_dir}/audit.log}"
    echo -e "\n  ${BOLD}Log file:${RESET}"
    if [[ -f "${log_file}" ]]; then
        local log_size; log_size="$(du -sh "${log_file}" 2>/dev/null | cut -f1)"
        local log_lines; log_lines="$(wc -l < "${log_file}" 2>/dev/null || echo 0)"
        echo -e "    ${CYAN}→${RESET} $(basename "${log_file}")  [${log_size}, ${log_lines} lines]"
    else
        echo -e "    ${YELLOW}(no log file yet)${RESET}"
    fi
}
