locals {
  resource_group_name  = "rg-${var.workload}-${var.environment_prefix}-${var.suffix}"
  law_name             = "log-${var.workload}-${var.environment_prefix}-${var.suffix}"
  appinsights_name     = "appi-${var.workload}-${var.environment_prefix}-${var.suffix}"
  apim_name            = "apim-${var.workload}-${var.environment_prefix}-${var.suffix}"
  databricks_name      = "dbw-${var.workload}-${var.environment_prefix}-${var.suffix}"
  actual_data_location = var.data_location != "" ? var.data_location : var.location

  obo_secret_named_value = "obo-client-secret"

  # Default APIM gateway hostname (no custom domain). Derived - not the module's computed
  # gateway_url - so it is known at plan time; templatefile() rejects unknown values.
  gateway_url = "https://${local.apim_name}.azure-api.net"

  # ---- Effective Entra identity values ----
  # When create_entra_apps = true, Terraform creates both app registrations and the
  # OBO secret (modules/azuread/mcp_entra_apps) and these locals resolve to the created
  # values; otherwise they fall back to the externally-created IDs/secret in tfvars.
  mcp_api_app_id    = var.create_entra_apps ? module.entra_apps[0].api_app_client_id : var.mcp_api_app_id
  mcp_client_app_id = var.create_entra_apps ? module.entra_apps[0].client_app_client_id : var.mcp_client_app_id
  obo_client_secret = var.create_entra_apps ? module.entra_apps[0].obo_client_secret : var.obo_client_secret

  # Optional client-application-ids restriction for the OBO validate-azure-ad-token.
  # Rendered only when the client app id is set (otherwise the audience alone gates access).
  client_app_ids_xml = local.mcp_client_app_id != "" ? "<client-application-ids><application-id>${local.mcp_client_app_id}</application-id></client-application-ids>" : ""

  # Protected Resource Metadata (RFC 9728) advertised at
  # <gateway>/.well-known/oauth-protected-resource for MCP client OAuth discovery.
  # authorization_servers points at the APIM OAuth facade (the gateway itself), which
  # brokers the flow to Entra - VS Code cannot use Entra directly as its authorization
  # server (no DCR, metadata shape). See modules/azurerm/apim_oauth_facade + README OBO steps.
  prm_metadata_json = jsonencode({
    resource                 = "${local.gateway_url}/${var.mcp_hub_path}/mcp"
    authorization_servers    = [local.gateway_url]
    bearer_methods_supported = ["header"]
    scopes_supported         = local.mcp_api_app_id != "" ? ["api://${local.mcp_api_app_id}/mcp.tools"] : []
  })

  # Scope the MCP client requests / the facade forwards to Entra.
  oauth_scope = local.mcp_api_app_id != "" ? "api://${local.mcp_api_app_id}/mcp.tools" : ""

  # ----- MCP observability dashboard (Azure Monitor Workbook) -----
  # Every report reads the App Insights `traces` telemetry emitted by the shared OBO
  # policy's <trace> step. Each MCP call writes customDimensions: mcp-server
  # (the cache_prefix, e.g. "dbx"/"foundry"), caller-upn (the user, a friendly name that
  # falls back to caller-oid when no preferred_username/upn/name claim is present), and request-body
  # (the JSON-RPC payload whose params.name is the tool for a tools/call).
  #
  # {User} is the multi-select UPN dropdown parameter (its "All" option expands to every
  # value from the parameter query, so `user in ({User})` matches all when All is picked).
  # {TimeRange:grain} comes from the workbook time-range parameter; report items bind
  # their window to it via timeContextFromParameter, except the fixed last-24h tool report.

  # Populates the User (UPN) dropdown parameter.
  mcp_dashboard_query_user_param = <<-KQL
    traces
    | where message == "MCP tool call through APIM (OBO)"
    | extend upn = tostring(customDimensions["caller-upn"]), oid = tostring(customDimensions["caller-oid"])
    | extend user = iff(isempty(upn) or upn == "n/a", oid, upn)
    | where isnotempty(user)
    | distinct user
    | order by user asc
  KQL

  # Time chart: MCP requests over time, one series per MCP server.
  mcp_dashboard_query_timechart = <<-KQL
    traces
    | where message == "MCP tool call through APIM (OBO)"
    | extend mcpServer = tostring(customDimensions["mcp-server"]),
             upn = tostring(customDimensions["caller-upn"]),
             oid = tostring(customDimensions["caller-oid"])
    | extend user = iff(isempty(upn) or upn == "n/a", oid, upn)
    | where isnotempty(mcpServer) and user in ({User})
    | summarize Requests = count() by bin(timestamp, {TimeRange:grain}), mcpServer
    | order by timestamp asc
  KQL

  # Report 1: which MCP servers each user has called (friendly name + Entra object id).
  mcp_dashboard_query_servers_by_user = <<-KQL
    traces
    | where message == "MCP tool call through APIM (OBO)"
    | extend mcpServer = tostring(customDimensions["mcp-server"]),
             upn = tostring(customDimensions["caller-upn"]),
             oid = tostring(customDimensions["caller-oid"])
    | extend user = iff(isempty(upn) or upn == "n/a", oid, upn)
    | where isnotempty(user) and user in ({User})
    | summarize Requests = count(), LastUsed = max(timestamp) by user, ObjectId = oid, mcpServer
    | project user, ObjectId, mcpServer, Requests, LastUsed
    | order by user asc, Requests desc
  KQL

  # Report 2 (grid): requests per tool per MCP server over the last 24 hours.
  mcp_dashboard_query_tools_24h = <<-KQL
    traces
    | where timestamp > ago(24h)
    | where message == "MCP tool call through APIM (OBO)"
    | extend mcpServer = tostring(customDimensions["mcp-server"]),
             upn = tostring(customDimensions["caller-upn"]),
             oid = tostring(customDimensions["caller-oid"]),
             body = tostring(customDimensions["request-body"])
    | extend user = iff(isempty(upn) or upn == "n/a", oid, upn)
    | where user in ({User})
    | extend method = tostring(parse_json(body).method),
             tool = tostring(parse_json(body).params.name)
    | where method == "tools/call" and isnotempty(tool)
    | summarize Requests = count() by mcpServer, tool
    | order by mcpServer asc, Requests desc
  KQL

  # Report 2 (bar chart): same last-24h data collapsed to one bar per server/tool.
  mcp_dashboard_query_tools_24h_chart = <<-KQL
    traces
    | where timestamp > ago(24h)
    | where message == "MCP tool call through APIM (OBO)"
    | extend mcpServer = tostring(customDimensions["mcp-server"]),
             upn = tostring(customDimensions["caller-upn"]),
             oid = tostring(customDimensions["caller-oid"]),
             body = tostring(customDimensions["request-body"])
    | extend user = iff(isempty(upn) or upn == "n/a", oid, upn)
    | where user in ({User})
    | extend method = tostring(parse_json(body).method),
             tool = tostring(parse_json(body).params.name)
    | where method == "tools/call" and isnotempty(tool)
    | summarize Requests = count() by ServerTool = strcat(mcpServer, " / ", tool)
    | order by Requests desc
  KQL

  mcp_dashboard_data_json = jsonencode({
    version = "Notebook/1.0"
    items = [
      {
        type = 1
        content = {
          json = "# MCP Observability\nRequests routed through APIM to the MCP servers (On-Behalf-Of). Source: Application Insights `traces` emitted by the APIM OBO policy. Use the **User** and **Time range** filters below. The tool report is always the last 24 hours."
        }
        name = "title"
      },
      {
        type = 9
        content = {
          version = "KqlParameterItem/1.0"
          parameters = [
            {
              id         = "8f1e0b10-0000-4a00-9a00-00000000t001"
              version    = "KqlParameterItem/1.0"
              name       = "TimeRange"
              label      = "Time range"
              type       = 4
              isRequired = true
              typeSettings = {
                selectableValues = [
                  { durationMs = 3600000 },
                  { durationMs = 14400000 },
                  { durationMs = 43200000 },
                  { durationMs = 86400000 },
                  { durationMs = 172800000 },
                  { durationMs = 604800000 },
                  { durationMs = 2592000000 }
                ]
                allowCustom = true
              }
              value = { durationMs = 86400000 }
            },
            {
              id                      = "8f1e0b10-0000-4a00-9a00-00000000u002"
              version                 = "KqlParameterItem/1.0"
              name                    = "User"
              label                   = "User"
              type                    = 2
              isRequired              = true
              multiSelect             = true
              quote                   = "'"
              delimiter               = ","
              query                   = local.mcp_dashboard_query_user_param
              queryType               = 0
              resourceType            = "microsoft.insights/components"
              crossComponentResources = [module.application_insights.id]
              typeSettings = {
                additionalResourceOptions = ["value::all"]
                showDefault               = false
              }
              value = ["value::all"]
            }
          ]
          style        = "pills"
          queryType    = 0
          resourceType = "microsoft.insights/components"
        }
        name = "parameters"
      },
      {
        type = 3
        content = {
          version                  = "KqlItem/1.0"
          query                    = local.mcp_dashboard_query_timechart
          size                     = 0
          title                    = "MCP requests over time by server"
          timeContextFromParameter = "TimeRange"
          queryType                = 0
          resourceType             = "microsoft.insights/components"
          crossComponentResources  = [module.application_insights.id]
          visualization            = "timechart"
        }
        name = "requests-over-time"
      },
      {
        type = 3
        content = {
          version                  = "KqlItem/1.0"
          query                    = local.mcp_dashboard_query_servers_by_user
          size                     = 0
          title                    = "MCP servers used per user"
          timeContextFromParameter = "TimeRange"
          queryType                = 0
          resourceType             = "microsoft.insights/components"
          crossComponentResources  = [module.application_insights.id]
          visualization            = "table"
        }
        name = "servers-by-user"
      },
      {
        type = 3
        content = {
          version                 = "KqlItem/1.0"
          query                   = local.mcp_dashboard_query_tools_24h
          size                    = 0
          title                   = "Requests per tool per MCP server (last 24h)"
          queryType               = 0
          resourceType            = "microsoft.insights/components"
          crossComponentResources = [module.application_insights.id]
          visualization           = "table"
        }
        name = "tools-last-24h"
      },
      {
        type = 3
        content = {
          version                 = "KqlItem/1.0"
          query                   = local.mcp_dashboard_query_tools_24h_chart
          size                    = 0
          title                   = "Tool usage by server (last 24h)"
          queryType               = 0
          resourceType            = "microsoft.insights/components"
          crossComponentResources = [module.application_insights.id]
          visualization           = "barchart"
        }
        name = "tools-last-24h-chart"
      }
    ]
    "$schema" = "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"
  })
}

