# 🛡️ SYS-AUDIT: Linux System Auditor

A modular Bash-based solution for real-time monitoring and hardware auditing. 
Developed for the Operating Systems 2 course.

## 📸 Screenshot
<img width="1800" height="450" alt="image" src="https://github.com/user-attachments/assets/c7a4a80e-983a-4ac6-b525-27f6a9ec16a7" />

*Caption: The main menu of the audit script showing system health.*

## ✨ Key Features
* **Hardware Profiling:** Detailed CPU, RAM, and Storage reports.
* **Real-time Monitoring:** Live tracking of system resources.
* **Network Auditing:** Integrated network configuration and security checks.
* **Modular Design:** Easily add new auditing functions via the `modules/` folder.

## 🚀 Getting Started
```bash
git clone [https://github.com/merouanengineer-collab/OS2-PROJECT-sysauditscript.git](https://github.com/merouanengineer-collab/OS2-PROJECT-sysauditscript.git)
cd OS2-PROJECT-sysauditscript
chmod +x audit.sh
./audit.sh


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
