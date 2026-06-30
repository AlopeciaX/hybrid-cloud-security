# Traffic Manager Profile
resource "azurerm_traffic_manager_profile" "tuna_tm" {
  name = "tuna-traffic-manager"
  resource_group_name    = var.rgname
  traffic_routing_method = "Priority"

  dns_config {
    relative_name = "tuna-team604"
    ttl           = 30
  }

  monitor_config {
    protocol                     = "HTTP"
    port                         = 80
    path                         = "/health.html"
    interval_in_seconds          = 30
    timeout_in_seconds           = 10
    tolerated_number_of_failures = 3
  }

  depends_on = [azurerm_resource_group.tuna_rg]
}

# Endpoint1 - AppGW1 (Korea Central, 우선순위 1)
resource "azurerm_traffic_manager_azure_endpoint" "appgw1_endpoint" {
  name               = "appgw1-endpoint"
  profile_id         = azurerm_traffic_manager_profile.tuna_tm.id
  target_resource_id = azurerm_public_ip.appgw1_pip.id
  priority           = 1
  enabled            = true
}

# Endpoint2 - AppGW2 (Korea South, 우선순위 2 - 장애 시 자동 전환)
resource "azurerm_traffic_manager_azure_endpoint" "appgw2_endpoint" {
  name               = "appgw2-endpoint"
  profile_id         = azurerm_traffic_manager_profile.tuna_tm.id
  target_resource_id = azurerm_public_ip.appgw2_pip.id
  priority           = 2
  enabled            = true
}
