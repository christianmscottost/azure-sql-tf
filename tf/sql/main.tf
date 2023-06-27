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
  purge_protection_enabled = true
  
  access_policy {
    tenant_id = "567e2175-bf4e-4bcc-b114-335fa0061f2f"
    #Placeholder value
    object_id = "7bdd0ef2-6c8c-4483-b155-b7e1401110f8"
    

    key_permissions = [
      "Get", 
      "List",
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
    default_action = "Allow"
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
#Settign up resource log for key vault
resource "azurerm_storage_account" "logs" {
  name = "sqlkvlogs"
  resource_group_name = azurerm_resource_group.sql.name
  location = azurerm_resource_group.sql.location
  account_tier = "Standard"
  account_replication_type = "LRS"
  public_network_access_enabled = true
  
}
resource "azurerm_monitor_diagnostic_setting" "logs" {
  name = "logs"
  target_resource_id = azurerm_key_vault.vault.id
  storage_account_id = azurerm_storage_account.logs.id

  enabled_log {
    category = "AuditEvent"
    retention_policy {
      enabled = false
    }
  }

  metric {
    category = "AllMetrics"
    retention_policy {
      enabled = false
    }
  }
}
resource "azurerm_mssql_server" "sql" {
    location = azurerm_resource_group.sql.location
    resource_group_name = azurerm_resource_group.sql.name
    name = "ost-sql-server"
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
#Private link
resource "random_string" "link" {
  length = 6
  special = false
  upper = false  
}

resource "azurerm_network_ddos_protection_plan" "ddos" {
  name = "ost-ddos-protection"
  resource_group_name = azurerm_resource_group.sql.name
  location = azurerm_resource_group.sql.location
}
resource "azurerm_virtual_network" "link" {
  name = "${random_string.link.result}-network"
  address_space = ["10.0.0.0/16"]
  location = azurerm_resource_group.sql.location
  resource_group_name = azurerm_resource_group.sql.name
  ddos_protection_plan {
    enable = true
    id = azurerm_network_ddos_protection_plan.ddos.id
  }
}

resource "azurerm_subnet" "link" {
  name = "${random_string.link.result}-subnet"
  resource_group_name = azurerm_resource_group.sql.name
  virtual_network_name = azurerm_virtual_network.link.name
  address_prefixes = ["10.0.0.0/24"]
  private_endpoint_network_policies_enabled = true
}

resource "azurerm_private_endpoint" "link" {
  name = "${random_string.link.result}-endpoint"
  subnet_id = azurerm_subnet.link.id
  location = azurerm_resource_group.sql.location
  resource_group_name = azurerm_resource_group.sql.name
  
  private_service_connection {
    name = "${random_string.link.result}-privateserviceconnection"
    private_connection_resource_id = azurerm_key_vault.vault.id
    is_manual_connection = false
    subresource_names = ["vault"]
    
  }

}
resource "azurerm_private_endpoint" "sql_link" {
  name = "${random_string.link.result}-sql-endpoint"
  subnet_id = azurerm_subnet.link.id
  location = azurerm_resource_group.sql.location
  resource_group_name = azurerm_resource_group.sql.name
  
  private_service_connection {
    name = "${random_string.link.result}-sql-privateserviceconnection"
    private_connection_resource_id = azurerm_mssql_server.sql.id
    is_manual_connection = false
    subresource_names = ["sqlServer"]
    
  }

}

resource "azurerm_private_endpoint" "storage_link" {
  name = "${random_string.link.result}-storage-endpoint"
  subnet_id = azurerm_subnet.link.id
  location = azurerm_resource_group.sql.location
  resource_group_name = azurerm_resource_group.sql.name
  
  private_service_connection {
    name = "${random_string.link.result}-storage-privateserviceconnection"
    private_connection_resource_id = azurerm_storage_account.logs.id
    is_manual_connection = false
    subresource_names = ["File"]
    
  }

}