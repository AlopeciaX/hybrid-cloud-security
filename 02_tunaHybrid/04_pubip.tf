# AppGW Public IPs
resource "azurerm_public_ip" "appgw1_pip" {
  name = "tuna-appgw1-pip"
  resource_group_name = var.rgname
  location            = var.loca1
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_version          = "IPv4"
  domain_name_label = "tuna-appgw1"
  depends_on          = [azurerm_resource_group.tuna_rg]
}

resource "azurerm_public_ip" "appgw2_pip" {
  name = "tuna-appgw2-pip"
  resource_group_name = var.rgname
  location            = var.loca2
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_version          = "IPv4"
  domain_name_label = "tuna-appgw2"
  depends_on          = [azurerm_resource_group.tuna_rg]
}

# VPN Gateway Public IPs
resource "azurerm_public_ip" "vpngw1_pip" {
  name = "tuna-vpngw1-pip"
  resource_group_name = var.rgname
  location            = var.loca1
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_version          = "IPv4"
  zones               = ["1", "2", "3"]
  depends_on          = [azurerm_resource_group.tuna_rg]
}

# Korea South는 가용성 영역(Availability Zone)을 지원하지 않아 zones 파라미터를 넣지 않음
# (vpngw1과 다른 게 누락이 아니라 리전 제약에 따른 의도된 차이)
resource "azurerm_public_ip" "vpngw2_pip" {
  name = "tuna-vpngw2-pip"
  resource_group_name = var.rgname
  location            = var.loca2
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_version          = "IPv4"
  depends_on          = [azurerm_resource_group.tuna_rg]
}

# Bastion Public IPs
resource "azurerm_public_ip" "bastion1_pip" {
  name = "tuna-bastion1-pip"
  resource_group_name = var.rgname
  location            = var.loca1
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_version          = "IPv4"
  depends_on          = [azurerm_resource_group.tuna_rg]
}

resource "azurerm_public_ip" "bastion2_pip" {
  name = "tuna-bastion2-pip"
  resource_group_name = var.rgname
  location            = var.loca2
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_version          = "IPv4"
  depends_on          = [azurerm_resource_group.tuna_rg]
}

# NAT Gateway Public IPs
resource "azurerm_public_ip" "natgw1_pip" {
  name = "tuna-natgw1-pip"
  resource_group_name = var.rgname
  location            = var.loca1
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_version          = "IPv4"
  depends_on          = [azurerm_resource_group.tuna_rg]
}

resource "azurerm_public_ip" "natgw2_pip" {
  name = "tuna-natgw2-pip"
  resource_group_name = var.rgname
  location            = var.loca2
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_version          = "IPv4"
  depends_on          = [azurerm_resource_group.tuna_rg]
}