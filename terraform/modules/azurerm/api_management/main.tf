locals {
  # TLS/cipher hardening (the `security` block below) is only honored on the classic
  # tiers (Developer/Basic/Standard/Premium). The V2 tiers (BasicV2/StandardV2/
  # PremiumV2) and Consumption enforce TLS 1.2+ and reject these custom properties,
  # so the block is emitted only for a classic SKU.
  apim_tier            = split("_", var.sku_name)[0]
  enable_tls_hardening = contains(["Developer", "Basic", "Standard", "Premium"], local.apim_tier)
}

resource "azurerm_api_management" "main" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = var.sku_name

  identity {
    type = "SystemAssigned"
  }

  # Disable legacy protocols and weak (SHA-1 / CBC / RSA-kx / 3DES) cipher suites on
  # both the client-facing (frontend) and backend-facing listeners. The strong modern
  # ECDHE-GCM suites are always on and not configurable here, so TLS 1.2 still
  # negotiates. Emitted only on classic tiers (see local.enable_tls_hardening).
  dynamic "security" {
    for_each = local.enable_tls_hardening ? [1] : []
    content {
      backend_ssl30_enabled  = false
      backend_tls10_enabled  = false
      backend_tls11_enabled  = false
      frontend_ssl30_enabled = false
      frontend_tls10_enabled = false
      frontend_tls11_enabled = false

      triple_des_ciphers_enabled = false

      tls_ecdhe_ecdsa_with_aes128_cbc_sha_ciphers_enabled = false
      tls_ecdhe_ecdsa_with_aes256_cbc_sha_ciphers_enabled = false
      tls_ecdhe_rsa_with_aes128_cbc_sha_ciphers_enabled   = false
      tls_ecdhe_rsa_with_aes256_cbc_sha_ciphers_enabled   = false
      tls_rsa_with_aes128_cbc_sha256_ciphers_enabled      = false
      tls_rsa_with_aes128_cbc_sha_ciphers_enabled         = false
      tls_rsa_with_aes128_gcm_sha256_ciphers_enabled      = false
      tls_rsa_with_aes256_cbc_sha256_ciphers_enabled      = false
      tls_rsa_with_aes256_cbc_sha_ciphers_enabled         = false
      tls_rsa_with_aes256_gcm_sha384_ciphers_enabled      = false
    }
  }

  tags = var.tags
}
