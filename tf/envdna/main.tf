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
    storage_account_name = "sasqlstate1"
    container_name       = "tfstate"
    use_oidc             = true
    subscription_id      = "62c223af-3ea4-4cf8-bb4a-c8449fe872e1"
    tenant_id            = "567e2175-bf4e-4bcc-b114-335fa0061f2f"
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  use_oidc = true
  features {}
}

# module "infrastructure" {
#   source      = "../infrastructure"
#   service     = var.service
#   environment = var.environment
#   region      = var.region
#   repo        = var.repo
# }

module "sql" {
  source      = "../sql"
  service     = var.service
  environment = var.environment
  region      = var.region
  repo        = var.repo
  sku         = var.sku
  names       = var.names
}
