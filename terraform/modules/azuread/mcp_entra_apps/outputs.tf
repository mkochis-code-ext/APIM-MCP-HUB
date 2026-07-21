output "api_app_client_id" {
  description = "Application (client) ID of App A, the API app (OBO middle-tier) -> mcp_api_app_id"
  value       = azuread_application_registration.api.client_id
}

output "client_app_client_id" {
  description = "Application (client) ID of App B, the VS Code public client -> mcp_client_app_id"
  value       = azuread_application_registration.client.client_id
}

output "obo_client_secret" {
  description = "Client secret of App A, consumed by the obo-client-secret APIM named value"
  value       = azuread_application_password.api.value
  sensitive   = true
}

output "api_service_principal_object_id" {
  description = "Object ID of App A's service principal (needed for consent grants)"
  value       = azuread_service_principal.api.object_id
}

output "client_service_principal_object_id" {
  description = "Object ID of App B's service principal (needed for consent grants)"
  value       = azuread_service_principal.client.object_id
}
