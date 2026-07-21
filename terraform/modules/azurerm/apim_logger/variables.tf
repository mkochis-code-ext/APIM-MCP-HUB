variable "name" {
  description = "Name of the APIM logger"
  type        = string
  default     = "appinsights"
}

variable "api_management_name" {
  description = "Name of the API Management instance"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "application_insights_id" {
  description = "Resource ID of the Application Insights instance"
  type        = string
}

variable "application_insights_connection_string" {
  description = "Application Insights connection string"
  type        = string
  sensitive   = true
}
