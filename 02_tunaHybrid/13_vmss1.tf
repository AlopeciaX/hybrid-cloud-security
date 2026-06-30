resource "azurerm_linux_virtual_machine_scale_set" "vmss1" {
  name = "tuna-vmss1"
  resource_group_name             = var.rgname
  location                        = var.loca1
  sku                             = var.size
  instances                       = var.vmss_instances
  admin_username                  = var.admin_user
  disable_password_authentication = true
  upgrade_mode                    = "Manual"

  admin_ssh_key {
    username   = var.admin_user
    public_key = file("~/.ssh/id_rsa.pub")
  }

  custom_data = base64encode(templatefile("${path.module}/install.sh.tpl", {
    key_vault_name             = data.azurerm_key_vault.tuna_kv.name
    db_name_secret_name        = var.db_name_secret_name
    db_user_secret_name        = var.db_user_secret_name
    db_password_secret_name    = var.db_password_secret_name
    managed_identity_client_id = azurerm_user_assigned_identity.vmss_kv_identity.client_id
    filebeat_version           = var.filebeat_version
    elk_private_ip             = var.elk_private_ip
  }))

  identity {
    type = "UserAssigned"

    identity_ids = [
      azurerm_user_assigned_identity.vmss_kv_identity.id
    ]
  }
  source_image_reference {
    publisher = var.publisher
    offer     = var.offer
    sku       = var.sku
    version   = var.ver
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  network_interface {
    name                      = "vmss1-nic"
    primary                   = true
    network_security_group_id = azurerm_network_security_group.vmss1_nsg.id

    ip_configuration {
      name      = "vmss1-ip-config"
      primary   = true
      subnet_id = azurerm_subnet.vnet1_vmss.id

      application_gateway_backend_address_pool_ids = [
        "${azurerm_application_gateway.appgw1.id}/backendAddressPools/vmss1-backend-pool"
      ]
    }
  }
  boot_diagnostics {
    storage_account_uri = null
  }

  depends_on = [azurerm_application_gateway.appgw1]
}

resource "azurerm_monitor_autoscale_setting" "vmss1_autoscale" {
  name = "tuna-vmss1-autoscale"
  resource_group_name = var.rgname
  location            = var.loca1
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.vmss1.id
  enabled             = true

  profile {
    name = "vmss1-profile"

    capacity {
      default = var.vmss_instances
      minimum = var.vmss_min
      maximum = var.vmss_max
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.vmss1.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThanOrEqual"
        threshold          = 70
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.vmss1.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThanOrEqual"
        threshold          = 20
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
}