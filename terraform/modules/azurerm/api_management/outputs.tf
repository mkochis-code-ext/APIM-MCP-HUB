output "id" {
  description = "ID of the API Management instance"
  value       = azurerm_api_management.main.id
}

output "name" {
  description = "Name of the API Management instance"
  value       = azurerm_api_management.main.name
}

output "gateway_url" {
  description = "Gateway URL of the API Management instance"
  value       = azurerm_api_management.main.gateway_url
}

output "principal_id" {
  description = "Object ID of the APIM system-assigned managed identity"
  value       = azurerm_api_management.main.identity[0].principal_id
}
