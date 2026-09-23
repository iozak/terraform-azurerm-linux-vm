# --- Providers --- #
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }
  #  backend "azurerm" {
  #    resource_group_name  = "###"
  #    storage_account_name = "###"
  #    container_name       = "tfstate"
  #    key                  = "terraform.tfstate"
  #  }

}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
}
