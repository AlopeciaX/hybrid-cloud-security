resource "azurerm_bastion_host" "bastion1" {
  name = "tuna-bastion1"
  location            = var.loca1
  resource_group_name = var.rgname
  sku                 = "Standard"
  tunneling_enabled   = true

  ip_configuration {
    name                 = "bastion1-ip-config"
    subnet_id            = azurerm_subnet.vnet1_bastion.id
    public_ip_address_id = azurerm_public_ip.bastion1_pip.id
  }
}

resource "azurerm_bastion_host" "bastion2" {
  name = "tuna-bastion2"
  location            = var.loca2
  resource_group_name = var.rgname
  sku                 = "Standard"
  tunneling_enabled   = true

  ip_configuration {
    name                 = "bastion2-ip-config"
    subnet_id            = azurerm_subnet.vnet2_bastion.id
    public_ip_address_id = azurerm_public_ip.bastion2_pip.id
  }
}