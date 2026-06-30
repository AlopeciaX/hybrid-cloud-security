#!/bin/bash
# =========================================================
# Failover 사전 준비 + 자동 감지 스크립트 설치 (VMSS 인스턴스 안에서 실행)
# wp-config 2버전 생성 + failover_check.sh 설치 + cron 등록까지 한 번에
# =========================================================

set -e

WP_DIR="/var/www/html"
WP_CONFIG="$WP_DIR/wp-config.php"
RESOURCE_GROUP="team604tuna"
MYSQL_SERVER_NAME="tuna-mysql-replica"

if ! az account show &>/dev/null; then
  echo "[0/4] Azure 로그인 안 됨 — managed identity로 로그인 시도..."
  az login --identity --allow-no-subscriptions -o none
fi

MYSQL_HOST="${MYSQL_SERVER_NAME}.mysql.database.azure.com"

echo "[1/4] wp-config 두 버전 생성 (이미 있으면 스킵)"

if [[ ! -f "$WP_DIR/wp-config-onprem.php" ]]; then
  cp "$WP_CONFIG" "$WP_DIR/wp-config-onprem.php"
  echo "  ✔ wp-config-onprem.php 생성 (현재 설정 기준)"
else
  echo "  ℹ️  wp-config-onprem.php 이미 존재, 스킵"
fi

NEED_REGEN=false
if [[ ! -f "$WP_DIR/wp-config-azure.php" ]]; then
  NEED_REGEN=true
elif ! grep -q "$MYSQL_HOST" "$WP_DIR/wp-config-azure.php"; then
  # 파일은 있지만 DB_HOST가 Azure FQDN이 아님 — 이전에 잘못 만들어진 채로 방치된 경우
  echo "  ⚠️  wp-config-azure.php가 있지만 DB_HOST가 Azure를 안 가리킴 — 다시 생성"
  NEED_REGEN=true
fi

if [[ "$NEED_REGEN" == "true" ]]; then
  sudo cp "$WP_DIR/wp-config-onprem.php" "$WP_DIR/wp-config-azure.php"
  sudo sed -i "s/define( *'DB_HOST', *'.*' *);/define( 'DB_HOST', '$MYSQL_HOST' );/" "$WP_DIR/wp-config-azure.php"
  if ! grep -q "MYSQL_CLIENT_FLAGS" "$WP_DIR/wp-config-azure.php"; then
    sudo sed -i "/\$table_prefix/i define('MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL);" "$WP_DIR/wp-config-azure.php"
  fi
  # 치환이 실제로 적용됐는지 검증 — 안 됐으면 명확히 에러로 알림 (조용히 넘어가지 않음)
  if grep -q "$MYSQL_HOST" "$WP_DIR/wp-config-azure.php"; then
    echo "  ✔ wp-config-azure.php 생성/갱신 (DB_HOST=$MYSQL_HOST, SSL 플래그 포함)"
  else
    echo "  ❌ wp-config-azure.php의 DB_HOST 치환 실패 — 수동으로 확인 필요"
  fi
else
  echo "  ℹ️  wp-config-azure.php 이미 정상 상태, 스킵"
fi

echo "[2/4] failover_check.sh 작성"

sudo tee /home/azureuser/failover_check.sh > /dev/null << 'INNER_EOF'
#!/bin/bash
ONPREM_DB_HOST="192.168.3.2"
ONPREM_DB_PORT="3306"
FAIL_THRESHOLD=3
FAIL_COUNT_FILE="/tmp/onprem_fail_count"
STATE_FILE="/var/www/html/.db_active_target"
LOCK_FILE="/tmp/failover_check.lock"
AZURE_HOST="tuna-mysql-replica.mysql.database.azure.com"
ADMIN_USER="tuna"
ADMIN_PASS="It12345@"
WP_CONFIG="/var/www/html/wp-config.php"
WP_CONFIG_AZURE="/var/www/html/wp-config-azure.php"
LOG_FILE="/var/log/failover.log"

