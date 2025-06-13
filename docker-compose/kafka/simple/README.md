# Kafka 简单部署版本

> **Apache Kafka 3.9.1 简单部署方案**  
> 适用于开发和测试环境，不带 SASL 认证，快速启动

## 📋 概述

这是一个简化的 Kafka 部署方案，专为开发和测试环境设计。该版本移除了复杂的安全配置，提供最简单的 Kafka 集群部署体验。

### 🎯 特性

- ✅ **简单配置**: 无需复杂的安全设置
- ✅ **快速启动**: 一键启动完整的 Kafka 集群
- ✅ **开发友好**: 自动创建主题，便于开发测试
- ✅ **管理界面**: 内置 Kafka UI 管理界面
- ✅ **健康检查**: 自动服务健康监控
- ✅ **跨平台**: 支持 Linux/Mac 和 Windows
- ✅ **资源优化**: 针对开发环境的资源配置

### 🏗️ 架构组件

| 组件             | 版本   | 端口 | 描述         |
| ---------------- | ------ | ---- | ------------ |
| **Kafka Broker** | 3.9.1  | 9092 | 消息代理服务 |
| **Zookeeper**    | 3.9.1  | 2181 | 集群协调服务 |
| **Kafka UI**     | latest | 8080 | Web 管理界面 |

## 🚀 快速开始

### 前置要求

- Docker 20.10+
- Docker Compose 2.0+
- 可用端口: 2181, 9092, 8080
- 系统内存: 至少 4GB

### 启动集群

**Linux/Mac:**

```bash
# 赋予执行权限
chmod +x start.sh

# 启动集群
./start.sh start
```

**Windows:**

```cmd
# 启动集群
start.bat start
```

### 验证部署

启动成功后，您将看到以下访问信息：

```
=== Kafka 集群访问信息 ===
Kafka Broker:     localhost:9092
Zookeeper:       localhost:2181
Kafka UI:        http://localhost:8080
```

## 🛠️ 管理命令

### 基础操作

```bash
# 启动集群
./start.sh start

# 查看状态
./start.sh status

# 停止集群
./start.sh stop

# 重启集群
./start.sh restart

# 查看日志
./start.sh logs

# 查看特定服务日志
./start.sh logs kafka
```

### 主题管理

```bash
# 列出所有主题
./start.sh topics --list

# 创建主题
./start.sh topics --create my-topic 3 1

# 删除主题
./start.sh topics --delete my-topic

# 描述主题
./start.sh topics --describe my-topic
```

### 测试和监控

```bash
# 测试连接
./start.sh test

# 健康检查
./start.sh health

# 打开管理界面
./start.sh ui

# 清理所有数据
./start.sh clean

# 重置集群
./start.sh reset
```

## 📊 配置说明

### Kafka 配置特点

```yaml
# 监听器配置 - 使用明文协议
KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092
KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092

# 开发环境优化
KAFKA_AUTO_CREATE_TOPICS_ENABLE: "true"
KAFKA_DELETE_TOPIC_ENABLE: "true"
KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1

# 资源配置
KAFKA_HEAP_OPTS: "-Xmx1G -Xms1G"
```

### 网络配置

- **网络名称**: `kafka-simple-network`
- **子网**: `172.20.0.0/16`
- **驱动**: `bridge`

### 数据持久化

| 数据卷                        | 挂载点                    | 描述           |
| ----------------------------- | ------------------------- | -------------- |
| `kafka-simple-kafka-data`     | `/var/lib/kafka/data`     | Kafka 数据     |
| `kafka-simple-kafka-logs`     | `/opt/kafka/logs`         | Kafka 日志     |
| `kafka-simple-zookeeper-data` | `/var/lib/zookeeper/data` | Zookeeper 数据 |
| `kafka-simple-zookeeper-logs` | `/var/lib/zookeeper/log`  | Zookeeper 日志 |

## 🔧 客户端连接

### Java 客户端

```java
Properties props = new Properties();
props.put("bootstrap.servers", "localhost:9092");
props.put("key.serializer", "org.apache.kafka.common.serialization.StringSerializer");
props.put("value.serializer", "org.apache.kafka.common.serialization.StringSerializer");

Producer<String, String> producer = new KafkaProducer<>(props);
```

### Python 客户端

```python
from kafka import KafkaProducer, KafkaConsumer

# 生产者
producer = KafkaProducer(
    bootstrap_servers=['localhost:9092'],
    value_serializer=lambda x: x.encode('utf-8')
)

# 消费者
consumer = KafkaConsumer(
    'my-topic',
    bootstrap_servers=['localhost:9092'],
    value_deserializer=lambda m: m.decode('utf-8')
)
```

