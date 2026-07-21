variable "name" {
  description = "Resource name of the named value"
  type        = string
}

variable "display_name" {
  description = "Display name referenced in policies as {{display_name}}"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "api_management_name" {
  description = "Name of the API Management instance"
  type        = string
}

variable "secret_value" {
  description = "Secret value stored in the named value (encrypted at rest in APIM)"
  type        = string
  sensitive   = true
}
