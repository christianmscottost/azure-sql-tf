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
    key                  = "init.terraform.tfstate"
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  use_oidc = true
  features {}
}

# Creating initial resource group to house shared services. 
resource "azurerm_resource_group" "init" {
  name     = "rg-${var.service}-${var.environment}-${var.region.suffix}"
  location = var.region.name
  tags = {
    app         = "${var.service}"
    environment = "${var.environment}"
    created-by  = "terraform"
    purpose     = "Service requirements."
  }
}

# Creating shared storage account for terraform state files used in the environments. 
resource "azurerm_storage_account" "init" {
  name                     = "sa${var.service}state"
  resource_group_name      = azurerm_resource_group.init.name
  location                 = azurerm_resource_group.init.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags = {
    app         = "${var.service}"
    environment = "${var.environment}"
    created-by  = "terraform"
    purpose     = "Environment terraform state."
  }
}

# Creating blob container with private access for TF state file. 
resource "azurerm_storage_container" "init" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.init.name
  container_access_type = "private"
}
