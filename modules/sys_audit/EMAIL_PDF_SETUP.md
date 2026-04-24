# 📧 Email & PDF Setup Guide

## Quick Setup (3 Steps)

### Step 1: Install PDF Dependencies
```bash
cd sys_audit
./install_pdf_deps.sh
```

This installs:
- WeasyPrint (PDF generator)
- Cairo, Pango (rendering libraries)
- All required system dependencies

### Step 2: Configure Email
```bash
./setup_email.sh
```

This will:
- Copy msmtp configuration to `~/.msmtprc`
- Set correct permissions (600)
- Guide you through Gmail App Password setup
- Send a test email

### Step 3: Verify Everything Works
```bash
./verify_email.sh
```

---

## Manual Setup (If needed)

### Install WeasyPrint
```bash
sudo apt update
sudo apt install -y python3-weasyprint libcairo2 libpango-1.0-0 \
    libpangocairo-1.0-0 libgdk-pixbuf2.0-0
```

### Configure msmtp

1. **Copy configuration:**
```bash
cp config/.msmtprc ~/.msmtprc
chmod 600 ~/.msmtprc
```

2. **Get Gmail App Password:**
   - Go to: https://myaccount.google.com/apppasswords
   - Enable 2-Step Verification first (if not already)
   - Generate new App Password (name it "SysAudit")
   - Copy the 16-character password (no spaces)

3. **Edit ~/.msmtprc:**
```bash
nano ~/.msmtprc
```

Replace `YOUR_PASSWORD_HERE` with your 16-character App Password.

4. **Update config.cfg:**
```bash
nano config/config.cfg
```

Set your email addresses:
```bash
EMAIL_RECIPIENT="your-email@gmail.com"
EMAIL_FROM="your-email@gmail.com"
```

---

## Features

### ✅ PDF Generation
- Professional HTML-to-PDF conversion
- Styled reports with dark theme
- Automatic attachment to emails
- Optimized file size

### ✅ Email Functionality
- msmtp SMTP client
- Gmail support (with App Passwords)
- MIME multipart messages
- PDF attachments
- Formal, professional templates

### ✅ Enhanced Full Audit Report
Now includes 7 comprehensive sections:

1. **Hardware Information**
   - CPU, GPU, RAM, Storage
   - Network interfaces
   - Motherboard & BIOS
   - USB devices, Battery

2. **Software & OS Information**
   - Operating system details
   - Packages, users, services
   - Processes, ports, firewall
   - SUID/SGID files
   - Kernel modules

3. **Security & Compliance** 
   - Authentication & access control
   - File permissions & ownership
   - Security updates
   - AppArmor/SELinux status

4. **Performance & Resource Analysis
   - CPU performance metrics
   - Memory performance
   - Disk I/O statistics
   - Network performance

5. **System Configuration Details** 
   - Environment variables
   - Systemd services
   - Scheduled tasks (cron, timers)
   - Kernel parameters (sysctl)
   - Loaded modules

6. **Logs & Diagnostics**
   - System errors
   - Authentication logs
   - Kernel messages (dmesg)
   - Disk usage analysis

7. **Network Configuration** 
   - Active connections
   - ARP table
   - Configuration files

---

## Usage

### Run Full Audit and Email PDF
```bash
sudo ./audit.sh --auto
```

### Generate Reports Only
```bash
sudo ./audit.sh
# Then select option 1 (Run Full Audit)
```

### Send Existing Report via Email
```bash
sudo ./audit.sh
# Select option 3 (Email Report)
```

### Test Email Configuration
```bash
./verify_email.sh
```

---

## Troubleshooting

### PDF Generation Fails

**Error:** `WeasyPrint not found`
```bash
./install_pdf_deps.sh
```

**Error:** `cairo` or `pango` missing
```bash
sudo apt install libcairo2 libpango-1.0-0 libpangocairo-1.0-0
```

### Email Sending Fails

