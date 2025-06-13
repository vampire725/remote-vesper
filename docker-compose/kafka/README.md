# Apache Kafka 部署方案

> **Apache Kafka 3.9.1 完整部署解决方案**  
> 提供从开发到生产的全套部署方案

## 📋 概述

本项目提供了两个完整的 Apache Kafka 部署方案，分别针对不同的使用场景和安全要求。每个方案都经过精心设计，确保在各自的使用环境中提供最佳的性能和安全性。

## 🎯 部署方案对比

| 特性           | Simple 版本 | SASL 版本          |
| -------------- | ----------- | ------------------ |
| **适用环境**   | 开发、测试  | 生产、预生产       |
| **安全等级**   | 基础        | 企业级             |
| **认证机制**   | 无          | SASL/SCRAM-SHA-256 |
| **访问控制**   | 无          | ACL 权限控制       |
| **用户管理**   | 无          | 多用户支持         |
| **加密传输**   | 明文        | 支持 SSL/TLS       |
| **部署复杂度** | 简单        | 中等               |
| **资源要求**   | 4GB 内存    | 8GB 内存           |
| **启动时间**   | 快速        | 中等               |
| **管理难度**   | 低          | 中等               |

## 📁 目录结构

```
kafka/
├── simple/                 # 简单部署版本
│   ├── docker-compose.yaml # Docker Compose配置
│   ├── start.sh            # Linux/Mac启动脚本
│   ├── start.bat           # Windows启动脚本
│   └── README.md           # 详细说明文档
├── with-sasl/              # SASL安全版本
│   ├── docker-compose.yaml # Docker Compose配置
│   ├── env-template.txt    # 环境变量模板
│   ├── start.sh            # Linux/Mac启动脚本
│   ├── start.bat           # Windows启动脚本
│   └── README.md           # 详细说明文档
├── dev/                    # 开发环境(已存在)
├── prod/                   # 生产环境(已存在)
└── README.md               # 本文件
```

## 🚀 快速选择指南

### 选择 Simple 版本，如果您：

- ✅ 正在进行开发或测试
- ✅ 需要快速启动 Kafka 集群
- ✅ 不需要复杂的安全配置
- ✅ 在本地或内网环境使用
- ✅ 希望简化配置和管理

**快速启动：**

```bash
cd kafka/simple
./start.sh start
```

### 选择 SASL 版本，如果您：

- ✅ 部署到生产环境
- ✅ 需要用户认证和权限控制
- ✅ 要求企业级安全标准
- ✅ 需要多用户访问管理
- ✅ 符合合规性要求

**快速启动：**

```bash
cd kafka/with-sasl
./start.sh setup-env  # 首次运行
./start.sh start
```

## 🔧 功能特性对比

### Simple 版本特性

- 🚀 **一键启动**: 无需复杂配置，立即可用
- 🎯 **开发友好**: 自动创建主题，便于开发测试
- 📊 **管理界面**: 内置 Kafka UI 管理界面
- 🔍 **健康检查**: 自动服务健康监控
- 🌐 **跨平台**: 支持 Linux/Mac 和 Windows
- ⚡ **轻量级**: 资源占用少，启动快速

### SASL 版本特性

- 🔐 **SASL 认证**: SCRAM-SHA-256 强认证机制
- 🛡️ **ACL 控制**: 细粒度权限管理
- 👥 **多用户**: 支持管理员、生产者、消费者角色
- 📋 **Schema Registry**: 消息模式管理
- 🔗 **Kafka Connect**: 数据连接器支持
- 🔍 **安全审计**: 访问日志和安全检查
- 📈 **企业级**: 生产环境优化配置

## 📊 服务组件对比

### Simple 版本组件

| 服务         | 端口 | 描述         |
| ------------ | ---- | ------------ |
| Kafka Broker | 9092 | 消息代理服务 |
| Zookeeper    | 2181 | 集群协调服务 |
| Kafka UI     | 8080 | Web 管理界面 |

### SASL 版本组件

| 服务            | 端口      | 描述                    |
| --------------- | --------- | ----------------------- |
| Kafka Broker    | 9092/9093 | 消息代理服务(内部/外部) |
| Zookeeper       | 2181      | 集群协调服务            |
| Kafka UI        | 8080      | Web 管理界面            |
| Schema Registry | 8081      | 消息模式管理            |
| Kafka Connect   | 8083      | 数据连接器              |

## 🛠️ 管理命令对比

### 通用命令

两个版本都支持以下基础命令：

```bash
# 启动集群
./start.sh start

# 查看状态
./start.sh status

# 停止集群
./start.sh stop

# 查看日志
./start.sh logs

# 健康检查
./start.sh health

# 打开UI界面
./start.sh ui
```

