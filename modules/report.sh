#!/usr/bin/env bash
# =============================================================================
# report.sh — Report Generation Module
# Project : Linux System Audit & Monitoring
# Author  : Merouane Ben Boucherit — NSCS 2025/2026
# =============================================================================
# Functions:
#   generate_short_report()  → short_report.txt
#   generate_full_report()   → full_report.txt
#   generate_html_report()   → report.html
#   generate_json_report()   → report.json
# =============================================================================

# ── Shared metadata ───────────────────────────────────────────────────────────
REPORT_DATE="$(date '+%Y-%m-%d %H:%M:%S %Z')"
REPORT_HOSTNAME="$(hostname -f 2>/dev/null || hostname)"
REPORT_TS="$(date '+%Y%m%d_%H%M%S')"

# ── Helper: section separator ─────────────────────────────────────────────────
sep()     { printf '%.0s─' {1..70}; echo; }
sep_dbl() { printf '%.0s═' {1..70}; echo; }
hdr() {
    echo
    sep_dbl
    echo "  $1"
    sep_dbl
}
sub() {
    echo
    echo "  ▸ $1"
    sep
}

# ════════════════════════════════════════════════════════════════════════════════
# generate_all_reports — called by _run_full_audit in audit.sh
# ════════════════════════════════════════════════════════════════════════════════
generate_all_reports() {
    local mode="${1:-full}"
    local rdir="${REPORT_DIR:-${OUTPUT_DIR:-/tmp/sys_audit}}"
    mkdir -p "${rdir}"

    # Refresh timestamp for this run
    REPORT_TS="$(date '+%Y%m%d_%H%M%S')"

    echo -e "\n${BOLD}Generating reports → ${rdir}${RESET}"
    generate_short_report
    generate_html_report
    generate_json_report
    if [[ "${mode}" == "full" ]]; then
        generate_full_report
    fi

    # Write sha256 hashes for integrity verification
    for f in "${rdir}"/*.txt "${rdir}"/*.html "${rdir}"/*.json; do
        [[ -f "$f" ]] || continue
        sha256sum "$f" > "${f}.sha256" 2>/dev/null || true
    done
    echo -e "  ${GREEN}[✓]${RESET} Integrity hashes written (.sha256)"
    log_info "Audit complete (${mode}). Reports in ${rdir}"
}

# ════════════════════════════════════════════════════════════════════════════════
# SHORT REPORT — concise essential information
# ══════════════════════════════════════════════════════════════════════════════
generate_short_report() {
    local outfile="${REPORT_DIR:-${OUTPUT_DIR}}/short_report_${REPORT_TS}.txt"
    log_debug "Attempting to generate short report to: ${outfile}"

    {
        sep_dbl
        echo "  SYS-AUDIT — SHORT REPORT (SUMMARY VIEW)"
        echo "  ${REPORT_INSTITUTION}"
        sep_dbl
        echo "  Generated : ${REPORT_DATE}"
        echo "  Hostname  : ${REPORT_HOSTNAME}"
        echo "  Author    : ${REPORT_AUTHOR}"
        sep_dbl

        hdr "HARDWARE SUMMARY"

        sub "CPU"
        echo "  Model       : ${HW_DATA[cpu_model]:-N/A}"
        echo "  Cores       : ${HW_DATA[cpu_cores]:-N/A} cores / ${HW_DATA[cpu_threads]:-N/A} threads"
        echo "  Architecture: ${HW_DATA[cpu_arch]:-N/A}"
        echo "  Current load: ${HW_DATA[cpu_usage]:-N/A}%"

        sub "GPU"
        echo "  ${HW_DATA[gpu_info]:-N/A}"

        sub "RAM"
        echo "  Total     : ${HW_DATA[ram_total]:-N/A}"
        echo "  Available : ${HW_DATA[ram_available]:-N/A}"
        echo "  Usage     : ${HW_DATA[ram_usage_pct]:-N/A}%"
        echo "  Swap      : ${HW_DATA[ram_swap_total]:-N/A} (used: ${HW_DATA[ram_swap_used]:-N/A})"

        sub "Disk Usage"
        echo "${HW_DATA[disk_df]:-N/A}"

        sub "Network — IP Addresses"
        echo "${HW_DATA[net_ip4]:-N/A}"
        echo "  MAC(s): ${HW_DATA[net_mac]:-N/A}"

        hdr "SOFTWARE SUMMARY"

        sub "Operating System"
        echo "  OS       : ${SW_DATA[os_name]:-N/A}"
        echo "  Kernel   : ${SW_DATA[kernel_version]:-N/A}"
        echo "  Arch     : ${SW_DATA[architecture]:-N/A}"
        echo "  Uptime   : ${SW_DATA[uptime]:-N/A}"
        echo "  Timezone : ${SW_DATA[timezone]:-N/A}"

        sub "Packages"
        echo "  Manager  : ${SW_DATA[pkg_manager]:-N/A}"
        echo "  Installed: ${SW_DATA[pkg_count]:-N/A} packages"

        sub "Logged-in Users"
        echo "${SW_DATA[logged_in_users]:-None}"

        sub "Open Listening Ports"
        echo "${SW_DATA[ports_listening]:-N/A}"

        sub "Failed Services"
        echo "${SW_DATA[services_failed]:-None}"

        sep_dbl
        echo "  END OF SHORT REPORT"
        sep_dbl

    } > "${outfile}"

    echo -e "    ${GREEN}[✓]${RESET} Short report → ${outfile}"
}

# ══════════════════════════════════════════════════════════════════════════════
# FULL REPORT — complete technical audit
# ══════════════════════════════════════════════════════════════════════════════
generate_full_report() {
    local outfile="${REPORT_DIR:-${OUTPUT_DIR}}/full_report_${REPORT_TS}.txt"

    {
        sep_dbl
        echo "  SYS-AUDIT — FULL REPORT (DETAILED AUDIT)"
        echo "  ${REPORT_INSTITUTION} | ${REPORT_COURSE}"
        sep_dbl
        echo "  Generated : ${REPORT_DATE}"
        echo "  Hostname  : ${REPORT_HOSTNAME}"
        echo "  Author    : ${REPORT_AUTHOR}"
        sep_dbl

        # ── HARDWARE ──
        hdr "1. HARDWARE INFORMATION"

        sub "1.1 CPU — Processor"
        echo "  Model        : ${HW_DATA[cpu_model]:-N/A}"
        echo "  Architecture : ${HW_DATA[cpu_arch]:-N/A}"
        echo "  Cores        : ${HW_DATA[cpu_cores]:-N/A}"
        echo "  Threads      : ${HW_DATA[cpu_threads]:-N/A}"
        echo "  Speed (MHz)  : ${HW_DATA[cpu_mhz]:-N/A}"
        echo "  Cache        : ${HW_DATA[cpu_cache]:-N/A}"
        echo "  Usage now    : ${HW_DATA[cpu_usage]:-N/A}%"
        if [[ -n "${HW_DATA[cpu_lscpu]:-}" ]]; then
            echo
            echo "${HW_DATA[cpu_lscpu]}"
        fi

        sub "1.2 GPU — Graphics"
        echo "${HW_DATA[gpu_info]:-N/A}"
        [[ -n "${HW_DATA[gpu_nvidia]:-}" ]] && echo "${HW_DATA[gpu_nvidia]}"

        sub "1.3 RAM — Memory"
        echo "  Total     : ${HW_DATA[ram_total]:-N/A}"
        echo "  Free      : ${HW_DATA[ram_free]:-N/A}"
        echo "  Available : ${HW_DATA[ram_available]:-N/A}"
        echo "  Usage     : ${HW_DATA[ram_usage_pct]:-N/A}%"
        echo "  Swap Total: ${HW_DATA[ram_swap_total]:-N/A}"
        echo "  Swap Used : ${HW_DATA[ram_swap_used]:-N/A}"
        if [[ -n "${HW_DATA[ram_dimm]:-}" ]]; then
            echo
            echo "  DIMM Slots:"
            echo "${HW_DATA[ram_dimm]}" | sed 's/^/    /'
        fi

        sub "1.4 Storage — Disks & Partitions"
        echo "${HW_DATA[disk_lsblk]:-N/A}"
        echo
        echo "  Filesystem Usage:"
        echo "${HW_DATA[disk_df]:-N/A}"

        sub "1.5 Network Interfaces"
        echo "  Interfaces:"
        echo "${HW_DATA[net_interfaces]:-N/A}"
        echo
        echo "  IP Addresses:"
        echo "${HW_DATA[net_ip4]:-N/A}"
        echo
        echo "  IPv6:"
        echo "${HW_DATA[net_ip6]:-N/A}"
        echo
        echo "  MAC Addresses : ${HW_DATA[net_mac]:-N/A}"
        echo "  DNS Servers   : ${HW_DATA[net_dns]:-N/A}"
        echo
        echo "  Routing Table:"
        echo "${HW_DATA[net_routing]:-N/A}"
        [[ -n "${HW_DATA[net_wireless]:-}" ]] && {
            echo; echo "  Wireless:"; echo "${HW_DATA[net_wireless]}"; }

        sub "1.6 Motherboard & BIOS"
        echo "  Board Vendor  : ${HW_DATA[mb_manufacturer]:-N/A}"
        echo "  Board Product : ${HW_DATA[mb_product]:-N/A}"
        echo "  BIOS Vendor   : ${HW_DATA[bios_vendor]:-N/A}"
        echo "  BIOS Version  : ${HW_DATA[bios_version]:-N/A}"
        echo "  BIOS Date     : ${HW_DATA[bios_date]:-N/A}"
        echo "  System Vendor : ${HW_DATA[sys_manufacturer]:-N/A}"
        echo "  System Model  : ${HW_DATA[sys_product]:-N/A}"

        sub "1.7 USB Devices"
        echo "${HW_DATA[usb_devices]:-N/A}"

        sub "1.8 Battery"
        echo "${HW_DATA[battery]:-N/A (no battery / not applicable)}"

        # ── SOFTWARE ──
        hdr "2. SOFTWARE & OS INFORMATION"

        sub "2.1 Operating System"
        echo "  OS Name     : ${SW_DATA[os_name]:-N/A}"
        echo "  OS Version  : ${SW_DATA[os_version]:-N/A}"
        echo "  Codename    : ${SW_DATA[os_codename]:-N/A}"
        echo "  Kernel      : ${SW_DATA[kernel_version]:-N/A}"
        echo "  Full uname  : ${SW_DATA[kernel_full]:-N/A}"
        echo "  Architecture: ${SW_DATA[architecture]:-N/A}"
        echo "  Hostname    : ${SW_DATA[hostname]:-N/A}"
        echo "  Uptime      : ${SW_DATA[uptime]:-N/A}"
        echo "  Boot since  : ${SW_DATA[uptime_since]:-N/A}"
        echo "  Timezone    : ${SW_DATA[timezone]:-N/A}"
        echo "  Locale      : ${SW_DATA[locale]:-N/A}"
        echo "  Shell       : ${SW_DATA[shell]:-N/A}"

        sub "2.2 Installed Packages (first 100)"
        echo "  Manager : ${SW_DATA[pkg_manager]:-N/A}"
        echo "  Count   : ${SW_DATA[pkg_count]:-N/A}"
        echo
        echo "${SW_DATA[pkg_list]:-N/A}"
        [[ -n "${SW_DATA[snap_packages]:-}" ]] && {
            echo; echo "  Snap Packages:"; echo "${SW_DATA[snap_packages]}"; }

        sub "2.3 Logged-in Users"
        echo "${SW_DATA[logged_in_users]:-None}"
        echo
        echo "  All system users (UID >= 1000):"
        echo "${SW_DATA[all_users]:-N/A}"
        echo
        echo "  Last logins:"
        echo "${SW_DATA[last_logins]:-N/A}"

        sub "2.4 Running Services"
        echo "${SW_DATA[services_running]:-N/A}"

        sub "2.5 Failed Services"
        echo "${SW_DATA[services_failed]:-None}"

        sub "2.6 Active Processes (Top 15 by CPU)"
        echo "${SW_DATA[proc_top_cpu]:-N/A}"

        sub "2.7 Active Processes (Top 15 by Memory)"
        echo "${SW_DATA[proc_top_mem]:-N/A}"

        sub "2.8 Open / Listening Ports"
        echo "${SW_DATA[ports_listening]:-N/A}"

        sub "2.9 Firewall Status"
        echo "${SW_DATA[firewall]:-N/A}"

        sub "2.10 SUID / SGID Files"
        echo "  SUID files:"
        echo "${SW_DATA[suid_files]:-N/A}"
        echo
        echo "  SGID files:"
        echo "${SW_DATA[sgid_files]:-N/A}"

        sub "2.11 Kernel Modules (first 40)"
        echo "${SW_DATA[kernel_modules]:-N/A}"

        sub "2.12 Boot Parameters"
        echo "${SW_DATA[boot_params]:-N/A}"

        sub "2.13 Cron Jobs"
        echo "${SW_DATA[crontabs]:-N/A}"
        echo
        echo "  System cron directories:"
        echo "${SW_DATA[cron_system]:-N/A}"

        sub "2.14 Mount Points"
        echo "${SW_DATA[mounts]:-N/A}"

        sep_dbl
        echo "  END OF FULL REPORT"
        sep_dbl

    } > "${outfile}"

    echo -e "    ${GREEN}[✓]${RESET} Full report  → ${outfile}"
}

# ══════════════════════════════════════════════════════════════════════════════
# HTML REPORT — styled web view
# ══════════════════════════════════════════════════════════════════════════════
generate_html_report() {
    local outfile="${REPORT_DIR:-${OUTPUT_DIR}}/report_${REPORT_TS}.html"
    local cpu_pct="${HW_DATA[ram_usage_pct]:-0}"

    cat > "${outfile}" << HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>SYS-AUDIT — ${REPORT_HOSTNAME}</title>
  <style>
    :root { --bg:#0f1117; --card:#1a1d27; --border:#2e3347; --accent:#4f9cf9;
            --green:#3de08e; --red:#f44; --text:#e2e8f0; --muted:#8892a4; }
    * { box-sizing:border-box; margin:0; padding:0; }
    body { background:var(--bg); color:var(--text); font:14px/1.6 'Cascadia Code','Courier New',monospace; padding:20px; }
    h1 { color:var(--accent); font-size:1.4em; border-bottom:1px solid var(--border); padding-bottom:8px; margin-bottom:16px; }
    h2 { color:var(--accent); font-size:1.1em; margin:20px 0 8px; }
    h3 { color:var(--muted); font-size:.95em; margin:12px 0 4px; }
    .card { background:var(--card); border:1px solid var(--border); border-radius:8px; padding:16px; margin-bottom:16px; }
    .meta { color:var(--muted); font-size:.85em; }
    .badge { display:inline-block; padding:2px 8px; border-radius:4px; font-size:.8em; font-weight:bold; }
    .badge-ok  { background:#1a3a2a; color:var(--green); }
    .badge-err { background:#3a1a1a; color:var(--red); }
    .grid { display:grid; grid-template-columns:repeat(auto-fit,minmax(200px,1fr)); gap:12px; }
    .stat { background:#0d1117; border:1px solid var(--border); border-radius:6px; padding:12px; }
    .stat-val { font-size:1.4em; font-weight:bold; color:var(--accent); }
    .stat-lbl { color:var(--muted); font-size:.8em; }
    pre { background:#0d1117; border:1px solid var(--border); border-radius:4px;
          padding:10px; overflow-x:auto; font-size:.82em; white-space:pre-wrap; word-break:break-word; }
    .bar { background:#0d1117; border-radius:99px; height:8px; margin-top:4px; overflow:hidden; }
    .bar-fill { height:100%; border-radius:99px; background:var(--accent); transition:width .3s; }
    .bar-fill.warn { background:#f5a623; }
    .bar-fill.crit { background:var(--red); }
    table { width:100%; border-collapse:collapse; font-size:.85em; }
    th { color:var(--muted); text-align:left; padding:6px; border-bottom:1px solid var(--border); }
    td { padding:5px 6px; border-bottom:1px solid #1e2235; }
    footer { margin-top:30px; color:var(--muted); font-size:.8em; text-align:center; }
  </style>
</head>
<body>
<h1>🛡 SYS-AUDIT — System Audit Report</h1>
<div class="meta">
  <strong>Host:</strong> ${REPORT_HOSTNAME} &nbsp;|&nbsp;
  <strong>Generated:</strong> ${REPORT_DATE} &nbsp;|&nbsp;
  <strong>Author:</strong> ${REPORT_AUTHOR}
</div>

<div class="card" style="margin-top:16px">
  <h2>Quick Stats</h2>
  <div class="grid">
    <div class="stat">
      <div class="stat-val">${SW_DATA[os_name]:-N/A}</div>
      <div class="stat-lbl">Operating System</div>
    </div>
    <div class="stat">
      <div class="stat-val">${SW_DATA[kernel_version]:-N/A}</div>
      <div class="stat-lbl">Kernel</div>
    </div>
    <div class="stat">
      <div class="stat-val">${HW_DATA[cpu_cores]:-N/A}</div>
      <div class="stat-lbl">CPU Cores</div>
    </div>
    <div class="stat">
      <div class="stat-val">${HW_DATA[ram_total]:-N/A}</div>
      <div class="stat-lbl">Total RAM</div>
    </div>
    <div class="stat">
      <div class="stat-val">${SW_DATA[pkg_count]:-N/A}</div>
      <div class="stat-lbl">Packages Installed</div>
    </div>
    <div class="stat">
      <div class="stat-val">${SW_DATA[uptime]:-N/A}</div>
      <div class="stat-lbl">System Uptime</div>
    </div>
  </div>
</div>

<div class="card">
  <h2>CPU & RAM Usage</h2>
  <h3>CPU Usage: ${HW_DATA[cpu_usage]:-0}%</h3>
  <div class="bar"><div class="bar-fill" style="width:${HW_DATA[cpu_usage]:-0}%"></div></div>
  <h3 style="margin-top:10px">RAM Usage: ${HW_DATA[ram_usage_pct]:-0}%</h3>
  <div class="bar"><div class="bar-fill" style="width:${HW_DATA[ram_usage_pct]:-0}%"></div></div>
</div>

<div class="card">
  <h2>Hardware</h2>
  <h3>CPU</h3>
  <pre>${HW_DATA[cpu_model]:-N/A} — ${HW_DATA[cpu_cores]:-?} cores / ${HW_DATA[cpu_threads]:-?} threads @ ${HW_DATA[cpu_mhz]:-?} MHz</pre>
  <h3>GPU</h3>
  <pre>${HW_DATA[gpu_info]:-N/A}</pre>
  <h3>Disk Partitions</h3>
  <pre>${HW_DATA[disk_df]:-N/A}</pre>
  <h3>Network</h3>
  <pre>${HW_DATA[net_ip4]:-N/A}
MACs: ${HW_DATA[net_mac]:-N/A}</pre>
  <h3>USB Devices</h3>
  <pre>${HW_DATA[usb_devices]:-N/A}</pre>
</div>

<div class="card">
  <h2>Software & OS</h2>
  <h3>Logged-in Users</h3>
  <pre>${SW_DATA[logged_in_users]:-None}</pre>
  <h3>Listening Ports</h3>
  <pre>${SW_DATA[ports_listening]:-N/A}</pre>
  <h3>Top Processes (CPU)</h3>
  <pre>${SW_DATA[proc_top_cpu]:-N/A}</pre>
  <h3>Failed Services</h3>
  <pre>${SW_DATA[services_failed]:-None ✓}</pre>
  <h3>SUID Files</h3>
  <pre>${SW_DATA[suid_files]:-N/A}</pre>
</div>

<footer>
  ${REPORT_INSTITUTION} &nbsp;|&nbsp; ${REPORT_COURSE} &nbsp;|&nbsp;
  Generated by sys_audit on ${REPORT_HOSTNAME}
</footer>
</body>
</html>
HTML

    echo -e "    ${GREEN}[✓]${RESET} HTML report  → ${outfile}"
}

# ══════════════════════════════════════════════════════════════════════════════
# JSON REPORT — machine-readable format
# ══════════════════════════════════════════════════════════════════════════════
generate_json_report() {
    local outfile="${REPORT_DIR:-${OUTPUT_DIR}}/report_${REPORT_TS}.json"

    # Helper to escape JSON strings
    json_escape() {
        printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null \
            || printf '"%s"' "$(echo "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/g' | tr -d '\n')"
    }

    cat > "${outfile}" << JSONEOF
{
  "report_meta": {
    "generated": "${REPORT_DATE}",
    "hostname": "${REPORT_HOSTNAME}",
    "author": "${REPORT_AUTHOR}",
    "institution": "${REPORT_INSTITUTION}",
    "course": "${REPORT_COURSE}"
  },
  "hardware": {
    "cpu": {
      "model": $(json_escape "${HW_DATA[cpu_model]:-N/A}"),
      "cores": "${HW_DATA[cpu_cores]:-N/A}",
      "threads": "${HW_DATA[cpu_threads]:-N/A}",
      "architecture": "${HW_DATA[cpu_arch]:-N/A}",
      "mhz": "${HW_DATA[cpu_mhz]:-N/A}",
      "cache": $(json_escape "${HW_DATA[cpu_cache]:-N/A}"),
      "usage_percent": "${HW_DATA[cpu_usage]:-N/A}"
    },
    "gpu": $(json_escape "${HW_DATA[gpu_info]:-N/A}"),
    "ram": {
      "total": "${HW_DATA[ram_total]:-N/A}",
      "available": "${HW_DATA[ram_available]:-N/A}",
      "usage_percent": "${HW_DATA[ram_usage_pct]:-N/A}",
      "swap_total": "${HW_DATA[ram_swap_total]:-N/A}",
      "swap_used": "${HW_DATA[ram_swap_used]:-N/A}"
    },
    "motherboard": {
      "manufacturer": $(json_escape "${HW_DATA[mb_manufacturer]:-N/A}"),
      "product": $(json_escape "${HW_DATA[mb_product]:-N/A}"),
      "bios_version": $(json_escape "${HW_DATA[bios_version]:-N/A}"),
      "bios_date": $(json_escape "${HW_DATA[bios_date]:-N/A}")
    },
    "network": {
      "ip4": $(json_escape "${HW_DATA[net_ip4]:-N/A}"),
      "mac": "${HW_DATA[net_mac]:-N/A}",
      "dns": "${HW_DATA[net_dns]:-N/A}"
    }
  },
  "software": {
    "os": {
      "name": $(json_escape "${SW_DATA[os_name]:-N/A}"),
      "version": $(json_escape "${SW_DATA[os_version]:-N/A}"),
      "kernel": "${SW_DATA[kernel_version]:-N/A}",
      "architecture": "${SW_DATA[architecture]:-N/A}",
      "uptime": $(json_escape "${SW_DATA[uptime]:-N/A}"),
      "timezone": "${SW_DATA[timezone]:-N/A}"
    },
    "packages": {
      "manager": "${SW_DATA[pkg_manager]:-N/A}",
      "count": "${SW_DATA[pkg_count]:-N/A}"
    },
    "security": {
      "suid_files_count": "$(echo "${SW_DATA[suid_files]:-}" | grep -c '/' 2>/dev/null || echo 0)"
    }
  }
}
JSONEOF

    echo -e "    ${GREEN}[✓]${RESET} JSON report  → ${outfile}"
}