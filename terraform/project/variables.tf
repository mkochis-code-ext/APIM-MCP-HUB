variable "environment_prefix" {
  description = "Environment prefix"
  type        = string
}

variable "suffix" {
  description = "Random suffix for uniqueness"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}

variable "workload" {
  description = "Workload name"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "data_location" {
  description = "Azure region for data resources"
  type        = string
}

# ---------- API Management ----------
variable "publisher_name" {
  description = "Publisher name for the APIM instance"
  type        = string
}

variable "publisher_email" {
  description = "Publisher email for the APIM instance"
  type        = string
}

variable "apim_sku_name" {
  description = "APIM SKU. Must support MCP (Developer_1, BasicV2_1, StandardV2_1, Premium_1, PremiumV2_1)."
  type        = string
  default     = "Developer_1"
}

# ---------- Microsoft Entra ID (On-Behalf-Of authentication) ----------
# The MCP server authenticates every caller with a Microsoft Entra ID access token and
# performs an On-Behalf-Of exchange to mint a per-user Databricks token. See the README
# "Per-user identity (OBO)" section for the two app registrations these values map to.
variable "entra_tenant_id" {
  description = "Microsoft Entra ID tenant ID (GUID)."
  type        = string
}

variable "mcp_api_app_id" {
  description = "Application (client) ID of the API app registration (the OBO middle-tier). Used as the inbound token audience (api://<id>) AND as the confidential client that performs the OBO exchange. Ignored when create_entra_apps = true."
  type        = string
  default     = ""
}

variable "mcp_client_app_id" {
  description = "Application (client) ID of the public client app registration used by VS Code. The OAuth facade returns this as the DCR client, and (when set) the policy restricts inbound tokens to it via client-application-ids. Ignored when create_entra_apps = true."
  type        = string
  default     = ""
}

variable "obo_client_secret" {
  description = "Client secret of the API app registration (mcp_api_app_id), used by APIM to perform the OBO token exchange. Stored as a secret APIM named value. Ignored when create_entra_apps = true."
  type        = string
  sensitive   = true
  default     = ""
}

# ---------- Entra app registrations (optional, Terraform-managed) ----------
variable "create_entra_apps" {
  description = "Create the two Entra app registrations (API app + VS Code client), the OBO secret, knownClientApplications and the Databricks delegated permission with Terraform. When true, mcp_api_app_id / mcp_client_app_id / obo_client_secret are ignored. Requires app-registration rights; consent stays manual."
  type        = bool
  default     = false
}

variable "entra_api_app_display_name" {
  description = "Display name for the Terraform-created API app (App A)"
  type        = string
  default     = "apim-mcp-api"
}

variable "entra_client_app_display_name" {
  description = "Display name for the Terraform-created VS Code client app (App B)"
  type        = string
  default     = "vscode-mcp-client"
}

variable "obo_secret_end_date" {
  description = "Expiry (RFC3339) for the Terraform-created OBO client secret (create_entra_apps = true). Rotate by changing this and re-applying."
  type        = string
  default     = "2027-07-01T00:00:00Z"
}

# ---------- OAuth facade ----------
variable "oauth_facade_enabled" {
  description = "Deploy the root-path OAuth authorization-server facade (PRM + AS metadata + authorize/token/register) with Terraform"
  type        = bool
  default     = true
}

# ---------- Graph role for the hub group-ACL fallback ----------
variable "apim_graph_role_assignment_enabled" {
  description = "Assign the GroupMember.Read.All Microsoft Graph application permission to the APIM managed identity (needed by mcp_hub_graph_fallback). The DEPLOYER needs directory privileges to create app role assignments; keep false and grant manually otherwise."
  type        = bool
  default     = false
}

variable "obo_cache_seconds" {
  description = "Seconds to cache each user's exchanged OBO token in the APIM internal cache. Keep below the Entra access-token lifetime (typically 60-90 min)."
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
  description = "Deploy the MCP Hub API (single aggregated endpoint with per-server ACL named values). Off by default so existing environments are unchanged."
  type        = bool
  default     = false
}

variable "mcp_hub_server_id" {
  description = "Resource name (api-id) for the hub API"
  type        = string
  default     = "mcp-hub"
}

variable "mcp_hub_path" {
  description = "Route prefix for the hub (endpoint becomes <gateway>/<path>/mcp)"
  type        = string
  default     = "mcp-hub"
}

variable "mcp_hub_tools_cache_seconds" {
  description = "Seconds to cache the merged+filtered tools/list result per ACL fingerprint. Bounds how long a persona ACL edit takes to reach clients."
  type        = number
  default     = 120
}

variable "mcp_hub_debug" {
  description = "When true the hub policy emits debug traces to Application Insights: auth challenges, token-validation failures, and per-request ACL evaluation summaries (claim counts and matched entry indices only - never claim values or tokens). Toggling only updates the mcp-hub-debug named value (~30s, no policy redeploy)."
  type        = bool
  default     = false
}

variable "mcp_hub_graph_fallback" {
  description = "When true, hub group ACL entries not satisfied by the token's groups claim are verified against Entra via Graph checkMemberGroups (transitive, handles overage/nesting; cached per user 300s). Requires the APIM managed identity to hold the GroupMember.Read.All Graph application permission."
  type        = bool
  default     = false
}

variable "mcp_hub_servers" {
  description = <<-EOT
    Hub server registry + ACLs in one block: onboarding a server is a single map entry
    (backend URL, auth mode, ACL personas) + terraform apply. Keys become the tool-name
    prefixes (<key>__<tool>) and ACL named-value suffixes (mcp-acl-<key>) - keep them
    short, lowercase, [a-z0-9-].
      backend_url = full MCP endpoint URL (split into host + rewrite path internally)
      auth        = "obo" (per-user Entra token exchange) | "pat" (per-user PAT from the
                    manually maintained mcp-pat-<key> named-value map - DEMO pattern for
                    non-Entra backends like GitHub) | "none" (public backend, auth stripped)
      obo_scope   = Entra scope for the OBO exchange (required when auth = "obo")
      acl         = max 3 persona entries per server; each matches ONE token claim:
        match_type  = "role" | "group" | "scope" | "any"  (group matches the Entra object
                      GUID; "any" matches every authenticated caller - match_value ignored)
        match_value = claim value to match
        allow       = list of tool names, or ["*"] for all tools
        deny        = tool names carved OUT (deny wins across all matched entries)
    Semantics: union of allows minus union of denies across matched entries; no match =>
    server invisible and every call denied (default deny). Onboarding/offboarding a server
    is a policy redeploy (terraform apply); editing an ACL only updates a named value
    (~30s propagation); granting a user is an Entra group-membership change.
  EOT
  type = map(object({
    backend_url = string
    auth        = string
    obo_scope   = optional(string, "")
    # Optional per-server, per-user rate limit on tools/call (null = only the hub-wide
    # limit applies). Changing these re-renders the policy (terraform apply).
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

  validation {
    condition     = alltrue([for k, v in var.mcp_hub_servers : can(regex("^[a-z0-9-]+$", k))])
    error_message = "Server keys become tool-name prefixes and named-value suffixes: lowercase [a-z0-9-] only."
  }

  validation {
    condition     = alltrue([for k, v in var.mcp_hub_servers : (v.rate_limit_calls == null || v.rate_limit_calls > 0) && v.rate_limit_period > 0])
    error_message = "rate_limit_calls (when set) and rate_limit_period must be positive."
  }

  validation {
    condition     = alltrue([for k, v in var.mcp_hub_servers : contains(["obo", "pat", "none"], v.auth)])
    error_message = "auth must be \"obo\", \"pat\" or \"none\"."
  }

  validation {
    condition     = alltrue([for k, v in var.mcp_hub_servers : v.auth != "obo" || v.obo_scope != ""])
    error_message = "obo_scope is required when auth = \"obo\" (e.g. \"<resource-app-id>/.default\")."
  }

  validation {
    condition     = alltrue([for k, v in var.mcp_hub_servers : can(regex("^https://", v.backend_url))])
    error_message = "backend_url must be an absolute https:// URL."
  }

  validation {
    condition     = alltrue([for k, v in var.mcp_hub_servers : length(v.acl) <= 3])
    error_message = "Max 3 ACL entries per server - keep entries persona-shaped (see design doc 12.2)."
  }

  validation {
    condition     = alltrue([for k, v in var.mcp_hub_servers : alltrue([for e in v.acl : contains(["role", "group", "scope", "any"], e.match_type)])])
    error_message = "match_type must be one of: role, group, scope, any."
  }

  validation {
    condition     = alltrue([for k, v in var.mcp_hub_servers : alltrue([for e in v.acl : length(e.allow) > 0])])
    error_message = "Each ACL entry needs a non-empty allow list (use [\"*\"] for all tools)."
  }
}
