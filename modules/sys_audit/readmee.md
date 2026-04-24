# sys_audit — Linux System Auditing & Monitoring Framework

> **OS2 Project — National School of Cybersecurity (NSCS), Algeria**

---

## Overview

`sys_audit` is a modular, production-ready Bash framework that performs comprehensive auditing of Linux systems. It collects hardware information, software inventory, and security data, then generates reports in multiple formats. It also supports remote host monitoring, automated alerting, and log management — all from the command line, with no external runtime dependencies.

---

## Project Structure

```
sys_audit/
├── main.sh               # Entry point & menu dispatcher
├── modules/
│   ├── hardware.sh       # Hardware & BIOS auditing
│   ├── software.sh       # OS, packages & process intelligence
│   ├── security.sh       # User, network & filesystem security checks
│   ├── report_gen.sh     # Multi-format report generation
│   ├── remote.sh         # SSH/SCP remote monitoring
│   ├── email_notify.sh   # msmtp-based email alerts
│   ├── log_rotate.sh     # Log archiving & rotation
│   ├── diff_reports.sh   # Audit-to-audit drift analysis
│   ├── integrity.sh      # SHA256 hash verification
│   └── monitor.sh        # Real-time resource monitor
└── reports/              # Generated audit output (text / HTML / JSON)
```

---

## What the Project Does

### 1. Hardware Auditing

Queries the machine's physical and logical hardware configuration using standard Linux tools (`/proc`, `dmidecode`, `lsblk`, `ip`).

| Component | What is collected |
|-----------|------------------|
| CPU | Model, architecture, cores/threads, clock speed, cache, real-time load |
| Memory | Total / available / free RAM, swap usage, DIMM slot details (dmidecode) |
| Storage | Partition layout (lsblk), filesystem usage and mount points (df) |
| Network HW | IPv4/IPv6 addresses, MAC addresses, DNS config, routing table |
| BIOS/System | Motherboard vendor, BIOS version, system model |
| Peripherals | USB devices (lsusb), battery status (/sys/class/power_supply) |

---

### 2. Software & OS Intelligence

Captures the complete software environment of the system.

- **OS Identity** — distribution, kernel version, uptime, hostname, locale
- **Package Management** — auto-detects `apt` / `dnf` / `pacman`, counts packages, lists recent installs
- **Service Monitoring** — running, enabled, and failed systemd units
- **Process Analysis** — top 15 processes by CPU and RAM, total count, process tree

---

### 3. Security & System Integrity

The security module performs checks aligned with standard Linux hardening practices.

- **User Auditing** — active sessions, login history, failed attempts (`lastb`/`auth.log`), sudo accounts
- **Network Security** — listening ports (`ss -tulnp`), firewall status (`ufw` / `firewalld` / `iptables`)
- **SUID/SGID Scan** — locates binaries that could be abused for privilege escalation
- **World-Writable Files** — scans sensitive directories (`/etc`, `/usr`, `/var`) for unsafe permissions
- **Cron Job Audit** — reviews all system and per-user crontab entries for unauthorized tasks
- **Integrity Module** — every report is SHA256-hashed; `integrity.sh` verifies hashes later to detect tampering

---

### 4. Multi-format Report Generation

A single audit run can produce four output formats:

| Format | Description |
|--------|-------------|
| **Text Short** | Concise summary — key metrics only |
| **Text Full** | Verbose technical report with all raw output |
| **HTML** | Styled web page with CSS progress bars for CPU / RAM / disk |
| **JSON** | Machine-readable structure for dashboards, SIEM, or pipelines |

---

### 5. Remote Monitoring & Centralization

Extends sys_audit to multi-host environments.

- **SSH Pull** — key-based auth to retrieve live stats from remote servers
- **SCP Push** — auto-pushes local reports to a central management server
- **Centralization** — pulls reports from multiple hosts into an organized directory tree

---

### 6. Automation & Maintenance

- **Email Notifications** — `msmtp` integration to send reports or threshold alerts to admins
- **Log Rotation** — `log_rotate.sh` compresses and archives historical audit logs to control disk usage
- **Drift Analysis** — `diff_reports.sh` diffs two audit snapshots and highlights what changed (new port, removed package, config delta)

---

### 7. Real-time Monitoring & Alerting

- **Live Monitor** — interactive loop showing CPU, RAM, and process metrics continuously
- **Health Checks** — configurable thresholds trigger alerts when resources exceed defined limits

---

## Technical Highlights

| Property | Detail |
|----------|--------|
| Language | Bash 5 — no external runtime needed |
| Size | ~1 800 lines across 9+ modules |
| Distro support | Debian/Ubuntu (apt), Fedora/RHEL (dnf), Arch (pacman) |
| Privilege handling | Works as normal user; richer data available with sudo |
| Tools used | awk, sed, grep, ps, ip, ss, find, dmidecode, lsblk, systemctl |
| Report integrity | SHA256 hash chain on all artifacts |

---

## How to Run

```bash
# Full audit
bash main.sh --full

# Generate HTML report only
bash main.sh --report html

# Real-time monitor
bash main.sh --monitor

# Verify report integrity
bash modules/integrity.sh reports/audit_2025-06-01.txt

# Compare two audits
bash modules/diff_reports.sh reports/old.txt reports/new.txt

# Remote audit via SSH
bash modules/remote.sh user@192.168.1.10
```

---

## Concepts Covered (OS2 Course)

This project demonstrates practical application of:

- **Process Management** — querying and analyzing running processes, CPU scheduling data
- **Filesystem & Permissions** — SUID/SGID detection, world-writable scanning, mount point analysis
- **Memory Management** — reading /proc/meminfo, swap tracking, DIMM introspection
- **I/O & Devices** — block device enumeration, USB detection, battery via sysfs
- **Networking** — interface enumeration, socket state inspection, firewall rule reading
- **System Calls & /proc** — direct reads from /proc/cpuinfo, /proc/uptime, /proc/net
- **Shell Scripting** — modular design, signal handling, argument parsing, text processing

---

*sys_audit — OS2 Project | NSCS Algeria*
