variable "server_name" {
  description = "Server key (tool-name prefix at the hub, ACL named-value suffix, and path segment). Lowercase [a-z0-9-]."
  type        = string
}

variable "path_prefix" {
  description = "Route prefix shared by all per-server APIs (endpoint becomes <gateway>/<path_prefix>/<server_name>/mcp)"
  type        = string
  default     = "mcp-servers"
}

variable "resource_group_name" {
  description = "Resource group of the APIM instance"
  type        = string
}

variable "api_management_name" {
  description = "Name of the APIM instance"
  type        = string
}

variable "api_management_id" {
  description = "Resource ID of the APIM instance (azapi parent for the MCP-type API)"
  type        = string
}

variable "backend_url" {
  description = "Full MCP endpoint URL of the backend server (becomes the MCP API's serviceUrl and the tools/list send-request target)"
  type        = string
}

variable "entra_tenant_id" {
  description = "Entra tenant GUID for validate-azure-ad-token"
  type        = string
}

variable "client_app_ids_xml" {
  description = "Optional pre-rendered <client-application-ids> block for validate-azure-ad-token (empty string to skip)"
  type        = string
  default     = ""
}

variable "mcp_api_app_id" {
  description = "Application (client) ID of the API app - token audience + OBO client id"
  type        = string
}

variable "auth" {
  description = "Backend auth mode: \"obo\" (per-user token exchange) or \"none\" (public backend, caller auth stripped)"
  type        = string

  validation {
    condition     = contains(["obo", "none"], var.auth)
    error_message = "auth must be \"obo\" or \"none\"."
  }
}

variable "obo_scope" {
  description = "Entra scope for the OBO exchange (required when auth = \"obo\")"
  type        = string
  default     = ""
}

variable "obo_secret_named_value" {
  description = "Name of the secret named value holding the OBO client secret"
  type        = string
}

variable "obo_cache_seconds" {
  description = "Cache TTL for exchanged OBO tokens (must be below token lifetime)"
  type        = number
  default     = 3000
}

variable "tools_cache_seconds" {
  description = "Seconds to cache this server's filtered tools/list result per ACL outcome"
  type        = number
  default     = 120
}

variable "rate_limit_calls" {
  description = "Optional per-user tools/call rate limit for this server (null = no server-level limit; the hub-wide limit still applies)"
  type        = number
  default     = null
}

variable "rate_limit_period" {
  description = "Renewal period (seconds) for the per-server rate limit"
  type        = number
  default     = 60
}

variable "acl_value" {
  description = "Rendered ACL named-value content (single-quoted JSON: { backend, path, acl })"
  type        = string
}

variable "acl_fragment_id" {
  description = "Name of the shared ACL-evaluation policy fragment (include-fragment fragment-id)"
  type        = string
  default     = "mcp-acl-eval"
}
