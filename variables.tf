# --- Variables --- #
variable "env" {
  description = "Set Environment"
  type        = string
}

variable "role" {
  description = "Set Role"
  type        = string
}

variable "region" {
  description = "Set Region"
  type        = string
}

variable "vmsize" {
  description = "Set VM Size"
  type        = string
}

variable "allowip" {
  description = "Allow Inbound IPs"
  type        = list(string)
}

variable "shutdown_alert_email" {
  description = "Email for Shutdown Alerts"
  type        = string
}

variable "vnet_cidr" {
  description = "Set Virtual Network CIDR"
  type        = string
}

variable "snet_cidr" {
  description = "Set Subnet CIDR"
  type        = string
}

variable "admin_user" {
  description = "Admin Username for SSH"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH Public Key"
  type        = string
  sensitive   = true
}

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
  sensitive   = true
}