log() { echo "$(date '+%F %T') $1" >> "$LOG_FILE"; }
mysql_cmd() {
  mysql -h "$AZURE_HOST" -u "$ADMIN_USER" -p"$ADMIN_PASS" --ssl-mode=REQUIRED --connect-timeout=5 -e "$1"
}

if [[ -f "$LOCK_FILE" ]]; then
  log "이전 실행이 아직 진행 중 — 스킵"
  exit 0
fi
trap 'rm -f "$LOCK_FILE"' EXIT
touch "$LOCK_FILE"

if [[ -f "$STATE_FILE" ]] && grep -q "azure" "$STATE_FILE"; then
  exit 0
fi

if timeout 3 bash -c "echo > /dev/tcp/$ONPREM_DB_HOST/$ONPREM_DB_PORT" 2>/dev/null; then
  echo 0 > "$FAIL_COUNT_FILE"
  exit 0
fi

COUNT=$(cat "$FAIL_COUNT_FILE" 2>/dev/null || echo 0)
COUNT=$((COUNT + 1))
echo "$COUNT" > "$FAIL_COUNT_FILE"
log "온프레미스 DB 연결 실패 ($COUNT/$FAIL_THRESHOLD)"

if [[ "$COUNT" -lt "$FAIL_THRESHOLD" ]]; then
  exit 0
fi

if [[ ! -f "$WP_CONFIG_AZURE" ]]; then
  log "failover 중단: $WP_CONFIG_AZURE 없음"
  exit 1
fi

log "failover 시작: Azure MySQL로 전환"
mysql_cmd "CALL mysql.az_replication_stop;" 2>>"$LOG_FILE"
mysql_cmd "CALL mysql.az_replication_remove_master;" 2>>"$LOG_FILE"
# SET GLOBAL read_only은 Azure MySQL이 SUPER 권한을 지원 안 해서 항상 실패함.
# az_replication_remove_master가 이미 쓰기 가능 상태로 전환해주므로 상태만 로그에 남김.
READ_ONLY_STATE=$(mysql_cmd "SHOW VARIABLES LIKE 'read_only';" 2>/dev/null | tail -1)
log "read_only 상태: ${READ_ONLY_STATE:-확인 실패}"
cp "$WP_CONFIG" "${WP_CONFIG}.bak.$(date +%s)"
cp "$WP_CONFIG_AZURE" "$WP_CONFIG"
echo "azure" > "$STATE_FILE"
systemctl restart apache2
log "failover 완료: wp-config.php → Azure MySQL로 교체, Apache 재시작됨"
INNER_EOF

sudo chmod +x /home/azureuser/failover_check.sh
echo "  ✔ /home/azureuser/failover_check.sh 작성 완료"

echo "[2.5/4] backup_to_storage.sh 작성 (Azure DB → Storage, 7일 보존)"

sudo tee /home/azureuser/backup_to_storage.sh > /dev/null << 'BACKUP_EOF'
#!/bin/bash
set -e
MYSQL_SERVER_NAME="tuna-mysql-replica"
KEY_VAULT_NAME="tuna-keyvault-604"
STORAGE_ACCOUNT="tunatfstate604"
BACKUP_CONTAINER="dbbackup"
RETENTION_DAYS=7
LOCK_FILE="/tmp/backup_to_storage.lock"
LOG_FILE="/var/log/db_backup.log"
log() { echo "$(date '+%F %T') $1" | tee -a "$LOG_FILE"; }

if [[ -f "$LOCK_FILE" ]]; then
  log "이전 백업이 아직 진행 중 (lock 존재) — 이번 실행 스킵"
  exit 0
fi
trap 'rm -f "$LOCK_FILE"' EXIT
touch "$LOCK_FILE"

if ! az account show &>/dev/null; then
  az login --identity --allow-no-subscriptions -o none
fi

