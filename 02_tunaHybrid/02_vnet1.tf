# VNet1 - Korea Central
resource "azurerm_virtual_network" "vnet1" {
  name = "tuna-vnet1"
  address_space       = ["10.101.0.0/16"]
  location            = var.loca1
  resource_group_name = var.rgname
  depends_on          = [azurerm_resource_group.tuna_rg]
}

resource "azurerm_subnet" "vnet1_appgw" {
  name                 = "appgw-subnet1"
  virtual_network_name = azurerm_virtual_network.vnet1.name
  resource_group_name  = var.rgname
  address_prefixes     = ["10.101.0.0/24"]
  depends_on           = [azurerm_virtual_network.vnet1]
}

resource "azurerm_subnet" "vnet1_vmss" {
  name                 = "vmss-subnet1"
  virtual_network_name = azurerm_virtual_network.vnet1.name
  resource_group_name  = var.rgname
  address_prefixes     = ["10.101.1.0/24"]
  depends_on           = [azurerm_virtual_network.vnet1]
}

resource "azurerm_subnet" "vnet1_gateway" {
  name                 = "GatewaySubnet"
  virtual_network_name = azurerm_virtual_network.vnet1.name
  resource_group_name  = var.rgname
  address_prefixes     = ["10.101.2.0/27"]
  depends_on           = [azurerm_virtual_network.vnet1]
}

resource "azurerm_subnet" "vnet1_bastion" {
  name                 = "AzureBastionSubnet"
  virtual_network_name = azurerm_virtual_network.vnet1.name
  resource_group_name  = var.rgname
  address_prefixes     = ["10.101.3.0/26"]
  depends_on           = [azurerm_virtual_network.vnet1]
}

# DB 서브넷 (Azure Database for MySQL Flexible Server - VNet 통합용, delegated subnet)
resource "azurerm_subnet" "vnet1_db" {
  name                 = "db-subnet1"
  virtual_network_name = azurerm_virtual_network.vnet1.name
  resource_group_name  = var.rgname
  address_prefixes     = ["10.101.4.0/24"]
  depends_on           = [azurerm_virtual_network.vnet1]

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
resource "azurerm_subnet" "vnet1_elk" {
  name                 = "elk-subnet1"
  virtual_network_name = azurerm_virtual_network.vnet1.name
  resource_group_name  = var.rgname
  address_prefixes     = ["10.101.5.0/24"]
  depends_on           = [azurerm_virtual_network.vnet1]
}
