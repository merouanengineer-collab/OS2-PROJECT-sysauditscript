#!/usr/bin/env bash
# =============================================================================
# install_pdf_deps.sh — Install PDF Generation Dependencies
# Project : Linux System Audit & Monitoring
# =============================================================================

echo "╔══════════════════════════════════════════════════════════╗"
echo "║     📄 Installing PDF Generation Dependencies         ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

echo "[1/2] Installing WeasyPrint and system dependencies..."
echo "Updating package lists..."
sudo apt update || echo -e "\n${YELLOW}⚠ Warning: Some repositories failed to update. Attempting installation anyway...${RESET}"

echo "Installing packages..."
sudo apt install -y \
    python3-weasyprint \
    libcairo2 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libgdk-pixbuf2.0-0 \
    libffi-dev \
    python3-cffi \
    python3-brotli

if [ $? -eq 0 ]; then
    echo "✓ Dependencies installed successfully!"
else
    echo "✗ Installation failed. Please check errors above."
    exit 1
fi

echo ""
echo "[2/2] Verifying installation..."
if python3 -c "import weasyprint; print('WeasyPrint version:', weasyprint.__version__)" 2>/dev/null; then
    echo "✓ WeasyPrint is working correctly!"
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║          ✅ PDF SUPPORT ENABLED!                       ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo "  You can now generate PDF audit reports."
else
    echo "✗ WeasyPrint verification failed."
    exit 1
fi
