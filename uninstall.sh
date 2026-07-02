#!/bin/bash

# SSH Login Notifier - Uninstallation Script

set -e

echo "=========================================="
echo "SSH Login Notifier - Uninstall Script"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

INSTALL_DIR="/opt/ssh-login-notifier"
LOG_FILE="/var/log/ssh-login-notifier.log"
PAM_SSH_CONFIG="/etc/pam.d/sshd"

# Remove PAM configuration
echo "Removing PAM configuration..."
if [ -f "$PAM_SSH_CONFIG" ]; then
    # Backup PAM configuration
    cp "$PAM_SSH_CONFIG" "${PAM_SSH_CONFIG}.backup.$(date +%Y%m%d-%H%M%S)"
    
    # Remove SSH Login Notifier entries
    sed -i '/# SSH Login Notifier/d' "$PAM_SSH_CONFIG"
    sed -i '/ssh-login-notifier/d' "$PAM_SSH_CONFIG"
    
    echo "✓ PAM configuration cleaned"
else
    echo "⚠  PAM configuration file not found"
fi

echo ""

# Remove installation directory
echo "Removing installation directory..."
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo "✓ Removed: $INSTALL_DIR"
else
    echo "⚠  Installation directory not found"
fi

echo ""

# Ask about log file
read -p "Do you want to remove the log file? ($LOG_FILE) [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -f "$LOG_FILE" ]; then
        rm -f "$LOG_FILE"
        echo "✓ Removed: $LOG_FILE"
    else
        echo "⚠  Log file not found"
    fi
else
    echo "⚠  Keeping log file: $LOG_FILE"
fi

echo ""
echo "=========================================="
echo "Uninstallation completed!"
echo "=========================================="
echo ""