ADMIN_USER=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "db-user" --query value -o tsv)
ADMIN_PASS=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "db-password" --query value -o tsv)
DB_NAME=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "db-name" --query value -o tsv)
STORAGE_KEY=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "storage-account-key" --query value -o tsv)
MYSQL_HOST="${MYSQL_SERVER_NAME}.mysql.database.azure.com"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DUMP_FILE="/tmp/${DB_NAME}_${TIMESTAMP}.sql"
BLOB_NAME="${DB_NAME}_${TIMESTAMP}.sql"

log "[1/4] Azure MySQL($MYSQL_HOST) 덤프 중..."
mysqldump -h "$MYSQL_HOST" -u "$ADMIN_USER" -p"$ADMIN_PASS" --ssl-mode=REQUIRED --single-transaction --routines --triggers "$DB_NAME" > "$DUMP_FILE"
log "  ✔ 덤프 완료: $DUMP_FILE ($(du -h "$DUMP_FILE" | cut -f1))"

log "[2/4] Storage Account($STORAGE_ACCOUNT/$BACKUP_CONTAINER)로 업로드 중..."
az storage blob upload --account-name "$STORAGE_ACCOUNT" --container-name "$BACKUP_CONTAINER" --name "$BLOB_NAME" --file "$DUMP_FILE" --account-key "$STORAGE_KEY" --overwrite --output none
log "  ✔ 업로드 완료: $BLOB_NAME"
rm -f "$DUMP_FILE"

log "[3/4] 보존 기간(${RETENTION_DAYS}일) 초과 백업 정리 중..."
CUTOFF_DATE=$(date -d "-${RETENTION_DAYS} days" -u +%Y-%m-%dT%H:%MZ)
az storage blob list --account-name "$STORAGE_ACCOUNT" --container-name "$BACKUP_CONTAINER" --account-key "$STORAGE_KEY" --query "[?properties.lastModified < '$CUTOFF_DATE'].name" -o tsv | while read -r OLD_BLOB; do
  [[ -z "$OLD_BLOB" ]] && continue
  az storage blob delete --account-name "$STORAGE_ACCOUNT" --container-name "$BACKUP_CONTAINER" --name "$OLD_BLOB" --account-key "$STORAGE_KEY" --output none
  log "  🗑  삭제: $OLD_BLOB (${RETENTION_DAYS}일 초과)"
done

REMAINING=$(az storage blob list --account-name "$STORAGE_ACCOUNT" --container-name "$BACKUP_CONTAINER" --account-key "$STORAGE_KEY" --query "length([])" -o tsv)
log "[4/4] 완료. 현재 보관 중인 백업 수: $REMAINING"
BACKUP_EOF

sudo chmod +x /home/azureuser/backup_to_storage.sh
echo "  ✔ /home/azureuser/backup_to_storage.sh 작성 완료"

echo "[3/4] cron 등록 (이미 있으면 중복 등록 안 함)"
CRON_TMP=$(mktemp)
sudo crontab -l 2>/dev/null | grep -v failover_check.sh | grep -v backup_to_storage.sh > "$CRON_TMP" || true
echo "* * * * * /home/azureuser/failover_check.sh" >> "$CRON_TMP"
echo "0 3 * * * /home/azureuser/backup_to_storage.sh" >> "$CRON_TMP"
sudo crontab "$CRON_TMP"
rm -f "$CRON_TMP"

# 등록 확인 — 비어있으면 run-command 환경에서 실패한 것이므로 명확히 알림
CRON_CHECK=$(sudo crontab -l 2>/dev/null | grep -c failover_check.sh || true)
if [[ "$CRON_CHECK" -ge 1 ]]; then
  echo "  ✔ cron 등록 완료 (failover 감지: 1분마다 / DB 백업: 매일 03:00, 7일 보존)"
else
  echo "  ❌ cron 등록 실패 — SSH로 직접 접속해서 'sudo crontab -e'로 등록해주세요"
fi

echo "[4/4] 완료. /var/log/failover.log 에서 동작 확인 가능"
