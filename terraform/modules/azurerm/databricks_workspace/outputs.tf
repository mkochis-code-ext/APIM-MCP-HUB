output "workspace_url" {
  description = "Workspace URL (host for managed MCP endpoints)"
  value       = azurerm_databricks_workspace.main.workspace_url
}
