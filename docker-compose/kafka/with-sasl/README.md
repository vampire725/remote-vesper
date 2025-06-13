# Kafka SASL 安全部署版本

> **Apache Kafka 3.9.1 安全部署方案**  
> 适用于生产环境，支持 SASL/SCRAM 认证和 ACL 访问控制

## 📋 概述

这是一个企业级的 Kafka 安全部署方案，专为生产环境设计。该版本实现了完整的身份认证、访问控制和安全管理功能，确保数据传输和存储的安全性。

### 🎯 特性

- 🔐 **SASL/SCRAM 认证**: 基于用户名密码的强认证机制
- 🛡️ **ACL 访问控制**: 细粒度的权限管理
- 👥 **多用户支持**: 支持管理员、生产者、消费者等角色
- 📊 **完整生态**: 包含 Schema Registry 和 Kafka Connect
- 🔍 **安全审计**: 访问日志和安全检查
- 🚀 **高可用**: 生产级配置和监控
- 🔧 **易管理**: 自动化脚本和 Web 界面

### 🏗️ 架构组件

| 组件                | 版本   | 端口      | 认证 | 描述         |
| ------------------- | ------ | --------- | ---- | ------------ |
| **Kafka Broker**    | 3.9.1  | 9092/9093 | SASL | 消息代理服务 |
| **Zookeeper**       | 3.9.1  | 2181      | SASL | 集群协调服务 |
| **Kafka UI**        | latest | 8080      | SASL | Web 管理界面 |
| **Schema Registry** | 7.5.0  | 8081      | SASL | 消息模式管理 |
| **Kafka Connect**   | 7.5.0  | 8083      | SASL | 数据连接器   |

## 🚀 快速开始

### 前置要求

- Docker 20.10+
- Docker Compose 2.0+
- 可用端口: 2181, 9092, 9093, 8080, 8081, 8083
- 系统内存: 至少 8GB
- 存储空间: 至少 10GB

### 环境配置

**1. 设置环境变量**

```bash
# Linux/Mac
./start.sh setup-env

# Windows
start.bat setup-env
```

**2. 编辑密码配置**

编辑生成的 `.env` 文件，修改默认密码：

```bash
# 强密码示例
KAFKA_ADMIN_PASSWORD=K@fka2024!Admin
KAFKA_USER_PASSWORD=Us3r$ecur3P@ss
KAFKA_PRODUCER_PASSWORD=Pr0duc3r#2024
KAFKA_CONSUMER_PASSWORD=C0nsum3r&S@fe
```

### 启动集群

**Linux/Mac:**

```bash
# 赋予执行权限
chmod +x start.sh

# 启动安全集群
./start.sh start
```

**Windows:**

```cmd
# 启动安全集群
start.bat start
```

### 验证部署

启动成功后，您将看到以下访问信息：

```
=== Kafka SASL 安全集群访问信息 ===
Kafka Broker (内部):  kafka:9092
Kafka Broker (外部):  localhost:9093
Zookeeper:           zookeeper:2181
Kafka UI:            http://localhost:8080
Schema Registry:     http://localhost:8081
Kafka Connect:       http://localhost:8083

认证信息:
  协议: SASL_PLAINTEXT
  机制: SCRAM-SHA-256
  管理员: admin / admin-secret
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

### 用户管理

```bash
# 列出所有用户
./start.sh users --list

# 创建新用户
./start.sh users --create myuser mypassword

# 删除用户
./start.sh users --delete myuser

# 修改密码
./start.sh users --change-password myuser newpassword
```

### ACL 权限管理

```bash
# 列出所有ACL规则
./start.sh acl --list

# 添加权限规则
./start.sh acl --add "User:producer" Write "Topic:my-topic"

# 删除权限规则
./start.sh acl --remove "User:producer"
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

### 安全和监控

```bash
# 测试SASL认证
./start.sh test

# 安全配置检查
./start.sh security

# 健康检查
./start.sh health

# 打开管理界面
./start.sh ui

# 清理所有数据
./start.sh clean

# 重置集群
./start.sh reset
```

## 🔐 安全配置

### SASL/SCRAM 认证

#### 认证机制

- **协议**: SASL_PLAINTEXT
- **机制**: SCRAM-SHA-256
- **加密**: 密码哈希存储

#### 默认用户

| 用户名      | 密码              | 角色       | 权限     |
| ----------- | ----------------- | ---------- | -------- |
| `admin`     | `admin-secret`    | 超级管理员 | 所有权限 |
| `kafkauser` | `user-secret`     | 普通用户   | 受限权限 |
| `producer`  | `producer-secret` | 生产者     | 写入权限 |
| `consumer`  | `consumer-secret` | 消费者     | 读取权限 |

### ACL 访问控制

#### 权限模型

