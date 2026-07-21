variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "api_management_name" {
  description = "Name of the API Management instance"
  type        = string
}

variable "logger_id" {
  description = "ID of the APIM Application Insights logger"
  type        = string
}

variable "sampling_percentage" {
  description = "Sampling percentage for diagnostics (100 for a demo so nothing is dropped)"
  type        = number
  default     = 100
}
