#!/bin/bash

# SSH Login Notifier Script
# This script sends Slack notifications when SSH login occurs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
else
    echo "Error: config.sh not found" >&2
    exit 1
fi

# Function to check if IP is in CIDR range
ip_in_cidr() {
    local ip=$1
    local cidr=$2
    
    # Use ipcalc if available, otherwise use Python
    if command -v ipcalc &> /dev/null; then
        ipcalc -c "$ip" "$cidr" &> /dev/null
        return $?
    elif command -v python3 &> /dev/null; then
        python3 -c "
import ipaddress
import sys
try:
    if ipaddress.ip_address('$ip') in ipaddress.ip_network('$cidr', strict=False):
        sys.exit(0)
    else:
        sys.exit(1)
except:
    sys.exit(1)
"
        return $?
    else
        # Fallback: cannot check, assume not in range
        return 1
    fi
}

# Function to check if IP is whitelisted
is_whitelisted() {
    local ip=$1
    
    for cidr in "${WHITELISTED_IPS[@]}"; do
        if ip_in_cidr "$ip" "$cidr"; then
            return 0
        fi
    done
    
    return 1
}

# Get login information
# PAM provides these environment variables:
# - PAM_USER: the username
# - PAM_RHOST: the remote host (IP address)
# - SSH_CLIENT: format "IP PORT DEST_PORT" (if available)

# Try to get IP from SSH_CLIENT first, fall back to PAM_RHOST
if [ -n "$SSH_CLIENT" ]; then
    SSH_CLIENT_STR=($SSH_CLIENT)
    IP=${SSH_CLIENT_STR[0]}
elif [ -n "$PAM_RHOST" ]; then
    IP=$PAM_RHOST
else
    IP="unknown"
fi

# Try to get user from PAM_USER first, fall back to USER
if [ -n "$PAM_USER" ]; then
    USER=$PAM_USER
elif [ -n "$USER" ]; then
    USER=$USER
else
    USER="unknown"
fi

HOST=$(hostname)
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S %Z")

# Log the login attempt
echo "$(date "+%Y-%m-%d %H:%M:%S") - SSH login: user=$USER ip=$IP host=$HOST" >> "$LOG_FILE" 2>/dev/null

# Check if we should send notification based on mode
SHOULD_NOTIFY=false

if [ "$NOTIFY_MODE" = "all" ]; then
    SHOULD_NOTIFY=true
    COLOR="#36a64f"  # Green
    TITLE="✅ SSH Login Detected"
elif [ "$NOTIFY_MODE" = "whitelist" ]; then
    if ! is_whitelisted "$IP"; then
        SHOULD_NOTIFY=true
        COLOR="#ff9900"  # Orange/Warning
        TITLE="⚠️  SSH Login from Non-Whitelisted IP"
    fi
fi

# Send notification if required
if [ "$SHOULD_NOTIFY" = true ]; then
    # Get location information (optional, requires internet)
    LOCATION="Unknown"
    if command -v curl &> /dev/null; then
        LOCATION=$(curl -s "https://ipapi.co/$IP/json/" 2>/dev/null | \
                   python3 -c "import sys, json; data=json.load(sys.stdin); print(f\"{data.get('city', 'Unknown')}, {data.get('region', '')}, {data.get('country_name', 'Unknown')}\")" 2>/dev/null || echo "Unknown")
    fi
    
    # Load message template
    if [ -f "$SCRIPT_DIR/slack_message.json" ]; then
        MESSAGE_ORIGINAL=$(< "$SCRIPT_DIR/slack_message.json")
        
        # Replace variables in message
        MESSAGE_REPLACED=$(echo "$MESSAGE_ORIGINAL" | \
            sed -e "s|\$HOST|$HOST|g" \
                -e "s|\$IP|$IP|g" \
                -e "s|\$USER|$USER|g" \
                -e "s|\$TIMESTAMP|$TIMESTAMP|g" \
                -e "s|\$LOCATION|$LOCATION|g" \
                -e "s|\$COLOR|$COLOR|g" \
                -e "s|\$TITLE|$TITLE|g")
        
        # Send to Slack
        curl --silent --output /dev/null \
            -X POST \
            -H 'Content-type: application/json' \
            --data "$MESSAGE_REPLACED" \
            "$SLACK_WEBHOOK_URL" 2>/dev/null
        
        echo "$(date "+%Y-%m-%d %H:%M:%S") - Notification sent to Slack for IP: $IP" >> "$LOG_FILE" 2>/dev/null
    else
        echo "Error: slack_message.json not found" >&2
    fi
fi

exit 0
