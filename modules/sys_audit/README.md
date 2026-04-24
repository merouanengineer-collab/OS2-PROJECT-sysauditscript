# sys_audit — Linux System Auditing & Monitoring Framework


**sys_audit** is a modular, high-integrity Bash framework designed for comprehensive auditing and real-time monitoring of Linux systems. Developed as a production-ready solution, it streamlines hardware introspection, software inventory management, and security hardening checks into a unified command-line interface.

This project was developed for the **Operating Systems 2 (OS2) course** at the **National School of Cybersecurity (NSCS), Algeria**.



# How we ensure reports are not tampered with
sha256sum "$REPORT_FILE" > "$REPORT_FILE.sha256"
```
</details>

*   **Integrity Verification:** Every generated report is secured with a SHA256 hash. The integrity module provides verification to detect post-generation tampering.
*   **Drift Analysis:** A built-in comparison engine (`diff`) to identify "system drift" between two audit snapshots (e.g., detecting newly opened ports or added users).

### 3. Remote Operations & Automation
*   **Agentless Monitoring:** Leverages SSH/SCP for remote status pulls and report centralization without requiring a remote agent.
*   **Automated Alerts:** Integrated `msmtp` support for threshold-based email notifications and scheduled report delivery.
*   **Lifecycle Management:** Automated log rotation and report archiving to maintain system storage health.

---

## 🛠 How to add your own Photos
To make this README look like the preview above with your real code:
1. **Take Screenshots:** Run `./audit.sh` and use `Shift + PrtSc` to capture your terminal.
2. **Create a Folder:** Create a folder named `assets` in your GitHub repo.
3. **Upload:** Drag your images into that folder.
4. **Update Links:** Change `https://via.placeholder.com/...` in the README to `./assets/your_image.png`.

---

## Technical Architecture

```text
sys_audit/
├── audit.sh                  # Main entry point & menu dispatcher
├── config/
│   └── config.cfg            # Centralized environment configuration
├── modules/
│   ├── hw_audit.sh           # Hardware & BIOS auditing logic
│   ├── sw_audit.sh           # OS, packages & process intelligence
│   ├── integrity.sh          # SHA256 checksum & verification
│   ├── remote_mon.sh         # SSH/SCP remote orchestration
│   ├── report.sh             # Multi-format report generators
│   ├── diff_reports.sh       # Audit-to-audit drift analysis
│   ├── alerts.sh             # Resource threshold monitoring
│   ├── email.sh              # msmtp/SMTP transmission logic
│   └── log_rotate.sh         # Log compression and rotation
└── cron/
    └── cron_runner.sh        # Scheduled execution handler
```

---

## Usage

### Interactive Mode (Recommended)
Launch the terminal-based dashboard for guided operations:
```bash
sudo ./audit.sh
```

### Command-Line Interface (CLI)
For automation and remote execution:

| Command | Description |
|:---|:---|
| `./audit.sh --full` | Execute comprehensive local audit |
| `./audit.sh --short` | Generate a high-level system summary |
| `./audit.sh --monitor` | Launch real-time resource dashboard |
| `./audit.sh --compare` | Diff the two most recent reports |
| `./audit.sh --verify` | Validate SHA256 integrity of reports |
| `./audit.sh --remote` | Fetch status from remote host via SSH |

---

## Installation & Deployment

### 1. Prerequisites
The framework utilizes standard POSIX utilities. Ensure the following are installed:
```bash
sudo apt update
sudo apt install -y openssh-client msmtp dmidecode lshw smartmontools sysstat whois python3-venv python3-full
# Create virtual environment and install WeasyPrint:
python3 -m venv venv && ./venv/bin/pip install weasyprint
# On Debian/Ubuntu, you might also need:
# sudo apt install -y python3-cffi libcairo2 libpango-1.0-0 libgdk-pixbuf-xlib-2.0-0 libffi-dev shared-mime-info
```

### 2. Configuration
Customize the environment via `config/config.cfg`:
*   **`OUTPUT_DIR`**: Destination for audit artifacts.
*   **`EMAIL_RECIPIENT`**: Target address for alerts and reports.
*   **`ALERT_THRESHOLDS`**: CPU/RAM/Disk limits for the monitor.

### 3. Service Integration
To schedule a daily audit at 04:00 AM, add the following to the system crontab:
```cronexp
0 4 * * * /path/to/sys_audit/cron/cron_runner.sh
```

---

## Academic Context (OS2 Coursework)

This project implements key Operating Systems concepts, including:
*   **Process & Resource Management:** Introspection of `/proc` and process state analysis.
*   **VFS & File Systems:** Permissions auditing and block device enumeration.
*   **Network Stack:** Inspection of socket states and firewall filter chains.
*   **Security Models:** User privilege auditing and SUID/SGID identification.

**Author:** Merouane Ben Boucherit  
**Supervisor:** Dr. Bentrad Sassi  
**Institution:** National School of Cybersecurity (NSCS), Algeria (2025/2026)

