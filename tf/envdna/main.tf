# Don't try to run this. It won't work.
# Backend config and variables get set 
# during the github actions workflow run.
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
  backend "azurerm" {
    resource_group_name  = "rg-sql-init-eus"
    storage_account_name = "sasqlstate"
    container_name       = "tfstate"
    use_oidc             = true
    subscription_id      = "d02bae9e-95e6-4ab0-abca-34992fd65b2d"
    tenant_id            = "46947e84-c7c5-4572-bf44-0c0b2d9013b8"
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  use_oidc = true
  features {}
}

module "infrastructure" {
  source      = "../infrastructure"
  service     = var.service
  environment = var.environment
  region      = var.region
  repo = var.repo
}
