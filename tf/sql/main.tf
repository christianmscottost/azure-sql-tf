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
# Key vault for to hold server users
resource "azurerm_key_vault" "vault" {
  name                     = "kv-${var.service}-${var.environment}-${var.region.suffix}"
  location                 = azurerm_resource_group.sql.location
  resource_group_name      = azurerm_resource_group.sql.name
  sku_name                 = var.sku
  tenant_id                = "567e2175-bf4e-4bcc-b114-335fa0061f2f"
  purge_protection_enabled = true

  access_policy {
    tenant_id = "567e2175-bf4e-4bcc-b114-335fa0061f2f"
    object_id = "7bdd0ef2-6c8c-4483-b155-b7e1401110f8"


    key_permissions = [
      "Get", "List", "Create", "Rotate", "GetRotationPolicy", "SetRotationPolicy", "Delete", "Recover",
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
  #Access policy for managed id
  access_policy {
    tenant_id = azurerm_user_assigned_identity.sql_id.tenant_id
    object_id = azurerm_user_assigned_identity.sql_id.principal_id


    key_permissions = [
      "Get", "WrapKey", "UnwrapKey"
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

  #Service Principal access policy
  access_policy {
    tenant_id = "567e2175-bf4e-4bcc-b114-335fa0061f2f"
    object_id = "08b5b379-4869-4b76-bc39-1904153c9b26"


    key_permissions = [
      "Get", "List", "Create", "Delete", "Recover", "Rotate", "GetRotationPolicy", "SetRotationPolicy", "WrapKey", "UnwrapKey",
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
    bypass                     = "AzureServices"
    default_action             = "Allow"
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }


}
resource "random_password" "sql-password" {
  length           = 16
  special          = true
  override_special = "!#$%&,."
}

resource "random_password" "sql-password-2" {
  length           = 16
  special          = true
  override_special = "!#$%&,."
}
resource "azurerm_key_vault_secret" "sql-secret" {
  key_vault_id    = azurerm_key_vault.vault.id
  name            = var.kv-secret
  value           = random_password.sql-password.result
  expiration_date = "2025-07-31T00:00:00Z"
  depends_on      = [azurerm_key_vault.vault]
}
#Setting up resource log for key vault
resource "azurerm_storage_account" "logs" {
  name                              = "sa${var.service}${var.environment}${var.region.suffix}"
  resource_group_name               = azurerm_resource_group.sql.name
  location                          = azurerm_resource_group.sql.location
  account_tier                      = "Standard"
  account_replication_type          = "GRS"
  public_network_access_enabled     = true
  infrastructure_encryption_enabled = true
  account_kind                      = "StorageV2"
  network_rules {
    default_action             = "Allow"
    virtual_network_subnet_ids = [azurerm_subnet.link.id]
  }
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.sql_id.id]
  }
  customer_managed_key {
    key_vault_key_id          = azurerm_key_vault_key.sql.id
    user_assigned_identity_id = azurerm_user_assigned_identity.sql_id.id
  }
}
resource "azurerm_storage_encryption_scope" "encrypt" {
  name                               = "scope${var.service}${var.environment}${var.region.suffix}"
  storage_account_id                 = azurerm_storage_account.logs.id
  source                             = "Microsoft.Storage"
  infrastructure_encryption_required = true
  key_vault_key_id                   = azurerm_key_vault_key.sql.id

}
resource "azurerm_monitor_diagnostic_setting" "logs" {
  name               = "ds-${var.service}-${var.environment}-${var.region.suffix}"
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
# SQL server and database
resource "azurerm_user_assigned_identity" "sql_id" {
  name                = "sql-admin-${var.service}-${var.environment}-${var.region.suffix}"
  location            = azurerm_resource_group.sql.location
  resource_group_name = azurerm_resource_group.sql.name
}

resource "azurerm_mssql_server" "sql" {
  location            = azurerm_resource_group.sql.location
  resource_group_name = azurerm_resource_group.sql.name
  name                = "sql-${var.service}-${var.environment}-${var.region.suffix}"
  version             = "12.0"

  administrator_login           = "OSTAdmin"
  administrator_login_password  = azurerm_key_vault_secret.sql-secret.value
  public_network_access_enabled = false

  azuread_administrator {
    azuread_authentication_only = false
    login_username              = "tim.moran@ostusa.com"
    object_id                   = "7bdd0ef2-6c8c-4483-b155-b7e1401110f8"
    tenant_id                   = "567e2175-bf4e-4bcc-b114-335fa0061f2f"
  }
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.sql_id.id]
  }

  primary_user_assigned_identity_id            = azurerm_user_assigned_identity.sql_id.id
  transparent_data_encryption_key_vault_key_id = azurerm_key_vault_key.sql.id

}
resource "azurerm_mssql_database" "database" {
  depends_on = [ azurerm_mssql_server.sql, azurerm_mssql_server_transparent_data_encryption.sql ]
  count                = length(var.names)
  name                 = var.names[count.index]
  server_id            = azurerm_mssql_server.sql.id
  storage_account_type = "Geo"

  long_term_retention_policy {
    monthly_retention = "P1M"
  }


}
# Virtual network, subnet, and private service endpoint creation
resource "random_string" "link" {
  length  = 6
  special = false
  upper   = false
}

# resource "azurerm_network_ddos_protection_plan" "ddos" {
#   name                = "ddos-${var.service}-${var.environment}-${var.region.suffix}"
#   resource_group_name = azurerm_resource_group.sql.name
#   location            = azurerm_resource_group.sql.location
# }
resource "azurerm_virtual_network" "link" {
  name                = "${random_string.link.result}-network-${var.service}-${var.environment}-${var.region.suffix}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.sql.location
  resource_group_name = azurerm_resource_group.sql.name
  # ddos_protection_plan {
  #   enable = true
  #   id     = azurerm_network_ddos_protection_plan.ddos.id
  # }
}

resource "azurerm_subnet" "link" {
  name                                      = "${random_string.link.result}-subnet-${var.service}-${var.environment}-${var.region.suffix}"
  resource_group_name                       = azurerm_resource_group.sql.name
  virtual_network_name                      = azurerm_virtual_network.link.name
  address_prefixes                          = ["10.0.0.0/24"]
  private_endpoint_network_policies_enabled = true
  service_endpoints                         = ["Microsoft.Sql", "Microsoft.Storage"]
}

resource "azurerm_private_endpoint" "link" {
  name                = "${random_string.link.result}-endpoint-${var.service}-${var.environment}-${var.region.suffix}"
  subnet_id           = azurerm_subnet.link.id
  location            = azurerm_resource_group.sql.location
  resource_group_name = azurerm_resource_group.sql.name

  private_service_connection {
    name                           = "${random_string.link.result}-psg-${var.service}-${var.environment}-${var.region.suffix}"
    private_connection_resource_id = azurerm_key_vault.vault.id
    is_manual_connection           = false
    subresource_names              = ["vault"]

  }

}
resource "azurerm_private_endpoint" "sql_link" {
  name                = "${random_string.link.result}-sql-endpoint-${var.service}-${var.environment}-${var.region.suffix}"
  subnet_id           = azurerm_subnet.link.id
  location            = azurerm_resource_group.sql.location
  resource_group_name = azurerm_resource_group.sql.name

  private_service_connection {
    name                           = "${random_string.link.result}-sql-psc-${var.service}-${var.environment}-${var.region.suffix}"
    private_connection_resource_id = azurerm_mssql_server.sql.id
    is_manual_connection           = false
    subresource_names              = ["sqlServer"]

  }

}

resource "azurerm_private_endpoint" "storage_link" {
  name                = "${random_string.link.result}-storage-endpoint-${var.service}-${var.environment}-${var.region.suffix}"
  subnet_id           = azurerm_subnet.link.id
  location            = azurerm_resource_group.sql.location
  resource_group_name = azurerm_resource_group.sql.name

  private_service_connection {
    name                           = "${random_string.link.result}-storage-psg-${var.service}-${var.environment}-${var.region.suffix}"
    private_connection_resource_id = azurerm_storage_account.logs.id
    is_manual_connection           = false
    subresource_names              = ["File"]

  }

}

# Security group and association for subnet
resource "azurerm_network_security_group" "sql-nsg" {
  name                = "nsg-${var.service}-${var.environment}-${var.region.suffix}"
  location            = azurerm_resource_group.sql.location
  resource_group_name = azurerm_resource_group.sql.name
  tags                = local.default-tags
}

resource "azurerm_subnet_network_security_group_association" "sql-nsg" {
  subnet_id                 = azurerm_subnet.link.id
  network_security_group_id = azurerm_network_security_group.sql-nsg.id
}

# Created customer managed keys
resource "azurerm_key_vault_key" "sql" {
  name         = "key-${var.service}-${var.environment}-${var.region.suffix}"
  key_vault_id = azurerm_key_vault.vault.id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "unwrapKey",
    "wrapKey",
  ]

  depends_on = [
    azurerm_key_vault.vault
  ]
}

resource "azurerm_mssql_server_transparent_data_encryption" "sql" {
  server_id        = azurerm_mssql_server.sql.id
  key_vault_key_id = azurerm_key_vault_key.sql.id

}
