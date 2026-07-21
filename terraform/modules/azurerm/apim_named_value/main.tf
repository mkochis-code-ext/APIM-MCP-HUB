resource "azurerm_api_management_named_value" "main" {
  name                = var.name
  display_name        = var.display_name
  resource_group_name = var.resource_group_name
  api_management_name = var.api_management_name
  secret              = true
  value               = var.secret_value
}
