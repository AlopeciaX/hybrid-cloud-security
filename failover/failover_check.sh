#!/bin/bash
# =========================================================
# 온프레미스 DB 장애 감지 + 자동 failover 스크립트
# VMSS 인스턴스에서 cron으로 1분마다 실행
# =========================================================

ONPREM_DB_HOST="192.168.3.2"
ONPREM_DB_PORT="3306"
FAIL_THRESHOLD=3                      # 연속 3번 실패해야 failover (오탐 방지)
FAIL_COUNT_FILE="/tmp/onprem_fail_count"
STATE_FILE="/var/www/html/.db_active_target"   # 현재 어디를 보고 있는지 기록
LOCK_FILE="/tmp/failover_check.lock"

AZURE_HOST="tuna-mysql-replica.mysql.database.azure.com"
ADMIN_USER="tuna"
ADMIN_PASS="It12345@"
WP_CONFIG="/var/www/html/wp-config.php"
WP_CONFIG_ONPREM="/var/www/html/wp-config-onprem.php"
WP_CONFIG_AZURE="/var/www/html/wp-config-azure.php"
LOG_FILE="/var/log/failover.log"

log() { echo "$(date '+%F %T') $1" >> "$LOG_FILE"; }

mysql_cmd() {
  mysql -h "$AZURE_HOST" -u "$ADMIN_USER" -p"$ADMIN_PASS" --ssl-mode=REQUIRED \
    --connect-timeout=5 -e "$1"
}

# 중복 실행 방지 (이전 실행이 아직 안 끝났으면 스킵)
if [[ -f "$LOCK_FILE" ]]; then
  log "이전 실행이 아직 진행 중 (lock 존재) — 이번 회차 스킵"
  exit 0
fi
trap 'rm -f "$LOCK_FILE"' EXIT
touch "$LOCK_FILE"

# 이미 azure로 전환된 상태면 더 체크 안 함 (failback은 별도 수동 절차)
if [[ -f "$STATE_FILE" ]] && grep -q "azure" "$STATE_FILE"; then
  exit 0
fi

# 온프레미스 DB 연결 테스트
if timeout 3 bash -c "echo > /dev/tcp/$ONPREM_DB_HOST/$ONPREM_DB_PORT" 2>/dev/null; then
  echo 0 > "$FAIL_COUNT_FILE"
  exit 0
fi

# 실패 카운트 증가
COUNT=$(cat "$FAIL_COUNT_FILE" 2>/dev/null || echo 0)
COUNT=$((COUNT + 1))
echo "$COUNT" > "$FAIL_COUNT_FILE"
log "온프레미스 DB 연결 실패 ($COUNT/$FAIL_THRESHOLD)"

if [[ "$COUNT" -lt "$FAIL_THRESHOLD" ]]; then
  exit 0
fi

# ── failover 실행 전 사전 점검 — 필요한 파일이 없으면 중단하고 명확히 로그 남김 ──
if [[ ! -f "$WP_CONFIG_AZURE" ]]; then
  log "❌ failover 중단: $WP_CONFIG_AZURE 가 없습니다. 사전 준비(wp-config-azure.php 생성)를 먼저 하세요."
  exit 1
fi

# ── 여기서부터 failover 실행 ──
log "failover 시작: Azure MySQL로 전환"

mysql_cmd "CALL mysql.az_replication_stop;" 2>>"$LOG_FILE"
mysql_cmd "CALL mysql.az_replication_remove_master;" 2>>"$LOG_FILE"
# 참고: SET GLOBAL read_only/super_read_only은 Azure MySQL Flexible Server가
# SUPER 권한 자체를 지원하지 않아 항상 실패함(Microsoft 공식 제약사항).
# az_replication_remove_master가 이미 내부적으로 쓰기 가능 상태로 전환해주므로
# 별도로 시도하지 않고, 상태만 로그에 남김.
READ_ONLY_STATE=$(mysql_cmd "SHOW VARIABLES LIKE 'read_only';" 2>/dev/null | tail -1)
log "read_only 상태: ${READ_ONLY_STATE:-확인 실패}"

cp "$WP_CONFIG" "${WP_CONFIG}.bak.$(date +%s)"
cp "$WP_CONFIG_AZURE" "$WP_CONFIG"
echo "azure" > "$STATE_FILE"

systemctl restart apache2

log "failover 완료: wp-config.php → Azure MySQL로 교체, Apache 재시작됨"
