# Elasticsearch SSL 安全部署环境

## 概述

这是一个完整的 Elasticsearch SSL 安全部署配置，专为生产环境和安全要求较高的场景设计。该配置启用了完整的 SSL 加密、用户认证和自动证书管理。

## 🔒 安全特性

- ✅ **完整 SSL 加密** - HTTP 和传输层全面加密
- ✅ **用户认证保护** - 基于用户名密码的访问控制
- ✅ **自动证书生成** - 自动创建和管理 SSL 证书
- ✅ **证书验证** - 启用完整的证书验证机制
- ✅ **生产级配置** - 适合生产环境的安全配置
- ✅ **Kibana 集成** - 包含安全配置的 Kibana 服务

## 快速开始

### 1. 环境准备

```bash
# 进入 with-ssl 目录
cd es/with-ssl

# 创建环境变量文件
cp env-template.txt .env

# 编辑 .env 文件，设置强密码
# ELASTIC_PASSWORD=你的强密码
# KIBANA_PASSWORD=你的Kibana密码
```

### 2. 启动服务

```bash
# Linux/Mac 用户
./start.sh

# Windows 用户
start.bat

# 或者直接使用 Docker Compose
docker-compose up -d
```

### 3. 验证部署

```bash
# 检查服务状态
./start.sh --status

# 测试SSL连接
./start.sh --test

# 获取CA证书用于客户端连接
docker-compose exec es01 cat /usr/share/elasticsearch/config/certs/ca/ca.crt > ca.crt
```

### 4. 访问服务

- **Elasticsearch HTTPS API**: https://localhost:9200
- **Kibana HTTPS 界面**: https://localhost:5601
- **用户名**: elastic
- **密码**: 在 .env 文件中设置的密码

## 🔧 配置说明

### 核心安全配置

| 配置项                                 | 值            | 说明           |
| -------------------------------------- | ------------- | -------------- |
| `xpack.security.enabled`               | `true`        | 启用安全功能   |
| `xpack.security.http.ssl.enabled`      | `true`        | 启用 HTTP SSL  |
| `xpack.security.transport.ssl.enabled` | `true`        | 启用传输层 SSL |
| `bootstrap.memory_lock`                | `true`        | 启用内存锁定   |
| `discovery.type`                       | `single-node` | 单节点模式     |

### SSL 证书配置

| 证书类型    | 路径                      | 用途               |
| ----------- | ------------------------- | ------------------ |
| CA 证书     | `certs/ca/ca.crt`         | 证书颁发机构       |
| 节点证书    | `certs/es01/es01.crt`     | Elasticsearch 节点 |
| 节点私钥    | `certs/es01/es01.key`     | Elasticsearch 私钥 |
| Kibana 证书 | `certs/kibana/kibana.crt` | Kibana 服务        |

### 资源配置

| 配置项     | 值  | 说明            |
| ---------- | --- | --------------- |
| JVM 堆内存 | 2GB | 生产环境配置    |
| 内存限制   | 4GB | Docker 容器限制 |
| 内存预留   | 2GB | Docker 容器预留 |

## 🚀 脚本使用说明

### 基本命令

```bash
# 启动服务
./start.sh

# 显示帮助
./start.sh --help

# 查看服务状态
./start.sh --status

# 查看服务日志
./start.sh --logs

# 测试SSL连接
./start.sh --test
```

### 高级命令

```bash
# 仅生成证书
./start.sh --setup

# 停止服务
./start.sh --stop

# 重启服务
./start.sh --restart

# 清理数据并重启
./start.sh --clean

# 重新生成证书
./start.sh --reset-certs
```

## 🔐 安全连接示例

### 获取 CA 证书

```bash
# 导出CA证书到本地文件
docker-compose exec es01 cat /usr/share/elasticsearch/config/certs/ca/ca.crt > ca.crt
```

### 使用 curl 访问 API

