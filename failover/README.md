# Failover 자동화 사용법

## 사전 준비 (VMSS 인스턴스에서, 1회만)

failover 전후로 쓸 wp-config.php 두 버전을 준비합니다.
(이미 wp-config.php.bak이 있다면 그게 onprem 버전입니다.)

    cp /var/www/html/wp-config.php.bak /var/www/html/wp-config-onprem.php
    cp /var/www/html/wp-config.php /var/www/html/wp-config-azure.php

다시 평상시(온프레미스) 상태로 맞춰두려면:

    cp /var/www/html/wp-config-onprem.php /var/www/html/wp-config.php
    sudo systemctl restart apache2
    rm -f /var/www/html/.db_active_target

## 설치

    chmod +x failover_check.sh
    sudo cp failover_check.sh /home/azureuser/failover_check.sh
    sudo crontab -e
    # 아래 줄 추가
    * * * * * /home/azureuser/failover_check.sh

## 동작

1분마다 온프레미스 DB(192.168.3.2:3306) 연결을 확인합니다.
연속 3회 실패하면:
  1. Azure MySQL 복제 중단 + 복제 관계 제거 (mysql.az_replication_stop / remove_master)
  2. Azure MySQL read_only 해제
  3. wp-config.php를 wp-config-azure.php로 교체
  4. Apache 재시작
  5. /var/log/failover.log에 기록

## 주의

- failback(온프레미스 복구 후 되돌리기)은 자동화되어 있지 않습니다. 수동으로 판단해서 처리해야 합니다.
- VMSS 인스턴스가 여러 대면 동시에 중복 실행될 수 있습니다. 단일 인스턴스 기준입니다.

## DB 백업 (Azure → Storage Account)

prepare_failover.sh가 backup_to_storage.sh도 같이 설치하고 cron에 등록합니다
(매일 03:00 실행, 7일 보존 — 그보다 오래된 백업은 실행 시마다 자동 삭제).

목적: 온프레미스가 죽어서 failover한 뒤(Azure가 새 원본이 된 상태)에서
Azure까지 같이 죽는 이중 장애에 대비. 평상시(failover 전)에는 온프레미스가
원본 데이터를 그대로 갖고 있어서 이 백업이 필수는 아님.

수동 실행: /home/azureuser/backup_to_storage.sh
로그 확인: /var/log/db_backup.log
백업 목록 확인:
    az storage blob list --account-name tunatfstate604 --container-name dbbackup --auth-mode login -o table
