#!/bin/bash
set -e

ELASTIC_VERSION="8.15.3"

for i in {1..10}; do
  apt-get update -y && break
  echo "apt-get update failed, retry $i/10..."
  sleep 30
done

apt-get install -y ca-certificates curl gnupg netcat-openbsd

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

mkdir -p /opt/elk
cd /opt/elk

cat > docker-compose.yml <<EOF
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:${ELASTIC_VERSION}
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - ES_JAVA_OPTS=-Xms512m -Xmx512m
    ports:
      - "127.0.0.1:9200:9200"
    volumes:
      - esdata:/usr/share/elasticsearch/data

  logstash:
    image: docker.elastic.co/logstash/logstash:${ELASTIC_VERSION}
    container_name: logstash
    ports:
      - "5044:5044"
    volumes:
      - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf
    depends_on:
      - elasticsearch

  kibana:
    image: docker.elastic.co/kibana/kibana:${ELASTIC_VERSION}
    container_name: kibana
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    depends_on:
      - elasticsearch

volumes:
  esdata:
EOF

cat > logstash.conf <<'EOF'
input {
  beats {
    port => 5044
  }
}

filter {
  # Apache Combined Log Format 파싱
  # 파싱 실패한 로그는 _grok_parse_failure 태그를 달고 그대로 저장됨 (로그 유실 없음)
  grok {
    # X-Forwarded-For 포함 커스텀 포맷 파싱
    # 필드: client_ip(실제접속자) appgw_ip verb request response bytes
    match => {
      "message" => "%{IP:client_ip} %{IPORHOST:appgw_ip} %{USER:ident} %{USER:auth} \[%{HTTPDATE:timestamp}\] \"%{WORD:verb} %{NOTSPACE:request}(?: HTTP/%{NUMBER:http_version})?\" %{NUMBER:response} %{NUMBER:bytes} \"%{DATA:referrer}\" \"%{DATA:user_agent}\""
    }
    tag_on_failure => ["_grok_parse_failure"]
  }

  # Filebeat가 넣은 문자열 timestamp → @timestamp 필드로 변환
  date {
    match => ["timestamp", "dd/MMM/yyyy:HH:mm:ss Z"]
    target => "@timestamp"
    remove_field => ["timestamp"]
  }

  # 문자열로 들어온 숫자 필드를 integer로 변환 (Kibana 집계용)
  mutate {
    convert => {
      "response" => "integer"
      "bytes"    => "integer"
    }
  }
}

output {
  elasticsearch {
    hosts => ["http://elasticsearch:9200"]
    index => "web-logs-%{+YYYY.MM.dd}"
  }
}
EOF

docker compose up -d

# Kibana가 준비되면 Data View를 자동 생성한다. 실패해도 ELK 배포 자체는 유지한다.
for i in {1..60}; do
  if curl -s http://localhost:5601/api/status | grep -q 'available\|degraded'; then
    break
  fi
  sleep 10
done

curl -s -X POST "http://localhost:5601/api/data_views/data_view" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{"data_view":{"title":"web-logs-*","name":"web-logs","timeFieldName":"@timestamp"}}' || true

echo "ELK Stack deployment completed"
