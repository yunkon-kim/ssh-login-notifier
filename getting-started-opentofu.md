# Getting Started: OpenTofu/Terraform Deployment

Automate SSH Login Notifier installation using Infrastructure as Code (IaC).

## Prerequisites

- Slack Webhook URL ([Get one here](https://api.slack.com/apps?new_app=1))
- OpenTofu or Terraform installed
- Existing infrastructure code or new project
- Cloud provider credentials configured (AWS, Azure, GCP, etc.)

## Quick Start

This guide adds SSH Login Notifier to your existing infrastructure. We'll use AWS EC2 as an example, but the approach works for any cloud provider.

## Step 1: Add Variables

In your `variables.tf` (or create it if it doesn't exist):

```hcl
variable "slack_webhook_url" {
  description = "Slack Webhook URL for SSH login notifications"
  type        = string
  sensitive   = true
}

variable "whitelisted_ips" {
  description = "Trusted IP ranges in CIDR notation"
  type        = list(string)
  default     = []
}

variable "notify_mode" {
  description = "Notification mode: 'all' or 'untrusted_only'"
  type        = string
  default     = "untrusted_only"
}
```

## Step 2: Create User Data Template

Create `user_data.sh.tpl` in your project root:

```bash
#!/bin/bash
set -e

# Wait for cloud-init to complete
cloud-init status --wait

# Install SSH Login Notifier
cd /tmp
git clone https://github.com/yunkon-kim/ssh-login-notifier.git
cd ssh-login-notifier

# Generate config
cat > config.sh << 'EOF'
#!/bin/bash
SLACK_WEBHOOK_URL="${slack_webhook_url}"
NOTIFY_MODE="${notify_mode}"
WHITELISTED_IPS=(
%{ for ip in whitelisted_ips ~}
    "${ip}"
%{ endfor ~}
)
INSTALL_DIR="/opt/ssh-login-notifier"
LOG_FILE="/var/log/ssh-login-notifier.log"
EOF

# Run installation
bash install.sh

# Log completion
echo "$(date) - SSH Login Notifier installed" >> /var/log/user-data.log
```

## Step 3: Update Your Resource Configuration

### AWS EC2 Example

In your `main.tf` (or wherever you define instances):

```hcl
resource "aws_instance" "web_server" {
  ami           = "ami-0c55b159cbfafe1f0"  # Ubuntu 22.04 LTS
  instance_type = "t3.micro"
  key_name      = "your-key-pair"

  vpc_security_group_ids = [aws_security_group.web_sg.id]
  subnet_id              = aws_subnet.public.id

  # Add SSH Login Notifier via user_data
  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    slack_webhook_url = var.slack_webhook_url
    notify_mode       = var.notify_mode
    whitelisted_ips   = var.whitelisted_ips
  })

  tags = {
    Name = "web-server"
  }
}
```

### Azure VM Example

```hcl
resource "azurerm_linux_virtual_machine" "web_server" {
  name                = "web-server"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  # Add SSH Login Notifier
  custom_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    slack_webhook_url = var.slack_webhook_url
    notify_mode       = var.notify_mode
    whitelisted_ips   = var.whitelisted_ips
  }))
}
```

### GCP Compute Instance Example

```hcl
resource "google_compute_instance" "web_server" {
  name         = "web-server"
  machine_type = "e2-micro"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  # Add SSH Login Notifier
  metadata_startup_script = templatefile("${path.module}/user_data.sh.tpl", {
    slack_webhook_url = var.slack_webhook_url
    notify_mode       = var.notify_mode
    whitelisted_ips   = var.whitelisted_ips
  })
}
```

## Step 4: Configure Values

Create `terraform.tfvars` (or `terraform.auto.tfvars`):

```hcl
slack_webhook_url = "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXX"
notify_mode       = "untrusted_only"
whitelisted_ips   = [
  "203.0.113.0/24",      # Office network
  "198.51.100.0/24",     # VPN
  "192.0.2.50/32",       # Admin workstation
]
```

⚠️ **Security:** Add to `.gitignore`:

```bash
echo "terraform.tfvars" >> .gitignore
echo "*.auto.tfvars" >> .gitignore
```

**Alternative:** Use environment variables:

```bash
export TF_VAR_slack_webhook_url="https://hooks.slack.com/services/..."
export TF_VAR_notify_mode="untrusted_only"
export TF_VAR_whitelisted_ips='["203.0.113.0/24","198.51.100.0/24"]'
```

## Step 5: Deploy

```bash
# Initialize
tofu init  # or: terraform init

# Preview changes
tofu plan  # or: terraform plan

# Apply
tofu apply  # or: terraform apply
```

## Step 6: Verify

After deployment (wait ~2 minutes for cloud-init to complete):

```bash
# Get instance IP
INSTANCE_IP=$(tofu output -raw instance_public_ip)

# SSH to test
ssh ubuntu@$INSTANCE_IP

# Check notification in Slack
# Check logs on instance
ssh ubuntu@$INSTANCE_IP 'sudo tail -f /var/log/ssh-login-notifier.log'
```

## Complete Example Project

Here's a minimal complete project structure:

```
my-infrastructure/
├── main.tf
├── variables.tf
├── outputs.tf
├── user_data.sh.tpl
├── terraform.tfvars     # gitignored
└── .gitignore
```

**main.tf:**

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
  key_name      = var.ssh_key_name

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    slack_webhook_url = var.slack_webhook_url
    notify_mode       = var.notify_mode
    whitelisted_ips   = var.whitelisted_ips
  })

  tags = {
    Name = "ssh-monitored-server"
  }
}
```

**outputs.tf:**

```hcl
output "instance_public_ip" {
  description = "Public IP of the instance"
  value       = aws_instance.web.public_ip
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh ubuntu@${aws_instance.web.public_ip}"
}
```

**.gitignore:**

```
# Terraform
.terraform/
*.tfstate
*.tfstate.*
terraform.tfvars
*.auto.tfvars

