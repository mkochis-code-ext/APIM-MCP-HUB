# Per-server MCP server: one NATIVE APIM MCP server (type = "mcp", preview RP via
# azapi - azurerm cannot create these) per hub server entry. Shows up under
# "MCP Servers" in the portal, path <prefix>/<name>/mcp. Owns ALL server-specific
# policy complexity - hub-only gate, token validation, ACL evaluation (shared
# mcp-acl-eval fragment), tool filtering, OBO or auth-strip, and the optional
# per-user rate limit. The hub stays a thin aggregator.
#
# HUB-ONLY: requests must carry the X-MCP-Internal-Key header matching the
# mcp-hub-internal-key secret named value; everything else gets 401. This includes
# the portal's MCP "Tools" test blade (expected: it has no internal key).
#
# MCP-type APIs run APIM's native MCP pipeline: serviceUrl is the backend MCP
# endpoint and GET/SSE/session handling is platform-managed. Policies still apply,
# but response bodies MUST NOT be read (breaks MCP streaming - documented
# limitation), so tools/list is answered entirely inbound via send-request.
#
# The mcp-acl-<name> named value (backend/path/acl, single-quoted JSON) lives here -
# same name and format as before, so ACL edits remain named-value-only updates.

terraform {
  required_providers {
    azapi = {
      source = "Azure/azapi"
    }
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

resource "azapi_resource" "server" {
  type      = "Microsoft.ApiManagement/service/apis@2025-09-01-preview"
  name      = "mcp-server-${var.server_name}"
  parent_id = var.api_management_id

  body = {
    properties = {
      type                 = "mcp"
      displayName          = "MCP Server - ${var.server_name}"
      description          = "Per-server MCP endpoint called by the hub: ACL evaluation + tool filtering + ${var.auth == "obo" ? "per-user OBO exchange" : var.auth == "pat" ? "per-user PAT lookup (manual named-value map)" : "anonymous passthrough"} to the backend."
      path                 = "${var.path_prefix}/${var.server_name}"
      protocols            = ["https"]
      serviceUrl           = var.backend_url
      subscriptionRequired = false
      mcpProperties = {
        transportType = "streamable"
      }
    }
  }

  # The MCP pipeline owns operations/transport; nothing else on the body is managed.
  schema_validation_enabled = true
}

# ACL named value: backend/path/acl as single-quoted JSON (see the policy template
# header for why single quotes). Editing this is a ~30s named-value update - no
# policy redeploy.
resource "azurerm_api_management_named_value" "acl" {
  name                = "mcp-acl-${var.server_name}"
  display_name        = "mcp-acl-${var.server_name}"
  resource_group_name = var.resource_group_name
  api_management_name = var.api_management_name
  secret              = false
  value               = var.acl_value
  tags                = ["mcp-hub", "acl"]
}

# Per-user PAT map (auth = "pat" only): SECRET named value mcp-pat-<name> holding a
# single-quoted JSON map of caller OID -> backend PAT, e.g. {'<oid>':'github_pat_...'}.
# Terraform creates ONLY the empty base structure and never overwrites the value
# (ignore_changes) - PATs are registered manually (portal, or az apim nv update).
# A caller with no entry gets 403 and never sees this server's tools.
# DEMO PATTERN ONLY: in production use Key Vault-backed named values or a real
# credential broker with rotation - long-lived PATs in APIM named values are not
# a production secret store.
resource "azurerm_api_management_named_value" "pat_map" {
  count = var.auth == "pat" ? 1 : 0

  name                = "mcp-pat-${var.server_name}"
  display_name        = "mcp-pat-${var.server_name}"
  resource_group_name = var.resource_group_name
  api_management_name = var.api_management_name
  secret              = true
  value               = "{}" # base structure only; real entries are set out-of-band
  tags                = ["mcp-hub", "pat", "manual"]

  lifecycle {
    ignore_changes = [value]
  }
}

locals {
  policy_xml = templatefile("${path.module}/templates/mcp-server-policy.xml.tftpl", {
    server_name         = var.server_name
    backend_url         = var.backend_url
    auth                = var.auth
    obo_scope           = var.obo_scope
    tools_cache_seconds = var.tools_cache_seconds
    rate_limit_calls    = var.rate_limit_calls
    rate_limit_period   = var.rate_limit_period
    acl_fragment_id     = var.acl_fragment_id
  })
}

resource "azurerm_api_management_api_policy" "server" {
  api_name            = azapi_resource.server.name
  api_management_name = var.api_management_name
  resource_group_name = var.resource_group_name
  xml_content         = local.policy_xml

  # Policy compilation resolves {{mcp-acl-<name>}} (plus the shared named values and
  # the mcp-acl-eval fragment the caller wires via depends_on on the module).
  depends_on = [azapi_resource.server, azurerm_api_management_named_value.acl, azurerm_api_management_named_value.pat_map]
}
