# =========================================================
# Azure Database for MySQL Flexible Server
# - 온프레미스 MySQL(Primary, SERVER FARM DB svr 192.168.3.2)을
#   원본(Source)으로 하는 Data-in Replication 구성
# - VPN(IPsec) 터널을 통해 온프레미스 <-> Azure 간 복제 트래픽 통신
# - 평상시: WordPress(VMSS) -> db.tuna.internal -> 온프레미스 DB
# - 장애 시: failover/failover_check.sh가 자동으로 복제를 끊고
#            wp-config.php의 DB_HOST를 이 Azure MySQL로 직접 교체함
#            (DNS 레코드 전환 방식이 아님, failover/README.md 참고)
# =========================================================

# Korea South 리전은 MySQL Flexible Server 용량(capacity) 미지원으로
# Korea Central(loca1, vnet1)에 배치함
#
# 주의: 온프레미스(Azure 외부) MySQL은 azurerm_mysql_flexible_server의
# create_mode="Replica" 로 지정할 수 없음 (이 옵션은 Azure MySQL 서버 간
# 복제만 지원). 따라서 일반 서버로 생성한 뒤, Azure MySQL의
# "Data-in Replication" 기능을 이용해 온프레미스를 복제 원본(Source)으로
# 지정하는 작업을 setup_mysql_replication.sh 로 별도 실행해야 함.
resource "azurerm_mysql_flexible_server" "mysql_replica" {
  name                = "tuna-mysql-replica"
  resource_group_name = var.rgname
  location            = var.loca1

  administrator_login    = data.azurerm_key_vault_secret.db_user.value
  administrator_password = data.azurerm_key_vault_secret.db_password.value

  sku_name = "GP_Standard_D2ds_v4"
  version  = "8.0.21"

  delegated_subnet_id = azurerm_subnet.vnet1_db.id
  private_dns_zone_id = azurerm_private_dns_zone.mysql_dns.id

  storage {
    size_gb           = 32
    auto_grow_enabled = true
  }

  backup_retention_days = 7

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.mysql_dns_link_vnet1,
    azurerm_virtual_network_gateway_connection.vpn_conn1,
  ]
}

# 참고: 이 서버 SKU/버전에서는 gtid_mode=ON 설정이 지원되지 않아
# (허용값이 OFF, OFF_PERMISSIVE로 제한됨) GTID 기반 설정은 제거함.
# Data-in Replication은 GTID 없이도 binlog 파일/포지션 기반으로 동작 가능
# (setup_mysql_replication.sh가 mysql.az_replication_change_master
#  stored procedure로 binlog 위치 기반 복제를 직접 설정함).

# Replica DB 생성 (온프레미스 DB와 동일 스키마 사용)
resource "azurerm_mysql_flexible_database" "wordpress_db_replica" {
  name                = data.azurerm_key_vault_secret.db_name.value
  resource_group_name = var.rgname
  server_name         = azurerm_mysql_flexible_server.mysql_replica.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"

  depends_on = [azurerm_mysql_flexible_server.mysql_replica]
}
