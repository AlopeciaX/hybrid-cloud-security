# MySQL Replica NSG - 온프레미스(VPN 터널 너머) 및 VMSS에서의 3306 접근 허용
resource "azurerm_network_security_group" "mysql_replica_nsg" {
  name                = "tuna-mysql-replica-nsg"
  location            = var.loca1
  resource_group_name = var.rgname

  # 온프레미스(192.168.3.0/29, SERVER FARM, VPN 터널 경유)에서 들어오는 MySQL 복제 트래픽 허용
  security_rule {
    name                       = "Allow-MySQL-from-OnPrem"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = "192.168.3.0/29"
    destination_address_prefix = "*"
  }

  # VMSS(WordPress, vnet1/vnet2)에서 장애 전환(failover) 시 접근 허용
  security_rule {
    name                       = "Allow-MySQL-from-VMSS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefixes    = ["10.101.1.0/24", "10.102.1.0/24"]
    destination_address_prefix = "*"
  }

  # 온프레미스(192.168.3.0/29, SERVER FARM)로 나가는 Data-in Replication 트래픽 허용 (outbound)
  security_rule {
    name                       = "Allow-Outbound-to-OnPrem"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "192.168.0.0/16"
  }

  depends_on = [azurerm_resource_group.tuna_rg]
}

resource "azurerm_subnet_network_security_group_association" "mysql_replica_nsg_assoc" {
  subnet_id                 = azurerm_subnet.vnet1_db.id
  network_security_group_id = azurerm_network_security_group.mysql_replica_nsg.id
}
