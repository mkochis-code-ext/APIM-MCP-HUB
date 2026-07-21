variable "name" {
  description = "Name of the Azure Databricks workspace"
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
  description = "Databricks SKU (standard, premium, trial). Premium is required for Unity Catalog / managed MCP governance."
  type        = string
  default     = "premium"
}

variable "tags" {
  description = "Tags to apply to the resource"
  type        = map(string)
  default     = {}
}
