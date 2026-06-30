#!/bin/bash
# =========================================================
# Azure MySQL Flexible Server <-> 온프레미스 MySQL
# Data-in Replication 설정 스크립트
#
# 전제조건 (실행 전 반드시 완료):
# 1. terraform apply 로 tuna-mysql-replica 서버 생성 완료
# 2. 온프레미스 DB svr(192.168.3.2)에서 사전 작업 완료
#    - repl 권한: GRANT RELOAD, REPLICATION CLIENT, REPLICATION SLAVE
#      ON *.* TO 'tuna'@'10.101.%'; (10.102.%도 동일하게)
#    - DB svr 자체 iptables: 10.101.0.0/16, 10.102.0.0/16 에서 3306 ACCEPT
#    - NGF: 지점 연결(VPN 대상 대역), 방화벽 정책(웹서버 DB연동) 모두
#      Azure VNet 전체 대역(10.101.0.0/16, 10.102.0.0/16) 포함 확인
# 3. VPN(IPsec) 터널이 정상 연결되어 온프레미스 <-> Azure 통신 가능
# 4. 이 스크립트는 Azure VNet 내부에서 실행해야 함
#    (Bastion 경유 SSH로 직접 실행, 또는 로컬 PC에서
#     az vmss run-command invoke --scripts @setup_mysql_replication.sh
#     로 VMSS 인스턴스 안에서 원격 실행 — 둘 다 가능)
# 5. 실행 환경에 mysql client, az cli 필요. 별도 az login 없이도
#    VMSS에 붙은 managed identity로 자동 로그인 시도함 (아래 0단계)
#
# 사용법: ./setup_mysql_replication.sh
# =========================================================

set -e

RESOURCE_GROUP="team604tuna"
MYSQL_SERVER_NAME="tuna-mysql-replica"
KEY_VAULT_NAME="tuna-keyvault-604"

ONPREM_DB_HOST="192.168.3.2"   # 온프레미스 DB svr IP (구성도 기준)
ONPREM_DB_PORT="3306"
REPL_USER="tuna"   # 별도 repl 계정 대신 기존 tuna 계정 사용 (REPLICATION SLAVE 권한 부여 필요)

# ────────────────────────────────────────────────────────────
#  0. Azure 로그인 확인 (이미 로그인돼 있으면 스킵, 아니면 managed
#     identity로 자동 로그인 — run-command로 원격 실행할 때 필요)
# ────────────────────────────────────────────────────────────
if ! az account show &>/dev/null; then
  echo "[0/5] Azure 로그인 안 됨 — managed identity로 로그인 시도..."
  az login --identity --allow-no-subscriptions -o none
else
  echo "[0/5] Azure 로그인 상태 확인됨, 스킵"
fi

# ────────────────────────────────────────────────────────────
#  Key Vault에서 값 가져오기 (00_bootstrap.sh가 등록해둔 값)
# ────────────────────────────────────────────────────────────
echo "[0/4] Key Vault에서 시크릿 조회 중..."

REPL_PASSWORD=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "repl-password" --query value -o tsv)
ONPREM_ROOT_PASSWORD=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "onprem-root-password" --query value -o tsv)
ADMIN_USER=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "db-user" --query value -o tsv)
ADMIN_PASS=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "db-password" --query value -o tsv)
DB_NAME=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "db-name" --query value -o tsv)

# az mysql flexible-server show 조회 없이 고정 패턴으로 FQDN 구성
# (managed identity로 자동 실행될 때 Reader 권한을 줄 수 없어서 조회 자체를 회피.
#  Azure MySQL Flexible Server FQDN은 항상 "서버이름.mysql.database.azure.com" 고정 패턴)
MYSQL_HOST="${MYSQL_SERVER_NAME}.mysql.database.azure.com"

echo "  -> MySQL Host: $MYSQL_HOST"
echo "  -> DB Name   : $DB_NAME"

run_az_mysql() {
  mysql -h "$MYSQL_HOST" -u "$ADMIN_USER" -p"$ADMIN_PASS" --ssl-mode=REQUIRED "$@"
}

