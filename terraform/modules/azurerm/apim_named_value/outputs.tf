output "id" {
  description = "ID of the named value"
  value       = azurerm_api_management_named_value.main.id
}

output "display_name" {
  description = "Display name referenced in policies"
  value       = azurerm_api_management_named_value.main.display_name
}
