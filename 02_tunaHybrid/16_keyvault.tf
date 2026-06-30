# Key Vault 참조 + 시크릿 불러오기
# 00_bootstrap.sh 실행 후 생성된 Key Vault를 참조
data "azurerm_client_config" "current" {}

data "azurerm_key_vault" "tuna_kv" {
  name                = var.key_vault_name
  resource_group_name = var.infra_rgname
}

data "azurerm_key_vault_secret" "db_name" {
  name         = "db-name"
  key_vault_id = data.azurerm_key_vault.tuna_kv.id
}

data "azurerm_key_vault_secret" "db_user" {
  name         = "db-user"
  key_vault_id = data.azurerm_key_vault.tuna_kv.id
}

data "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  key_vault_id = data.azurerm_key_vault.tuna_kv.id
}

data "azurerm_key_vault_secret" "vpn_shared_key" {
  name         = "vpn-shared-key"
  key_vault_id = data.azurerm_key_vault.tuna_kv.id
}

data "azurerm_key_vault_secret" "onprem_vpn_ip" {
  name         = "onprem-vpn-ip"
  key_vault_id = data.azurerm_key_vault.tuna_kv.id
}

data "azurerm_key_vault_secret" "onprem_db_ip" {
  name         = "onprem-db-ip"
  key_vault_id = data.azurerm_key_vault.tuna_kv.id
}