# ---------- Foundation ----------
module "resource_group" {
  source = "../modules/azurerm/resource_group"

  name     = local.resource_group_name
  location = var.location
  tags     = var.tags
}

module "log_analytics_workspace" {
  source = "../modules/azurerm/log_analytics_workspace"

  name                = local.law_name
  location            = var.location
  resource_group_name = module.resource_group.name
  tags                = var.tags
}

module "application_insights" {
  source = "../modules/azurerm/application_insights"

  name                = local.appinsights_name
  location            = var.location
  resource_group_name = module.resource_group.name
  workspace_id        = module.log_analytics_workspace.id
  tags                = var.tags
}

# ---------- API Management ----------
module "api_management" {
  source = "../modules/azurerm/api_management"

  name                = local.apim_name
  location            = var.location
  resource_group_name = module.resource_group.name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = var.apim_sku_name
  tags                = var.tags
}

# App Insights logger + global diagnostic (body_bytes = 0 => MCP-safe)
module "apim_logger" {
  source = "../modules/azurerm/apim_logger"

  api_management_name                    = module.api_management.name
  resource_group_name                    = module.resource_group.name
  application_insights_id                = module.application_insights.id
  application_insights_connection_string = module.application_insights.connection_string
}

module "apim_diagnostic" {
  source = "../modules/azurerm/apim_diagnostic"

