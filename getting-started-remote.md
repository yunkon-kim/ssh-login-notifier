# Getting Started: Remote Installation via SSH

Install SSH Login Notifier on remote servers using SSH commands from your local machine.

## Prerequisites

- Slack Webhook URL ([Get one here](https://api.slack.com/apps?new_app=1))
- SSH access to target server(s)
- Server requirements: Linux (Ubuntu 18.04+, CentOS 7+, Amazon Linux 2+), sudo privileges

## Step 1: Prepare Installation Script

On your **local machine**, create the installation script:

```bash
# Download the template
curl -O https://raw.githubusercontent.com/yunkon-kim/ssh-login-notifier/main/remote-install.sh.template

# Copy to working file
cp remote-install.sh.template remote-install.sh
```

## Step 2: Configure Settings

Edit `remote-install.sh` with your settings:

```bash
nano remote-install.sh  # or vi, vim, code, etc.
```

**Update these lines:**

```bash
# Replace with your actual Slack Webhook URL
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# Set notification mode
NOTIFY_MODE="untrusted_only"  # or "all"

# Add your trusted IP ranges
WHITELISTED_IPS=(
    "203.0.113.0/24"      # Office network
    "198.51.100.0/24"     # VPN
    "192.0.2.50/32"       # Specific admin IP (single IP uses /32)
)
```

**Notification Modes:**

- `untrusted_only`: Only alert on unknown IPs (recommended)
- `all`: Alert on all logins, distinguish trusted vs untrusted

**CIDR Examples:**

- `192.168.1.0/24` = 256 IPs (192.168.1.0 ~ 192.168.1.255)
- `10.0.0.0/16` = 65,536 IPs (10.0.0.0 ~ 10.0.255.255)
- `192.168.1.50/32` = Single IP (192.168.1.50)

**Check your current IP:**

```bash
curl ifconfig.me
```

## Step 3: Install on Remote Server(s)

### Single Server

```bash
ssh user@remote-server 'bash -s' < remote-install.sh
```

**With private key:**

```bash
ssh -i ~/.ssh/your-key.pem user@remote-server 'bash -s' < remote-install.sh
```

### Multiple Servers

```bash
# Method 1: Loop through servers
for server in user@server1 user@server2 user@server3; do
    ssh "$server" 'bash -s' < remote-install.sh
done

# Method 2: With private key
KEY_FILE="~/.ssh/your-key.pem"
for server in ubuntu@10.0.1.10 ubuntu@10.0.1.11 ubuntu@10.0.1.12; do
    ssh -i "$KEY_FILE" "$server" 'bash -s' < remote-install.sh
done
```

**AWS EC2 Example:**

```bash
#!/bin/bash
KEY="~/.ssh/my-aws-key.pem"
SERVERS=(
    "ubuntu@ec2-54-123-45-67.compute-1.amazonaws.com"
    "ubuntu@ec2-54-123-45-68.compute-1.amazonaws.com"
    "ubuntu@ec2-54-123-45-69.compute-1.amazonaws.com"
)

for server in "${SERVERS[@]}"; do
    echo "Installing on $server..."
    ssh -i "$KEY" "$server" 'bash -s' < remote-install.sh
    echo "✓ $server completed"
done
```

## Step 4: Test

**Test the installation:**

1. SSH into one of the servers:

   ```bash
   ssh -i ~/.ssh/your-key.pem user@remote-server
   ```

2. Check Slack for notification

3. View logs on server:
   ```bash
   sudo tail -f /var/log/ssh-login-notifier.log
   ```

**Expected log output:**

```
2026-07-06 10:30:15 - SSH login: user=ubuntu ip=129.254.75.2 host=ip-172-31-24-9 whitelisted=true
2026-07-06 10:30:15 - Notification sent to Slack for IP: 129.254.75.2
```

## Verify Installation

```bash
# Check installed files
ssh user@remote-server 'ls -la /opt/ssh-login-notifier/'

# Check PAM configuration
ssh user@remote-server 'grep "ssh-login-notifier" /etc/pam.d/sshd'

# Manual test notification
ssh user@remote-server 'sudo SSH_CLIENT="1.2.3.4 12345 22" PAM_TYPE="open_session" /opt/ssh-login-notifier/notify.sh'
```

## Update Configuration

To change settings after installation:

```bash
# Edit config on remote server
ssh user@remote-server 'sudo nano /opt/ssh-login-notifier/config.sh'

# Changes take effect immediately (no restart needed)
```

## Uninstall

### Single Server

```bash
ssh user@remote-server 'sudo bash /opt/ssh-login-notifier/uninstall.sh'
```

### Multiple Servers

```bash
KEY_FILE="~/.ssh/your-key.pem"
for server in user@server1 user@server2 user@server3; do
    ssh -i "$KEY_FILE" "$server" 'sudo bash /opt/ssh-login-notifier/uninstall.sh'
done
```

## Troubleshooting

### No Notification Received

```bash
# 1. Check Webhook URL
ssh user@remote-server 'sudo grep SLACK_WEBHOOK_URL /opt/ssh-login-notifier/config.sh'

# 2. Check logs
ssh user@remote-server 'sudo tail -30 /var/log/ssh-login-notifier.log'

# 3. Test manually
ssh user@remote-server 'sudo SSH_CLIENT="1.2.3.4 12345 22" PAM_TYPE="open_session" /opt/ssh-login-notifier/notify.sh'
```

### SSH Permission Denied

```bash
# Ensure correct key permissions
chmod 600 ~/.ssh/your-key.pem

# Verify SSH access
ssh -i ~/.ssh/your-key.pem user@remote-server 'echo "Connection OK"'
```

### Installation Fails

```bash
# Check server connectivity
ping remote-server

# Verify sudo access
ssh user@remote-server 'sudo echo "Sudo OK"'

# Check script syntax
bash -n remote-install.sh
```

## Security Notes

⚠️ **Never commit `remote-install.sh` with real credentials to git**

The file is already in `.gitignore`. To be safe:

```bash
# Verify it's ignored
git status | grep remote-install.sh

# If not ignored, add to .gitignore
echo "remote-install.sh" >> .gitignore
```

## Next Steps

- [View main README](README.md)
- [OpenTofu/Terraform deployment guide](getting-started-opentofu.md)
- [Configure advanced settings](README.md#configuration)