```bash
# 查看集群健康状态
curl --cacert ca.crt -u elastic:YOUR_PASSWORD \
  https://localhost:9200/_cluster/health?pretty

# 查看节点信息
curl --cacert ca.crt -u elastic:YOUR_PASSWORD \
  https://localhost:9200/_nodes?pretty

# 查看所有索引
curl --cacert ca.crt -u elastic:YOUR_PASSWORD \
  https://localhost:9200/_cat/indices?v

# 用户认证信息
curl --cacert ca.crt -u elastic:YOUR_PASSWORD \
  https://localhost:9200/_security/_authenticate?pretty
```

### 索引操作示例

```bash
# 创建索引
curl --cacert ca.crt -u elastic:YOUR_PASSWORD \
  -X PUT https://localhost:9200/secure-index

# 添加文档
curl --cacert ca.crt -u elastic:YOUR_PASSWORD \
  -X POST https://localhost:9200/secure-index/_doc/1 \
  -H "Content-Type: application/json" \
  -d '{"title": "安全文档", "content": "这是一个加密传输的文档"}'

# 搜索文档
curl --cacert ca.crt -u elastic:YOUR_PASSWORD \
  -X GET https://localhost:9200/secure-index/_search?pretty \
  -H "Content-Type: application/json" \
  -d '{"query": {"match_all": {}}}'
```

## 🔧 客户端配置

### Java 客户端配置

```java
// 使用SSL连接Elasticsearch
RestHighLevelClient client = new RestHighLevelClient(
    RestClient.builder(new HttpHost("localhost", 9200, "https"))
        .setHttpClientConfigCallback(httpClientBuilder -> {
            return httpClientBuilder
                .setSSLContext(sslContext)
                .setDefaultCredentialsProvider(credentialsProvider);
        })
);
```

### Python 客户端配置

```python
from elasticsearch import Elasticsearch

# 使用SSL连接
es = Elasticsearch(
    ['https://localhost:9200'],
    http_auth=('elastic', 'your_password'),
    ca_certs='ca.crt',
    verify_certs=True
)
```

### Node.js 客户端配置

```javascript
const { Client } = require("@elastic/elasticsearch");

const client = new Client({
  node: "https://localhost:9200",
  auth: {
    username: "elastic",
    password: "your_password",
  },
  tls: {
    ca: fs.readFileSync("ca.crt"),
    rejectUnauthorized: true,
  },
});
```

## 🛠️ 故障排除

### 常见问题

#### 1. 证书生成失败

**症状**: setup 容器启动失败

**解决方案**:

```bash
# 检查环境变量
cat .env

# 重新生成证书
./start.sh --reset-certs

# 查看详细日志
docker-compose logs setup
```

#### 2. SSL 连接失败

**症状**: curl 连接被拒绝

**解决方案**:

```bash
# 检查证书是否存在
docker-compose exec es01 ls -la /usr/share/elasticsearch/config/certs/

# 验证服务状态
./start.sh --status

# 重新导出CA证书
docker-compose exec es01 cat /usr/share/elasticsearch/config/certs/ca/ca.crt > ca.crt
```

#### 3. 认证失败

**症状**: 401 Unauthorized 错误

**解决方案**:

```bash
# 检查密码设置
cat .env

# 重置elastic用户密码
docker-compose exec es01 bin/elasticsearch-reset-password -u elastic

# 验证用户认证
curl --cacert ca.crt -u elastic:NEW_PASSWORD \
  https://localhost:9200/_security/_authenticate
```

#### 4. 内存不足

**症状**: 容器因内存不足被杀死

**解决方案**:

```bash
# 修改JVM堆内存（在docker-compose.yaml中）
- "ES_JAVA_OPTS=-Xms1g -Xmx1g"  # 减少内存使用

# 或者增加系统内存
```

#### 5. 端口冲突

**症状**: 端口 9200 或 5601 被占用

**解决方案**:

```bash
# 检查端口占用
netstat -tlnp | grep 9200
netstat -tlnp | grep 5601

# 修改端口映射（在docker-compose.yaml中）
ports:
  - "9201:9200"  # 使用不同端口
```

### 性能优化

#### 1. 内存优化

```bash
# 根据系统内存调整JVM堆内存
# 建议设置为系统内存的25-50%
# 在docker-compose.yaml中修改:
- "ES_JAVA_OPTS=-Xms4g -Xmx4g"  # 8GB系统内存
```

