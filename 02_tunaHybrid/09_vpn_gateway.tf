# VPN Gateway1 (Korea Central)
resource "azurerm_virtual_network_gateway" "vpngw1" {
  name                = "tuna-vpngw1"
  location            = var.loca1
  resource_group_name = var.rgname
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1AZ"

  ip_configuration {
    name                          = "vpngw1-ip-config"
    public_ip_address_id          = azurerm_public_ip.vpngw1_pip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.vnet1_gateway.id
  }
}

# VPN Gateway2 (Korea South)
resource "azurerm_virtual_network_gateway" "vpngw2" {
  name                = "tuna-vpngw2"
  location            = var.loca2
  resource_group_name = var.rgname
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1AZ"

  ip_configuration {
    name                          = "vpngw2-ip-config"
    public_ip_address_id          = azurerm_public_ip.vpngw2_pip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.vnet2_gateway.id
  }
}

# 온프레미스 VPN 장비 정보
# 주의: address_space는 실제 온프레미스 내부 대역(인프라구성도의
# VLAN10/20/30/40/50 = 192.168.x.x)으로 설정해야 함.
# 기존 "2.2.2.0/24"는 placeholder 값이라 실제 라우팅이 안 되는 문제가 있었음.
resource "azurerm_local_network_gateway" "onprem_db" {
  name                = "tuna-onprem-db-lng"
  location            = var.loca1
  resource_group_name = var.rgname
  gateway_address     = data.azurerm_key_vault_secret.onprem_vpn_ip.value
  address_space       = ["192.168.0.0/16"]
  depends_on          = [azurerm_resource_group.tuna_rg]
}

# VPN 연결1 (vnet1 → 온프레미스)
resource "azurerm_virtual_network_gateway_connection" "vpn_conn1" {
  name                       = "tuna-vpn-conn1-to-onprem"
  location                   = var.loca1
  resource_group_name        = var.rgname
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpngw1.id
  local_network_gateway_id   = azurerm_local_network_gateway.onprem_db.id
  shared_key                 = data.azurerm_key_vault_secret.vpn_shared_key.value

  ipsec_policy {
    dh_group         = "DHGroup14"
    ike_encryption   = "AES256"
    ike_integrity    = "SHA256"
    ipsec_encryption = "AES256"
    ipsec_integrity  = "SHA256"
    pfs_group        = "PFS14"
    sa_lifetime      = 27000
    sa_datasize      = 102400000
  }

  depends_on = [azurerm_virtual_network_gateway.vpngw1, azurerm_local_network_gateway.onprem_db]
}

# VPN 연결2 (vnet2 → 온프레미스)
resource "azurerm_virtual_network_gateway_connection" "vpn_conn2" {
  name                       = "tuna-vpn-conn2-to-onprem"
  location                   = var.loca2
  resource_group_name        = var.rgname
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpngw2.id
  local_network_gateway_id   = azurerm_local_network_gateway.onprem_db.id
  shared_key                 = data.azurerm_key_vault_secret.vpn_shared_key.value

  ipsec_policy {
    dh_group         = "DHGroup14"
    ike_encryption   = "AES256"
    ike_integrity    = "SHA256"
    ipsec_encryption = "AES256"
    ipsec_integrity  = "SHA256"
    pfs_group        = "PFS14"
    sa_lifetime      = 27000
    sa_datasize      = 102400000
  }

  depends_on = [azurerm_virtual_network_gateway.vpngw2, azurerm_local_network_gateway.onprem_db]
}
