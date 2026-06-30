# VNet2 - Korea South
resource "azurerm_virtual_network" "vnet2" {
  name = "tuna-vnet2"
  address_space       = ["10.102.0.0/16"]
  location            = var.loca2
  resource_group_name = var.rgname
  depends_on          = [azurerm_resource_group.tuna_rg]
}

resource "azurerm_subnet" "vnet2_appgw" {
  name                 = "appgw-subnet2"
  virtual_network_name = azurerm_virtual_network.vnet2.name
  resource_group_name  = var.rgname
  address_prefixes     = ["10.102.0.0/24"]
  depends_on           = [azurerm_virtual_network.vnet2]
}

resource "azurerm_subnet" "vnet2_vmss" {
  name                 = "vmss-subnet2"
  virtual_network_name = azurerm_virtual_network.vnet2.name
  resource_group_name  = var.rgname
  address_prefixes     = ["10.102.1.0/24"]
  depends_on           = [azurerm_virtual_network.vnet2]
}

resource "azurerm_subnet" "vnet2_gateway" {
  name                 = "GatewaySubnet"
  virtual_network_name = azurerm_virtual_network.vnet2.name
  resource_group_name  = var.rgname
  address_prefixes     = ["10.102.2.0/27"]
  depends_on           = [azurerm_virtual_network.vnet2]
}

resource "azurerm_subnet" "vnet2_bastion" {
  name                 = "AzureBastionSubnet"
  virtual_network_name = azurerm_virtual_network.vnet2.name
  resource_group_name  = var.rgname
  address_prefixes     = ["10.102.3.0/26"]
  depends_on           = [azurerm_virtual_network.vnet2]
}

# DB 서브넷 (Korea South). MySQL Flexible Server는 19_mysql_flexible.tf의 사유로
# Korea Central(vnet1_db)에만 배치되어, 이 서브넷은 현재 어떤 리소스도 사용하지 않음.
resource "azurerm_subnet" "vnet2_db" {
  name                 = "db-subnet2"
  virtual_network_name = azurerm_virtual_network.vnet2.name
  resource_group_name  = var.rgname
  address_prefixes     = ["10.102.4.0/24"]
  depends_on           = [azurerm_virtual_network.vnet2]

  delegation {
    name = "mysql-flexible-server-delegation"

    service_delegation {
      name = "Microsoft.DBforMySQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}