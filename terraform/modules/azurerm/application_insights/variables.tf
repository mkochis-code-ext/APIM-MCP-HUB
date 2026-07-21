variable "name" {
  description = "Name of the Application Insights instance"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "workspace_id" {
  description = "Log Analytics workspace ID (workspace-based App Insights)"
  type        = string
}

variable "application_type" {
  description = "Application type"
  type        = string
  default     = "web"
}

variable "tags" {
  description = "Tags to apply to the resource"
  type        = map(string)
  default     = {}
}
