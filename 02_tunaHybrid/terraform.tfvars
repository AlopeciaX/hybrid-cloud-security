rgname       = "team604tuna"
infra_rgname = "team604tuna-infra"

loca1 = "KoreaCentral"
loca2 = "KoreaSouth"

size = "Standard_B2s"

publisher = "Canonical"
offer     = "0001-com-ubuntu-server-focal"
sku       = "20_04-lts-gen2"
ver       = "latest"

admin_user = "azureuser"

vmss_instances = 2
vmss_min       = 1
vmss_max       = 5

key_vault_name = "tuna-keyvault-604"

# ELK Stack
elk_private_ip   = "10.101.5.4"
elk_vm_size      = "Standard_B2ms"
filebeat_version = "8.15.3"
