terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

provider "azapi" {}

# Uses the Azure CLI login (same tenant as azurerm) for Entra app registrations,
# consent-free permission wiring, and the optional Graph role assignment.
provider "azuread" {}

# Generate random suffix for uniqueness
resource "random_string" "suffix" {
  length  = 3
  special = false
  upper   = false
}

locals {
  suffix = random_string.suffix.result
  tags = merge(
    var.tags,
    {
      Environment = var.environment_prefix
      ManagedBy   = "Terraform"
    }
  )
}

module "project" {
  source = "../../project"

  environment_prefix = var.environment_prefix
  suffix             = local.suffix
  tags               = local.tags
  workload           = var.workload
  location           = var.location
  data_location      = var.data_location

  publisher_name  = var.publisher_name
  publisher_email = var.publisher_email
  apim_sku_name   = var.apim_sku_name

  entra_tenant_id   = var.entra_tenant_id
  mcp_api_app_id    = var.mcp_api_app_id
  mcp_client_app_id = var.mcp_client_app_id
  obo_client_secret = var.obo_client_secret
  obo_cache_seconds = var.obo_cache_seconds

  create_entra_apps                  = var.create_entra_apps
  obo_secret_end_date                = var.obo_secret_end_date
  oauth_facade_enabled               = var.oauth_facade_enabled
  apim_graph_role_assignment_enabled = var.apim_graph_role_assignment_enabled

  rate_limit_calls  = var.rate_limit_calls
  rate_limit_period = var.rate_limit_period

  create_databricks_workspace = var.create_databricks_workspace

  mcp_hub_enabled             = var.mcp_hub_enabled
  mcp_hub_path                = var.mcp_hub_path
  mcp_hub_tools_cache_seconds = var.mcp_hub_tools_cache_seconds
  mcp_hub_debug               = var.mcp_hub_debug
  mcp_hub_graph_fallback      = var.mcp_hub_graph_fallback
  mcp_hub_servers             = var.mcp_hub_servers
}