---

*This project is provided for educational and administrative auditing purposes.*
```

I have also updated `readmee.md` to be a simple redirection to the main README to ensure you don't have conflicting information on your GitHub page.


-# sys_audit — Linux System Auditing & Monitoring Framework
-
-> **OS2 Project — National School of Cybersecurity (NSCS), Algeria**
-
----
-
-## Overview
-
-`sys_audit` is a modular, production-ready Bash framework that performs comprehensive auditing of Linux systems. It collects hardware information, software inventory, and security data, then generates reports in multiple formats. It also supports remote host monitoring, automated alerting, and log management — all from the command line, with no external runtime dependencies.
-
----
-
-## Project Structure
-
-```
-sys_audit/
-├── main.sh               # Entry point & menu dispatcher
-├── modules/
-│   ├── hardware.sh       # Hardware & BIOS auditing
-│   ├── software.sh       # OS, packages & process intelligence
-│   ├── security.sh       # User, network & filesystem security checks
-│   ├── report_gen.sh     # Multi-format report generation
-│   ├── remote.sh         # SSH/SCP remote monitoring
-│   ├── email_notify.sh   # msmtp-based email alerts
-│   ├── log_rotate.sh     # Log archiving & rotation
-│   ├── diff_reports.sh   # Audit-to-audit drift analysis
-│   ├── integrity.sh      # SHA256 hash verification
-│   └── monitor.sh        # Real-time resource monitor
-└── reports/              # Generated audit output (text / HTML / JSON)
-```
-
----
-
-## What the Project Does
-
-### 1. Hardware Auditing
-
-Queries the machine's physical and logical hardware configuration using standard Linux tools (`/proc`, `dmidecode`, `lsblk`, `ip`).
-
-| Component | What is collected |
-|-----------|------------------|
-| CPU | Model, architecture, cores/threads, clock speed, cache, real-time load |
-| Memory | Total / available / free RAM, swap usage, DIMM slot details (dmidecode) |
-| Storage | Partition layout (lsblk), filesystem usage and mount points (df) |
-| Network HW | IPv4/IPv6 addresses, MAC addresses, DNS config, routing table |
-| BIOS/System | Motherboard vendor, BIOS version, system model |
-| Peripherals | USB devices (lsusb), battery status (/sys/class/power_supply) |
-
----
-
-### 2. Software & OS Intelligence
-
-Captures the complete software environment of the system.
-
-- **OS Identity** — distribution, kernel version, uptime, hostname, locale
-- **Package Management** — auto-detects `apt` / `dnf` / `pacman`, counts packages, lists recent installs
-- **Service Monitoring** — running, enabled, and failed systemd units
-- **Process Analysis** — top 15 processes by CPU and RAM, total count, process tree
-
----
-
-### 3. Security & System Integrity
-
-The security module performs checks aligned with standard Linux hardening practices.
-
-- **User Auditing** — active sessions, login history, failed attempts (`lastb`/`auth.log`), sudo accounts
-- **Network Security** — listening ports (`ss -tulnp`), firewall status (`ufw` / `firewalld` / `iptables`)
-- **SUID/SGID Scan** — locates binaries that could be abused for privilege escalation
-- **World-Writable Files** — scans sensitive directories (`/etc`, `/usr`, `/var`) for unsafe permissions
-- **Cron Job Audit** — reviews all system and per-user crontab entries for unauthorized tasks
-- **Integrity Module** — every report is SHA256-hashed; `integrity.sh` verifies hashes later to detect tampering
-
----
-
-### 4. Multi-format Report Generation
-
-A single audit run can produce four output formats:
-
-| Format | Description |
-|--------|-------------|
-| **Text Short** | Concise summary — key metrics only |
-| **Text Full** | Verbose technical report with all raw output |
-| **HTML** | Styled web page with CSS progress bars for CPU / RAM / disk |
-| **JSON** | Machine-readable structure for dashboards, SIEM, or pipelines |
-
----
-
-### 5. Remote Monitoring & Centralization
-
-Extends sys_audit to multi-host environments.
-
-- **SSH Pull** — key-based auth to retrieve live stats from remote servers
-- **SCP Push** — auto-pushes local reports to a central management server
-- **Centralization** — pulls reports from multiple hosts into an organized directory tree
-
----
-
-### 6. Automation & Maintenance
-
-- **Email Notifications** — `msmtp` integration to send reports or threshold alerts to admins
-- **Log Rotation** — `log_rotate.sh` compresses and archives historical audit logs to control disk usage
-- **Drift Analysis** — `diff_reports.sh` diffs two audit snapshots and highlights what changed (new port, removed package, config delta)
-
----
-
-### 7. Real-time Monitoring & Alerting
-
-- **Live Monitor** — interactive loop showing CPU, RAM, and process metrics continuously
-- **Health Checks** — configurable thresholds trigger alerts when resources exceed defined limits
-
----
-
-## Technical Highlights
-
-| Property | Detail |
-|----------|--------|
-| Language | Bash 5 — no external runtime needed |
-| Size | ~1 800 lines across 9+ modules |
-| Distro support | Debian/Ubuntu (apt), Fedora/RHEL (dnf), Arch (pacman) |
-| Privilege handling | Works as normal user; richer data available with sudo |
-| Tools used | awk, sed, grep, ps, ip, ss, find, dmidecode, lsblk, systemctl |
-| Report integrity | SHA256 hash chain on all artifacts |
-
----
-
-## How to Run
-
-```bash
-# Full audit
-bash main.sh --full
-
-# Generate HTML report only
-bash main.sh --report html
-
-# Real-time monitor
-bash main.sh --monitor
-
-# Verify report integrity
-bash modules/integrity.sh reports/audit_2025-06-01.txt
-
-# Compare two audits
-bash modules/diff_reports.sh reports/old.txt reports/new.txt
-
-# Remote audit via SSH
-bash modules/remote.sh user@192.168.1.10
-```
-
----
-
-## Concepts Covered (OS2 Course)
-
-This project demonstrates practical application of:
-
-- **Process Management** — querying and analyzing running processes, CPU scheduling data
-- **Filesystem & Permissions** — SUID/SGID detection, world-writable scanning, mount point analysis
-- **Memory Management** — reading /proc/meminfo, swap tracking, DIMM introspection
-- **I/O & Devices** — block device enumeration, USB detection, battery via sysfs
-- **Networking** — interface enumeration, socket state inspection, firewall rule reading
-- **System Calls & /proc** — direct reads from /proc/cpuinfo, /proc/uptime, /proc/net
-- **Shell Scripting** — modular design, signal handling, argument parsing, text processing
-
----
-
-*sys_audit — OS2 Project | NSCS Algeria*
+# sys_audit
+
+This project has been consolidated. Please refer to the primary README.md for full documentation, installation instructions, and technical details.

```bash
cd sys_audit/
```

**Interactive Menu (Recommended):**

```bash
./audit.sh
```

**Command-Line Interface (CLI) Options:**

```bash
# Run a complete audit (hardware + software)
./audit.sh --full

