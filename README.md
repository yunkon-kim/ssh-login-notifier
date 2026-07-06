# SSH Login Notifier

Real-time SSH login monitoring with Slack notifications

## What is this?

A lightweight security monitoring tool that sends Slack notifications when someone logs into your Linux server via SSH. It uses PAM (Pluggable Authentication Modules) to detect logins and supports IP whitelist for filtering trusted sources.

**Key Features:**

- 🔔 Real-time Slack notifications with IP geolocation
- 🛡️ IP whitelist-based selective alerts (CIDR support)
- 🚀 Remote installation via SSH or OpenTofu/Terraform
- 📝 Comprehensive logging

**Example Notification:**

```
⚠️ Untrusted IP 129.254.75.2 from Seoul, South Korea logged in as ubuntu to ip-172-31-19-69
✅ Trusted IP 203.0.113.50 from New York, United States logged in as ubuntu to ip-172-31-19-69
```

## How It Works

```
SSH Login → PAM Hook → Extract IP → Check Whitelist → Get Location → Send to Slack
```

1. **PAM Hook**: `pam_exec.so` module intercepts SSH sessions
2. **IP Extraction**: Reads `$SSH_CLIENT` environment variable
3. **Whitelist Check**: Python `ipaddress` module validates against CIDR ranges
4. **Geolocation**: Queries ip-api.com (free, no API key)
5. **Notification**: Sends formatted message to Slack Webhook
6. **Logging**: Records all attempts to `/var/log/ssh-login-notifier.log`

## Project Structure

```
ssh-login-notifier/
├── config.sh                      # Main configuration (Slack URL, whitelist IPs)
├── notify.sh                      # Core notification script (called by PAM)
├── slack_message.json             # Slack message template
├── install.sh                     # Local installation script
├── uninstall.sh                   # Removal script
├── remote-install.sh.template     # Remote installation template
├── remote-install.sh              # Your customized remote installer (gitignored)
├── test.sh                        # Manual testing script
├── README.md                      # This file
├── getting-started-remote.md      # SSH remote installation guide
└── getting-started-opentofu.md    # OpenTofu/Terraform deployment guide
```

**Key Files:**

- **config.sh**: Set Slack Webhook URL, notification mode, and IP whitelist
- **notify.sh**: Main logic for IP checking and Slack notification
- **install.sh**: Installs dependencies, copies files, configures PAM
- **remote-install.sh.template**: Template for remote deployment

## Prerequisites

Before you begin, prepare:

1. **Slack Webhook URL**
   - Visit [Slack API](https://api.slack.com/apps?new_app=1) → Create New App
   - Enable "Incoming Webhooks" → Add webhook to your channel
   - Copy webhook URL (format: `https://hooks.slack.com/services/T.../B.../XXX...`)

2. **IP Whitelist** (optional but recommended)
   - Identify trusted IP ranges (office, VPN, admin IPs)
   - Use CIDR notation: `203.0.113.0/24` (range) or `203.0.113.50/32` (single IP)
   - Check your current IP: `curl ifconfig.me`

3. **System Requirements**
   - Linux server (Ubuntu 18.04+, CentOS 7+, Amazon Linux 2+)
   - Root or sudo privileges
   - Internet connection

## Getting Started

Choose your deployment method:

### 📡 [Remote Installation via SSH](getting-started-remote.md)

Install from your local machine to one or multiple remote servers using SSH commands.

- ✅ Best for: Manual setup, ad-hoc deployments, testing
- ⏱️ Setup time: 5 minutes

### 🏗️ [OpenTofu/Terraform Deployment](getting-started-opentofu.md)

Automate installation during infrastructure provisioning with IaC tools.

- ✅ Best for: Production, multiple instances, repeatable deployments
- ⏱️ Setup time: 10 minutes

## Configuration

After installation, settings are in `/opt/ssh-login-notifier/config.sh`:

```bash
# Notification mode
NOTIFY_MODE="untrusted_only"  # or "all"

# IP whitelist (CIDR notation)
WHITELISTED_IPS=(
    "203.0.113.0/24"      # Office network
    "198.51.100.0/24"     # VPN
    "192.0.2.50/32"       # Specific admin IP
)
```

**Notification Modes:**

- `untrusted_only`: Only alert on unknown IPs (recommended)
- `all`: Alert on all logins, mark trusted vs untrusted

**Changes take effect immediately** (no restart needed)

## Logs & Troubleshooting

**View logs:**

```bash
# Real-time monitoring
tail -f /var/log/ssh-login-notifier.log

# Search for specific IP
grep "1.2.3.4" /var/log/ssh-login-notifier.log
```

**Manual test:**

```bash
sudo SSH_CLIENT="1.2.3.4 12345 22" PAM_TYPE="open_session" /opt/ssh-login-notifier/notify.sh
```

**Verify installation:**

```bash
# Check PAM configuration
grep "ssh-login-notifier" /etc/pam.d/sshd

# Check files
ls -la /opt/ssh-login-notifier/
```

**Uninstall:**

```bash
sudo bash /opt/ssh-login-notifier/uninstall.sh
```

## FAQ

**Q: Does this affect SSH connections?**  
A: No. It runs in PAM's `optional` mode—notification failures won't block logins.

**Q: What about failed login attempts?**  
A: This tracks successful logins only. For failed attempts, use Fail2Ban or similar tools.

**Q: Can I use other messengers?**  
A: Yes. Modify `notify.sh` to support Discord, Teams, Telegram, etc.

**Q: Any costs?**  
A: Free. Slack Webhook is free. IP geolocation API (ip-api.com) is free for up to 1,000 requests/month.

## References

**Original Inspiration:**  
Based on [vaibhavpandeyvpz's gist](https://gist.github.com/vaibhavpandeyvpz/5d27b3e8d0591e76ebb1339ae68cd517) with enhancements:

- IP whitelist functionality
- Automated installation
- Selective notification modes
- Geolocation display

**Documentation:**

- [Linux PAM](https://linux.die.net/man/5/pam.d)
- [Slack Webhooks](https://api.slack.com/messaging/webhooks)
- [EC2 User Data](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html)

## License

MIT License

Original: [vaibhavpandeyvpz](https://gist.github.com/vaibhavpandeyvpz)  
Enhanced: Yunkon Kim

---

**Contributing**: Issues and PRs welcome! [GitHub Repository](https://github.com/yunkon-kim/ssh-login-notifier)
