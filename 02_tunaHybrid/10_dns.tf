resource "azurerm_private_dns_zone" "tuna_dns" {
  name                = "tuna.internal"
  resource_group_name = var.rgname
  depends_on          = [azurerm_resource_group.tuna_rg]
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_vnet1" {
  name                  = "tuna-dns-link-vnet1"
  resource_group_name   = var.rgname
  private_dns_zone_name = azurerm_private_dns_zone.tuna_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet1.id
  registration_enabled  = true
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_vnet2" {
  name                  = "tuna-dns-link-vnet2"
  resource_group_name   = var.rgname
  private_dns_zone_name = azurerm_private_dns_zone.tuna_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet2.id
  registration_enabled  = true
}

# db.tuna.internal -> 온프레미스 DB IP (Key Vault의 onprem-db-ip 시크릿 값).
# 평상시 WordPress가 보는 주소이며, failover 시에는 이 DNS가 아니라
# wp-config.php의 DB_HOST를 직접 교체하는 방식으로 전환함 (failover/ 폴더 참고).
resource "azurerm_private_dns_a_record" "db_record" {
  name                = "db"
  zone_name           = azurerm_private_dns_zone.tuna_dns.name
  resource_group_name = var.rgname
  ttl                 = 300
  records             = [data.azurerm_key_vault_secret.onprem_db_ip.value]
}
