output "resource_group_name" {
  description = "Name of the resource group"
  value       = module.project.resource_group_name
}

# ---------- MCP Hub (single aggregated MCP endpoint) ----------
output "mcp_hub_url" {
  description = "Aggregated MCP hub endpoint to configure in VS Code (only when mcp_hub_enabled)"
  value       = module.project.mcp_hub_url
}

output "mcp_hub_policy_xml" {
  description = "Rendered hub policy for review. Retrieve with: terraform output -raw mcp_hub_policy_xml"
  value       = module.project.mcp_hub_policy_xml
}

output "mcp_hub_acl_named_values" {
  description = "Per-server ACL named-value content (single-quoted JSON) for review"
  value       = module.project.mcp_hub_acl_named_values
}

output "mcp_server_urls" {
  description = "Per-server MCP API endpoints (hub-only: reject requests without the hub's X-MCP-Internal-Key)"
  value       = module.project.mcp_server_urls
}

output "apim_name" {
  description = "Name of the API Management instance"
  value       = module.project.apim_name
}

output "apim_gateway_url" {
  description = "Gateway URL of the API Management instance"
  value       = module.project.apim_gateway_url
}

output "mcp_named_value_name" {
  description = "Name of the secret APIM named value holding the OBO client secret (refreshSecret after rotating it)"
  value       = module.project.mcp_named_value_name
}

output "prm_metadata_json" {
  description = "Protected Resource Metadata (RFC 9728) document for MCP OAuth discovery. Retrieve with: terraform output -raw prm_metadata_json"
  value       = module.project.prm_metadata_json
}

output "prm_well_known_url" {
  description = "URL where the Protected Resource Metadata document must be served (obo mode)"
  value       = module.project.prm_well_known_url
}

output "oauth_scope" {
  description = "Delegated scope the MCP client requests and the OAuth facade forwards to Entra (obo mode)"
  value       = module.project.oauth_scope
}

output "entra_tenant_id" {
  description = "Entra tenant ID used by the OAuth facade (obo mode)"
  value       = module.project.entra_tenant_id
}

output "mcp_client_app_id" {
  description = "VS Code public client app registration ID returned by the facade DCR shim (obo mode)"
  value       = module.project.mcp_client_app_id
}

output "mcp_api_app_id" {
  description = "API app (OBO middle-tier) registration ID - the inbound token audience api://<id>"
  value       = module.project.mcp_api_app_id
}

output "application_insights_name" {
  description = "Name of the Application Insights instance"
  value       = module.project.application_insights_name
}

output "databricks_workspace_url" {
  description = "Databricks workspace URL (only when created by this deployment)"
  value       = module.project.databricks_workspace_url
}
