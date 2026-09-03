# --- Outputs --- #
output "PublicIP" {
  value = azurerm_public_ip.PublicIP.ip_address

}