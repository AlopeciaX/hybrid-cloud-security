# Hybrid Cloud 보안 구축

온프레미스와 Azure 클라우드를 연결한 하이브리드 환경에서 MySQL 복제, 자동 Failover, ELK 기반 보안 모니터링을 구성한 프로젝트입니다.

※ 생성하기 전 claude 코드에 코드 zip 파일 올려서 tuna --> tuna(원하는값)으로 변경해서 재생성해줘라는 프롬포트 입력 후 돌리시길 바랍니다.

---

## 기술 스택

- **IaC**: Terraform (azurerm 4.74.0)
- **Cloud**: Microsoft Azure + On-premises
- **DB**: Azure MySQL Flexible Server, MySQL Replication
- **모니터링**: ELK Stack (Elasticsearch, Logstash, Kibana)
- **네트워크**: VPN Gateway, VNet, NAT Gateway, NSG, Traffic Manager
- **보안**: Azure Key Vault, Bastion, Managed Identity

---

## 인프라 구성

```
├── 00_bootstrap.sh              # 초기 인프라 세팅
├── 100_run.sh                   # 전체 배포 스크립트
├── setup_mysql_replication.sh   # MySQL 복제 초기 설정
├── 02_tunaHybrid/
│   ├── 00_init.tf ~ 18_identity.tf  # Azure 기본 인프라 (VNet, NSG, VMSS 등)
│   ├── 19_mysql_flexible.tf     # Azure MySQL Flexible Server
│   ├── 20_mysql_dns.tf          # MySQL Private DNS
│   ├── 21_mysql_nsg.tf          # MySQL NSG
│   ├── 22_elk.tf                # ELK 서버
│   ├── install_elk.sh           # ELK 설치 스크립트
│   └── ONPREM_DB_SETUP.md       # 온프레미스 DB 설정 가이드
└── failover/
    ├── failover_check.sh        # 자동 Failover 감지 스크립트
    ├── prepare_failover.sh      # Failover 준비
    ├── backup_to_storage.sh     # DB 백업 (Storage Account)
    ├── run_failover_test.sh     # Failover 테스트
    └── README.md                # Failover 사용법
```

---

## 실행 방법

본 프로젝트는 교육·실습 목적으로 구성되었으며, `SUBSCRIPTION_ID`만 본인 Azure 구독 ID로 입력하면 나머지 인프라는 자동으로 구성됩니다. 리소스 이름, 비밀번호 등은 실습용으로 사용한 값이 그대로 들어가 있으므로 별도 수정 없이 바로 실행 가능합니다.

```bash
# 1. SUBSCRIPTION_ID 환경변수 설정
export SUBSCRIPTION_ID="본인 구독 ID 입력"

# 2. 전체 배포 (bootstrap → Terraform → MySQL 복제 → Failover 설치 순서로 자동 실행)
bash 100_run.sh
```

> VPN 터널 연결 실패 시 MySQL 복제 단계는 스킵되며, 이후 수동으로 `setup_mysql_replication.sh`를 실행하면 됩니다.

---

## Failover 자동화

온프레미스 DB 장애 시 Azure MySQL로 자동 전환됩니다.

- 1분마다 온프레미스 DB 연결 상태 확인
- 연속 3회 실패 시 자동 Failover 실행
  1. Azure MySQL 복제 중단 및 read_only 해제
  2. 애플리케이션 DB 연결 정보 자동 교체
  3. Apache 재시작
- DB 백업: 매일 03:00 자동 실행, 7일 보존

```bash
# Failover 스크립트 설치
bash failover/prepare_failover.sh

# Failover 테스트
bash failover/run_failover_test.sh
```

---

## 주요 보안 구성

- **VPN Gateway**: 온프레미스 ↔ Azure 암호화 터널
- **Azure Bastion**: 공개 IP 없이 VM 안전 접속
- **Key Vault**: 시크릿 중앙 관리, Managed Identity 접근
- **ELK Stack**: 로그 수집 및 보안 이벤트 시각화
- **MySQL Private DNS**: DB 엔드포인트 프라이빗 접근
