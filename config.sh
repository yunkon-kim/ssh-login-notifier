#!/bin/bash

# Slack Webhook URL
# Create a Slack app and add an Incoming Webhook: https://api.slack.com/apps
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# Notification mode
# "all" - Notify on all successful SSH logins (distinguishes trusted vs untrusted)
# "untrusted_only" - Only notify for untrusted IPs (recommended)
NOTIFY_MODE="untrusted_only"

# Whitelisted IP ranges (CIDR notation)
# Only used when NOTIFY_MODE="untrusted_only"
# Add your trusted IP ranges here
WHITELISTED_IPS=(
    "203.0.113.0/24"      # Example: Office network
    "198.51.100.0/24"     # Example: VPN network
    "192.0.2.50/32"       # Example: Single IP
)

# Installation directory
INSTALL_DIR="/opt/ssh-login-notifier"

# Log file location
LOG_FILE="/var/log/ssh-login-notifier.log"
