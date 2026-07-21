variable "api_name" {
  description = "Resource name (api-id) of the hub API"
  type        = string
  default     = "mcp-hub"
}

variable "display_name" {
  description = "Display name of the hub API"
  type        = string
  default     = "MCP Hub"
}

variable "path" {
  description = "Route prefix for the hub (endpoint becomes <gateway>/<path>/mcp)"
  type        = string
  default     = "mcp-hub"
}

variable "resource_group_name" {
  description = "Resource group of the APIM instance"
  type        = string
}

variable "api_management_name" {
  description = "Name of the APIM instance"
  type        = string
}

variable "policy_xml" {
  description = "Rendered hub policy XML (templates/hub-mcp-policy.xml.tftpl). References project-level named values and fragments; the caller must depends_on them."
  type        = string
}
