variable "subscription_id" {
  description = "Azure subscription ID to deploy resources into"
  type        = string
}

variable "environment_prefix" {
  description = "Environment prefix (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "workload" {
  description = "Workload name"
  type        = string
  default     = "apimobs"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus2"
}

variable "data_location" {
  description = "Azure region for data resources (defaults to location if not specified)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project = "APIM MCP Observability Demo"
    Owner   = "Developer Name"
  }
}

# ---------- API Management ----------
variable "publisher_name" {
  description = "Publisher name for the APIM instance"
  type        = string
  default     = "MCP Observability Demo"
}

variable "publisher_email" {
  description = "Publisher email for the APIM instance"
  type        = string
}

variable "apim_sku_name" {
  description = "APIM SKU. Developer_1 is cheapest MCP-capable; BasicV2_1 provisions faster."
  type        = string
  default     = "Developer_1"
}

# ---------- Microsoft Entra ID (On-Behalf-Of authentication) ----------
variable "entra_tenant_id" {
  description = "Microsoft Entra ID tenant ID (GUID)."
  type        = string
}

variable "mcp_api_app_id" {
  description = "App (client) ID of the API app registration (OBO middle-tier): token audience api://<id>, owns obo_client_secret and the Databricks user_impersonation permission. Ignored when create_entra_apps = true."
  type        = string
  default     = ""
}

variable "mcp_client_app_id" {
  description = "App (client) ID of the VS Code public client app registration (loopback redirects). Returned by the OAuth facade DCR shim; also locks inbound tokens to this client. Ignored when create_entra_apps = true."
  type        = string
  default     = ""
}

variable "obo_client_secret" {
  description = "Client secret of the API app registration (mcp_api_app_id), used for the OBO exchange (stored as a secret APIM named value). Ignored when create_entra_apps = true."
  type        = string
  sensitive   = true
  default     = ""
}

variable "create_entra_apps" {
  description = "Create both Entra app registrations + the OBO secret + permission wiring with Terraform (requires app-registration rights; consent stays manual). When true, the three values above are ignored."
  type        = bool
  default     = false
}

variable "obo_secret_end_date" {
  description = "Expiry (RFC3339) for the Terraform-created OBO client secret (create_entra_apps = true)"
  type        = string
  default     = "2027-07-01T00:00:00Z"
}

variable "oauth_facade_enabled" {
  description = "Deploy the root-path OAuth authorization-server facade (PRM + AS metadata + authorize/token/register) with Terraform"
  type        = bool
  default     = true
}

variable "apim_graph_role_assignment_enabled" {
  description = "Assign GroupMember.Read.All (Graph app permission) to the APIM managed identity for the hub's group-ACL fallback. Deployer needs directory privileges."
  type        = bool
  default     = false
}

variable "obo_cache_seconds" {
  description = "Seconds to cache each user's exchanged OBO token (keep below the Entra token lifetime)."
  type        = number
  default     = 3000
}

# ---------- Policy tuning ----------
variable "rate_limit_calls" {
  description = "Rate-limit call count for the demo throttle policy"
  type        = number
  default     = 5
}

variable "rate_limit_period" {
  description = "Rate-limit renewal period in seconds"
  type        = number
  default     = 30
}

# ---------- Optional ----------
variable "create_databricks_workspace" {
  description = "Create an Azure Databricks workspace as part of this deployment"
  type        = bool
  default     = false
}

# ---------- MCP Hub (single aggregated MCP endpoint - design doc section 12) ----------
variable "mcp_hub_enabled" {
  description = "Deploy the MCP Hub API (single aggregated endpoint with per-server ACL named values)"
  type        = bool
  default     = false
}

variable "mcp_hub_path" {
  description = "Route prefix for the hub (endpoint becomes <gateway>/<path>/mcp)"
  type        = string
  default     = "mcp-hub"
}

variable "mcp_hub_tools_cache_seconds" {
  description = "Seconds to cache the merged+filtered tools/list result per ACL fingerprint"
  type        = number
  default     = 120
}

variable "mcp_hub_debug" {
  description = "Emit hub debug traces to App Insights (auth failures + ACL evaluation summaries; non-sensitive: counts/indices only). Toggle = named-value update, ~30s."
  type        = bool
  default     = false
}

variable "mcp_hub_graph_fallback" {
  description = "Verify unmatched group ACL entries against Entra via Graph checkMemberGroups (needs GroupMember.Read.All on the APIM managed identity). Toggle = named-value update, ~30s."
  type        = bool
  default     = false
}

variable "mcp_hub_servers" {
  description = "Hub server registry + ACLs in one block (backend URL, auth mode, persona ACL entries). Onboarding = one map entry + apply. See terraform/project/variables.tf and docs/mcp-hub-design.md 12.2 for semantics."
  type = map(object({
    backend_url = string
    auth        = string
    obo_scope   = optional(string, "")
    rate_limit_calls  = optional(number)
    rate_limit_period = optional(number, 60)
    acl = list(object({
      match_type  = string
      match_value = optional(string, "")
      allow       = list(string)
      deny        = optional(list(string), [])
    }))
  }))
  default = {}
}
