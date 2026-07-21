variable "api_app_display_name" {
  description = "Display name for App A, the API app (OBO middle-tier)"
  type        = string
  default     = "apim-mcp-api"
}

variable "client_app_display_name" {
  description = "Display name for App B, the VS Code public client"
  type        = string
  default     = "vscode-mcp-client"
}

variable "secret_end_date" {
  description = "Expiry (RFC3339) for the OBO client secret. Rotate by changing this value and re-applying, then refreshSecret on the named value."
  type        = string
}

variable "databricks_permission_enabled" {
  description = "Register the delegated AzureDatabricks user_impersonation permission on App A (requires the Databricks first-party SP to exist in the tenant)"
  type        = bool
  default     = true
}

variable "databricks_app_id" {
  description = "Entra application ID of the Azure Databricks first-party app (default: the well-known public-cloud ID)"
  type        = string
  default     = "2ff814a6-3304-4ab8-85cb-cd0e6f879c1d"
}