  resource_group_name = module.resource_group.name
  api_management_name = module.api_management.name
  logger_id           = module.apim_logger.id
}

# MCP observability dashboard: two reports (MCP servers per user, and requests per
# tool per MCP server in the last 24h) over the App Insights traces the OBO policy emits.
module "mcp_dashboard" {
  source = "../modules/azurerm/monitor_workbook"

  display_name        = "MCP Observability - ${var.workload}-${var.environment_prefix}"
  location            = var.location
  resource_group_name = module.resource_group.name
  source_id           = module.application_insights.id
  data_json           = local.mcp_dashboard_data_json
  tags                = var.tags
}

# ---------- Credential custody (APIM secret named value) ----------
# Holds the OBO client secret (the middle-tier app registration's secret) as a
# plain APIM secret named value (encrypted at rest in APIM). There is no standing
# shared data credential in OBO mode - each caller's Databricks token is minted
# per-request via the On-Behalf-Of exchange.
module "apim_named_value" {
  source = "../modules/azurerm/apim_named_value"

  name                = local.obo_secret_named_value
  display_name        = local.obo_secret_named_value
  resource_group_name = module.resource_group.name
  api_management_name = module.api_management.name
  secret_value        = local.obo_client_secret
}

# ---------- Entra app registrations (optional, Terraform-managed) ----------
# App A (API app / OBO middle-tier) + App B (VS Code public client) + the OBO client
# secret + knownClientApplications + the Databricks delegated permission. When enabled,
# mcp_api_app_id / mcp_client_app_id / obo_client_secret in tfvars are ignored.
# Consent (both legs) and the Foundry permission remain manual - see the README.
module "entra_apps" {
  source = "../modules/azuread/mcp_entra_apps"
  count  = var.create_entra_apps ? 1 : 0

