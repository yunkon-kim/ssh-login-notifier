#!/bin/bash

# SSH Login Notifier Script
# This script sends Slack notifications when SSH login occurs

# Only run on session open (login), not on session close (logout/exit)
# PAM_TYPE is set by PAM: "open_session" for login, "close_session" for logout
if [ "$PAM_TYPE" != "open_session" ]; then
    exit 0
fi

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
    
    # Debug log
    echo "$(date "+%Y-%m-%d %H:%M:%S") - ip_in_cidr: ip=[$ip] cidr=[$cidr]" >> "$LOG_FILE" 2>/dev/null
    
    # Use ipcalc if available, otherwise use Python
    if command -v ipcalc &> /dev/null; then
        ipcalc -c "$ip" "$cidr" &> /dev/null
        local result=$?
        echo "$(date "+%Y-%m-%d %H:%M:%S") - ip_in_cidr: using ipcalc, result=$result" >> "$LOG_FILE" 2>/dev/null
        return $result
    elif command -v python3 &> /dev/null; then
        local python_output
        python_output=$(python3 -c "
import ipaddress
import sys
try:
    ip_addr = ipaddress.ip_address('$ip')
    network = ipaddress.ip_network('$cidr', strict=False)
    result = ip_addr in network
    print(f'DEBUG: ip={ip_addr}, network={network}, in_network={result}', file=sys.stderr)
    sys.exit(0 if result else 1)
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
" 2>&1)
        local result=$?
        echo "$(date "+%Y-%m-%d %H:%M:%S") - ip_in_cidr: using python3, result=$result, output=[$python_output]" >> "$LOG_FILE" 2>/dev/null
        return $result
    else
        # Fallback: cannot check, assume not in range
        echo "$(date "+%Y-%m-%d %H:%M:%S") - ip_in_cidr: no tool available" >> "$LOG_FILE" 2>/dev/null
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

# Check if IP is in whitelist
IS_WHITELISTED=false
if is_whitelisted "$IP"; then
    IS_WHITELISTED=true
fi

# Log the login attempt with whitelist status
echo "$(date "+%Y-%m-%d %H:%M:%S") - SSH login: user=$USER ip=$IP host=$HOST whitelisted=$IS_WHITELISTED" >> "$LOG_FILE" 2>/dev/null

# Check if we should send notification based on mode
SHOULD_NOTIFY=false

if [ "$NOTIFY_MODE" = "all" ]; then
    # In 'all' mode, always notify but distinguish trusted vs untrusted
    SHOULD_NOTIFY=true
    if [ "$IS_WHITELISTED" = true ]; then
        COLOR="#36a64f"  # Green
        STATUS="✅ Logged in"
    else
        COLOR="#ff9900"  # Orange/Warning
        STATUS="⚠️ Untrusted IP"
    fi
elif [ "$NOTIFY_MODE" = "untrusted_only" ]; then
    # In 'untrusted_only' mode, only notify for untrusted IPs
    if [ "$IS_WHITELISTED" = false ]; then
        SHOULD_NOTIFY=true
        COLOR="#ff9900"  # Orange/Warning
        STATUS="⚠️ Untrusted IP"
    fi
fi

# Send notification if required
if [ "$SHOULD_NOTIFY" = true ]; then
    # Get location information (optional, requires internet)
    LOCATION="Unknown"
    if command -v curl &> /dev/null && command -v python3 &> /dev/null; then
        LOCATION=$(curl -s "https://ipapi.co/$IP/json/" 2>/dev/null | \
                   python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    city = data.get('city', '')
    country = data.get('country_name', '')
    if city and country:
        print(f'{city}, {country}')
    elif country:
        print(country)
    else:
        print('Unknown')
except:
    print('Unknown')
" 2>/dev/null)
    fi
    
    # Fallback if location is empty
    if [ -z "$LOCATION" ] || [ "$LOCATION" = "null" ]; then
        LOCATION="Unknown"
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
                -e "s|\$STATUS|$STATUS|g")
        
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
