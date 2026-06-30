# 온프레미스 DB 서버(192.168.3.2) 사전 작업 안내

Azure MySQL Flexible Server를 Replica로 연결하려면, 온프레미스 DB svr에서
먼저 아래 작업을 진행해야 합니다. (terraform apply 이후, setup_mysql_replication.sh
실행 전에 완료)

## 1. 바이너리 로그(binlog) 활성화

Azure MySQL Flexible Server(이 SKU)는 GTID 기반 복제(`gtid_mode=ON`)를
지원하지 않으므로, 전통적인 **binlog 파일/포지션 기반 복제**를 사용합니다.

`/etc/my.cnf` (CentOS 7 기준)에 아래 설정 추가 후 mysqld 재시작:

```ini
[mysqld]
log_bin=mysql-bin
binlog_format=ROW
server_id=1
```

```bash
systemctl restart mysqld
```

## 2. 복제용 계정 생성

```sql
CREATE USER 'repl_user'@'%' IDENTIFIED BY '<강력한 비밀번호>';
GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';
FLUSH PRIVILEGES;
```

생성한 비밀번호는 Key Vault에 `repl-password` 시크릿으로 저장해두고,
`setup_mysql_replication.sh`의 `REPL_PASSWORD` 변수에서 참조하세요.

## 3. 방화벽(SECUI BLUEMAX NGF) 정책 추가

Azure VPN Gateway 대역(10.101.2.0/27, 10.102.2.0/27)에서 들어오는
3306/TCP 트래픽이 SERVER FARM(192.168.3.0/29)까지 도달하도록 정책 추가:

- Source: Azure VNet 대역 (VPN 터널 경유)
- Destination: 192.168.3.2 (DB svr)
- Port: 3306/TCP
- Action: Allow

## 4. L3 스위치 라우팅 확인

기존 구성도 상 VLAN30(192.168.3.1/29)이 DB svr이 속한 SERVER FARM
네트워크이므로, 방화벽을 거쳐 VPN 게이트웨이까지의 경로가 라우팅
테이블에 존재하는지 확인하세요 (F/W ETH2 - L3 GE24 경로).

## 5. 연결 확인

위 작업이 끝나면 Azure 쪽에서 온프레미스로 3306 포트가 열리는지 확인:

```bash
# Azure Bastion으로 접속한 VM 등에서
nc -zv 192.168.3.2 3306
```

성공하면 `setup_mysql_replication.sh`를 실행해 Data-in Replication을
시작할 수 있습니다.

## 6. 장애 전환(Failover) 절차 (참고)

온프레미스 DB 장애 시:

1. Azure MySQL Replica를 복제 모드에서 분리(stop replication)
2. `azurerm_private_dns_a_record.db_record`의 레코드 값을
   Azure MySQL의 Private IP로 변경 (terraform apply 또는 az cli)
3. WordPress(VMSS)는 `db.tuna.internal` 그대로 사용 중이므로
   DNS 갱신만으로 애플리케이션 재배포 없이 전환 완료
4. 온프레미스 DB 복구 후에는 역방향 동기화를 거쳐 다시 Primary로 복귀
