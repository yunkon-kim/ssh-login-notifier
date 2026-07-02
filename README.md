# SSH Login Notifier

Real-time SSH login monitoring and Slack notification tool for security

## What is this?

A security monitoring tool that automatically sends Slack notifications when someone logs into your AWS VM via SSH. It leverages PAM (Pluggable Authentication Modules) to track login sessions and supports IP whitelist-based selective notifications.

## When to use?

- Multiple VMs requiring real-time access monitoring
- Additional security layer beyond Security Groups
- Test environments with frequent redeployments needing automated setup

## Key Features

- Real-time Slack notifications with IP geolocation
- IP whitelist-based selective alerts
- Bootstrapping support for automated setup

## How It Works

1. **PAM Hook**: Adds `pam_exec.so` module to `/etc/pam.d/sshd`
2. **Session Info Collection**: Extracts IP from `$SSH_CLIENT` environment variable
3. **IP Validation**: Uses Python's `ipaddress` module for CIDR-based whitelist checking
4. **Geolocation Lookup**: Queries ip-api.com API for geographic location (free, no API key required)
5. **Slack Notification**: Sends JSON message via Webhook
6. **Logging**: Records all login attempts to file

## Prerequisites

<details>
<summary>💡 <strong>First-time users only</strong> - Click to expand prerequisites</summary>

### 1. Prepare Slack Webhook URL

**Create a Slack Webhook URL in advance:**