  api_app_display_name    = var.entra_api_app_display_name
  client_app_display_name = var.entra_client_app_display_name
  secret_end_date         = var.obo_secret_end_date
}

# ---------- OAuth authorization-server facade (Terraform-managed) ----------
# The root-path APIM API (PRM + AS metadata + authorize/token/register) that lets the
# VS Code MCP client sign in against Entra.
module "oauth_facade" {
  source = "../modules/azurerm/apim_oauth_facade"
  count  = var.oauth_facade_enabled ? 1 : 0

  resource_group_name = module.resource_group.name
  api_management_name = module.api_management.name
  gateway_url         = local.gateway_url
  entra_tenant_id     = var.entra_tenant_id
  mcp_client_app_id   = local.mcp_client_app_id
  oauth_scope         = local.oauth_scope
  prm_metadata_json   = local.prm_metadata_json
}

# ---------- Graph roles for the hub's group-ACL fallback (optional) ----------
# Grants the APIM system-assigned identity the Graph APPLICATION permissions needed by
# checkMemberGroups on /users/{id} (transitive; handles the groups-overage claim):
# per the Graph docs, the least-privileged pair for "group memberships for other
# users" with an application identity is GroupMember.Read.All AND User.ReadBasic.All -
# GroupMember.Read.All alone gets a 403. Creating app role assignments requires
# directory privileges (e.g. Privileged Role Administrator / Global Admin) - hence
# the separate toggle from mcp_hub_graph_fallback itself.
data "azuread_service_principal" "msgraph" {
  count     = var.apim_graph_role_assignment_enabled ? 1 : 0
  client_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
}

resource "azuread_app_role_assignment" "apim_graph_fallback" {
  for_each = var.apim_graph_role_assignment_enabled ? toset(["GroupMember.Read.All", "User.ReadBasic.All"]) : toset([])

  app_role_id         = data.azuread_service_principal.msgraph[0].app_role_ids[each.key]
  principal_object_id = module.api_management.principal_id
  resource_object_id  = data.azuread_service_principal.msgraph[0].object_id
}

# ---------- Optional Databricks workspace ----------
module "databricks_workspace" {
  source = "../modules/azurerm/databricks_workspace"
  count  = var.create_databricks_workspace ? 1 : 0

  name                = local.databricks_name
  location            = var.location
  resource_group_name = module.resource_group.name
  tags                = var.tags
}

# ---------- MCP Hub: thin aggregator + one APIM API per MCP server ----------
# The hub (POST <gateway>/<hub-path>/mcp) answers initialize/ping locally, broadcasts
# tools/list to every per-server API (drops 403/failed responses, prefixes
# <server>__<tool>, merges), and routes tools/call to the right per-server API.
# ALL server-specific policy complexity - ACL evaluation (shared mcp-acl-eval
# fragment), tool filtering, OBO, per-server rate limits - lives in the per-server
# APIs (<gateway>/mcp-servers/<name>/mcp), which are HUB-ONLY: they reject requests
# without the X-MCP-Internal-Key shared secret the hub injects.
#
# Entitlements: per-server ACL named values (mcp-acl-<server>) - unchanged format.
#   - Onboarding a server   => one var.mcp_hub_servers entry + terraform apply
#   - Editing a persona ACL => named-value-only update (~30s, no policy redeploy)
#   - Granting a user       => Entra group membership; no APIM change at all

