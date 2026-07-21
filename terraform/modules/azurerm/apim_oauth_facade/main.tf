# OAuth authorization-server facade for MCP client (VS Code) sign-in, fully
# Terraform-managed.
#
# One anonymous APIM API at the GATEWAY ROOT (path = "") hosting:
#   GET  /.well-known/oauth-protected-resource   (PRM, RFC 9728)
#   GET  /.well-known/oauth-authorization-server (AS metadata, RFC 8414)
#   GET  /authorize                              (302 -> Entra authorize)
#   POST /token                                  (proxy -> Entra token)
#   POST /register                               (DCR shim -> pre-registered client)
# plus OPTIONS CORS handlers.
#
# This is a STREAMLINED facade tailored to VS Code + Entra with a pre-registered
# public client. PKCE flows end-to-end between VS Code and Entra, so no server-side
# state is stored (no CosmosDB, no consent page - see the AI-Gateway
# mcp-client-authorization lab for the full pattern).

locals {
  policy_vars = {
    gateway_url   = var.gateway_url
    tenant_id     = var.entra_tenant_id
    mcp_client_id = var.mcp_client_app_id
    oauth_scope   = var.oauth_scope
    prm_json      = var.prm_metadata_json
  }

  cors_policy = file("${path.module}/templates/cors-options.policy.xml.tftpl")

  # operation_id => { name, method, url, policy }
  operations = {
    prm-get = {
      display = "PRM"
      method  = "GET"
      url     = "/.well-known/oauth-protected-resource"
      policy  = templatefile("${path.module}/templates/prm-get.policy.xml.tftpl", local.policy_vars)
    }
    metadata-get = {
      display = "AS Metadata"
      method  = "GET"
      url     = "/.well-known/oauth-authorization-server"
      policy  = templatefile("${path.module}/templates/oauthmetadata-get.policy.xml.tftpl", local.policy_vars)
    }
    metadata-options = {
      display = "AS Metadata (CORS)"
      method  = "OPTIONS"
      url     = "/.well-known/oauth-authorization-server"
      policy  = local.cors_policy
    }
    authorize = {
      display = "Authorize"
      method  = "GET"
      url     = "/authorize"
      policy  = templatefile("${path.module}/templates/authorize.policy.xml.tftpl", local.policy_vars)
    }
    token = {
      display = "Token"
      method  = "POST"
      url     = "/token"
      policy  = templatefile("${path.module}/templates/token.policy.xml.tftpl", local.policy_vars)
    }
    token-options = {
      display = "Token (CORS)"
      method  = "OPTIONS"
      url     = "/token"
      policy  = local.cors_policy
    }
    register = {
      display = "Register"
      method  = "POST"
      url     = "/register"
      policy  = templatefile("${path.module}/templates/register.policy.xml.tftpl", local.policy_vars)
    }
    register-options = {
      display = "Register (CORS)"
      method  = "OPTIONS"
      url     = "/register"
      policy  = local.cors_policy
    }
  }
}

resource "azurerm_api_management_api" "oauth" {
  name                  = "oauth"
  resource_group_name   = var.resource_group_name
  api_management_name   = var.api_management_name
  revision              = "1"
  display_name          = "OAuth (MCP facade)"
  path                  = "" # gateway root - the .well-known URLs must live there
  protocols             = ["https"]
  subscription_required = false

  # Never used: every operation either returns in policy or re-routes with
  # set-backend-service (token proxy). A syntactically valid placeholder is required.
  service_url = "https://unused.invalid"
}

resource "azurerm_api_management_api_operation" "op" {
  for_each = local.operations

  operation_id        = each.key
  api_name            = azurerm_api_management_api.oauth.name
  api_management_name = var.api_management_name
  resource_group_name = var.resource_group_name
  display_name        = each.value.display
  method              = each.value.method
  url_template        = each.value.url

  response {
    status_code = 200
  }
}

resource "azurerm_api_management_api_operation_policy" "op" {
  for_each = local.operations

  api_name            = azurerm_api_management_api.oauth.name
  api_management_name = var.api_management_name
  resource_group_name = var.resource_group_name
  operation_id        = azurerm_api_management_api_operation.op[each.key].operation_id
  xml_content         = each.value.policy
}