1. Visit [Slack API page](https://api.slack.com/apps?new_app=1)
2. Click "Create New App" → "From scratch"
3. Enter app name (e.g., "SSH Login Monitor") and select Workspace
4. Go to "Incoming Webhooks" → Turn "Activate Incoming Webhooks" ON
5. Click "Add New Webhook to Workspace" → Select notification channel
6. Copy the generated Webhook URL (format: `https://hooks.slack.com/services/T.../B.../XXX...`)
7. Save it securely (will be used in Step 2)

### 2. Identify Trusted IP Ranges

Determine which IP ranges should be whitelisted (office network, VPN, admin IPs, etc.)

```bash
# Check your current IP (if you want to whitelist yourself)
curl ifconfig.me
```

### 3. System Requirements

- Linux server (Ubuntu 18.04+, CentOS 7+, Amazon Linux 2+)
- Root or sudo privileges
- Internet connection (for Slack API communication)
- curl, python3 (auto-installed if missing)

</details>

---

## Step-by-Step Usage Guide

### Step 1: Download the Project

After SSH into your server, download the project:

```bash
cd /tmp
git clone https://github.com/yunkon-kim/ssh-login-notifier.git
cd ssh-login-notifier
```

### Step 2: Configure Settings

Open `config.sh` and configure your Slack Webhook URL and IP whitelist:

```bash
vi config.sh  # or nano, vim, etc.
```

**Required settings:**

```bash
# 1. Set Slack Webhook URL (from Prerequisites)
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXX"

# 2. Select notification mode
NOTIFY_MODE="untrusted_only"  # "all" or "untrusted_only"

# 3. Whitelist IP ranges (CIDR notation)
WHITELISTED_IPS=(
    "203.0.113.0/24"      # e.g., Office network
    "198.51.100.0/24"     # e.g., VPN network
    "192.0.2.50/32"       # e.g., Admin IP (single IP uses /32)
)
```

**Notification modes:**

- `all`: Notify on all SSH logins (distinguishes trusted vs untrusted IPs)
- `untrusted_only`: Notify only for untrusted IPs (recommended)

### Step 3: Run Installation

```bash
sudo bash install.sh
```

The installation automatically:

- Installs required packages (curl, python3)
- Copies files to `/opt/ssh-login-notifier/`
- Configures PAM settings
- Creates log file

### Step 4: Test

SSH from a **new terminal**:

```bash
ssh username@your-server-ip
```

Check for notification in Slack!

**View logs:**

```bash
sudo tail -f /var/log/ssh-login-notifier.log
```

---

## Bootstrapping Script

For automated installation (cloud-init, provisioning tools, or any Linux server):

```bash
#!/bin/bash
cd /tmp
git clone https://github.com/yunkon-kim/ssh-login-notifier.git
cd ssh-login-notifier

cat > config.sh << 'EOF'
#!/bin/bash
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
NOTIFY_MODE="untrusted_only"
WHITELISTED_IPS=(
    "203.0.113.0/24"
    "198.51.100.0/24"
)
INSTALL_DIR="/opt/ssh-login-notifier"
LOG_FILE="/var/log/ssh-login-notifier.log"
EOF

sudo bash install.sh
```

### Remote Installation via SSH

Install on remote servers from your local machine.

**Step 1**: Create your installation script from template:

```bash
# Copy template
cp remote-install.sh.template remote-install.sh

# Edit with your actual Slack Webhook URL and IP whitelist
vi remote-install.sh  # or nano, vim, etc.
```

**Step 2**: Run the remote installation command:

```bash
# Single server
ssh user@remote-server 'bash -s' < remote-install.sh

# With private key
ssh -i /path/to/private-key.pem user@remote-server 'bash -s' < remote-install.sh

# Multiple servers
for server in user@server1 user@server2 user@server3; do
    ssh "$server" 'bash -s' < remote-install.sh
done

# Multiple servers with private key
KEY_FILE="/path/to/private-key.pem"
for server in user@server1 user@server2 user@server3; do
    ssh -i "$KEY_FILE" "$server" 'bash -s' < remote-install.sh
done
```

**Step 3**: Uninstall remotely (if needed):

```bash
# Single server
ssh user@remote-server 'sudo bash /opt/ssh-login-notifier/uninstall.sh'

# With private key
ssh -i /path/to/private-key.pem user@remote-server 'sudo bash /opt/ssh-login-notifier/uninstall.sh'

# Multiple servers
for server in user@server1 user@server2 user@server3; do
    ssh "$server" 'sudo bash /opt/ssh-login-notifier/uninstall.sh'
done

---

## Automated Deployment Examples

### OpenTofu/Terraform

Add SSH login monitoring to your existing infrastructure configuration.

**Add these files to your existing OpenTofu project:**

```

your-project/
├── user_data.sh.tpl (create this)
├── terraform.tfvars (add SSH notifier variables)
└── ... (your existing .tf files)

````

**Add to your existing OpenTofu/Terraform configuration:**

**1. Add variables** (in `variables.tf` or inline)

```hcl
variable "slack_webhook_url" {
  description = "Slack Webhook URL for SSH login notifications"
  type        = string
  sensitive   = true
}

variable "whitelisted_ips" {
  description = "Whitelisted IP ranges (CIDR notation)"
  type        = list(string)
  default     = ["203.0.113.0/24", "198.51.100.0/24"]
}
````

**2. Create `user_data.sh.tpl` template file**

```bash
#!/bin/bash
cd /tmp
git clone https://github.com/yunkon-kim/ssh-login-notifier.git
cd ssh-login-notifier

cat > config.sh << 'EOF'
#!/bin/bash
SLACK_WEBHOOK_URL="${slack_webhook_url}"
NOTIFY_MODE="untrusted_only"
WHITELISTED_IPS=(
%{ for ip in jsondecode(whitelisted_ips) ~}
    "${ip}"
%{ endfor ~}
)
INSTALL_DIR="/opt/ssh-login-notifier"
LOG_FILE="/var/log/ssh-login-notifier.log"
EOF

sudo bash install.sh
```

**3. Add `user_data` to your EC2 instance resource**

```hcl
resource "aws_instance" "your_instance" {
  # ... your existing configuration (ami, instance_type, etc.)

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    slack_webhook_url = var.slack_webhook_url
    whitelisted_ips   = jsonencode(var.whitelisted_ips)
  })
}
```

**4. Create `terraform.tfvars`** (⚠️ Don't commit this file!)

```hcl
slack_webhook_url = "https://hooks.slack.com/services/YOUR/ACTUAL/WEBHOOK"
whitelisted_ips   = [
  "203.0.113.0/24",  # Office network
  "198.51.100.0/24", # VPN
]
```

**5. Deploy:**

```bash
tofu init
tofu plan
tofu apply
```

**Verify:**

```bash
# SSH to any instance
ssh ubuntu@<instance-ip>

