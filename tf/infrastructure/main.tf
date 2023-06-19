locals {
  default-tags = {
    environment     = "${var.environment}"
    service         = "${var.service}"
    purpose         = "Infrastructure for ${var.service}."
    created-by      = "terraform"
    repository-link = "${var.repo}"
  }
}


resource "azurerm_resource_group" "main" {
  name     = "rg-${var.service}-${var.environment}-${var.region.suffix}"
  location = var.region.name
  tags     = local.default-tags
}



resource "random_password" "main" {
  length      = 15
  min_upper   = 4
  min_lower   = 2
  min_numeric = 4
  special     = false
}

resource "azurerm_mssql_server" "main" {
  name                         = format("%s-primary", "sql-${var.environment}-${var.region.suffix}")
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = random_password.main.result
  minimum_tls_version          = "1.2"

  azuread_administrator {
    login_username = "AzureAD Admin"
    object_id      = data.azuread_group.admins.object_id
  }

  dynamic "identity" {
    content {
      type = "SystemAssigned"
    }
  }

  tags = local.default-tags
}
/* 
resource "azurerm_sql_database" "db" {
  name                             = var.database_name
  resource_group_name              = local.resource_group_name
  location                         = local.location
  server_name                      = azurerm_sql_server.primary.name
  edition                          = var.sql_database_edition
  requested_service_objective_name = var.sqldb_service_objective_name
  tags                             = local.default-tags

  dynamic "threat_detection_policy" {
    for_each = local.if_threat_detection_policy_enabled
    content {
      state                      = "Enabled"
      storage_endpoint           = azurerm_storage_account.storeacc.0.primary_blob_endpoint
      storage_account_access_key = azurerm_storage_account.storeacc.0.primary_access_key
      retention_days             = var.log_retention_days
      email_addresses            = var.email_addresses_for_alerts
    }
  }
} */

# resource "null_resource" "create_sql" {
#   count = var.initialize_sql_script_execution ? 1 : 0
#   provisioner "local-exec" {
#     command = "sqlcmd -I -U ${azurerm_sql_server.primary.administrator_login} -P ${azurerm_sql_server.primary.administrator_login_password} -S ${azurerm_sql_server.primary.fully_qualified_domain_name} -d ${azurerm_sql_database.db.name} -i ${var.sqldb_init_script_file} -o ${format("%s.log", replace(var.sqldb_init_script_file, "/.sql/", ""))}"
#   }
# }

/* resource "azurerm_private_endpoint" "pep1" {
  name                = format("%s-primary", "sqldb-private-endpoint")
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = data.azurerm_subnet.shared.id
  tags                = local.default-tags

  private_service_connection {
    name                           = "sqldbprivatelink-primary"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_sql_server.primary.id
    subresource_names              = ["sqlServer"]
  }
}
 */