locals {
  # Route prefix for the per-server APIs: <gateway>/mcp-servers/<name>/mcp
  mcp_servers_path_prefix = "mcp-servers"

  # Server registry driven entirely by var.mcp_hub_servers (tfvars): onboarding = one
  # map entry + terraform apply, no .tf edits. Keys become the tool-name prefixes
  # (dbx__<tool>), the ACL named-value suffixes (mcp-acl-dbx), and the API path
  # segments (mcp-servers/dbx). backend_url is split into host + rewrite path.
  hub_servers = {
    for name, s in var.mcp_hub_servers : name => {
      backend   = regex("^https?://[^/]+", s.backend_url)
      path      = replace(s.backend_url, regex("^https?://[^/]+", s.backend_url), "") != "" ? replace(s.backend_url, regex("^https?://[^/]+", s.backend_url), "") : "/"
      auth      = s.auth
      obo_scope = s.obo_scope
    }
  }

  # Per-server ACL named-value content. SINGLE-QUOTED JSON: named values are substituted
  # into the policy as raw text inside C# string literals, and Newtonsoft's JObject.Parse
  # accepts single quotes - double quotes would break policy compilation. Consequence:
  # tool names / GUIDs / URLs must not contain apostrophes (they can't, per their specs).
  hub_acl_values = {
    for name, s in local.hub_servers :
    name => replace(jsonencode({
      backend = s.backend
      path    = s.path
      acl = [
        for e in var.mcp_hub_servers[name].acl : merge(
          {
            match = { type = e.match_type, value = e.match_value }
            # jsonencode/jsondecode round-trip: Terraform conditionals require both
            # branches to have the same type (string "all" vs list of tools), so
            # serialize each branch to a string first and decode the winner.
            allow = jsondecode(contains(e.allow, "*") ? jsonencode("all") : jsonencode(e.allow))
          },
          length(e.deny) > 0 ? { deny = e.deny } : {}
        )
      ]
    }), "\"", "'")
  }

  hub_policy_xml = templatefile("${path.module}/templates/hub-mcp-policy.xml.tftpl", {
    gateway_url         = local.gateway_url
    entra_tenant_id     = var.entra_tenant_id
    client_app_ids_xml  = local.client_app_ids_xml
    mcp_api_app_id      = local.mcp_api_app_id
    rate_limit_calls    = var.rate_limit_calls
    rate_limit_period   = var.rate_limit_period
    tools_cache_seconds = var.mcp_hub_tools_cache_seconds
    servers_path_prefix = local.mcp_servers_path_prefix
    server_names        = keys(var.mcp_hub_servers)
  })
}

# Shared secret gating the per-server APIs to hub-originated traffic only.
resource "random_password" "mcp_hub_internal_key" {
  count = var.mcp_hub_enabled ? 1 : 0

  length  = 48
  special = false
}

# ---- Shared named values (project-level so BOTH the hub policy and the per-server
# policies/fragments can reference them without a module dependency cycle). Toggle
# edits propagate in ~30s with no policy redeploy. ----
resource "azurerm_api_management_named_value" "mcp_hub_internal_key" {
  count = var.mcp_hub_enabled ? 1 : 0

  name                = "mcp-hub-internal-key"
  display_name        = "mcp-hub-internal-key"
  resource_group_name = module.resource_group.name
  api_management_name = module.api_management.name
  secret              = true
  value               = random_password.mcp_hub_internal_key[0].result
  tags                = ["mcp-hub"]
}

resource "azurerm_api_management_named_value" "mcp_hub_debug" {
  count = var.mcp_hub_enabled ? 1 : 0

  name                = "mcp-hub-debug"
  display_name        = "mcp-hub-debug"
  resource_group_name = module.resource_group.name
  api_management_name = module.api_management.name
  secret              = false
  value               = var.mcp_hub_debug ? "true" : "false"
  tags                = ["mcp-hub", "debug"]
}

