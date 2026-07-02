#!/bin/bash

# SSH Login Notifier - Installation Script
# This script automatically installs and configures the SSH login notifier

set -e  # Exit on error

echo "=========================================="
echo "SSH Login Notifier - Installation Script"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default installation directory
INSTALL_DIR="/opt/ssh-login-notifier"

# Load configuration
if [ ! -f "$SCRIPT_DIR/config.sh" ]; then
    echo "Error: config.sh not found in $SCRIPT_DIR"
    exit 1
fi

source "$SCRIPT_DIR/config.sh"

echo "Installation directory: $INSTALL_DIR"
echo ""

# Check dependencies
echo "Checking dependencies..."
MISSING_DEPS=()

if ! command -v curl &> /dev/null; then
    MISSING_DEPS+=("curl")
fi

if ! command -v python3 &> /dev/null; then
    MISSING_DEPS+=("python3")
fi

# Install missing dependencies
if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo "Installing missing dependencies: ${MISSING_DEPS[*]}"
    
    if command -v apt-get &> /dev/null; then
        apt-get update -qq
        apt-get install -y "${MISSING_DEPS[@]}"
    elif command -v yum &> /dev/null; then
        yum install -y "${MISSING_DEPS[@]}"
    elif command -v dnf &> /dev/null; then
        dnf install -y "${MISSING_DEPS[@]}"
    else
        echo "Error: Unable to install dependencies. Please install manually: ${MISSING_DEPS[*]}"
        exit 1
    fi
fi

echo "✓ All dependencies are installed"
echo ""

# Create installation directory
echo "Creating installation directory..."
mkdir -p "$INSTALL_DIR"
echo "✓ Directory created: $INSTALL_DIR"
echo ""

# Copy files
echo "Copying files..."
cp "$SCRIPT_DIR/config.sh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/notify.sh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/slack_message.json" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/uninstall.sh" "$INSTALL_DIR/"

# Set proper permissions
chmod 755 "$INSTALL_DIR"
chmod 644 "$INSTALL_DIR/config.sh"
chmod 755 "$INSTALL_DIR/notify.sh"
chmod 644 "$INSTALL_DIR/slack_message.json"
chmod 755 "$INSTALL_DIR/uninstall.sh"

echo "✓ Files copied and permissions set"
echo ""

# Create log file
echo "Creating log file..."
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"
echo "✓ Log file created: $LOG_FILE"
echo ""

# Configure PAM
echo "Configuring PAM for SSH login notifications..."

PAM_SSH_CONFIG="/etc/pam.d/sshd"
PAM_ENTRY="session optional pam_exec.so seteuid $INSTALL_DIR/notify.sh"

if [ ! -f "$PAM_SSH_CONFIG" ]; then
    echo "Error: PAM SSH configuration file not found: $PAM_SSH_CONFIG"
    exit 1
fi

# Backup PAM configuration
cp "$PAM_SSH_CONFIG" "${PAM_SSH_CONFIG}.backup.$(date +%Y%m%d-%H%M%S)"

# Check if entry already exists
if grep -q "ssh-login-notifier" "$PAM_SSH_CONFIG"; then
    echo "⚠  PAM entry already exists, skipping..."
else
    # Add PAM entry
    echo "" >> "$PAM_SSH_CONFIG"
    echo "# SSH Login Notifier" >> "$PAM_SSH_CONFIG"
    echo "$PAM_ENTRY" >> "$PAM_SSH_CONFIG"
    echo "✓ PAM configuration updated"
fi

echo ""

# Validate Slack Webhook URL
echo "Validating configuration..."
if [[ "$SLACK_WEBHOOK_URL" == *"YOUR/WEBHOOK/URL"* ]] || [ -z "$SLACK_WEBHOOK_URL" ]; then
    echo ""
    echo "⚠️  WARNING: Slack Webhook URL is not configured!"
    echo ""
    echo "Please edit the configuration file and set your Slack Webhook URL:"
    echo "  sudo nano $INSTALL_DIR/config.sh"
    echo ""
    echo "To create a Slack Webhook:"
    echo "  1. Go to https://api.slack.com/apps"
    echo "  2. Create a new app or select existing one"
    echo "  3. Enable 'Incoming Webhooks'"
    echo "  4. Create a new webhook and copy the URL"
    echo ""
else
    echo "✓ Configuration looks good"
fi

echo ""
echo "=========================================="
echo "Installation completed successfully!"
echo "=========================================="
echo ""
echo "Configuration file: $INSTALL_DIR/config.sh"
echo "Notification script: $INSTALL_DIR/notify.sh"
echo "Log file: $LOG_FILE"
echo ""
echo "Notification mode: $NOTIFY_MODE"

if [ "$NOTIFY_MODE" = "whitelist" ]; then
    echo "Whitelisted IPs:"
    for ip in "${WHITELISTED_IPS[@]}"; do
        echo "  - $ip"
    done
fi

echo ""
echo "The SSH login notifier is now active!"
echo "New SSH logins will trigger notifications based on your configuration."
echo ""
echo "To test: SSH into this server from another terminal"
echo "To view logs: tail -f $LOG_FILE"
echo ""
