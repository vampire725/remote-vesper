#!/bin/bash

# ===========================================
# Elasticsearch 密码设置脚本
# 文件名: setup-passwords.sh
# 功能: 自动设置 Elasticsearch 内置用户密码
# ===========================================

set -e

echo "🔑 开始设置 Elasticsearch 用户密码..."

# 检查 Elasticsearch 是否运行
if ! curl -k -s http://localhost:9200 > /dev/null 2>&1; then
    echo "❌ Elasticsearch 未运行，请先启动服务"
    echo "💡 运行命令: docker-compose up -d"
    exit 1
fi

# 等待 Elasticsearch 完全启动
echo "⏳ 等待 Elasticsearch 完全启动..."
for i in {1..30}; do
    if curl -k -s http://localhost:9200/_cluster/health > /dev/null 2>&1; then
        echo "✅ Elasticsearch 已启动"
        break
    fi
    echo "  等待中... ($i/30)"
    sleep 2
done

# 设置密码
echo "🔐 设置内置用户密码..."

# 读取用户输入的密码
read -s -p "请输入 elastic 用户密码: " ELASTIC_PASSWORD
echo ""
read -s -p "请输入 kibana_system 用户密码: " KIBANA_PASSWORD
echo ""
read -s -p "请输入 logstash_system 用户密码: " LOGSTASH_PASSWORD
echo ""

# 验证密码不为空
if [[ -z "$ELASTIC_PASSWORD" || -z "$KIBANA_PASSWORD" || -z "$LOGSTASH_PASSWORD" ]]; then
    echo "❌ 密码不能为空"
    exit 1
fi

# 设置 elastic 用户密码
echo "🔑 设置 elastic 用户密码..."
curl -k -X POST "http://localhost:9200/_security/user/elastic/_password" \
  -H "Content-Type: application/json" \
  -u "elastic:changeme" \
  -d "{\"password\":\"$ELASTIC_PASSWORD\"}" || {
    echo "⚠️  使用默认密码失败，尝试使用环境变量密码..."
    curl -k -X POST "http://localhost:9200/_security/user/elastic/_password" \
      -H "Content-Type: application/json" \
      -u "elastic:your_elastic_password" \
      -d "{\"password\":\"$ELASTIC_PASSWORD\"}"
  }

# 设置 kibana_system 用户密码
echo "🔑 设置 kibana_system 用户密码..."
curl -k -X POST "http://localhost:9200/_security/user/kibana_system/_password" \
  -H "Content-Type: application/json" \
  -u "elastic:$ELASTIC_PASSWORD" \
  -d "{\"password\":\"$KIBANA_PASSWORD\"}"

# 设置 logstash_system 用户密码
echo "🔑 设置 logstash_system 用户密码..."
curl -k -X POST "http://localhost:9200/_security/user/logstash_system/_password" \
  -H "Content-Type: application/json" \
  -u "elastic:$ELASTIC_PASSWORD" \
  -d "{\"password\":\"$LOGSTASH_PASSWORD\"}"

# 创建 logstash_writer 角色
echo "👤 创建 logstash_writer 角色..."
curl -k -X POST "http://localhost:9200/_security/role/logstash_writer" \
  -H "Content-Type: application/json" \
  -u "elastic:$ELASTIC_PASSWORD" \
  -d '{
    "cluster": ["manage_index_templates", "monitor", "manage_ilm"],
    "indices": [
      {
        "names": ["logstash-*"],
        "privileges": ["write", "create", "create_index", "manage", "manage_ilm"]
      }
    ]
  }'

# 创建 logstash 用户
echo "👤 创建 logstash 用户..."
curl -k -X POST "http://localhost:9200/_security/user/logstash" \
  -H "Content-Type: application/json" \
  -u "elastic:$ELASTIC_PASSWORD" \
  -d "{
    \"password\": \"$LOGSTASH_PASSWORD\",
    \"roles\": [\"logstash_writer\"],
    \"full_name\": \"Logstash User\",
    \"email\": \"logstash@example.com\"
  }"

echo ""
echo "✅ 密码设置完成！"
echo ""
echo "📋 用户信息："
echo "  - elastic: $ELASTIC_PASSWORD"
echo "  - kibana_system: $KIBANA_PASSWORD"
echo "  - logstash_system: $LOGSTASH_PASSWORD"
echo "  - logstash: $LOGSTASH_PASSWORD"
echo ""
echo "🔧 请更新以下配置文件中的密码："
echo "  - docker-compose.yaml: ELASTIC_PASSWORD"
echo "  - ../logstash/docker-compose.yaml: ELASTICSEARCH_PASSWORD"
echo ""
echo "🚀 重启服务以应用新密码："
echo "  docker-compose restart" 