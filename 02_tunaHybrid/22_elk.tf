# ELK Stack 서버 - Korea Central 중앙 로그 수집 서버

resource "azurerm_network_security_group" "elk_nsg" {
  name                = "tuna-elk-nsg"
  location            = var.loca1
  resource_group_name = var.rgname

  security_rule {
    name                       = "Allow-SSH-from-Bastion"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = azurerm_subnet.vnet1_bastion.address_prefixes[0]
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Kibana-from-Bastion"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5601"
    source_address_prefix      = azurerm_subnet.vnet1_bastion.address_prefixes[0]
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Logstash-from-VMSS1"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5044"
    source_address_prefix      = azurerm_subnet.vnet1_vmss.address_prefixes[0]
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Logstash-from-VMSS2"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5044"
    source_address_prefix      = azurerm_subnet.vnet2_vmss.address_prefixes[0]
    destination_address_prefix = "*"
  }

  depends_on = [azurerm_resource_group.tuna_rg]
}

resource "azurerm_subnet_network_security_group_association" "elk_nsg_assoc" {
  subnet_id                 = azurerm_subnet.vnet1_elk.id
  network_security_group_id = azurerm_network_security_group.elk_nsg.id
}

resource "azurerm_network_interface" "elk_nic" {
  name                = "tuna-elk-nic"
  location            = var.loca1
  resource_group_name = var.rgname

  ip_configuration {
    name                          = "elk-ip-config"
    subnet_id                     = azurerm_subnet.vnet1_elk.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.elk_private_ip
  }
}

resource "azurerm_linux_virtual_machine" "elk" {
  name                            = "tuna-ELK-vm"
  resource_group_name             = var.rgname
  location                        = var.loca1
  size                            = var.elk_vm_size
  admin_username                  = var.admin_user
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.elk_nic.id]

  admin_ssh_key {
    username   = var.admin_user
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(file("${path.module}/install_elk.sh"))

  boot_diagnostics {
    storage_account_uri = null
  }

  depends_on = [
    azurerm_subnet_nat_gateway_association.natgw1_elk,
    azurerm_subnet_network_security_group_association.elk_nsg_assoc
  ]
}
