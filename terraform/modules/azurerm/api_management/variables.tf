variable "name" {
  description = "Name of the API Management instance (globally unique)"
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

variable "publisher_name" {
  description = "Publisher name for the APIM instance"
  type        = string
}

variable "publisher_email" {
  description = "Publisher email for the APIM instance"
  type        = string
}

variable "sku_name" {
  description = "APIM SKU in <tier>_<capacity> form. Must support MCP: Developer_1, BasicV2_1, StandardV2_1, Premium_1, PremiumV2_1. Consumption is NOT supported."
  type        = string
  default     = "Developer_1"
}

variable "tags" {
  description = "Tags to apply to the resource"
  type        = map(string)
  default     = {}
}