- **默认策略**: 拒绝所有访问
- **超级用户**: admin 拥有所有权限
- **细粒度控制**: 基于用户、主题、操作的权限控制

#### 常用权限操作

```bash
# 授予生产者写入权限
./start.sh acl --add "User:producer" Write "Topic:orders"

# 授予消费者读取权限
./start.sh acl --add "User:consumer" Read "Topic:orders"
./start.sh acl --add "User:consumer" Read "Group:order-processors"

# 授予管理员所有权限
./start.sh acl --add "User:admin" All "Topic:*"
```

### 密码安全

#### 密码要求

- 最少 8 个字符
- 包含大小写字母
- 包含数字和特殊字符
- 避免使用常见密码

#### 密码管理

```bash
# 生成强密码
openssl rand -base64 16 | tr -d '=+/' | cut -c1-12

# 修改用户密码
./start.sh users --change-password username newpassword

# 定期轮换密码（建议每90天）
```

## 🔧 客户端连接

### Java 客户端

```java
Properties props = new Properties();
props.put("bootstrap.servers", "localhost:9093");
props.put("security.protocol", "SASL_PLAINTEXT");
props.put("sasl.mechanism", "SCRAM-SHA-256");
props.put("sasl.jaas.config",
    "org.apache.kafka.common.security.scram.ScramLoginModule required " +
    "username=\"producer\" " +
    "password=\"producer-secret\";");

// 序列化器配置
props.put("key.serializer", "org.apache.kafka.common.serialization.StringSerializer");
props.put("value.serializer", "org.apache.kafka.common.serialization.StringSerializer");

Producer<String, String> producer = new KafkaProducer<>(props);
```

### Python 客户端

```python
from kafka import KafkaProducer, KafkaConsumer

# 生产者配置
producer = KafkaProducer(
    bootstrap_servers=['localhost:9093'],
    security_protocol='SASL_PLAINTEXT',
    sasl_mechanism='SCRAM-SHA-256',
    sasl_plain_username='producer',
    sasl_plain_password='producer-secret',
    value_serializer=lambda x: x.encode('utf-8')
)

# 消费者配置
consumer = KafkaConsumer(
    'my-topic',
    bootstrap_servers=['localhost:9093'],
    security_protocol='SASL_PLAINTEXT',
    sasl_mechanism='SCRAM-SHA-256',
    sasl_plain_username='consumer',
    sasl_plain_password='consumer-secret',
    group_id='my-group',
    value_deserializer=lambda m: m.decode('utf-8')
)
```

### Node.js 客户端

```javascript
const kafka = require("kafkajs");

const client = kafka({
  clientId: "my-app",
  brokers: ["localhost:9093"],
  sasl: {
    mechanism: "scram-sha-256",
    username: "producer",
    password: "producer-secret",
  },
});

const producer = client.producer();
const consumer = client.consumer({ groupId: "my-group" });
```

### 命令行工具

```bash
# 创建客户端配置文件
cat > client.properties << EOF
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-256
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="producer" password="producer-secret";
EOF

# 生产消息
docker exec -it kafka-broker-sasl /opt/kafka/bin/kafka-console-producer.sh \
  --topic my-topic \
  --bootstrap-server localhost:9092 \
  --producer.config /path/to/client.properties

# 消费消息
docker exec -it kafka-broker-sasl /opt/kafka/bin/kafka-console-consumer.sh \
  --topic my-topic \
  --bootstrap-server localhost:9092 \
  --consumer.config /path/to/client.properties \
  --from-beginning
```

## 📈 监控和管理

### Kafka UI 功能

访问 http://localhost:8080 可以使用以下功能：

- 📊 **集群监控**: 实时查看集群状态和性能指标
- 📝 **主题管理**: 创建、删除、配置主题
- 💬 **消息浏览**: 查看和搜索消息内容
- 👥 **消费者组**: 监控消费者组状态和延迟
- ⚙️ **配置管理**: 查看和修改集群配置
- 🔐 **安全管理**: 查看用户和权限信息
- 📋 **Schema 管理**: 管理 Avro/JSON 模式

### Schema Registry

访问 http://localhost:8081 进行模式管理：

```bash
# 注册新模式
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data '{"schema":"{\"type\":\"record\",\"name\":\"User\",\"fields\":[{\"name\":\"name\",\"type\":\"string\"}]}"}' \
  http://localhost:8081/subjects/user-value/versions

# 获取模式列表
curl http://localhost:8081/subjects

# 获取特定模式
curl http://localhost:8081/subjects/user-value/versions/latest
```

### Kafka Connect

访问 http://localhost:8083 管理连接器：

```bash
# 查看连接器状态
curl http://localhost:8083/connectors

# 创建连接器
curl -X POST -H "Content-Type: application/json" \
  --data '{"name":"my-connector","config":{"connector.class":"..."}}' \
  http://localhost:8083/connectors

# 查看连接器配置
curl http://localhost:8083/connectors/my-connector/config
```

