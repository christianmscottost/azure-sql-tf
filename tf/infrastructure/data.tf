data "azurerm_virtual_network" "shared" {
  name                = "vnet-shared-eus"
  resource_group_name = "rg-shared-net-eus"
}

data "azurerm_subnet" "shared" {
  name                 = "snet-default"
  virtual_network_name = data.azurerm_virtual_network.shared.name
  resource_group_name  = data.azurerm_virtual_network.example.resource_group_name
}

data "azuread_group" "admins" {
  name = "OSTAdmins"
}
