#!/bin/bash
# =========================================================
# Azure MySQL Flexible Server → Storage Account 백업 스크립트
#
# 목적: 온프레미스가 죽어서 failover한 뒤(Azure가 쓰기 모드로
#       전환된 뒤), Azure까지 같이 죽는 이중 장애에 대비한 백업.
#       평상시(failover 전)에는 온프레미스가 원본을 그대로 갖고
#       있어서 이 백업이 굳이 필요하지 않음.
#
# 보존 기간: 기본 7일. 그보다 오래된 백업은 매 실행마다 자동 삭제.
#            → 무한정 쌓이지 않도록 함.
#
# 인증: Storage는 RBAC(--auth-mode login) 대신 계정 키 방식 사용.
#       이 구독 계정이 roleAssignments/write 권한이 없어 RBAC 역할을
#       부여할 수 없었기 때문 (00_bootstrap.sh가 키를 Key Vault에
#       저장해두고, 여기서 그 시크릿을 읽어서 사용).
#
# 실행 위치: Azure VNet 내부 (MySQL FQDN이 프라이빗 DNS)
# 실행 주기: cron으로 하루 1회 권장 (예: 매일 03:00)
# =========================================================

set -e

MYSQL_SERVER_NAME="tuna-mysql-replica"
KEY_VAULT_NAME="tuna-keyvault-604"
STORAGE_ACCOUNT="tunatfstate604"
BACKUP_CONTAINER="dbbackup"
RETENTION_DAYS=7
LOCK_FILE="/tmp/backup_to_storage.lock"

LOG_FILE="/var/log/db_backup.log"
log() { echo "$(date '+%F %T') $1" | tee -a "$LOG_FILE"; }

# 중복 실행 방지 (수동 실행과 cron이 겹치는 경우 등)
if [[ -f "$LOCK_FILE" ]]; then
  log "이전 백업이 아직 진행 중 (lock 존재) — 이번 실행 스킵"
  exit 0
fi
trap 'rm -f "$LOCK_FILE"' EXIT
touch "$LOCK_FILE"

if ! az account show &>/dev/null; then
  log "[0/4] Azure 로그인 안 됨 — managed identity로 로그인 시도..."
  az login --identity --allow-no-subscriptions -o none
fi

ADMIN_USER=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "db-user" --query value -o tsv)
ADMIN_PASS=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "db-password" --query value -o tsv)
DB_NAME=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "db-name" --query value -o tsv)
STORAGE_KEY=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "storage-account-key" --query value -o tsv)

# az mysql flexible-server show 조회 없이 고정 패턴으로 FQDN 구성
# (Reader 권한을 부여할 수 없어서 조회 자체를 회피)
MYSQL_HOST="${MYSQL_SERVER_NAME}.mysql.database.azure.com"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DUMP_FILE="/tmp/${DB_NAME}_${TIMESTAMP}.sql"
BLOB_NAME="${DB_NAME}_${TIMESTAMP}.sql"

log "[1/4] Azure MySQL($MYSQL_HOST) 덤프 중..."
mysqldump -h "$MYSQL_HOST" -u "$ADMIN_USER" -p"$ADMIN_PASS" --ssl-mode=REQUIRED \
  --single-transaction --routines --triggers \
  "$DB_NAME" > "$DUMP_FILE"
log "  ✔ 덤프 완료: $DUMP_FILE ($(du -h "$DUMP_FILE" | cut -f1))"

log "[2/4] Storage Account($STORAGE_ACCOUNT/$BACKUP_CONTAINER)로 업로드 중..."
az storage blob upload \
  --account-name "$STORAGE_ACCOUNT" \
  --container-name "$BACKUP_CONTAINER" \
  --name "$BLOB_NAME" \
  --file "$DUMP_FILE" \
  --account-key "$STORAGE_KEY" \
  --overwrite \
  --output none
log "  ✔ 업로드 완료: $BLOB_NAME"

rm -f "$DUMP_FILE"

log "[3/4] 보존 기간(${RETENTION_DAYS}일) 초과 백업 정리 중..."
CUTOFF_DATE=$(date -d "-${RETENTION_DAYS} days" -u +%Y-%m-%dT%H:%MZ)

az storage blob list \
  --account-name "$STORAGE_ACCOUNT" \
  --container-name "$BACKUP_CONTAINER" \
  --account-key "$STORAGE_KEY" \
  --query "[?properties.lastModified < '$CUTOFF_DATE'].name" -o tsv | \
while read -r OLD_BLOB; do
  [[ -z "$OLD_BLOB" ]] && continue
  az storage blob delete \
    --account-name "$STORAGE_ACCOUNT" \
    --container-name "$BACKUP_CONTAINER" \
    --name "$OLD_BLOB" \
    --account-key "$STORAGE_KEY" \
    --output none
  log "  🗑  삭제: $OLD_BLOB (${RETENTION_DAYS}일 초과)"
done

REMAINING=$(az storage blob list \
  --account-name "$STORAGE_ACCOUNT" --container-name "$BACKUP_CONTAINER" \
  --account-key "$STORAGE_KEY" --query "length([])" -o tsv)

log "[4/4] 완료. 현재 보관 중인 백업 수: $REMAINING"
