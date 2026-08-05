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

variable "auth" {
  description = "Backend auth mode: \"obo\" (per-user Entra token exchange), \"pat\" (per-user PAT from the manually maintained mcp-pat-<name> named-value map - demo pattern), or \"none\" (public backend, caller auth stripped)"
  type        = string

  validation {
    condition     = contains(["obo", "pat", "none"], var.auth)
    error_message = "auth must be \"obo\", \"pat\" or \"none\"."
  }
}

variable "obo_scope" {
  description = "Entra scope for the OBO exchange (required when auth = \"obo\"; consumed by the shared mcp-obo-exchange fragment)"
  type        = string
  default     = ""
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
