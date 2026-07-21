# The two Entra app registrations for MCP OBO auth, fully Terraform-managed
# (replaces the manual "Identities" setup in the README):
#
#   App A - the API app (OBO middle-tier): exposes api://<id>/mcp.tools (the inbound
#           token audience), owns the client secret APIM uses for the OBO exchange,
#           and holds the delegated Databricks user_impersonation permission.
#   App B - the VS Code public client: loopback redirect URIs + public client flows,
#           granted the mcp.tools scope on App A.
#
# Composition uses the STANDALONE azuread resources (application_registration,
# application_permission_scope, application_api_access, application_known_clients,
# ...) instead of monolithic azuread_application blocks, because the two apps
# reference each other (A.knownClientApplications -> B; B.requiredResourceAccess -> A)
# - a cycle that only the standalone resources can express.
#
# NOT managed here (still manual / out-of-band):
#   - Admin consent for both permission legs (see README "Consent")
#   - The Foundry first-party SP + Foundry.Mcp.Tools permission
#   - Databricks SCIM provisioning + Unity Catalog / Genie grants

# ---------- App A: the API app (OBO middle-tier) ----------
resource "azuread_application_registration" "api" {
  display_name     = var.api_app_display_name
  sign_in_audience = "AzureADMyOrg"
}

# Application ID URI = api://<client-id>; this is the audience the hub policy validates.
resource "azuread_application_identifier_uri" "api" {
  application_id = azuread_application_registration.api.id
  identifier_uri = "api://${azuread_application_registration.api.client_id}"
}

resource "random_uuid" "mcp_tools_scope" {}

resource "azuread_application_permission_scope" "mcp_tools" {
  application_id = azuread_application_registration.api.id
  scope_id       = random_uuid.mcp_tools_scope.result
  value          = "mcp.tools"

  admin_consent_description  = "Allow the application to call MCP tools through APIM on behalf of the signed-in user."
  admin_consent_display_name = "Call MCP tools"
  user_consent_description   = "Allow the application to call MCP tools through APIM on your behalf."
  user_consent_display_name  = "Call MCP tools"
  type                       = "User" # admins and users can consent
}

# The client secret APIM uses for the OBO exchange. Lands in Terraform state and is
# wired straight into the obo-client-secret named value - never in tfvars.
resource "azuread_application_password" "api" {
  application_id = azuread_application_registration.api.id
  display_name   = "apim-obo-exchange"
  end_date       = var.secret_end_date
}

resource "azuread_service_principal" "api" {
  client_id = azuread_application_registration.api.client_id
}

# App A -> AzureDatabricks user_impersonation (delegated): authorizes Entra to mint
# the per-user Databricks token during the OBO exchange. Consent stays manual.
data "azuread_service_principal" "databricks" {
  count     = var.databricks_permission_enabled ? 1 : 0
  client_id = var.databricks_app_id
}

resource "azuread_application_api_access" "api_to_databricks" {
  count = var.databricks_permission_enabled ? 1 : 0

  application_id = azuread_application_registration.api.id
  api_client_id  = var.databricks_app_id
  scope_ids      = [data.azuread_service_principal.databricks[0].oauth2_permission_scope_ids["user_impersonation"]]
}

# ---------- App B: the VS Code public client ----------
resource "azuread_application_registration" "client" {
  display_name     = var.client_app_display_name
  sign_in_audience = "AzureADMyOrg"
}

resource "azuread_application_redirect_uris" "client_public" {
  application_id = azuread_application_registration.client.id
  type           = "PublicClient"
  redirect_uris = [
    "http://localhost",
    "http://127.0.0.1",
    "https://vscode.dev/redirect",          # VS Code stable MCP auth flow
    "https://insiders.vscode.dev/redirect", # VS Code Insiders
  ]
}

resource "azuread_application_fallback_public_client" "client" {
  application_id = azuread_application_registration.client.id
  enabled        = true
}

resource "azuread_service_principal" "client" {
  client_id = azuread_application_registration.client.client_id
}

# App B -> App A mcp.tools (delegated)
resource "azuread_application_api_access" "client_to_api" {
  application_id = azuread_application_registration.client.id
  api_client_id  = azuread_application_registration.api.client_id
  scope_ids      = [azuread_application_permission_scope.mcp_tools.scope_id]
}

# ---------- Link the two apps (combined consent) ----------
# knownClientApplications on App A so the client sign-in prompts for BOTH permission
# legs at once - the OBO middle-tier cannot prompt for consent itself.
resource "azuread_application_known_clients" "api" {
  application_id = azuread_application_registration.api.id
  known_client_ids = [
    azuread_application_registration.client.client_id,
  ]
}
