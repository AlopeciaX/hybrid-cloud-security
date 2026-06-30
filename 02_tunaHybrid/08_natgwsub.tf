resource "azurerm_subnet_nat_gateway_association" "natgw1_vmss" {
  nat_gateway_id = azurerm_nat_gateway.natgw1.id
  subnet_id      = azurerm_subnet.vnet1_vmss.id
}

resource "azurerm_subnet_nat_gateway_association" "natgw2_vmss" {
  nat_gateway_id = azurerm_nat_gateway.natgw2.id
  subnet_id      = azurerm_subnet.vnet2_vmss.id
}

resource "azurerm_subnet_nat_gateway_association" "natgw1_elk" {
  nat_gateway_id = azurerm_nat_gateway.natgw1.id
  subnet_id      = azurerm_subnet.vnet1_elk.id
}
