# MCP Hub: a plain HTTP API on APIM that aggregates the per-server MCP APIs behind one
# endpoint. The hub policy is a THIN aggregator (auth + fan-out + merge + routing);
# ACLs, tool filtering, OBO, and per-server rate limits live in the per-server APIs
# (modules/azurerm/apim_mcp_server). This module owns the hub API + its policy only;
# the shared named values (mcp-hub-debug, mcp-hub-graph-fallback, mcp-hub-internal-key)
# and the policy fragments live at the project level - the caller must depends_on them
# so the policy compiles.

resource "azurerm_api_management_api" "hub" {
  name                  = var.api_name
  resource_group_name   = var.resource_group_name
  api_management_name   = var.api_management_name
  revision              = "1"
  display_name          = var.display_name
  path                  = var.path
  protocols             = ["https"]
  subscription_required = false

  # Never used: every request is either answered in policy or re-routed with
  # set-backend-service. A syntactically valid placeholder is still required.
  service_url = "https://unused.invalid"
}

resource "azurerm_api_management_api_operation" "mcp_post" {
  operation_id        = "mcp-post"
  api_name            = azurerm_api_management_api.hub.name
  api_management_name = var.api_management_name
  resource_group_name = var.resource_group_name
  display_name        = "MCP endpoint (JSON-RPC)"
  method              = "POST"
  url_template        = "/mcp"
  description         = "Single aggregated MCP endpoint: initialize/ping answered locally, tools/list fan-out + merge + ACL filter, tools/call ACL check + routed passthrough."

  response {
    status_code = 200
  }
}

# The MCP streamable-HTTP spec has clients open GET (SSE notification stream) and
# DELETE (session termination) against the same endpoint. The hub supports neither,
# but they MUST answer 405 (spec) - an APIM-level 404 (no matching operation) makes
# clients treat the transport as broken and re-run initialize in a loop. These
# operations exist only so the requests reach the policy, which returns 405.
resource "azurerm_api_management_api_operation" "mcp_get" {
  operation_id        = "mcp-get"
  api_name            = azurerm_api_management_api.hub.name
  api_management_name = var.api_management_name
  resource_group_name = var.resource_group_name
  display_name        = "MCP endpoint (SSE stream - not supported)"
  method              = "GET"
  url_template        = "/mcp"
  description         = "Always 405: the hub does not offer a server-initiated SSE stream."

  response {
    status_code = 405
  }
}

resource "azurerm_api_management_api_operation" "mcp_delete" {
  operation_id        = "mcp-delete"
  api_name            = azurerm_api_management_api.hub.name
  api_management_name = var.api_management_name
  resource_group_name = var.resource_group_name
  display_name        = "MCP endpoint (session delete - not supported)"
  method              = "DELETE"
  url_template        = "/mcp"
  description         = "Always 405: the hub is stateless and has no sessions to delete."

  response {
    status_code = 405
  }
}

resource "azurerm_api_management_api_policy" "hub" {
  api_name            = azurerm_api_management_api.hub.name
  api_management_name = var.api_management_name
  resource_group_name = var.resource_group_name
  xml_content         = var.policy_xml
}
