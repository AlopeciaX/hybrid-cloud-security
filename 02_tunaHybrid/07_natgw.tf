resource "azurerm_nat_gateway" "natgw1" {
  name = "tuna-natgw1"
  location                = var.loca1
  resource_group_name     = var.rgname
  sku_name                = "Standard"
  idle_timeout_in_minutes = "4"
  depends_on              = [azurerm_resource_group.tuna_rg]
}

resource "azurerm_nat_gateway_public_ip_association" "natgw1_pip" {
  nat_gateway_id       = azurerm_nat_gateway.natgw1.id
  public_ip_address_id = azurerm_public_ip.natgw1_pip.id
}

resource "azurerm_nat_gateway" "natgw2" {
  name = "tuna-natgw2"
  location                = var.loca2
  resource_group_name     = var.rgname
  sku_name                = "Standard"
  idle_timeout_in_minutes = "4"
  depends_on              = [azurerm_resource_group.tuna_rg]
}

resource "azurerm_nat_gateway_public_ip_association" "natgw2_pip" {
  nat_gateway_id       = azurerm_nat_gateway.natgw2.id
  public_ip_address_id = azurerm_public_ip.natgw2_pip.id
}
