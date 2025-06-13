# 🔓 Kafka 无 SASL 认证配置指南

> 📋 本文档说明当 Kafka 集群未启用 SASL 认证时，如何调整 Logstash 配置以正常连接和处理数据。

## 📖 目录

- [🔍 概述](#-概述)
- [⚙️ 配置调整](#️-配置调整)
- [📁 文件修改](#-文件修改)
- [🔧 环境变量调整](#-环境变量调整)
- [🚀 启动验证](#-启动验证)
- [🛠️ 故障排除](#️-故障排除)
- [📊 性能优化](#-性能优化)

## 🔍 概述

当 Kafka 集群运行在**无认证模式**（不使用 SASL/SSL）时，Logstash 的连接配置需要相应简化。这种配置通常用于：

- 🧪 **开发测试环境**
- 🏠 **内网隔离环境**
- 🔒 **通过其他方式保护的网络**

## ⚙️ 配置调整

### 1️⃣ 管道配置修改

需要修改 `pipeline/main.conf` 文件中的 Kafka 输入配置：

#### 🔴 **当前配置（带 SASL）**

```ruby
input {
  kafka {
    bootstrap_servers => "${KAFKA_HOSTS}"
    topics => ["${KAFKA_TOPIC}"]
    client_id => "logstash"
    group_id => "logstash"
    auto_offset_reset => "latest"
    consumer_threads => 2
    decorate_events => true
    sasl_mechanism => "PLAIN"                    # ❌ 需要删除
    security_protocol => "SASL_SSL"              # ❌ 需要修改
    sasl_jaas_config => "org.apache.kafka..."   # ❌ 需要删除
  }
}
```

#### 🟢 **调整后配置（无 SASL）**

```ruby
input {
  kafka {
    # Kafka 集群地址
    bootstrap_servers => "${KAFKA_HOSTS}"

    # 订阅的主题列表
    topics => ["${KAFKA_TOPIC}"]

    # 客户端标识符
    client_id => "logstash"

    # 消费者组标识符
    group_id => "logstash"

    # 偏移量重置策略：从最新消息开始消费
    auto_offset_reset => "latest"

    # 消费者线程数：并行处理提高性能
    consumer_threads => 2

    # 添加 Kafka 元数据到事件中
    decorate_events => true

    # 🔓 无认证配置
    security_protocol => "PLAINTEXT"

    # 🔧 可选：性能优化配置
    session_timeout_ms => 30000
    heartbeat_interval_ms => 3000
    max_poll_records => 500
    fetch_min_bytes => 1
    fetch_max_wait_ms => 500
  }
}
```

### 2️⃣ SSL 配置调整（如果使用 SSL 但无认证）

如果 Kafka 使用 SSL 加密但不需要客户端认证：

```ruby
input {
  kafka {
    bootstrap_servers => "${KAFKA_HOSTS}"
    topics => ["${KAFKA_TOPIC}"]
    client_id => "logstash"
    group_id => "logstash"
    auto_offset_reset => "latest"
    consumer_threads => 2
    decorate_events => true

    # 🔐 SSL 加密但无客户端认证
    security_protocol => "SSL"
    ssl_truststore_location => "/usr/share/logstash/certs/kafka.client.truststore.jks"
    ssl_truststore_password => "${KAFKA_TRUSTSTORE_PASSWORD}"
    ssl_endpoint_identification_algorithm => ""
  }
}
```

## 📁 文件修改

### 📝 修改 pipeline/main.conf

**步骤 1：备份原始文件**

```bash
cp pipeline/main.conf pipeline/main.conf.backup
```

**步骤 2：编辑配置文件**

```bash
# 使用你喜欢的编辑器
vim pipeline/main.conf
# 或者
nano pipeline/main.conf
```

**步骤 3：替换 input 部分**

找到以下行并删除或注释：

```ruby
# 删除这些 SASL 相关配置
sasl_mechanism => "PLAIN"
security_protocol => "SASL_SSL"
sasl_jaas_config => "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"${KAFKA_USERNAME}\" password=\"${KAFKA_PASSWORD}\";"
```

替换为：

```ruby
# 添加无认证配置
security_protocol => "PLAINTEXT"
```

### 📝 修改 docker-compose.yaml

**步骤 1：调整环境变量**

在 `docker-compose.yaml` 中，可以移除或注释掉 SASL 相关的环境变量：

```yaml
environment:
  # Elasticsearch 连接配置
  - ELASTICSEARCH_HOSTS=https://es01:9200
  - ELASTICSEARCH_USERNAME=elastic
  - ELASTICSEARCH_PASSWORD=your_password

  # Kafka 连接配置
  - KAFKA_HOSTS=kafka:9092
  - KAFKA_TOPIC=filebeat-logs
  # ❌ 以下 SASL 相关变量可以删除或注释
  # - KAFKA_USERNAME=your_username
  # - KAFKA_PASSWORD=your_password

  # JVM 内存配置
  - LS_JAVA_OPTS=-Xms1g -Xmx1g
```

## 🔧 环境变量调整

### 🗂️ 必需的环境变量

```bash
# Kafka 连接配置
export KAFKA_HOSTS="localhost:9092"
export KAFKA_TOPIC="your-topic-name"

# Elasticsearch 连接配置
export ELASTICSEARCH_HOSTS="https://localhost:9200"
export ELASTICSEARCH_USERNAME="elastic"
export ELASTICSEARCH_PASSWORD="your_es_password"
```

### 🗂️ 可选的环境变量

```bash
# 性能调优
export KAFKA_SESSION_TIMEOUT="30000"
export KAFKA_HEARTBEAT_INTERVAL="3000"
export KAFKA_MAX_POLL_RECORDS="500"

# 日志级别
export LOG_LEVEL="info"
```

## 🚀 启动验证

### 1️⃣ 配置验证

**检查配置语法**：

```bash
# 进入 logstash 目录
cd logstash

# 验证配置文件语法
docker run --rm \
  -v $(pwd)/pipeline:/usr/share/logstash/pipeline:ro \
  -v $(pwd)/logstash.yml:/usr/share/logstash/config/logstash.yml:ro \
  docker.elastic.co/logstash/logstash:9.0.2 \
  logstash --config.test_and_exit
```

### 2️⃣ 启动服务

```bash
# 启动 Logstash
docker-compose up -d

# 查看启动日志
docker-compose logs -f logstash
```

### 3️⃣ 连接测试

**检查 Kafka 连接**：

```bash
# 查看 Logstash 日志中的连接信息
docker-compose logs logstash | grep -i kafka

# 检查消费者组
docker exec -it kafka kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --list
```

## 🛠️ 故障排除

### ❌ 常见问题

#### 1. 连接被拒绝

```
[ERROR] Failed to connect to Kafka: Connection refused
```

**解决方案**：

- ✅ 检查 Kafka 服务是否运行
- ✅ 验证 `KAFKA_HOSTS` 地址是否正确
- ✅ 确认网络连通性

#### 2. 认证错误

```
[ERROR] SASL authentication failed
```

**解决方案**：

- ✅ 确认已删除所有 SASL 相关配置
- ✅ 检查 `security_protocol` 设置为 `PLAINTEXT`

#### 3. 主题不存在

```
[WARN] Topic 'your-topic' does not exist
```

**解决方案**：

```bash
# 创建主题
docker exec -it kafka kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create \
  --topic your-topic-name \
  --partitions 3 \
  --replication-factor 1
```

### 🔍 调试命令

```bash
# 查看详细日志
docker-compose logs --tail=100 logstash

# 检查网络连接
docker exec -it logstash netstat -an | grep 9092

# 测试 Kafka 连接
docker exec -it logstash curl -v telnet://kafka:9092
```

## 📊 性能优化

### ⚡ 消费者优化

```ruby
input {
  kafka {
    bootstrap_servers => "${KAFKA_HOSTS}"
    topics => ["${KAFKA_TOPIC}"]
    security_protocol => "PLAINTEXT"

    # 🚀 性能优化配置
    consumer_threads => 4                    # 增加消费者线程
    max_poll_records => 1000                # 增加批量大小
    fetch_min_bytes => 1024                 # 最小获取字节数
    fetch_max_wait_ms => 100                # 减少等待时间
    session_timeout_ms => 30000             # 会话超时
    heartbeat_interval_ms => 3000           # 心跳间隔

    # 🔧 高级配置
    enable_auto_commit => true
    auto_commit_interval_ms => 5000
    max_poll_interval_ms => 300000
  }
}
```

### 📈 监控指标

```ruby
# 在 filter 部分添加性能监控
filter {
  # 添加处理时间戳
  ruby {
    code => "event.set('[@metadata][processing_time]', Time.now.to_f)"
  }

  # 添加消费延迟监控
  if [@metadata][kafka][timestamp] {
    ruby {
      code => "
        kafka_timestamp = event.get('[@metadata][kafka][timestamp]')
        current_time = Time.now.to_f * 1000
        lag = current_time - kafka_timestamp
        event.set('[@metadata][consumer_lag_ms]', lag)
      "
    }
  }
}
```

## 📋 配置模板

### 🔧 完整的无认证配置模板

```ruby
# ===========================================
# Kafka 无 SASL 认证输入配置模板
# ===========================================
input {
  kafka {
    # 基础连接配置
    bootstrap_servers => "${KAFKA_HOSTS}"
    topics => ["${KAFKA_TOPIC}"]
    client_id => "logstash-${HOSTNAME}"
    group_id => "logstash-group"

    # 安全配置（无认证）
    security_protocol => "PLAINTEXT"

    # 消费者配置
    auto_offset_reset => "latest"
    consumer_threads => 2
    decorate_events => true

    # 性能优化
    session_timeout_ms => 30000
    heartbeat_interval_ms => 3000
    max_poll_records => 500
    fetch_min_bytes => 1
    fetch_max_wait_ms => 500

    # 编解码配置
    codec => json {
      charset => "UTF-8"
    }
  }
}
```

---

## 📞 获取帮助

如果遇到问题，可以通过以下方式获取帮助：

1. 📖 **查看日志**：`docker-compose logs logstash`
2. 🔍 **检查配置**：使用配置验证命令
3. 🌐 **社区支持**：访问 [Elastic 官方论坛](https://discuss.elastic.co/)
4. 📚 **官方文档**：参考 [Logstash Kafka 插件文档](https://www.elastic.co/guide/en/logstash/current/plugins-inputs-kafka.html)

---

**⚠️ 注意**：无认证配置仅适用于受信任的网络环境。在生产环境中，建议启用适当的安全措施。
