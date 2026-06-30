# Azure Database for MySQL Flexible Server VNet 통합(delegated subnet)용 Private DNS Zone.
# "{서버이름}.private.mysql.database.azure.com" 형식은 VNet 통합 방식의 규칙이며,
# Private Endpoint 방식에서 쓰는 "privatelink.mysql.database.azure.com"과는 다름.
resource "azurerm_private_dns_zone" "mysql_dns" {
  name                = "tuna-mysql-replica.private.mysql.database.azure.com"
  resource_group_name = var.rgname
  depends_on          = [azurerm_resource_group.tuna_rg]
}

resource "azurerm_private_dns_zone_virtual_network_link" "mysql_dns_link_vnet2" {
  name                  = "tuna-mysql-dns-link-vnet2"
  resource_group_name   = var.rgname
  private_dns_zone_name = azurerm_private_dns_zone.mysql_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet2.id
}

# vnet1(WordPress가 있는 리전)에서도 MySQL 이름 해석이 필요하므로 함께 연결
resource "azurerm_private_dns_zone_virtual_network_link" "mysql_dns_link_vnet1" {
  name                  = "tuna-mysql-dns-link-vnet1"
  resource_group_name   = var.rgname
  private_dns_zone_name = azurerm_private_dns_zone.mysql_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet1.id
}
