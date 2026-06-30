#!/bin/bash

DB_HOST="db.tuna.internal"

KEYVAULT_NAME="${key_vault_name}"
DB_NAME_SECRET_NAME="${db_name_secret_name}"
DB_USER_SECRET_NAME="${db_user_secret_name}"
DB_PASSWORD_SECRET_NAME="${db_password_secret_name}"
MANAGED_IDENTITY_CLIENT_ID="${managed_identity_client_id}"

for i in {1..10}; do
  apt-get update -y && break
  echo "apt-get update failed, retry $i/10..."
  sleep 30
done

apt-get install -y apache2 php php-mysql php-curl php-gd php-mbstring php-xml wget tar libapache2-mod-php python3 curl default-mysql-client

ACCESS_TOKEN=$(curl -s -H Metadata:true \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net&client_id=$MANAGED_IDENTITY_CLIENT_ID" \
  | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])")

get_secret() {
  local secret_name="$1"

  curl -s \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    "https://$KEYVAULT_NAME.vault.azure.net/secrets/$secret_name?api-version=7.4" \
    | python3 -c "import sys, json; print(json.load(sys.stdin)['value'])"
}

DB_NAME=$(get_secret "$DB_NAME_SECRET_NAME")
DB_USER=$(get_secret "$DB_USER_SECRET_NAME")
DB_PASS=$(get_secret "$DB_PASSWORD_SECRET_NAME")

systemctl enable --now apache2

cd /tmp
rm -rf /tmp/wordpress /tmp/wordpress-6.7.2-ko_KR.tar.gz

wget -q https://ko.wordpress.org/wordpress-6.7.2-ko_KR.tar.gz
tar xzf wordpress-6.7.2-ko_KR.tar.gz

rm -rf /var/www/html/*
cp -a /tmp/wordpress/. /var/www/html/

cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php

sed -i "s/database_name_here/$DB_NAME/g" /var/www/html/wp-config.php
sed -i "s/username_here/$DB_USER/g" /var/www/html/wp-config.php
sed -i "s/password_here/$DB_PASS/g" /var/www/html/wp-config.php
sed -i "s/localhost/$DB_HOST/g" /var/www/html/wp-config.php

# az cli 설치 (setup_mysql_replication.sh를 az vmss run-command로 자동 실행하기 위해 필요)
if ! command -v az &>/dev/null; then
  for i in {1..5}; do
    curl -sL https://aka.ms/InstallAzureCLIDeb | bash && break
    echo "az cli 설치 실패, retry $i/5..."
    sleep 20
  done
fi

a2enmod rewrite

# X-Forwarded-For 포함 로그 포맷 설정 (AppGW 뒤 실제 접속자 IP 기록)
cat > /etc/apache2/conf-available/logformat-xforwarded.conf <<'EOF'
LogFormat "%%{X-Forwarded-For}i %h %l %u %t \"%r\" %>s %O %%{Referer}i %%{User-Agent}i" appgw_combined
CustomLog $${APACHE_LOG_DIR}/access.log appgw_combined
EOF

a2enconf logformat-xforwarded

cat > /etc/apache2/conf-available/wordpress-override.conf <<'EOF'
<Directory /var/www/html/>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
EOF

a2enconf wordpress-override

cat > /var/www/html/.htaccess <<'EOF'
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteRule .* - [E=HTTP_AUTHORIZATION:%%{HTTP:Authorization}]
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %%{REQUEST_FILENAME} !-f
RewriteCond %%{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
EOF

mkdir -p /var/www/html/wp-content/mu-plugins

cat > /var/www/html/wp-content/mu-plugins/tuna-vacation-request.php <<'PHP'
<?php
/*
Plugin Name: TUNA Vacation Request
Description: Groupware vacation request form.
Version: 1.0
*/

