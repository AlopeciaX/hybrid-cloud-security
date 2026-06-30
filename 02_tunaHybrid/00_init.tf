terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.74.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "team604tuna-infra"
    storage_account_name = "tunatfstate604"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subid
}