# Check Slack for notification
# View logs: sudo tail -f /var/log/ssh-login-notifier.log
```

---

## Configuration & Usage

### Modifying IP Whitelist

```bash
# Edit configuration file
sudo vi /opt/ssh-login-notifier/config.sh  # or nano, vim, etc.

# Changes apply immediately after save (no restart needed)
```

### CIDR Notation

- `192.168.1.0/24`: 192.168.1.0 ~ 192.168.1.255 (256 IPs)
- `10.0.0.0/16`: 10.0.0.0 ~ 10.0.255.255 (65,536 IPs)
- `203.0.113.50/32`: Single IP

### Viewing Logs

```bash
# Real-time log monitoring
tail -f /var/log/ssh-login-notifier.log

# Search for specific IP
grep "1.2.3.4" /var/log/ssh-login-notifier.log
```

---

## Notification Message Example

### Untrusted Only Mode (Recommended)

**Untrusted IP** (notification sent):

```
⚠️ Untrusted IP ip-172-31-19-69 - ubuntu from 129.254.75.2 (Seoul, South Korea)
```

**Trusted IP** (no notification):

```
(No notification)
```

### All Mode

**Untrusted IP**:

```
⚠️ Untrusted IP ip-172-31-19-69 - ubuntu from 129.254.75.2 (Seoul, South Korea)
```

**Trusted IP**:

```
✅ Logged in ip-172-31-19-69 - ubuntu from 203.0.113.50 (Seoul, South Korea)
```

---

## Troubleshooting

### No Notifications Received

```bash
# 1. Verify Webhook URL
sudo cat /opt/ssh-login-notifier/config.sh

# 2. Check PAM configuration
grep "ssh-login-notifier" /etc/pam.d/sshd

# 3. Manual test
sudo SSH_CLIENT="1.2.3.4 12345 22" /opt/ssh-login-notifier/notify.sh

# 4. Check logs
tail -20 /var/log/ssh-login-notifier.log
```

### Uninstallation

```bash
sudo bash uninstall.sh
```

---

## FAQ

**Q: Does this affect SSH connections?**  
A: No. It operates in PAM's `optional` mode, so notification failures don't impact SSH logins.

**Q: How to install on multiple servers simultaneously?**  
A: Use the [Bootstrapping Script](#bootstrapping-script) or IaC tools like OpenTofu/Terraform. (See [Automated Deployment Examples](#automated-deployment-examples))

**Q: Can I use messengers other than Slack?**  
A: Yes, modify `notify.sh` to support Discord, Teams, Telegram, etc.

**Q: Does it detect failed logins?**  
A: Currently only successful logins. For failures, use tools like Fail2Ban.

**Q: Are there any costs?**  
A: The tool and Slack Webhook are free. IP geolocation API is free up to 1,000 requests/month.

---

## References

### Original Inspiration

This project is based on [vaibhavpandeyvpz's gist](https://gist.github.com/vaibhavpandeyvpz/5d27b3e8d0591e76ebb1339ae68cd517) with the following enhancements:

- IP whitelist functionality
- Automated installation script (Bootstrapping)
- Selective notification modes
- IP geolocation display
- AWS deployment automation

### Documentation

- [Linux PAM Documentation](https://linux.die.net/man/5/pam.d)
- [pam_exec Module](https://linux.die.net/man/8/pam_exec)
- [Slack Incoming Webhooks](https://api.slack.com/messaging/webhooks)
- [EC2 User Data Guide](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html)

---

## License

MIT License - Free to use, modify, and distribute.

Original author: [vaibhavpandeyvpz](https://gist.github.com/vaibhavpandeyvpz)  
Enhanced by: Yunkon Kim

---

**Contributing**: Issues and PRs welcome! [GitHub Repository](https://github.com/yunkon-kim/ssh-login-notifier)
