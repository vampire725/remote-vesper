# Logstash 部署方案

本目录包含两个不同的 Logstash 部署方案，分别适用于不同的使用场景和安全要求。

## 📁 目录结构

```
logstash/
├── simple/              # 简单部署版本
│   ├── docker-compose.yaml
│   ├── config/
│   │   └── logstash.yml
│   ├── pipeline/
│   │   └── main.conf
│   ├── start.sh
│   ├── start.bat
│   └── README.md
├── with-auth/           # 企业级认证版本
│   ├── docker-compose.yaml
│   ├── config/
│   │   └── logstash.yml
│   ├── pipeline/
│   │   └── main.conf
│   ├── certs/           # SSL证书目录
│   ├── env-template.txt
│   ├── start.sh
│   ├── start.bat
│   └── README.md
└── README.md           # 本文件
```

## 🚀 部署版本对比

### Simple 版本 - 开发测试环境

**适用场景:**

- 开发和测试环境
- 快速原型验证
- 学习和实验
- 内网环境部署

**特性:**

- ✅ 快速启动，无需复杂配置
- ✅ 支持多种输入源（Beats、TCP、UDP、HTTP）
- ✅ 基础的日志处理和过滤
- ✅ 输出到外部 Elasticsearch
- ❌ 无 SSL/TLS 加密
- ❌ 无用户认证
- ❌ 无高级安全功能

**资源要求:**

- 内存: 2GB+
- CPU: 1 核心+
- 存储: 10GB+

### With-Auth 版本 - 企业级生产环境

**适用场景:**

- 生产环境部署
- 企业级应用
- 安全合规要求
- 多租户环境

**特性:**

- ✅ 完整的 SSL/TLS 加密
- ✅ 用户认证和授权
- ✅ X-Pack 监控集成
- ✅ 安全事件检测
- ✅ 审计日志记录
- ✅ 证书自动管理
- ✅ 高级过滤和处理
- ✅ 内置完整 ELK 栈

**资源要求:**

- 内存: 8GB+
- CPU: 2 核心+
- 存储: 50GB+

## 📊 功能对比表

| 功能               | Simple 版本 | With-Auth 版本 |
| ------------------ | ----------- | -------------- |
| **基础功能**       |
| Beats 输入         | ✅          | ✅             |
| TCP/UDP 输入       | ✅          | ✅             |
| HTTP 输入          | ✅          | ✅             |
| JSON 解析          | ✅          | ✅             |
| Grok 解析          | ✅          | ✅             |
| Elasticsearch 输出 | ✅          | ✅             |
| **安全功能**       |
| SSL/TLS 加密       | ❌          | ✅             |
| 用户认证           | ❌          | ✅             |
| 证书管理           | ❌          | ✅             |
| 客户端认证         | ❌          | ✅             |
| **监控功能**       |
| 基础监控           | ✅          | ✅             |
| X-Pack 监控        | ❌          | ✅             |
| 性能指标           | ✅          | ✅             |
| 健康检查           | ✅          | ✅             |
| **高级功能**       |
| 地理位置解析       | ✅          | ✅             |
| 用户代理解析       | ✅          | ✅             |
| 安全事件检测       | ❌          | ✅             |
| 数据脱敏           | ❌          | ✅             |
| 多管道支持         | ❌          | ✅             |
| 持久化队列         | ❌          | ✅             |
| **集成服务**       |
| Elasticsearch      | 外部        | 内置           |
| Kibana             | 外部        | 内置           |
| 证书服务           | ❌          | 内置           |

## 🛠️ 快速开始

### 选择部署版本

**如果您需要:**

- 快速测试和开发 → 选择 `simple` 版本
- 生产环境部署 → 选择 `with-auth` 版本
- 安全合规要求 → 选择 `with-auth` 版本
- 学习和实验 → 选择 `simple` 版本

### 部署步骤

#### Simple 版本部署

```bash
# 进入 simple 目录
cd simple/

# Linux/macOS
chmod +x start.sh
./start.sh start

# Windows
start.bat start
```

#### With-Auth 版本部署

```bash
# 进入 with-auth 目录
cd with-auth/

# 配置环境变量
cp env-template.txt .env
nano .env  # 设置密码

# Linux/macOS
chmod +x start.sh
./start.sh start

# Windows
start.bat start
```

## 🔧 配置说明

### 端口使用

| 端口 | Simple 版本  | With-Auth 版本 | 说明           |
| ---- | ------------ | -------------- | -------------- |
| 5044 | Beats (HTTP) | Beats (SSL)    | Beats 输入端口 |
| 9600 | API (HTTP)   | API (HTTPS)    | Logstash API   |
| 5000 | TCP          | TCP (SSL)      | TCP 输入       |
| 5001 | UDP          | UDP            | UDP 输入       |
| 8080 | HTTP         | HTTPS          | HTTP 输入      |
| 9200 | -            | HTTPS          | Elasticsearch  |
| 5601 | -            | HTTPS          | Kibana         |

