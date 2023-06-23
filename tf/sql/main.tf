locals {
  default-tags = {
    environment     = "${var.environment}"
    service         = "${var.service}"
    purpose         = "MS SQL Server for ${var.service}."
    created-by      = "terraform"
    repository-link = "${var.repo}"
  }
}

resource "azurerm_resource_group" "sql" {
  name     = "rg-${var.service}-${var.environment}-${var.region.suffix}"
  location = var.region.name
  tags     = local.default-tags
}

resource "azurerm_key_vault" "vault" {
  name = "kv-sql-usernames"
  location = azurerm_resource_group.sql.location
  resource_group_name = azurerm_resource_group.sql.name
  sku_name = var.sku
  tenant_id = "567e2175-bf4e-4bcc-b114-335fa0061f2f"
  purge_protection_enabled = false
  access_policy {
    tenant_id = "567e2175-bf4e-4bcc-b114-335fa0061f2f"
    #Placeholder value
    object_id = "04b07795-8ddb-461a-bbee-02f9e1bf7b46"

    key_permissions = [
      "Get", 
    ]
    secret_permissions = [
      "Get",
      "Set",
      "List",
    ]
    storage_permissions = [
      "Get", "Set",
    ]
  }

  network_acls {
    bypass = "AzureServices"
    default_action = "Deny"
    ip_rules = []
    virtual_network_subnet_ids = []
  }
  

}
resource "random_password" "sql-password" {
    length = 16
    special = true
    override_special = "!#$%&,."
}
resource "azurerm_key_vault_secret" "sql-secret" {
    key_vault_id = azurerm_key_vault.vault.id
    name = var.kv-secret
    value = random_password.sql-password.result
    expiration_date = "2023-07-31T00:00:00Z"
}
resource "azurerm_mssql_server" "sql" {
    location = azurerm_resource_group.sql.location
    resource_group_name = azurerm_resource_group.sql.name
    #Placeholder name
    name = "ost-sql-server"
    #Placeholder version
    version = "12.0"

    administrator_login = "OSTAdmin"
    administrator_login_password = azurerm_key_vault_secret.sql-secret.value
    public_network_access_enabled = false

    
  
}
resource "azurerm_mssql_database" "database" {
    count = length(var.names)
    name = var.names[count.index]
    server_id = azurerm_mssql_server.sql.id
    storage_account_type = "Geo"

    long_term_retention_policy {
      monthly_retention = "P1M"
    }
  
}