#### 2. 磁盘优化

```bash
# 使用SSD存储
# 确保有足够的磁盘空间（至少20GB）
df -h

# 配置数据卷到高性能存储
volumes:
  es-data01:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /path/to/fast/storage
```

## 🔒 安全最佳实践

### 密码管理

1. **使用强密码**

   - 长度至少 12 位
   - 包含大小写字母、数字和特殊字符
   - 避免使用常见密码或个人信息

2. **定期更换密码**

   ```bash
   # 更改elastic用户密码
   docker-compose exec es01 bin/elasticsearch-reset-password -u elastic
   ```

3. **密码存储**
   - 将.env 文件添加到.gitignore
   - 使用密码管理器存储密码
   - 限制.env 文件的访问权限

### 网络安全

1. **防火墙配置**

   ```bash
   # 仅允许必要的端口访问
   ufw allow from 192.168.1.0/24 to any port 9200
   ufw allow from 192.168.1.0/24 to any port 5601
   ```

2. **反向代理**
   - 使用 Nginx 或 Apache 作为反向代理
   - 配置额外的 SSL 终止
   - 实现访问控制和速率限制

### 证书管理

1. **证书轮换**

   ```bash
   # 定期重新生成证书
   ./start.sh --reset-certs
   ```

2. **证书备份**
   ```bash
   # 备份证书数据卷
   docker run --rm -v es-with-ssl_certs:/data -v $(pwd):/backup \
     alpine tar czf /backup/certs-backup.tar.gz -C /data .
   ```

## 📊 监控和日志

### 日志管理

```bash
# 实时查看日志
./start.sh --logs

# 查看特定服务日志
docker-compose logs es01
docker-compose logs kibana

# 查看最近的错误日志
docker-compose logs --tail=100 es01 | grep ERROR
```

### 监控指标

```bash
# 集群健康监控
curl --cacert ca.crt -u elastic:PASSWORD \
  https://localhost:9200/_cluster/health?pretty

# 节点统计信息
curl --cacert ca.crt -u elastic:PASSWORD \
  https://localhost:9200/_nodes/stats?pretty

# 索引统计信息
curl --cacert ca.crt -u elastic:PASSWORD \
  https://localhost:9200/_stats?pretty
```

## 🔄 备份和恢复

### 数据备份

```bash
# 创建快照仓库
curl --cacert ca.crt -u elastic:PASSWORD \
  -X PUT https://localhost:9200/_snapshot/backup_repo \
  -H "Content-Type: application/json" \
  -d '{
    "type": "fs",
    "settings": {
      "location": "/usr/share/elasticsearch/backup"
    }
  }'

# 创建快照
curl --cacert ca.crt -u elastic:PASSWORD \
  -X PUT https://localhost:9200/_snapshot/backup_repo/snapshot_1
```

### 数据恢复

```bash
# 恢复快照
curl --cacert ca.crt -u elastic:PASSWORD \
  -X POST https://localhost:9200/_snapshot/backup_repo/snapshot_1/_restore
```

## 📋 版本信息

- **Elasticsearch**: 8.15.3
- **Kibana**: 8.15.3
- **Docker Compose**: 3.8
- **支持的操作系统**: Linux, macOS, Windows

## 🆕 更新日志

### v2.0.0 (2024-01-01)

- 完整 SSL 安全配置
- 自动证书生成和管理
- 集成 Kibana 服务
- 增强的启动脚本
- 完整的安全文档

### v1.0.0 (2024-01-01)

- 基础 SSL 配置
- 手动证书管理

## 📄 许可证

此配置遵循 Elasticsearch 的开源许可证。

## 🆘 支持

如有问题，请检查：

1. [故障排除](#故障排除)部分
2. [安全最佳实践](#安全最佳实践)部分
3. Elasticsearch 官方安全文档
4. Docker 和 Docker Compose 文档

---

**⚠️ 重要提醒**:

- 请务必修改默认密码
- 定期更新证书和密码
- 监控系统安全日志
- 遵循安全最佳实践