# Run a quick summary audit
./audit.sh --short

# Start real-time resource monitor
./audit.sh --monitor

# Get quick status of a remote machine via SSH
./audit.sh --remote

# Compare the two latest audit reports
./audit.sh --compare

# Verify report integrity using SHA256 checksums
./audit.sh --verify

# Show help menu
./audit.sh --help
```

## Installation & Setup

### 1. Clone the Repository

```bash
git clone <YOUR_GITHUB_REPO_URL> /home/merwan/OSprojectMerwanV/sys_audit/
cd /home/merwan/OSprojectMerwanV/sys_audit/
```

### 2. Dependencies

Ensure you have the following tools installed:

```bash
sudo apt update
sudo apt install openssh-server openssh-client msmtp msmtp-mta python3 dmidecode lshw lscpu smartmontools hdparm iostat sysstat whois
```

### 3. Configuration

Edit the `config/config.cfg` file to set your preferences, including `OUTPUT_DIR`, `EMAIL_RECIPIENT`, `REMOTE_HOST`, `SSH_KEY`, and alert thresholds.

```bash
nano config/config.cfg
```

### 4. Email Setup

Configure `msmtp` for sending emails. The script provides an interactive guide:

```bash
./audit.sh --setup-email
```

### 5. SSH Setup (for Remote Features)

Generate SSH keys and authorize them on your remote host (or `localhost` for testing):

```bash
./audit.sh --setup-ssh
# Follow the instructions to copy your public key to the remote host.
# Example: ssh-copy-id -i ~/.ssh/id_ed25519.pub user@remote_host
```

## Testing

-   **Test Email Configuration:** `./audit.sh --test-email`
-   **Test SSH Connection:** `./audit.sh --test-ssh`

## Project Structure

```
.
├── audit.sh                  # Main entry point, interactive menu & CLI handler
├── config/
│   └── config.cfg            # Central configuration file
├── modules/
│   ├── alerts.sh             # Resource monitoring and alerting logic
│   ├── diff_reports.sh       # Report comparison (diff) module
│   ├── email.sh              # Email sending functionality (msmtp)
│   ├── hw_audit.sh           # Hardware information collection
│   ├── integrity.sh          # Report integrity verification (SHA256)
│   ├── lib.sh                # Shared library (colors, logging, banner)
│   ├── log_rotate.sh         # Log rotation and archive management
│   ├── remote_mon.sh         # Remote monitoring and report pushing via SSH
│   ├── report.sh             # Report generation (TXT, HTML, JSON)
│   └── sw_audit.sh           # Software and OS information collection
└── cron/
    └── cron_runner.sh        # Script for scheduled audits (e.g., via cron)
```