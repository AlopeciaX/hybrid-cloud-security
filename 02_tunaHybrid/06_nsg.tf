# AppGW NSG1
resource "azurerm_network_security_group" "appgw1_nsg" {
  name = "tuna-appgw1-nsg"
  location            = var.loca1
  resource_group_name = var.rgname

  security_rule {
    name                       = "Allow-GatewayManager"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  depends_on = [azurerm_resource_group.tuna_rg]
}

# AppGW NSG2
resource "azurerm_network_security_group" "appgw2_nsg" {
  name = "tuna-appgw2-nsg"
  location            = var.loca2
  resource_group_name = var.rgname

  security_rule {
    name                       = "Allow-GatewayManager"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  depends_on = [azurerm_resource_group.tuna_rg]
}

# VMSS NSG1
resource "azurerm_network_security_group" "vmss1_nsg" {
  name = "tuna-vmss1-nsg"
  location            = var.loca1
  resource_group_name = var.rgname

  security_rule {
    name                       = "Allow-HTTP-from-AppGW"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "10.101.0.0/24"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-SSH-from-Bastion"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.101.3.0/26"
    destination_address_prefix = "*"
  }

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

# VMSS NSG2
resource "azurerm_network_security_group" "vmss2_nsg" {
  name = "tuna-vmss2-nsg"
  location            = var.loca2
  resource_group_name = var.rgname

  security_rule {
    name                       = "Allow-HTTP-from-AppGW"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "10.102.0.0/24"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-SSH-from-Bastion"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.102.3.0/26"
    destination_address_prefix = "*"
  }

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

# Bastion NSG1 (Korea Central) - Azure 필수 규칙 완전 포함
resource "azurerm_network_security_group" "bastion1_nsg" {
  name = "tuna-bastion1-nsg"
  location            = var.loca1
  resource_group_name = var.rgname

  # 인바운드 필수 규칙
  security_rule {
    name                       = "Allow-HTTPS-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-GatewayManager"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-AzureLoadBalancer"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-BastionHostCommunication-8080"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Allow-BastionHostCommunication-5701"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "5701"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  # 아웃바운드 필수 규칙
  security_rule {
    name                       = "Allow-SSH-Outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Allow-RDP-Outbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Allow-AzureCloud-Outbound"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCloud"
  }

  security_rule {
    name                       = "Allow-BastionCommunication-8080"
    priority                   = 130
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Allow-BastionCommunication-5701"
    priority                   = 140
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "5701"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Allow-GetSessionInfo"
    priority                   = 150
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  depends_on = [azurerm_resource_group.tuna_rg]
}

# Bastion NSG2 (Korea South) - 동일한 필수 규칙
resource "azurerm_network_security_group" "bastion2_nsg" {
  name = "tuna-bastion2-nsg"
  location            = var.loca2
  resource_group_name = var.rgname

  security_rule {
    name                       = "Allow-HTTPS-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-GatewayManager"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-AzureLoadBalancer"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-BastionHostCommunication-8080"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Allow-BastionHostCommunication-5701"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "5701"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Allow-SSH-Outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Allow-RDP-Outbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Allow-AzureCloud-Outbound"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCloud"
  }

  security_rule {
    name                       = "Allow-BastionCommunication-8080"
    priority                   = 130
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Allow-BastionCommunication-5701"
    priority                   = 140
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "5701"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "Allow-GetSessionInfo"
    priority                   = 150
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  depends_on = [azurerm_resource_group.tuna_rg]
}

# NSG → 서브넷 연결
resource "azurerm_subnet_network_security_group_association" "appgw1_nsg_assoc" {
  subnet_id                 = azurerm_subnet.vnet1_appgw.id
  network_security_group_id = azurerm_network_security_group.appgw1_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "appgw2_nsg_assoc" {
  subnet_id                 = azurerm_subnet.vnet2_appgw.id
  network_security_group_id = azurerm_network_security_group.appgw2_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "vmss1_nsg_assoc" {
  subnet_id                 = azurerm_subnet.vnet1_vmss.id
  network_security_group_id = azurerm_network_security_group.vmss1_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "vmss2_nsg_assoc" {
  subnet_id                 = azurerm_subnet.vnet2_vmss.id
  network_security_group_id = azurerm_network_security_group.vmss2_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "bastion1_nsg_assoc" {
  subnet_id                 = azurerm_subnet.vnet1_bastion.id
  network_security_group_id = azurerm_network_security_group.bastion1_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "bastion2_nsg_assoc" {
  subnet_id                 = azurerm_subnet.vnet2_bastion.id
  network_security_group_id = azurerm_network_security_group.bastion2_nsg.id
}