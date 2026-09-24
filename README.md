# terraform-azurerm-linux-vm

Opinionated Terraform configuration that stands up a single, ready to SSH **Linux VM on Azure**, together with all of its networking, in one `terraform apply`.

Designed for initial testing and lab environments, providing a baseline template to expand upon as requirements evolve. Inbound access is restricted to your IPs, SSH password authentication is disabled, and the VM automatically shuts down each evening to help control costs.

## What it creates

```
Resource Group  <env>-<role>-rg
└── Virtual Network  <env>-<role>-vnet   (vnet_cidr)
    └── Subnet  <env>-<role>-snet        (snet_cidr)
        └── NSG  <env>-<role>-nsg  ← inbound Allow rule:
        │     TCP ports all_ports, source = allowip
        └── Network Interface  <env>-<role>-nic
            ├── Static Public IP  <env>-<role>-pip   → exposed as an output
            └── Linux VM  <env>-<role>-vm-01
                ├── Ubuntu 26.04 LTS (minimal), SSH key auth only
                ├── OS disk: StandardSSD_LRS
                ├── cloud-init custom data (scripts/customdata.tpl)
                └── Daily auto-shutdown @ 18:00 GMT
                    (email alert 30 min before)
```

Every resource is tagged with `AppRole`, `AppEnvironment` and `TerraformManaged = "true"` (see [locals.tf](locals.tf)). The subnet is the exception: `azurerm_subnet` does not support tags, and it inherits tagging from its parent Virtual Network.

## Repository layout

| File                                             | Purpose                                                                        |
| ------------------------------------------------ | ------------------------------------------------------------------------------ |
| [providers.tf](providers.tf)                     | `azurerm` provider (`~> 5.0`) and remote-state backend (optional)              |
| [main.tf](main.tf)                               | All resources: networking, VM, auto shutdown                                   |
| [variables.tf](variables.tf)                     | Input variables with validation rules (sensitive ones marked `sensitive`)      |
| [locals.tf](locals.tf)                           | Shared name prefix and common tags applied to every resource                   |
| [outputs.tf](outputs.tf)                         | `public_ip` output                                                             |
| [terraform.tfvars.dist](terraform.tfvars.dist)   | Template for your `terraform.tfvars` - copy and fill in the `###` placeholders |
| [scripts/customdata.tpl](scripts/customdata.tpl) | Bash script passed to the VM as `custom_data` (runs on first boot)             |
| [keys/](.)                                       | Your SSH public keys live here - **gitignored**                                |

## Requirements

- An Azure subscription
- Azure CLI authenticated locally (`az login`) or equivalent `ARM_*` environment variables / service principal

## Usage

### 1. Configure remote state (optional)
[providers.tf](providers.tf) ships with an `azurerm` backend pointing at an Azure Storage account:

```hcl
backend "azurerm" {
  resource_group_name  = "###"
  storage_account_name = "###"
  container_name       = "tfstate"
  key                  = "terraform.tfstate"
}
```

Replace the `###` placeholders with your storage account details - or leave the whole `backend "azurerm" { ... }` hashed out to keep state locally.

### 2. Add your SSH public key

Place your SSH public key in a `keys/` directory and reference it by filename via the `ssh_public_key` variable:

```
keys/
└── sshkey.pub
```

The `keys/` directory is gitignored, so your keys never leave your machine.

### 3. Create `terraform.tfvars`

```bash
cp terraform.tfvars.dist terraform.tfvars
```

Then fill in the placeholders:
```hcl
# General
env    = "dev"      # environment prefix (dev, staging, prod…)
role   = "app"      # role/app name, used in every resource name
region = "ukwest"   # Azure region

# Azure Subscription
subscription_id = "00000000-0000-0000-0000-000000000000"

# Network
vnet_cidr = "10.0.0.0/16"
snet_cidr = "10.0.1.0/24"

# Virtual Machine
vmsize = "Standard_B2s"

# SSH
admin_user     = "iozak"
ssh_public_key = "sshkey.pub"   # filename inside keys/

# Inbound allowed IPs
allowip = [
  "51.140.0.1/32",   # your office
  "104.237.241.33/32",   # your home
]

# Email address for auto shutdown alerts;
shutdown_alert_email = "iozak@github.com"
```

> `terraform.tfvars` is gitignored - real values stay out of version control.

### 4. Deploy

```bash
terraform init
terraform plan
terraform apply
```

### 5. Connect

```bash
terraform output -raw PublicIP
ssh -i keys/sshkey iozak@$(terraform output -raw PublicIP)
```

## Variables

| Variable               | Description                                                         | Type           | Sensitive |
| ---------------------- | ------------------------------------------------------------------- | -------------- | --------- |
| `env`                  | Environment prefix used in resource names (e.g. `dev`)              | `string`       |           |
| `role`                 | Role/app name used in resource names                                | `string`       |           |
| `region`               | Azure region to deploy into                                         | `string`       |           |
| `vmsize`               | VM size (e.g. `Standard_B2s`)                                       | `string`       |           |
| `allowip`              | CIDRs/IPv4 addresses allowed inbound through the NSG                | `list(string)` |           |
| `shutdown_alert_email` | Email for auto shutdown notifications; empty string disables alerts | `string`       |           |
| `vnet_cidr`            | Virtual Network address space                                       | `string`       |           |
| `snet_cidr`            | Subnet address prefix (must fall inside `vnet_cidr`)                | `string`       |           |
| `admin_user`           | Admin username for SSH                                              | `string`       | ✅         |
| `ssh_public_key`       | Filename of the public key inside `keys/`                           | `string`       | ✅         |
| `subscription_id`      | Azure subscription ID                                               | `string`       | ✅         |

All variables ship with validation rules (lowercase naming, CIDR format, port range, GUID format, `.pub` key filename) so misconfiguration fails fast at `plan` time - see [variables.tf](variables.tf).

## Outputs

| Output      | Description                                     |
| ----------- | ----------------------------------------------- |
| `public_ip` | The static public IP address assigned to the VM |

## Security notes

- **Password auth is disabled** (`disable_password_authentication = true`) - SSH key only.
- The NSG ships with **a single inbound rule** allowing **TCP** traffic on all ports from `allowip` sources.
- Sensitive values (`subscription_id`, `admin_user`, `ssh_public_key`) are declared `sensitive`, and `terraform.tfvars` / `keys/` are gitignored.

## Cost control

The [`azurerm_dev_test_global_vm_shutdown_schedule`](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/dev_test_global_vm_shutdown_schedule) resource **shuts the VM down daily at 18:00 GMT** (configurable in [main.tf](main.tf)), with an optional email notification 30 minutes beforehand. Ideal for lab/dev boxes you forget to switch off.

## Customizing first boot

Anything in [scripts/customdata.tpl](scripts/customdata.tpl) runs on the VM at first boot (passed via `custom_data`). Point it at your own provisioning script or replace it with a full [cloud-init](https://cloudinit.readthedocs.io/) config.

## Cleanup

```bash
terraform destroy
```

## License

Distributed under the [MIT License](LICENSE).
