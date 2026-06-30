#!/bin/bash
# ============================================================
#  전체 실행 스크립트
#
#  폴더 구조 (어느 경로든 상관없음):
#    <실행위치>/
#      ├── 100_run.sh          ← 이 파일
#      ├── 00_bootstrap.sh     ← 리소스그룹A 생성
#      └── 02_tunaHybrid/            ← Terraform 코드
#
#  실행 환경:
#    Git Bash 전용 (PowerShell, CMD 사용 불가)
#
#  실행:
#    bash 100_run.sh
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TF_DIR="$SCRIPT_DIR/02_tunaHybrid"

# ────────────────────────────────────────────────────────────
#  구독 ID 설정 (메모리에만 존재, 쉘 닫으면 사라짐)
# ────────────────────────────────────────────────────────────
export SUBSCRIPTION_ID=""
export TF_VAR_subid="$SUBSCRIPTION_ID"

echo "============================================"
echo "  전체 인프라 배포 시작"
echo "============================================"
echo ""

# ────────────────────────────────────────────────────────────
#  사전 확인
# ────────────────────────────────────────────────────────────
if [[ ! -f "$SCRIPT_DIR/00_bootstrap.sh" ]]; then
  echo "❌ 00_bootstrap.sh 파일을 찾을 수 없습니다."
  exit 1
fi

if [[ ! -d "$TF_DIR" ]]; then
  echo "❌ 02_tunaHybrid 폴더를 찾을 수 없습니다."
  exit 1
fi

if ! command -v terraform &>/dev/null; then
  echo "❌ terraform이 설치되어 있지 않습니다."
  exit 1
fi

if ! command -v az &>/dev/null; then
  echo "❌ az CLI가 설치되어 있지 않습니다."
  exit 1
fi

# ────────────────────────────────────────────────────────────
#  1단계: Bootstrap
# ────────────────────────────────────────────────────────────
echo "============================================"
echo "  [1단계] Bootstrap 실행"
echo "============================================"
echo ""

bash "$SCRIPT_DIR/00_bootstrap.sh"

echo ""
echo "✅ Bootstrap 완료"

# ────────────────────────────────────────────────────────────
#  2단계: Terraform
# ────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  [2단계] Terraform 실행"
echo "============================================"
echo ""

cd "$TF_DIR"
echo "  경로: $(pwd)"
echo ""

echo "── terraform init ──────────────────────────"
terraform init
echo ""

echo "── terraform apply ─────────────────────────"
terraform apply --auto-approve

# ────────────────────────────────────────────────────────────
#  3단계: VPN 터널 연결 대기
# ────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  [3단계] VPN 터널 연결 대기"
echo "============================================"
echo ""

for i in $(seq 1 15); do
  STATUS=$(az network vpn-connection show -g team604tuna --name tuna-vpn-conn1-to-onprem \
    --query connectionStatus -o tsv 2>/dev/null || echo "Unknown")
  echo "  vpn-conn1 상태: $STATUS ($i/15)"
  [[ "$STATUS" == "Connected" ]] && break
  sleep 20
done

if [[ "$STATUS" != "Connected" ]]; then
  echo "  ⚠️  VPN 터널이 아직 Connected가 아닙니다. 4단계는 스킵합니다."
  echo "      수동으로 상태 확인 후, setup_mysql_replication.sh를 따로 실행하세요."
else
  # ────────────────────────────────────────────────────────────
  #  4단계: MySQL Data-in Replication (VMSS1 인스턴스 안에서 원격 실행)
  # ────────────────────────────────────────────────────────────
  echo ""
  echo "============================================"
  echo "  [4단계] MySQL 복제 설정 (run-command, SSH 불필요)"
  echo "============================================"
  echo ""

  az vmss run-command invoke \
    --resource-group team604tuna \
    --name tuna-vmss1 \
    --instance-id 0 \
    --command-id RunShellScript \
    --scripts "$(cat "$SCRIPT_DIR/setup_mysql_replication.sh")" \
    --query "value[0].message" -o tsv

  echo ""
  echo "✅ MySQL 복제 설정 완료 (출력에서 Replica_IO_Running: Yes 확인)"

  # ────────────────────────────────────────────────────────────
  #  5단계: Failover 자동화 설치 (wp-config 준비 + cron 등록)
  # ────────────────────────────────────────────────────────────
  echo ""
  echo "============================================"
  echo "  [5단계] Failover 자동화 설치"
  echo "============================================"
  echo ""

  az vmss run-command invoke \
    --resource-group team604tuna \
    --name tuna-vmss1 \
    --instance-id 0 \
    --command-id RunShellScript \
    --scripts "$(cat "$SCRIPT_DIR/failover/prepare_failover.sh")" \
    --query "value[0].message" -o tsv

  echo ""
  echo "✅ Failover 자동화 설치 완료 (1분마다 자동 감지, /var/log/failover.log 확인 가능)"
fi

# ────────────────────────────────────────────────────────────
#  완료
# ────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  ✅ 전체 배포 완료!"
echo "============================================"
echo ""
echo "  output 확인:"
echo "  cd 02_tunaHybrid && terraform output"
