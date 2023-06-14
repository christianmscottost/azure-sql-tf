resource "azurerm_resource_group" "main" {
  name     = "rg-${var.service}-${var.environment}-${var.region.suffix}"
  location = var.region.name
  tags = {
    app         = "${var.service}"
    environment = "${var.environment}"
    created-by  = "terraform"
  }
}