function tuna_vacation_form() {
    global $wpdb;

    $dept_table = $wpdb->prefix . "departments";
    $vac_table  = $wpdb->prefix . "vacation_requests";

    $message = "";

    if ($_SERVER["REQUEST_METHOD"] === "POST" && isset($_POST["tuna_vacation_submit"])) {
        $inserted = $wpdb->insert(
            $vac_table,
            array(
                "employee_name" => sanitize_text_field($_POST["employee_name"]),
                "department"    => sanitize_text_field($_POST["department"]),
                "vacation_type" => sanitize_text_field($_POST["vacation_type"]),
                "phone"         => sanitize_text_field($_POST["phone"]),
                "start_date"    => sanitize_text_field($_POST["start_date"]),
                "end_date"      => sanitize_text_field($_POST["end_date"]),
                "reason"        => sanitize_textarea_field($_POST["reason"]),
                "status"        => "승인 대기"
            ),
            array("%s", "%s", "%s", "%s", "%s", "%s", "%s", "%s")
        );

        if ($inserted !== false) {
            $message = '<div class="tuna-success">휴가 신청이 정상적으로 접수되었습니다.</div>';
        } else {
            $message = '<div class="tuna-error">DB 저장 중 오류가 발생했습니다.</div>';
        }
    }

    $departments = $wpdb->get_results("SELECT dept_name FROM {$dept_table} ORDER BY dept_id ASC");

    ob_start();
    echo $message;
    ?>

    <style>
    * { box-sizing: border-box; }
    .tuna-wrap { max-width: 980px; margin: 30px auto; display: flex; gap: 20px; font-family: 'Malgun Gothic', sans-serif; }
    .tuna-sidebar { width: 230px; background: #fff; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,.1); }
    .tuna-menu-title { padding: 20px; font-weight: bold; border-bottom: 1px solid #ddd; }
    .tuna-menu { padding: 15px 20px; }
    .tuna-card { flex: 1; background: #fff; border-radius: 10px; padding: 30px; box-shadow: 0 2px 10px rgba(0,0,0,.1); }
    .tuna-title { font-size: 28px; font-weight: bold; }
    .tuna-desc { color: #666; margin: 10px 0 25px; }
    .tuna-status { display: inline-block; background: #fff7ed; color: #c2410c; padding: 6px 12px; border-radius: 20px; font-size: 13px; margin-bottom: 25px; }
    .tuna-row { display: flex; gap: 20px; margin-bottom: 20px; }
    .tuna-group { flex: 1; }
    .tuna-group label { display: block; margin-bottom: 8px; font-weight: bold; }
    .tuna-group input, .tuna-group select, .tuna-group textarea {
        width: 100%;
        height: 46px;
        padding: 10px 12px;
        border: 1px solid #ccc;
        border-radius: 8px;
        font-size: 15px;
    }
    .tuna-group textarea { height: 120px; resize: vertical; }
    .tuna-btn { background: #2563eb; color: white; border: none; padding: 14px 30px; border-radius: 8px; font-size: 16px; cursor: pointer; }
    .tuna-success { max-width: 980px; margin: 20px auto; padding: 15px; background: #ecfdf5; color: #047857; border-radius: 10px; font-weight: bold; }
    .tuna-error { max-width: 980px; margin: 20px auto; padding: 15px; background: #fef2f2; color: #b91c1c; border-radius: 10px; font-weight: bold; }
    </style>

    <div class="tuna-wrap">
        <div class="tuna-sidebar">
            <div class="tuna-menu-title">업무 메뉴</div>
            <div class="tuna-menu">공지사항</div>
            <div class="tuna-menu">전자결재</div>
            <div class="tuna-menu">휴가 신청</div>
            <div class="tuna-menu">자료실</div>
            <div class="tuna-menu">사내 게시판</div>
        </div>

        <div class="tuna-card">
            <div class="tuna-title">휴가 신청</div>
            <div class="tuna-desc">휴가 신청 정보를 입력하여 결재를 요청합니다.</div>
            <div class="tuna-status">승인 대기</div>

            <form method="post">
                <div class="tuna-row">
                    <div class="tuna-group">
                        <label>사원명</label>
                        <input type="text" name="employee_name" placeholder="홍길동" required>
                    </div>

                    <div class="tuna-group">
                        <label>부서</label>
                        <select name="department" required>
                            <option value="">부서 선택</option>
                            <?php foreach ($departments as $dept) : ?>
                                <option value="<?php echo esc_attr($dept->dept_name); ?>">
                                    <?php echo esc_html($dept->dept_name); ?>
                                </option>
                            <?php endforeach; ?>
                        </select>
                    </div>
                </div>

                <div class="tuna-row">
                    <div class="tuna-group">
                        <label>휴가 종류</label>
                        <select name="vacation_type" required>
                            <option>연차</option>
                            <option>오전 반차</option>
                            <option>오후 반차</option>
                            <option>병가</option>
                            <option>공가</option>
                        </select>
                    </div>

                    <div class="tuna-group">
                        <label>연락처</label>
                        <input type="text" name="phone" placeholder="010-0000-0000">
                    </div>
                </div>

                <div class="tuna-row">
                    <div class="tuna-group">
                        <label>시작일</label>
                        <input type="date" name="start_date" required>
                    </div>

                    <div class="tuna-group">
                        <label>종료일</label>
                        <input type="date" name="end_date" required>
                    </div>
                </div>

                <div class="tuna-group">
                    <label>휴가 사유</label>
                    <textarea name="reason" placeholder="휴가 사유를 입력하세요." required></textarea>
                </div>

                <br>

                <button class="tuna-btn" type="submit" name="tuna_vacation_submit">휴가 신청</button>
            </form>
        </div>
    </div>

    <?php
    return ob_get_clean();
}

add_shortcode("tuna_vacation", "tuna_vacation_form");
PHP

chown -R www-data:www-data /var/www/html/
chmod -R 755 /var/www/html/

echo "healthy" > /var/www/html/health.html

systemctl restart apache2

# ────────────────────────────────────────────────────────────
#  Filebeat 설치 및 설정 (ELK로 Apache 로그 전송)
# ────────────────────────────────────────────────────────────
FILEBEAT_VERSION="${filebeat_version}"
ELK_IP="${elk_private_ip}"

# Filebeat 설치
wget -qO /tmp/filebeat.deb "https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-$${FILEBEAT_VERSION}-amd64.deb"
dpkg -i /tmp/filebeat.deb
rm -f /tmp/filebeat.deb

# Filebeat 설정
cat > /etc/filebeat/filebeat.yml <<EOF
filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - /var/log/apache2/access.log
    fields:
      log_type: apache_access
    fields_under_root: true

output.logstash:
  hosts: ["$${ELK_IP}:5044"]

logging.level: warning
EOF

systemctl enable filebeat
systemctl start filebeat

echo "TUNA WordPress deployment completed"