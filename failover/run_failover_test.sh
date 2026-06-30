#!/bin/bash
# =========================================================
# Failover 자동 테스트 스크립트 (VMSS1 인스턴스 안에서 실행)
#
# 1~5, 7, 8단계를 자동 수행.
# 6, 9단계(TUNADB01에서 iptables 차단/해제)는
# ONPREM_SSH_HOST 변수가 채워져 있으면 SSH로 자동 실행,
# 비어있으면 사람에게 직접 해달라고 안내하고 대기함.
# =========================================================

set -e

WP_DIR="/var/www/html"
WP_CONFIG="$WP_DIR/wp-config.php"
LOG_FILE="/var/log/failover.log"

# TUNADB01에 키 인증으로 SSH 가능하면 아래 값 채우기. 안 되면 빈 문자열로 둠.
ONPREM_SSH_HOST=""            # 예: "root@192.168.3.2"
ONPREM_SSH_KEY=""             # 예: "/home/azureuser/.ssh/tunadb01_key"

run_on_onprem() {
  local cmd="$1"
  if [[ -n "$ONPREM_SSH_HOST" ]]; then
    ssh -o StrictHostKeyChecking=no ${ONPREM_SSH_KEY:+-i "$ONPREM_SSH_KEY"} "$ONPREM_SSH_HOST" "$cmd"
  else
    echo ""
    echo "⚠️  수동 작업 필요 — TUNADB01에서 직접 실행하세요:"
    echo "    $cmd"
    read -p "    완료하셨으면 Enter를 누르세요... " _
  fi
}

echo "==> [1/8] wp-config 버전 준비"
[[ -f "$WP_DIR/wp-config.php.bak" ]] && cp "$WP_DIR/wp-config.php.bak" "$WP_DIR/wp-config-onprem.php" || true
cp "$WP_CONFIG" "$WP_DIR/wp-config-azure.php" 2>/dev/null || true
ls -la "$WP_DIR"/wp-config-onprem.php "$WP_DIR"/wp-config-azure.php

echo "==> [2/8] 평상시(온프레미스) 상태로 리셋"
cp "$WP_DIR/wp-config-onprem.php" "$WP_CONFIG"
sudo systemctl restart apache2
rm -f "$WP_DIR/.db_active_target"

echo "==> [3/8] 복제 재수립"
bash "$(dirname "$0")/setup_mysql_replication.sh"

echo "==> [4/8] failover_check.sh 설치 + cron 등록"
chmod +x "$(dirname "$0")/failover_check.sh"
sudo cp "$(dirname "$0")/failover_check.sh" /home/azureuser/failover_check.sh
CRON_TMP=$(mktemp)
sudo crontab -l 2>/dev/null | grep -v failover_check.sh > "$CRON_TMP" || true
echo "* * * * * /home/azureuser/failover_check.sh" >> "$CRON_TMP"
sudo crontab "$CRON_TMP"
rm -f "$CRON_TMP"
sudo crontab -l

echo "==> [5/8] 로그 초기화"
sudo truncate -s 0 "$LOG_FILE" 2>/dev/null || sudo touch "$LOG_FILE"

echo "==> [6/8] 온프레미스 DB 강제 차단"
run_on_onprem "sudo iptables -I INPUT 1 -s 10.101.4.0/24 -p tcp --dport 3306 -j DROP; sudo iptables -I INPUT 1 -s 10.101.1.0/24 -p tcp --dport 3306 -j DROP"

echo "==> [7/8] failover 발동 대기 (최대 5분, 로그 폴링)"
for i in $(seq 1 30); do
  if grep -q "failover 완료" "$LOG_FILE" 2>/dev/null; then
    echo "  ✔ failover 완료 감지됨 (${i}0초 경과)"
    break
  fi
  echo "  대기 중... (${i}0초 / 300초)"
  sleep 10
done

tail -20 "$LOG_FILE"

echo "==> [8/8] 사이트 정상 동작 확인"
if curl -s http://localhost/ | grep -qi "error establishing"; then
  echo "  ❌ 여전히 DB 연결 에러 — failover 실패"
else
  echo "  ✔ 정상 응답 — failover 성공"
fi

echo ""
echo "테스트 종료. 온프레미스 차단을 해제하려면:"
echo "  sudo iptables -D INPUT -s 10.101.4.0/24 -p tcp --dport 3306 -j DROP"
echo "  sudo iptables -D INPUT -s 10.101.1.0/24 -p tcp --dport 3306 -j DROP"
