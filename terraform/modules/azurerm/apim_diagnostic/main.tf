# Global (all-APIs) Application Insights diagnostic.
#
# IMPORTANT: frontend_response.body_bytes is set to 0. Logging response bodies at
# the global scope buffers responses and breaks MCP streaming transport. Keeping
# body_bytes = 0 here is the MCP-safe configuration recommended by Microsoft.
resource "azurerm_api_management_diagnostic" "main" {
  identifier               = "applicationinsights"
  resource_group_name      = var.resource_group_name
  api_management_name      = var.api_management_name
  api_management_logger_id = var.logger_id

  sampling_percentage       = var.sampling_percentage
  always_log_errors         = true
  log_client_ip             = true
  verbosity                 = "information"
  http_correlation_protocol = "W3C"
  operation_name_format     = "Name"

  frontend_request {
    body_bytes = 0
  }

  frontend_response {
    body_bytes = 0
  }

  backend_request {
    body_bytes = 0
  }

  backend_response {
    body_bytes = 0
  }
}
