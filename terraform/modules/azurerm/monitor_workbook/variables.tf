variable "display_name" {
  description = "Display name shown in the Azure portal workbook gallery"
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

variable "data_json" {
  description = "Serialized workbook definition (Notebook/1.0 JSON)"
  type        = string
}

variable "source_id" {
  description = "Resource the workbook is scoped to (e.g. the Application Insights component ID). Lowercased by the module."
  type        = string
}

variable "category" {
  description = "Workbook gallery category"
  type        = string
  default     = "workbook"
}

variable "tags" {
  description = "Tags to apply to the resource"
  type        = map(string)
  default     = {}
}