## 🔍 故障排除

### 常见问题

#### 1. 认证失败

```bash
# 检查用户是否存在
./start.sh users --list

# 检查密码是否正确
./start.sh test

# 查看认证日志
./start.sh logs kafka | grep -i "authentication\|sasl"
```

#### 2. 权限不足

```bash
# 检查ACL规则
./start.sh acl --list

# 添加必要权限
./start.sh acl --add "User:myuser" Read "Topic:mytopic"

# 查看权限日志
./start.sh logs kafka | grep -i "authorization\|acl"
```

#### 3. 连接超时

```bash
# 检查网络连接
docker exec kafka-broker-sasl nc -zv kafka 9092

# 检查SASL配置
docker exec kafka-broker-sasl cat /opt/kafka/config/sasl/client.properties

# 检查防火墙设置
sudo ufw status
```

#### 4. 服务启动失败

```bash
# 查看详细日志
./start.sh logs kafka

# 检查容器状态
docker ps -a

# 检查资源使用
docker stats
```

### 日志分析

```bash
# 查看认证日志
./start.sh logs kafka | grep -i "sasl\|scram\|authentication"

# 查看授权日志
./start.sh logs kafka | grep -i "acl\|authorization"

# 查看错误日志
./start.sh logs kafka | grep -i "error\|exception\|failed"

# 实时监控日志
./start.sh logs -f
```

### 性能调优

```yaml
# 生产环境性能优化
environment:
  # 增加内存分配
  KAFKA_HEAP_OPTS: "-Xmx4G -Xms4G"

  # 优化网络配置
  KAFKA_NUM_NETWORK_THREADS: 8
  KAFKA_NUM_IO_THREADS: 16

  # 优化日志配置
  KAFKA_LOG_FLUSH_INTERVAL_MESSAGES: 10000
  KAFKA_LOG_FLUSH_INTERVAL_MS: 1000

  # 优化副本配置
  KAFKA_REPLICA_FETCH_MAX_BYTES: 1048576
  KAFKA_MESSAGE_MAX_BYTES: 1000000
```

## 🔒 安全最佳实践

### 密码管理

1. **使用强密码**

   - 至少 12 个字符
   - 包含大小写字母、数字、特殊字符
   - 避免使用字典词汇

2. **定期轮换密码**

   - 建议每 90 天更换一次
   - 使用密码管理工具
   - 记录密码变更历史

3. **安全存储**
   - 使用环境变量或密钥管理系统
   - 避免在代码中硬编码密码
   - 限制配置文件访问权限

### 网络安全

1. **网络隔离**

   - 使用专用网络
   - 配置防火墙规则
   - 限制外部访问

2. **端口管理**

   - 只开放必要端口
   - 使用非标准端口
   - 配置端口转发

3. **SSL/TLS 加密**
   - 在生产环境启用 SSL
   - 使用有效的 SSL 证书
   - 配置强加密算法

### 访问控制

1. **最小权限原则**

   - 只授予必要权限
   - 定期审查权限
   - 及时回收不需要的权限

2. **角色分离**

   - 区分管理员和普通用户
   - 分离生产者和消费者权限
   - 使用专用服务账户

3. **审计日志**
   - 启用访问日志
   - 监控异常访问
   - 定期分析日志

### 监控告警

1. **关键指标监控**

   - 认证失败次数
   - 权限拒绝次数
   - 异常连接尝试

2. **告警配置**

   - 设置阈值告警
   - 配置通知渠道
   - 建立响应流程

3. **日志管理**
   - 集中化日志收集
   - 长期日志保存
   - 日志完整性保护

## 📚 参考资料

- [Apache Kafka 安全文档](https://kafka.apache.org/documentation/#security)
- [SASL/SCRAM 认证指南](https://kafka.apache.org/documentation/#security_sasl_scram)
- [ACL 权限管理](https://kafka.apache.org/documentation/#security_authz)
- [Schema Registry 文档](https://docs.confluent.io/platform/current/schema-registry/)
- [Kafka Connect 文档](https://kafka.apache.org/documentation/#connect)

## 🤝 支持

如遇到问题，请检查：

1. **环境配置**: 确保环境变量正确设置
2. **密码配置**: 检查用户密码是否正确
3. **权限设置**: 验证 ACL 规则是否正确
4. **网络连接**: 确保服务间网络通信正常
5. **日志信息**: 查看详细的错误日志

### 紧急联系

- **安全事件**: 立即检查访问日志和用户活动
- **性能问题**: 监控资源使用和网络延迟
- **数据丢失**: 检查副本状态和备份情况

---

**版本信息**: Apache Kafka 3.9.1 | SASL 安全部署版本  
**更新时间**: 2024 年 12 月  
**适用环境**: 生产、预生产  
**安全等级**: 企业级
