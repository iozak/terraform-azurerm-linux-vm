# --- Locals --- #
locals {
  common_tags = {
    AppRole          = var.role
    AppEnvironment   = var.env
    TerraformManaged = "true"
  }
}