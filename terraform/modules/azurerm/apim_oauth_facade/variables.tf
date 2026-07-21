variable "resource_group_name" {
  description = "Resource group of the APIM instance"
  type        = string
}

variable "api_management_name" {
  description = "Name of the APIM instance"
  type        = string
}

variable "gateway_url" {
  description = "APIM gateway base URL (the facade issuer), e.g. https://apim-x.azure-api.net"
  type        = string
}

variable "entra_tenant_id" {
  description = "Microsoft Entra ID tenant ID (GUID)"
  type        = string
}

variable "mcp_client_app_id" {
  description = "Application (client) ID of the pre-registered VS Code public client (App B), returned by the DCR shim and pinned by /authorize"
  type        = string
}

variable "oauth_scope" {
  description = "Delegated scope the facade forwards to Entra (api://<app-A>/mcp.tools)"
  type        = string
}

variable "prm_metadata_json" {
  description = "Protected Resource Metadata JSON document (RFC 9728) served at /.well-known/oauth-protected-resource"
  type        = string
}