### 网络配置

**Simple 版本:**

- 使用外部 `logging-network` 网络
- 需要外部 Elasticsearch 服务
- 轻量级部署，资源占用少

**With-Auth 版本:**

- 使用内部 `elastic-auth-network` 网络
- 包含完整的 ELK 栈
- 自动生成和管理 SSL 证书

## 📈 性能调优

### Simple 版本优化

```yaml
# 调整 JVM 内存
environment:
  - LS_JAVA_OPTS=-Xmx1g -Xms1g

# 调整管道配置
pipeline.workers: 2
pipeline.batch.size: 125
```

### With-Auth 版本优化

```yaml
# 调整 JVM 内存
environment:
  - LS_JAVA_OPTS=-Xmx4g -Xms4g
  - ES_JAVA_OPTS=-Xmx2g -Xms2g

# 调整管道配置
pipeline.workers: 8
pipeline.batch.size: 500
queue.max_bytes: 4gb
```

## 🔄 版本迁移

### 从 Simple 迁移到 With-Auth

1. **备份配置**

   ```bash
   # 备份 simple 版本配置
   cp -r simple/pipeline/ with-auth/pipeline_backup/
   ```

2. **配置认证**

   ```bash
   cd with-auth/
   cp env-template.txt .env
   # 编辑 .env 设置密码
   ```

3. **启动新版本**
   ```bash
   ./start.sh start
   ```

### 从 With-Auth 降级到 Simple

1. **导出数据**

   ```bash
   # 从 Elasticsearch 导出数据
   curl -X GET "localhost:9200/_search" > data_backup.json
   ```

2. **提取管道配置**

   ```bash
   # 复制管道配置（移除 SSL 相关配置）
   cp with-auth/pipeline/main.conf simple/pipeline/
   ```

3. **启动 Simple 版本**
   ```bash
   cd simple/
   ./start.sh start
   ```

## 🚨 故障排除

### 常见问题

1. **端口冲突**

   ```bash
   # 检查端口占用
   netstat -tulpn | grep :5044

   # 修改端口映射
   # 编辑 docker-compose.yaml
   ```

2. **内存不足**

   ```bash
   # 调整内存限制
   # 编辑 docker-compose.yaml 中的 JVM 参数
   ```

3. **网络连接问题**

   ```bash
   # 检查网络
   docker network ls
   docker network inspect logging-network
   ```

4. **SSL 证书问题** (仅 With-Auth)
   ```bash
   # 重新生成证书
   cd with-auth/
   ./start.sh certs
   ```

### 日志分析

```bash
# Simple 版本
cd simple/
./start.sh logs

# With-Auth 版本
cd with-auth/
./start.sh logs logstash
./start.sh logs elasticsearch
```

## 📚 相关文档

- [Simple 版本详细文档](simple/README.md)
- [With-Auth 版本详细文档](with-auth/README.md)
- [Logstash 官方文档](https://www.elastic.co/guide/en/logstash/current/index.html)
- [Elasticsearch 文档](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [Kibana 文档](https://www.elastic.co/guide/en/kibana/current/index.html)

## 🤝 最佳实践

### 开发环境

1. 使用 Simple 版本进行快速开发
2. 定期备份配置文件
3. 使用版本控制管理配置
4. 监控资源使用情况

### 生产环境

1. 使用 With-Auth 版本确保安全
2. 定期更新镜像版本
3. 实施完整的备份策略
4. 配置监控和告警
5. 定期进行安全审计
6. 遵循最小权限原则

### 迁移建议

1. 在测试环境验证配置
2. 制定详细的迁移计划
3. 准备回滚方案
4. 进行充分的测试
5. 监控迁移后的性能

## ⚠️ 注意事项

1. **版本选择**: 根据实际需求选择合适的版本
2. **资源规划**: 确保有足够的系统资源
3. **安全考虑**: 生产环境必须使用 With-Auth 版本
4. **备份策略**: 定期备份数据和配置
5. **监控告警**: 配置适当的监控机制
6. **文档维护**: 保持部署文档的更新

## 🔍 版本特点总结

### Simple 版本

- **优点**: 部署简单、资源占用少、适合开发测试
- **缺点**: 无安全功能、不适合生产环境
- **推荐场景**: 开发、测试、学习、内网环境

### With-Auth 版本

- **优点**: 安全完整、功能丰富、适合生产环境
- **缺点**: 配置复杂、资源占用多
- **推荐场景**: 生产环境、企业应用、安全合规

选择适合您需求的版本，并参考相应的详细文档进行部署和配置。
