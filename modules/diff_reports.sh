#!/usr/bin/env bash
# =============================================================================
# diff_reports.sh — Report Comparison Module (BONUS)
# Project : Linux System Audit & Monitoring
# Author  : Merouane Ben Boucherit — NSCS 2025/2026
# =============================================================================
# Compares two audit reports and highlights what changed between them.
# Useful for detecting new packages, port changes, new users, etc.
# =============================================================================

# Wrappers used by audit.sh menu / CLI
select_and_compare() { compare_reports; }

compare_latest_two() {
    local report_type="${1:-full}"
    local report_dir="${OUTPUT_DIR:-${REPORT_DIR:-/tmp/sys_audit}}"
    
    # Improved search to include archived reports
    local reports=()
    while IFS= read -r f; do [[ -f "$f" ]] && reports+=("$f"); done \
        < <(find "${report_dir}" -maxdepth 3 -name "${report_type}_report*.txt" -printf "%T@ %p\n" | sort -rn | cut -d' ' -f2-)

    if [[ ${#reports[@]} -lt 2 ]]; then
        echo -e "  ${YELLOW}[!]${RESET} Need at least 2 ${report_type} reports to compare."
        echo -e "  Run the audit more than once, then try again."
        return 1
    fi
    diff --unified=3 "${reports[1]}" "${reports[0]}" || true
}

compare_reports() {
    local report_dir="${OUTPUT_DIR}"

    # Find available reports
    local reports=()
    while IFS= read -r f; do
        [[ -f "$f" ]] && reports+=("$f")
    done < <(find "${report_dir}" -maxdepth 3 -name "*report*.txt" -printf "%T@ %p\n" | sort -rn | cut -d' ' -f2-)

    if [[ ${#reports[@]} -lt 2 ]]; then
        echo -e "  ${YELLOW}[!]${RESET} Need at least 2 report files to compare."
        echo -e "  Available reports in ${report_dir}:"
        find "${report_dir}" -maxdepth 3 -name "*report*.txt" -printf "    %p  [%TY-%Tm-%Td %TH:%TM]\n" | sort -r || \
            echo "    (none found)"
        echo -e "\n  Tip: Run the audit multiple times to generate more reports for comparison."
        return 1
    fi

    # Let user pick files if interactive, else use last two
    local file1 file2
    if [[ -t 0 ]]; then
        echo -e "  Available reports:"
        local i=1
        echo -e "    0) [Exit/Back]"
        for r in "${reports[@]}"; do
            echo -e "    ${i}) $(basename "${r}")  [$(date -r "${r}" '+%Y-%m-%d %H:%M' 2>/dev/null)]"
            ((i++))
        done

        echo -ne "\n  Select file 1 (older) [1 or 'q' to quit]: "
        read -r sel1; sel1="${sel1:-1}"
        [[ "$sel1" =~ ^(0|q|exit|quit)$ ]] && return 0

        echo -ne "  Select file 2 (newer) [2 or 'q' to quit]: "
        read -r sel2; sel2="${sel2:-2}"
        [[ "$sel2" =~ ^(0|q|exit|quit)$ ]] && return 0

        file1="${reports[$((sel1-1))]}"
        file2="${reports[$((sel2-1))]}"
    else
        # Non-interactive: compare the two most recent
        file1="${reports[1]}"
        file2="${reports[0]}"
    fi

    if [[ ! -f "${file1}" || ! -f "${file2}" ]]; then
        echo -e "  ${RED}[ERROR]${RESET} Invalid file selection." >&2
        return 1
    fi

    local diff_out="${report_dir}/diff_$(date '+%Y%m%d_%H%M%S').txt"

    {
        echo "══════════════════════════════════════════════════════════════════════"
        echo "  REPORT COMPARISON / DIFF"
        echo "  Generated : $(date '+%Y-%m-%d %H:%M:%S')"
        echo "  File A    : $(basename "${file1}")"
        echo "  File B    : $(basename "${file2}")"
        echo "══════════════════════════════════════════════════════════════════════"
        echo
        echo "Legend:  < (lines only in A — removed/old)"
        echo "         > (lines only in B — added/new)"
        echo
        diff --unified=2 "${file1}" "${file2}" || true
        echo
        echo "══════════════════════════════════════════════════════════════════════"

        # Summary of interesting changes
        echo
        echo "  ── CHANGE SUMMARY ──────────────────────────────────────────────────"

        local added removed
        added="$(diff "${file1}" "${file2}" 2>/dev/null | grep '^>' | wc -l || echo 0)"
        removed="$(diff "${file1}" "${file2}" 2>/dev/null | grep '^<' | wc -l || echo 0)"
        echo "  Lines added   : ${added}"
        echo "  Lines removed : ${removed}"

        # Highlight potential security-relevant changes
        local pkg_changes port_changes user_changes suid_changes
        pkg_changes="$(diff "${file1}" "${file2}" | grep -i 'package\|install\|dpkg\|apt' | head -10)"
        port_changes="$(diff "${file1}" "${file2}" | grep -iE ':[0-9]{2,5}' | head -10)"
        user_changes="$(diff "${file1}" "${file2}" | grep -i 'user\|login\|who\|logged' | head -10)"
        suid_changes="$(diff "${file1}" "${file2}" | grep -i 'suid\|/usr/bin\|/bin' | head -10)"

        [[ -n "${pkg_changes}" ]]  && { echo; echo "  Package changes:"; echo "${pkg_changes}"; }
        [[ -n "${port_changes}" ]] && { echo; echo "  Port changes:"; echo "${port_changes}"; }
        [[ -n "${user_changes}" ]] && { echo; echo "  User changes:"; echo "${user_changes}"; }
        [[ -n "${suid_changes}" ]] && { echo; echo "  SUID changes:"; echo "${suid_changes}"; }

        echo
        echo "══════════════════════════════════════════════════════════════════════"
        echo "  END OF DIFF REPORT"
        echo "══════════════════════════════════════════════════════════════════════"

    } > "${diff_out}"

    echo -e "  ${GREEN}[✓]${RESET} Diff report → ${diff_out}"
    # Show a preview
    head -60 "${diff_out}"
}