**Error:** `Authentication failed`
- Verify App Password is correct (16 characters, no spaces)
- Ensure 2-Step Verification is enabled on Google Account
- Re-generate App Password if needed

**Error:** `msmtp configuration not found`
```bash
cp config/.msmtprc ~/.msmtprc
chmod 600 ~/.msmtprc
```

**Error:** `Permission denied`
```bash
chmod 600 ~/.msmtprc
```

**Check msmtp log:**
```bash
tail -20 ~/.msmtp.log
```

### PDF Not Attached to Email

**Check if PDF was generated:**
```bash
ls -lh /var/log/sys_audit/*.pdf
```

**Verify email module finds PDF:**
```bash
grep "pdf" /var/log/sys_audit/audit.log
```

---

## Email Template

The email sent includes:

```
╔══════════════════════════════════════════════════════════╗
║          🛡️  SYSTEM AUDIT REPORT — OFFICIAL           ║
╚══════════════════════════════════════════════════════════╝

Dear System Administrator,

This is an automated notification regarding the completion of a 
comprehensive system audit on your infrastructure.

╭────────────────────────────────────────────────────────────╮
│  📋 AUDIT INFORMATION                                     │
╰────────────────────────────────────────────────────────────╯
  • Report Type     : FULL Audit Report
  • System Hostname : your-hostname
  • Generated On    : 2026-04-24 20:00:00 CET
  • Report Format   : report_20260424_200000.pdf
  • Author          : Merouane Ben Boucherit

╭────────────────────────────────────────────────────────────╮
│  ⚡ CURRENT SYSTEM STATUS                                 │
╰────────────────────────────────────────────────────────────╯
  • CPU Load        : 15%
  • Memory Usage    : 45%
  • System Uptime   : 5 days, 3 hours
  • Operating System: Ubuntu 24.04 LTS
  • Kernel Version  : 6.12.0

╭────────────────────────────────────────────────────────────╮
│  📎 ATTACHED DOCUMENTS                                    │
╰────────────────────────────────────────────────────────────╯
  The complete system audit report is attached in PDF format.
  This document contains detailed hardware inventory, software 
  configuration, security assessment, and performance metrics.

[... PDF attached ...]
```

---

## File Locations

- **msmtp config:** `~/.msmtprc`
- **Email config:** `sys_audit/config/config.cfg`
- **Reports:** `/var/log/sys_audit/`
- **PDF Generator:** `sys_audit/generate_pdf.py`
- **Email module:** `sys_audit/modules/email.sh`
- **Report generator:** `sys_audit/modules/report.sh`

---

## Security Notes

- **App Passwords:** Never use your actual Gmail password
- **File Permissions:** `~/.msmtprc` must be 600 (read/write for owner only)
- **TLS:** All email connections use TLS encryption
- **Password Storage:** Stored locally in `~/.msmtprc` (protected by file permissions)

---

## What's Fixed

### ✅ Email Sending
- Multiple config file location support
- Better error messages
- Automatic permission fixing
- Professional email templates

### ✅ PDF Generation
- Improved error handling
- Dependency checking
- File size validation
- Silent operation (no verbose output)

### ✅ Full Audit Report
- Added 5 new major sections
- 30+ new subsections
- Security analysis
- Performance metrics
- Log diagnostics
- Network details

### ✅ Integration
- PDFs automatically attached to emails
- Prefers PDF over text when available
- Graceful fallback if PDF fails
- Status tracking in logs

---

## Support

For issues:
1. Check `~/.msmtp.log` for email errors
2. Check `/var/log/sys_audit/audit.log` for system errors
3. Run `./verify_email.sh` for diagnostics
4. Check `/tmp/pdf_check.log` for PDF errors

---

**Author:** Merouane Ben Boucherit  
**Institution:** NSCS — National School of Cyber Security  
**Course:** OS2 — Operating Systems 2  
**Date:** April 2026
