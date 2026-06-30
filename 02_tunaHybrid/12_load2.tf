resource "azurerm_web_application_firewall_policy" "appgw2_waf" {
  name = "tuna-appgw2-waf-policy"
  resource_group_name = var.rgname
  location            = var.loca2

  policy_settings {
    enabled = true
    mode    = "Prevention"
  }

  custom_rules {
    name      = "AllowWpAdmin"
    priority  = 1
    rule_type = "MatchRule"
    action    = "Allow"

    match_conditions {
      match_variables {
        variable_name = "RequestUri"
      }
      operator     = "Contains"
      match_values = ["/wp-admin/", "/wp-json/"]
    }
  }

  managed_rules {
    exclusion {
      match_variable          = "RequestArgNames"
      selector                = "reason"
      selector_match_operator = "Equals"
    }

    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }

  depends_on = [azurerm_resource_group.tuna_rg]
}

resource "azurerm_application_gateway" "appgw2" {
  name = "tuna-appgw2"
  resource_group_name = var.rgname
  location            = var.loca2
  firewall_policy_id  = azurerm_web_application_firewall_policy.appgw2_waf.id

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
  }

  gateway_ip_configuration {
    name      = "appgw2-ip-config"
    subnet_id = azurerm_subnet.vnet2_appgw.id
  }

  frontend_ip_configuration {
    name                 = "appgw2-frontend"
    public_ip_address_id = azurerm_public_ip.appgw2_pip.id
  }

  frontend_port {
    name = "port-80"
    port = 80
  }

  backend_address_pool {
    name = "vmss2-backend-pool"
  }

  backend_http_settings {
    name                  = "http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
    probe_name            = "health-probe"
  }

  probe {
    name                = "health-probe"
    protocol            = "Http"
    path                = "/health.html"
    host                = "127.0.0.1"
    interval            = 30
    timeout             = 20
    unhealthy_threshold = 3
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "appgw2-frontend"
    frontend_port_name             = "port-80"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "vmss2-backend-pool"
    backend_http_settings_name = "http-settings"
    priority                   = 100
  }

  depends_on = [azurerm_public_ip.appgw2_pip, azurerm_subnet.vnet2_appgw]
}