# Secrets
remote-install.sh
```

## Advanced: Multiple Environments

**Directory structure:**

```
infrastructure/
├── modules/
│   └── monitored-instance/
│       ├── main.tf
│       ├── variables.tf
│       └── user_data.sh.tpl
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   └── terraform.tfvars
│   └── prod/
│       ├── main.tf
│       └── terraform.tfvars
```

**modules/monitored-instance/main.tf:**

```hcl
resource "aws_instance" "this" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    slack_webhook_url = var.slack_webhook_url
    notify_mode       = var.notify_mode
    whitelisted_ips   = var.whitelisted_ips
  })

  tags = merge(var.tags, {
    ManagedBy = "Terraform"
  })
}
```

**environments/prod/main.tf:**

```hcl
module "web_servers" {
  source = "../../modules/monitored-instance"
  count  = 3

  ami_id            = "ami-0c55b159cbfafe1f0"
  instance_type     = "t3.small"
  key_name          = "prod-key"
  slack_webhook_url = var.slack_webhook_url
  notify_mode       = "untrusted_only"
  whitelisted_ips   = var.prod_whitelisted_ips
}
```

## Troubleshooting

### User Data Not Running

```bash
# Check cloud-init logs
ssh ubuntu@instance-ip 'sudo cat /var/log/cloud-init-output.log'

# Check user-data execution
ssh ubuntu@instance-ip 'sudo journalctl -u cloud-final'
```

### Installation Failed

```bash
# View full user-data log
ssh ubuntu@instance-ip 'sudo cat /var/log/user-data.log'

# Check notifier logs
ssh ubuntu@instance-ip 'sudo cat /var/log/ssh-login-notifier.log'

# Verify files installed
ssh ubuntu@instance-ip 'ls -la /opt/ssh-login-notifier/'
```

### Variable Substitution Issues

```bash
# Test template rendering locally
terraform console
> templatefile("user_data.sh.tpl", {
    slack_webhook_url = "test-url",
    notify_mode = "all",
    whitelisted_ips = ["192.168.1.0/24"]
  })
```

## Update Existing Instances

To add SSH Login Notifier to already-running instances:

1. **Update configuration** with user_data
2. **Recreate instances:**
   ```bash
   tofu taint aws_instance.web_server
   tofu apply
   ```

Or use the [remote installation method](getting-started-remote.md) for existing instances.

## Next Steps

- [View main README](README.md)
- [Remote SSH installation guide](getting-started-remote.md)
- [Configure advanced settings](README.md#configuration)
