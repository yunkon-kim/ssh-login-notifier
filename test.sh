#!/bin/bash

# SSH Login Notifier - Test Script
# This script tests the notification system without requiring an actual SSH login

echo "=========================================="
echo "SSH Login Notifier - Test Script"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

INSTALL_DIR="/opt/ssh-login-notifier"

# Check if notifier is installed
if [ ! -f "$INSTALL_DIR/notify.sh" ]; then
    echo "Error: SSH Login Notifier is not installed"
    echo "Please run: sudo bash install.sh"
    exit 1
fi

echo "Testing notification system..."
echo ""

# Test with a simulated IP address
TEST_IP="1.2.3.4"
TEST_USER="test-user"

echo "Simulating SSH login from:"
echo "  IP: $TEST_IP"
echo "  User: $TEST_USER"
echo ""

# Execute notification script
SSH_CLIENT="$TEST_IP 12345 22" USER="$TEST_USER" "$INSTALL_DIR/notify.sh"

echo ""
echo "=========================================="
echo "Test completed!"
echo "=========================================="
echo ""
echo "Please check your Slack channel for the notification."
echo ""
echo "If you received a notification, the system is working correctly!"
echo "If not, please check:"
echo "  1. Slack Webhook URL in config.sh"
echo "  2. Log file: /var/log/ssh-login-notifier.log"
echo "  3. Network connectivity"
echo ""
