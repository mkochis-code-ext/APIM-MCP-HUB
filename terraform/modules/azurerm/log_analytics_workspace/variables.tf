variable "name" {
  description = "Name of the Log Analytics workspace"
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

variable "sku" {
  description = "Log Analytics SKU"
  type        = string
  default     = "PerGB2018"
}

variable "retention_in_days" {
  description = "Data retention in days"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply to the resource"
  type        = map(string)
  default     = {}
}
