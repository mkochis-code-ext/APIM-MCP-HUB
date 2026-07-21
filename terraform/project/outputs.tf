output "resource_group_name" {
  description = "Name of the resource group"
  value       = module.resource_group.name
}

output "apim_name" {
  description = "Name of the API Management instance"
  value       = module.api_management.name
}

output "apim_gateway_url" {
  description = "Gateway URL of the API Management instance"
  value       = module.api_management.gateway_url
}

output "mcp_named_value_name" {
  description = "Name of the secret APIM named value holding the OBO client secret. This is the value to refreshSecret after rotating the secret."
  value       = local.obo_secret_named_value
}

output "prm_metadata_json" {
  description = "Protected Resource Metadata (RFC 9728) document to serve at <gateway>/.well-known/oauth-protected-resource for MCP OAuth discovery. Retrieve with: terraform output -raw prm_metadata_json"
  value       = local.prm_metadata_json
}

output "prm_well_known_url" {
  description = "URL where the Protected Resource Metadata document must be served"
  value       = "${local.gateway_url}/.well-known/oauth-protected-resource"
}

output "oauth_scope" {
  description = "Delegated scope the MCP client requests and the OAuth facade forwards to Entra"
  value       = local.oauth_scope
}

output "entra_tenant_id" {
  description = "Entra tenant ID used by the OAuth facade"
  value       = var.entra_tenant_id
}

output "mcp_client_app_id" {
  description = "VS Code public client app registration ID returned by the facade DCR shim"
  value       = local.mcp_client_app_id
}

output "mcp_api_app_id" {
  description = "API app (OBO middle-tier) registration ID - the inbound token audience api://<id>"
  value       = local.mcp_api_app_id
}

output "application_insights_name" {
  description = "Name of the Application Insights instance"
  value       = module.application_insights.name
}

output "databricks_workspace_url" {
  description = "Databricks workspace URL (only when created by this deployment)"
  value       = var.create_databricks_workspace ? module.databricks_workspace[0].workspace_url : null
}

# ---------- MCP Hub (single aggregated MCP endpoint) ----------
output "mcp_hub_url" {
  description = "Aggregated MCP hub endpoint to configure in VS Code / GitHub Copilot (only when mcp_hub_enabled)"
  value       = var.mcp_hub_enabled ? "${local.gateway_url}/${var.mcp_hub_path}/mcp" : null
}

output "mcp_hub_policy_xml" {
  description = "Rendered hub policy (applied by Terraform when mcp_hub_enabled; exported for review). Retrieve with: terraform output -raw mcp_hub_policy_xml"
  value       = local.hub_policy_xml
}

output "mcp_hub_acl_named_values" {
  description = "Per-server ACL named-value content (single-quoted JSON) keyed by server. Review before apply; after apply, edit the mcp-acl-<server> named values to change persona tool lists without a policy redeploy."
  value       = local.hub_acl_values
}

output "mcp_server_urls" {
  description = "Per-server MCP API endpoints (hub-only: reject requests without the hub's X-MCP-Internal-Key)"
  value       = { for name, m in module.mcp_server : name => "${local.gateway_url}/${m.path}/mcp" }
}