# ────────────────────────────────────────────────────────────
#  이미 복제 중이면 스킵 (재실행 시 안전장치)
# ────────────────────────────────────────────────────────────
ALREADY_RUNNING=$(run_az_mysql -N -e "SHOW REPLICA STATUS\G" 2>/dev/null | grep -c "Replica_IO_Running: Yes" || true)

if [[ "$ALREADY_RUNNING" -ge 1 ]]; then
  echo ""
  echo "ℹ️  이미 복제가 진행 중입니다. 재설정하려면 먼저 아래로 중단하세요:"
  echo "    CALL mysql.az_replication_stop;"
  echo "    CALL mysql.az_replication_remove_master;"
  echo ""
  run_az_mysql -e "SHOW REPLICA STATUS\G"
  exit 0
fi

# ────────────────────────────────────────────────────────────
#  1. 온프레미스 초기 데이터 덤프 (binlog 파일/포지션 포함)
# ────────────────────────────────────────────────────────────
DUMP_FILE="/tmp/${DB_NAME}_dump.sql"

echo ""
echo "[1/4] 온프레미스(${ONPREM_DB_HOST}) 덤프 중..."

mysqldump -h "$ONPREM_DB_HOST" -P "$ONPREM_DB_PORT" -u "$REPL_USER" -p"$REPL_PASSWORD" \
  --single-transaction \
  --master-data=2 \
  --routines --triggers \
  "$DB_NAME" > "$DUMP_FILE"

LOG_FILE=$(grep -m1 -E "CHANGE (MASTER|REPLICATION SOURCE) TO" "$DUMP_FILE" | grep -oE "(MASTER_LOG_FILE|SOURCE_LOG_FILE)='[^']+'" | cut -d"'" -f2)
LOG_POS=$(grep -m1 -E "CHANGE (MASTER|REPLICATION SOURCE) TO" "$DUMP_FILE" | grep -oE "(MASTER_LOG_POS|SOURCE_LOG_POS)=[0-9]+" | cut -d= -f2)

if [[ -z "$LOG_FILE" || -z "$LOG_POS" ]]; then
  echo "❌ 덤프 파일에서 binlog 파일/포지션을 못 찾았습니다."
  echo "   $DUMP_FILE 맨 윗줄 주석을 직접 확인하고, 아래 변수에 수동으로 넣어서 재실행하세요:"
  echo "   LOG_FILE=... / LOG_POS=..."
  exit 1
fi

echo "  -> binlog file = $LOG_FILE, position = $LOG_POS"

# ────────────────────────────────────────────────────────────
#  2. Azure MySQL Flexible Server로 복원
# ────────────────────────────────────────────────────────────
echo ""
echo "[2/4] Azure MySQL Flexible Server(${MYSQL_HOST})로 복원 중..."

run_az_mysql "$DB_NAME" < "$DUMP_FILE"
rm -f "$DUMP_FILE"

echo "  ✔ 복원 완료"

# ────────────────────────────────────────────────────────────
#  3. Data-in Replication 시작
#     (az mysql flexible-server replica create 는 Azure-to-Azure 전용이라
#      온프레미스 소스에는 쓸 수 없음 — stored procedure로 직접 연결)
# ────────────────────────────────────────────────────────────
echo ""
echo "[3/4] Data-in Replication 연결 설정 중..."

run_az_mysql -e "CALL mysql.az_replication_change_master('$ONPREM_DB_HOST', '$REPL_USER', '$REPL_PASSWORD', $ONPREM_DB_PORT, '$LOG_FILE', $LOG_POS, '');"
run_az_mysql -e "CALL mysql.az_replication_start;"

echo "  ✔ 복제 시작 명령 전송 완료"

# ────────────────────────────────────────────────────────────
#  4. 복제 상태 확인
# ────────────────────────────────────────────────────────────
echo ""
echo "[4/4] 복제 상태 확인 중..."
sleep 5
run_az_mysql -e "SHOW REPLICA STATUS\G"

echo ""
echo "✅ 완료. Replica_IO_Running / Replica_SQL_Running이 Yes이고"
echo "   Seconds_Behind_Source가 0에 가까운지 확인하세요."
echo "   에러가 있으면 Last_IO_Error / Last_SQL_Error 항목을 확인하세요."
