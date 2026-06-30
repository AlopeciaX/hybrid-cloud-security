# Application Gateway Public IP 출력
output "appgw1_public_ip" { value = azurerm_public_ip.appgw1_pip.ip_address }
output "appgw2_public_ip" { value = azurerm_public_ip.appgw2_pip.ip_address }

# VPN Public IP 출력
output "vpngw1_public_ip" { value = azurerm_public_ip.vpngw1_pip.ip_address }
output "vpngw2_public_ip" { value = azurerm_public_ip.vpngw2_pip.ip_address }

# Traffic Manager FQDN 출력
output "traffic_manager_fqdn" {
  value       = azurerm_traffic_manager_profile.tuna_tm.fqdn
  description = "Traffic Manager 접속 주소"
}

# Azure MySQL Replica 정보 출력 (온프레미스 DB와 Master-Slave 이중화)
output "mysql_replica_fqdn" {
  value       = azurerm_mysql_flexible_server.mysql_replica.fqdn
  description = "Azure MySQL Flexible Server(Replica) FQDN - failover 시 wp-config.php의 DB_HOST 교체 대상"
}
