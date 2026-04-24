# 🚀 Quick Start Guide

## Get Email & PDF Working in 3 Commands

```bash
# 1. Install PDF support
./install_pdf_deps.sh

# 2. Setup email (follow prompts)
./setup_email.sh

# 3. Test everything
./verify_email.sh
```

## Then Run Your First Audit

```bash
sudo ./audit.sh --auto
```

This will:
1. ✅ Collect all system information
2. ✅ Generate comprehensive reports (TXT, HTML, JSON, **PDF**)
3. ✅ Email the PDF report to you automatically

---

## What You'll Receive

A professional email with:
- System status summary
- CPU, RAM, disk usage
- **PDF audit report attached** (complete system analysis)
- 7 major sections with detailed diagnostics

---

## If Email Fails

You need a **Gmail App Password** (not your regular password):

1. Go to: https://myaccount.google.com/apppasswords
2. Enable "2-Step Verification" first
3. Create new App Password → name it "SysAudit"
4. Copy the 16-character code
5. Edit `~/.msmtprc` and paste it in the `password` line
6. Run `./verify_email.sh` to test

---

## Report Locations

All reports saved to: `/var/log/sys_audit/`

```bash
ls -lh /var/log/sys_audit/
```

You'll see:
- `short_report_*.txt` - Quick summary
- `full_report_*.txt` - **Detailed 7-section analysis**
- `report_*.html` - Web viewable
- `report_*.pdf` - **Email-ready PDF**
- `report_*.json` - Machine readable

---

## Full Audit Report Now Includes

### Section 1: Hardware (8 subsections)
CPU, GPU, RAM, Storage, Network, Motherboard, USB, Battery

### Section 2: Software (14 subsections)
OS, Packages, Users, Services, Processes, Ports, Firewall, SUID files, etc.

### Section 3: Security 🆕
Password policy, PAM, SSH config, File permissions, Security updates, AppArmor/SELinux

### Section 4: Performance 🆕
CPU metrics, Memory analysis, Disk I/O, Network stats

### Section 5: System Configuration 🆕
Environment, Systemd units, Cron jobs, Kernel parameters, Modules

### Section 6: Logs & Diagnostics 🆕
System errors, Auth logs, Kernel messages, Disk usage

### Section 7: Network 🆕
Active connections, ARP table, Config files

---

## Need Help?

```bash
./audit.sh --help
./setup_email.sh
./verify_email.sh
```

See `EMAIL_PDF_SETUP.md` for detailed troubleshooting.