### SASL 版本额外命令

```bash
# 环境配置
./start.sh setup-env

# 用户管理
./start.sh users --list
./start.sh users --create username password

# 权限管理
./start.sh acl --list
./start.sh acl --add "User:producer" Write "Topic:my-topic"

# 安全检查
./start.sh security
```

## 🔒 安全性对比

### Simple 版本安全特性

- ❌ 无身份认证
- ❌ 无访问控制
- ❌ 无数据加密
- ❌ 无审计日志
- ⚠️ **仅适用于开发环境**

### SASL 版本安全特性

- ✅ SASL/SCRAM-SHA-256 认证
- ✅ ACL 访问控制
- ✅ 多用户权限管理
- ✅ 密码安全存储
- ✅ 访问审计日志
- ✅ 支持 SSL/TLS 加密
- ✅ **适用于生产环境**

## 📈 性能和资源

### Simple 版本

- **内存要求**: 4GB
- **CPU 要求**: 2 核心
- **存储要求**: 5GB
- **启动时间**: 30-60 秒
- **并发连接**: 适中
- **吞吐量**: 开发级别

### SASL 版本

- **内存要求**: 8GB
- **CPU 要求**: 4 核心
- **存储要求**: 10GB
- **启动时间**: 60-120 秒
- **并发连接**: 高
- **吞吐量**: 生产级别

## 🔄 迁移指南

### 从 Simple 到 SASL

1. **备份数据**

   ```bash
   cd kafka/simple
   ./start.sh stop
   # 备份重要主题数据
   ```

2. **配置 SASL 环境**

   ```bash
   cd kafka/with-sasl
   ./start.sh setup-env
   # 编辑.env文件设置密码
   ```

3. **启动 SASL 集群**

   ```bash
   ./start.sh start
   ```

4. **创建用户和权限**

   ```bash
   ./start.sh users --create myuser mypassword
   ./start.sh acl --add "User:myuser" All "Topic:*"
   ```

5. **更新客户端配置**
   - 添加 SASL 认证配置
   - 更新连接参数
   - 测试连接

### 从 SASL 到 Simple (不推荐)

⚠️ **警告**: 从安全版本降级到简单版本会失去所有安全保护，不建议在生产环境中执行。

## 🔧 客户端配置示例

### Simple 版本客户端

```java
// Java客户端
Properties props = new Properties();
props.put("bootstrap.servers", "localhost:9092");
props.put("key.serializer", "org.apache.kafka.common.serialization.StringSerializer");
props.put("value.serializer", "org.apache.kafka.common.serialization.StringSerializer");
```

### SASL 版本客户端

```java
// Java客户端
Properties props = new Properties();
props.put("bootstrap.servers", "localhost:9093");
props.put("security.protocol", "SASL_PLAINTEXT");
props.put("sasl.mechanism", "SCRAM-SHA-256");
props.put("sasl.jaas.config",
    "org.apache.kafka.common.security.scram.ScramLoginModule required " +
    "username=\"producer\" password=\"producer-secret\";");
```

## 🔍 故障排除

### 通用问题

1. **端口冲突**

   ```bash
   # 检查端口占用
   netstat -tulpn | grep -E ':(2181|9092|8080)'
   ```

2. **Docker 问题**

   ```bash
   # 检查Docker状态
   docker info
   docker-compose version
   ```

3. **资源不足**
   ```bash
   # 检查系统资源
   free -h
   df -h
   ```

### Simple 版本特有问题

- 主题自动创建失败
- UI 界面无法访问
- 连接超时

### SASL 版本特有问题

- 认证失败
- 权限不足
- 用户创建失败
- 密码错误

## 📚 相关文档

- [Simple 版本详细文档](./simple/README.md)
- [SASL 版本详细文档](./with-sasl/README.md)
- [Apache Kafka 官方文档](https://kafka.apache.org/documentation/)
- [Docker Compose 文档](https://docs.docker.com/compose/)

## 🤝 支持和贡献

### 获取帮助

1. 查看相应版本的 README 文档
2. 检查日志文件排查问题
3. 参考官方文档
4. 在 GitHub 上提交 Issue

### 贡献代码

1. Fork 本项目
2. 创建功能分支
3. 提交更改
4. 发起 Pull Request

## 📝 更新日志

### v1.0.0 (2024-12)

- ✅ 发布 Simple 简单部署版本
- ✅ 发布 SASL 安全部署版本
- ✅ 支持 Apache Kafka 3.9.1
- ✅ 提供跨平台启动脚本
- ✅ 完整的文档和示例

---

**版本信息**: Apache Kafka 3.9.1  
**更新时间**: 2024 年 12 月  
**维护状态**: 积极维护  
**许可证**: Apache License 2.0
