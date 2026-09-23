# --- Locals --- #
locals {
  name_prefix = "${var.env}-${var.role}"

  common_tags = {
    AppRole          = var.role
    AppEnvironment   = var.env
    TerraformManaged = "true"
  }
}
