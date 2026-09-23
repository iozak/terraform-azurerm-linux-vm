# --- Resource Group --- #
resource "azurerm_resource_group" "ResourceGroup" {
  name     = "${local.name_prefix}-rg"
  location = var.region
  tags     = local.common_tags
}

# --- Virtual Network --- #
resource "azurerm_virtual_network" "VirtualNetwork" {
  name                = "${local.name_prefix}-vnet"
  resource_group_name = azurerm_resource_group.ResourceGroup.name
  location            = azurerm_resource_group.ResourceGroup.location
  address_space       = [var.vnet_cidr]
  tags                = local.common_tags
}

# --- Subnet --- #
resource "azurerm_subnet" "Subnet" {
  name                 = "${local.name_prefix}-snet"
  resource_group_name  = azurerm_resource_group.ResourceGroup.name
  virtual_network_name = azurerm_virtual_network.VirtualNetwork.name
  address_prefixes     = [var.snet_cidr]
}

# --- Network Security Group --- #
resource "azurerm_network_security_group" "NetworkSecurityGroup" {
  name                = "${local.name_prefix}-nsg"
  location            = azurerm_resource_group.ResourceGroup.location
  resource_group_name = azurerm_resource_group.ResourceGroup.name
  tags                = local.common_tags
}

# --- NSG Rules --- #
resource "azurerm_network_security_rule" "nsg_rule_1" {
  name                        = "${local.name_prefix}-nsg-rule1"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = var.allowip
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.ResourceGroup.name
  network_security_group_name = azurerm_network_security_group.NetworkSecurityGroup.name
}

# --- Security Group Association --- #
resource "azurerm_subnet_network_security_group_association" "SecurityGroupAssociation" {
  subnet_id                 = azurerm_subnet.Subnet.id
  network_security_group_id = azurerm_network_security_group.NetworkSecurityGroup.id
}

# --- Public IP --- #
resource "azurerm_public_ip" "PublicIP" {
  name                = "${local.name_prefix}-pip"
  resource_group_name = azurerm_resource_group.ResourceGroup.name
  location            = azurerm_resource_group.ResourceGroup.location
  allocation_method   = "Static"
  tags                = local.common_tags
}

# --- Network Interface (NIC)--- #
resource "azurerm_network_interface" "NetworkInterface" {
  name                = "${local.name_prefix}-nic"
  location            = azurerm_resource_group.ResourceGroup.location
  resource_group_name = azurerm_resource_group.ResourceGroup.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.Subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.PublicIP.id
  }
  tags = local.common_tags
}

# --- Linux Virtual Machine --- #
resource "azurerm_linux_virtual_machine" "LinuxVM" {
  name                  = "${local.name_prefix}-vm-01"
  resource_group_name   = azurerm_resource_group.ResourceGroup.name
  location              = azurerm_resource_group.ResourceGroup.location
  size                  = var.vmsize
  admin_username        = var.admin_user
  network_interface_ids = [azurerm_network_interface.NetworkInterface.id]

  custom_data = filebase64("scripts/customdata.tpl")

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_user
    public_key = file("/keys/${var.ssh_public_key}")
  }

  os_disk {
    name                 = "${local.name_prefix}-vm-01_OsDisk"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-26_04-lts"
    sku       = "minimal"
    version   = "latest"
  }

  tags = local.common_tags


}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "VMAutoShutdown" {
  daily_recurrence_time = "1800"
  enabled               = true
  location              = var.region
  tags                  = local.common_tags
  timezone              = "GMT Standard Time"
  virtual_machine_id    = azurerm_linux_virtual_machine.LinuxVM.id
  notification_settings {
    email           = var.shutdown_alert_email
    enabled         = true
    time_in_minutes = 30
  }
}