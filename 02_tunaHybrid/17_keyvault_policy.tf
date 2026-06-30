# VMSS Managed Identity → Key Vault 시크릿 읽기 권한
resource "azurerm_key_vault_access_policy" "vmss_secret_get" {
  key_vault_id = data.azurerm_key_vault.tuna_kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.vmss_kv_identity.principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}