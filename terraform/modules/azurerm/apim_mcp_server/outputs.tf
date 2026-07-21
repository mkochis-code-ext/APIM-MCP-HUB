output "path" {
  description = "Route prefix of the per-server MCP API (<path_prefix>/<server_name>)"
  value       = "${var.path_prefix}/${var.server_name}"
}
