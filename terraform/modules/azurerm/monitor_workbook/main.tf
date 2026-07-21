terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

# Azure Monitor Workbook (Microsoft.Insights/workbooks).
#
# The workbook `name` must be a GUID; it is generated once and kept stable so
# re-applies do not force replacement. `source_id` scopes the workbook to a
# resource (here the Application Insights component) and must be lowercase to
# avoid a perpetual diff.
resource "random_uuid" "workbook" {}

resource "azurerm_application_insights_workbook" "main" {
  name                = random_uuid.workbook.result
  resource_group_name = var.resource_group_name
  location            = var.location
  display_name        = var.display_name
  data_json           = var.data_json
  source_id           = lower(var.source_id)
  category            = var.category
  tags                = var.tags
}