### Node.js 客户端

```javascript
const kafka = require("kafkajs");

const client = kafka({
  clientId: "my-app",
  brokers: ["localhost:9092"],
});

const producer = client.producer();
const consumer = client.consumer({ groupId: "test-group" });
```

### 命令行工具

```bash
# 生产消息
docker exec -it kafka-broker /opt/kafka/bin/kafka-console-producer.sh \
  --topic my-topic \
  --bootstrap-server localhost:9092

# 消费消息
docker exec -it kafka-broker /opt/kafka/bin/kafka-console-consumer.sh \
  --topic my-topic \
  --bootstrap-server localhost:9092 \
  --from-beginning
```

## 📈 监控和管理

### Kafka UI 功能

访问 http://localhost:8080 可以使用以下功能：

- 📊 **集群概览**: 查看集群状态和指标
- 📝 **主题管理**: 创建、删除、配置主题
- 💬 **消息浏览**: 查看和搜索消息
- 👥 **消费者组**: 监控消费者组状态
- ⚙️ **配置管理**: 查看和修改配置
- 📋 **Schema Registry**: 管理消息模式

### 健康检查端点

```bash
# 检查 Kafka 服务
curl -f http://localhost:9092 || echo "Kafka 不可用"

# 检查 Kafka UI
curl -f http://localhost:8080/actuator/health || echo "UI 不可用"
```

## 🔍 故障排除

### 常见问题

#### 1. 端口占用

```bash
# 检查端口占用
netstat -tulpn | grep -E ':(2181|9092|8080)'

# 或使用 lsof (Linux/Mac)
lsof -i :9092
```

#### 2. 服务启动失败

```bash
# 查看详细日志
./start.sh logs kafka

# 检查容器状态
docker ps -a
```

#### 3. 连接超时

```bash
# 检查网络连接
docker exec kafka-broker nc -zv kafka 9092

# 检查防火墙设置
sudo ufw status
```

#### 4. 内存不足

```bash
# 检查系统资源
free -h
docker stats

# 调整 JVM 内存设置
# 编辑 docker-compose.yaml 中的 KAFKA_HEAP_OPTS
```

### 日志分析

```bash
# 查看 Kafka 启动日志
./start.sh logs kafka | grep -i "started"

# 查看错误日志
./start.sh logs kafka | grep -i "error\|exception"

# 实时监控日志
./start.sh logs -f
```

### 性能调优

```yaml
# 针对开发环境的性能优化
environment:
  # 减少日志刷新频率
  KAFKA_LOG_FLUSH_INTERVAL_MESSAGES: 10000
  KAFKA_LOG_FLUSH_INTERVAL_MS: 1000

  # 调整网络线程
  KAFKA_NUM_NETWORK_THREADS: 3
  KAFKA_NUM_IO_THREADS: 8

  # 优化 JVM 参数
  KAFKA_JVM_PERFORMANCE_OPTS: >-
    -server -XX:+UseG1GC -XX:MaxGCPauseMillis=20
    -XX:InitiatingHeapOccupancyPercent=35
    -XX:+ExplicitGCInvokesConcurrent
    -Djava.awt.headless=true
```

## 🔒 安全注意事项

> ⚠️ **重要提醒**: 此版本仅适用于开发和测试环境

### 开发环境限制

- ❌ 无身份认证
- ❌ 无数据加密
- ❌ 无访问控制
- ❌ 无审计日志

### 生产环境建议

如需生产环境部署，请使用 `kafka/with-sasl` 版本，该版本包含：

- ✅ SASL/SCRAM 认证
- ✅ SSL/TLS 加密
- ✅ ACL 访问控制
- ✅ 审计日志
- ✅ 监控告警

## 📚 参考资料

- [Apache Kafka 官方文档](https://kafka.apache.org/documentation/)
- [Kafka 快速入门指南](https://kafka.apache.org/quickstart)
- [Docker Compose 文档](https://docs.docker.com/compose/)
- [Kafka UI 项目](https://github.com/provectus/kafka-ui)

## 🤝 支持

如遇到问题，请检查：

1. **系统要求**: 确保满足最低系统要求
2. **端口冲突**: 检查必需端口是否被占用
3. **Docker 状态**: 确保 Docker 服务正常运行
4. **日志信息**: 查看详细的错误日志
5. **网络连接**: 检查容器间网络通信

---

**版本信息**: Apache Kafka 3.9.1 | 简单部署版本  
**更新时间**: 2024 年 12 月  
**适用环境**: 开发、测试
