resource "azurerm_api_management_logger" "main" {
  name                = var.name
  api_management_name = var.api_management_name
  resource_group_name = var.resource_group_name
  resource_id         = var.application_insights_id

  application_insights {
    connection_string = var.application_insights_connection_string
  }
}