resource "azurerm_api_management_named_value" "mcp_hub_graph_fallback" {
  count = var.mcp_hub_enabled ? 1 : 0

  name                = "mcp-hub-graph-fallback"
  display_name        = "mcp-hub-graph-fallback"
  resource_group_name = module.resource_group.name
  api_management_name = module.api_management.name
  secret              = false
  value               = var.mcp_hub_graph_fallback ? "true" : "false"
  tags                = ["mcp-hub"]
}

# ---- Policy fragments: shared ACL evaluation + isolated debug tracing. Main
# policies stay pure control flow with one-line <include-fragment> references.
# All fragments reference the named values above, hence the depends_on. ----
locals {
  mcp_policy_fragments = var.mcp_hub_enabled ? {
    "mcp-acl-eval"    = "Shared MCP ACL evaluation: token claims + Graph checkMemberGroups fallback + persona entry matching"
    "mcp-debug-acl"   = "Debug trace (mcp-hub-debug gated): claim shape + Graph fallback outcome + ACL result"
    "mcp-debug-obo"   = "Debug trace (mcp-hub-debug gated): OBO exchange failure with the Entra AADSTS error body"
    "mcp-debug-error" = "Debug trace (mcp-hub-debug gated): on-error source/reason/message, shared by hub + servers"
  } : {}
}

resource "azurerm_api_management_policy_fragment" "mcp" {
  for_each = local.mcp_policy_fragments

  api_management_id = module.api_management.id
  name              = each.key
  description       = each.value
  format            = "rawxml"
  value             = file("${path.module}/templates/${each.key}.fragment.xml")

  depends_on = [
    azurerm_api_management_named_value.mcp_hub_debug,
    azurerm_api_management_named_value.mcp_hub_graph_fallback,
    azurerm_api_management_named_value.mcp_hub_internal_key,
  ]
}

module "mcp_hub" {
  source = "../modules/azurerm/apim_mcp_hub"
  count  = var.mcp_hub_enabled ? 1 : 0

  api_name            = var.mcp_hub_server_id
  display_name        = "MCP Hub"
  path                = var.mcp_hub_path
  resource_group_name = module.resource_group.name
  api_management_name = module.api_management.name
  policy_xml          = local.hub_policy_xml

  # The hub policy references {{mcp-hub-internal-key}}/{{mcp-hub-debug}} and the
  # mcp-debug-error fragment; all must exist before the policy compiles.
  depends_on = [azurerm_api_management_policy_fragment.mcp]
}

# One NATIVE APIM MCP server (type = "mcp", preview RP via azapi - shows under
# "MCP Servers" in the portal) per hub entry. Hub-only; owns ACL named value,
# filtering, OBO, rate limit. Policies reference the shared named values
# ({{mcp-hub-debug}}, {{mcp-hub-graph-fallback}}, {{mcp-hub-internal-key}},
# {{obo-client-secret}}) and the mcp-acl-eval fragment - hence the depends_on.
module "mcp_server" {
  source   = "../modules/azurerm/apim_mcp_server"
  for_each = var.mcp_hub_enabled ? var.mcp_hub_servers : {}

  server_name         = each.key
  path_prefix         = local.mcp_servers_path_prefix
  resource_group_name = module.resource_group.name
  api_management_name = module.api_management.name
  api_management_id   = module.api_management.id
  backend_url         = each.value.backend_url

  entra_tenant_id    = var.entra_tenant_id
  client_app_ids_xml = local.client_app_ids_xml
  mcp_api_app_id     = local.mcp_api_app_id

  auth                   = each.value.auth
  obo_scope              = each.value.obo_scope
  obo_secret_named_value = local.obo_secret_named_value
  obo_cache_seconds      = var.obo_cache_seconds
  tools_cache_seconds    = var.mcp_hub_tools_cache_seconds
  rate_limit_calls       = each.value.rate_limit_calls
  rate_limit_period      = each.value.rate_limit_period

  acl_value = local.hub_acl_values[each.key]

  depends_on = [
    azurerm_api_management_policy_fragment.mcp,
    module.apim_named_value,
  ]
}
