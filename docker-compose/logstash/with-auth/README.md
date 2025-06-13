# Logstash 企业级部署

这是一个适用于生产环境的 Logstash 企业级部署配置，包含完整的 SSL/TLS 加密、用户认证、监控和安全功能。

## 🔐 安全特性

### SSL/TLS 加密

- **全链路加密**: 所有服务间通信均使用 SSL/TLS 加密
- **自动证书生成**: 启动脚本自动生成 CA 和服务证书
- **证书验证**: 强制验证客户端和服务端证书
- **密钥管理**: 安全的密钥存储和权限控制

### 用户认证

- **Elasticsearch 认证**: 基于用户名/密码的访问控制
- **Kibana 集成**: 与 Elasticsearch 安全集成
- **API 认证**: Logstash API 端点的基本认证
- **客户端认证**: Beats 和其他客户端的证书认证

### 监控和审计

- **X-Pack 监控**: 完整的性能和健康监控
- **安全事件检测**: 自动识别和标记安全相关事件
- **审计日志**: 详细的访问和操作日志记录
- **地理位置分析**: 基于 IP 的地理位置和风险评估

## 🚀 快速开始

### 前置要求

- Docker 20.10+
- Docker Compose 2.0+
- OpenSSL (用于证书生成)
- 可用端口：5044, 9600, 5000, 5001, 8080, 9200, 9300, 5601
- 至少 8GB 可用内存

### 初始化部署

1. **配置环境变量**

   ```bash
   # 复制环境变量模板
   cp env-template.txt .env

   # 编辑环境变量文件
   nano .env
   ```

2. **设置密码**

   ```bash
   # 生成强密码
   ELASTIC_PASSWORD=$(openssl rand -base64 32)
   KIBANA_PASSWORD=$(openssl rand -base64 32)
   LOGSTASH_KEYSTORE_PASS=$(openssl rand -base64 32)
   KIBANA_ENCRYPTION_KEY=$(openssl rand -hex 32)
   ```

3. **启动服务**

   **Linux/macOS:**

   ```bash
   chmod +x start.sh
   ./start.sh start
   ```

   **Windows:**

   ```cmd
   start.bat start
   ```

### 验证部署

```bash
# 检查服务状态
./start.sh status

# 测试连接
curl -k -u elastic:your_password https://localhost:9200/_cluster/health

# 查看日志
./start.sh logs logstash
```

## 📋 服务配置

### 端口映射

| 端口 | 服务          | 协议    | 用途       |
| ---- | ------------- | ------- | ---------- |
| 5044 | Logstash      | SSL/TLS | Beats 输入 |
| 9600 | Logstash      | HTTPS   | API 管理   |
| 5000 | Logstash      | SSL/TLS | TCP 输入   |
| 5001 | Logstash      | UDP     | UDP 输入   |
| 8080 | Logstash      | HTTPS   | HTTP 输入  |
| 9200 | Elasticsearch | HTTPS   | REST API   |
| 9300 | Elasticsearch | SSL/TLS | 集群通信   |
| 5601 | Kibana        | HTTPS   | Web 界面   |

### 环境变量

| 变量                   | 必需 | 说明                                 |
| ---------------------- | ---- | ------------------------------------ |
| ELASTIC_PASSWORD       | ✅   | Elasticsearch 超级用户密码           |
| KIBANA_PASSWORD        | ✅   | Kibana 系统用户密码                  |
| LOGSTASH_KEYSTORE_PASS | ✅   | Logstash 密钥库密码                  |
| KIBANA_ENCRYPTION_KEY  | ✅   | Kibana 加密密钥 (32 字符)            |
| ELASTIC_USERNAME       | ❌   | Elasticsearch 用户名 (默认: elastic) |

### 数据卷

- `logstash_auth_logs`: Logstash 日志文件
- `logstash_auth_data`: Logstash 数据文件
- `logstash_auth_queue`: 持久化队列数据
- `elasticsearch_auth_data`: Elasticsearch 数据
- `kibana_auth_data`: Kibana 配置和数据

## 🔧 配置详解

### SSL 证书结构

```
certs/
├── ca/
│   ├── ca.crt          # CA 根证书
│   ├── ca.key          # CA 私钥
│   └── ca.srl          # CA 序列号
├── elasticsearch/
│   ├── elasticsearch.crt
│   └── elasticsearch.key
├── kibana/
│   ├── kibana.crt
│   └── kibana.key
└── logstash/
    ├── logstash.crt
    └── logstash.key
```

### Logstash 管道配置

#### 输入源

1. **Beats 输入** (端口 5044)

   - SSL 客户端证书认证
   - 自动元数据标记
   - 拥塞控制

2. **TCP 输入** (端口 5000)

   - SSL 加密传输
   - JSON 格式解析
   - 连接验证

3. **HTTP 输入** (端口 8080)
   - HTTPS 加密
   - 基本认证支持
   - RESTful API 接口

#### 过滤器功能

- **安全事件检测**: 自动识别攻击模式
- **地理位置解析**: IP 地址地理定位
- **用户代理分析**: 浏览器和设备识别
- **数据脱敏**: 敏感信息自动清理
- **性能监控**: 处理时间统计

#### 输出配置

- **主索引**: `logstash-auth-YYYY.MM.dd`
- **安全事件**: `security-events-YYYY.MM.dd`
- **错误日志**: 本地文件存储
- **监控数据**: X-Pack 监控集成

## 🛠️ 管理命令

### 启动脚本选项

```bash
./start.sh [选项]
```

| 选项        | 说明                 |
| ----------- | -------------------- |
| start       | 启动所有服务（默认） |
| stop        | 停止所有服务         |
| restart     | 重启所有服务         |
| status      | 显示服务状态         |
| logs [服务] | 查看服务日志         |
| test        | 测试服务连接         |
| certs       | 重置 SSL 证书        |
| cleanup     | 清理所有数据         |
| help        | 显示帮助信息         |

### 常用操作

```bash
# 启动服务
./start.sh start

# 查看所有服务状态
./start.sh status

# 查看 Logstash 日志
./start.sh logs logstash

# 查看 Elasticsearch 日志
./start.sh logs elasticsearch

# 测试连接和认证
./start.sh test

# 重启服务
./start.sh restart

# 重置 SSL 证书
./start.sh certs

# 停止服务
./start.sh stop

# 清理所有数据（危险操作）
./start.sh cleanup
```

## 📊 监控和管理

### Elasticsearch 管理

```bash
# 集群健康状态
curl -k -u elastic:password https://localhost:9200/_cluster/health

# 节点信息
curl -k -u elastic:password https://localhost:9200/_nodes

# 索引列表
curl -k -u elastic:password https://localhost:9200/_cat/indices

# 集群统计
curl -k -u elastic:password https://localhost:9200/_cluster/stats
```

### Logstash 管理

```bash
# 节点统计
curl -k -u elastic:password https://localhost:9600/_node/stats

# 管道信息
curl -k -u elastic:password https://localhost:9600/_node/pipelines

# 插件列表
curl -k -u elastic:password https://localhost:9600/_node/plugins

# 热线程
curl -k -u elastic:password https://localhost:9600/_node/hot_threads
```

### Kibana 访问

1. 打开浏览器访问: https://localhost:5601
2. 使用 Elasticsearch 凭据登录:
   - 用户名: `elastic`
   - 密码: 在 `.env` 文件中设置的 `ELASTIC_PASSWORD`

## 🔗 客户端配置

### Filebeat 配置

```yaml
# filebeat.yml
output.logstash:
  hosts: ["localhost:5044"]
  ssl.enabled: true
  ssl.certificate_authorities: ["path/to/ca.crt"]
  ssl.certificate: "path/to/client.crt"
  ssl.key: "path/to/client.key"
  ssl.verification_mode: "strict"

filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - /var/log/*.log
    fields:
      log_type: system
      environment: production
```

### Metricbeat 配置

```yaml
# metricbeat.yml
output.logstash:
  hosts: ["localhost:5044"]
  ssl.enabled: true
  ssl.certificate_authorities: ["path/to/ca.crt"]
  ssl.certificate: "path/to/client.crt"
  ssl.key: "path/to/client.key"

metricbeat.modules:
  - module: system
    metricsets: ["cpu", "memory", "network", "process"]
    period: 10s
```

### Java 应用配置

```java
// Logback 配置
import net.logstash.logback.appender.LogstashTcpSocketAppender;
import net.logstash.logback.encoder.LoggingEventCompositeJsonEncoder;

LogstashTcpSocketAppender appender = new LogstashTcpSocketAppender();
appender.setDestination("localhost:5000");
appender.setSsl(true);
appender.setSslKeystoreLocation("path/to/client.p12");
appender.setSslKeystorePassword("password");
appender.setSslTruststoreLocation("path/to/truststore.p12");
appender.setSslTruststorePassword("password");
```

### Python 应用配置

```python
import logging
import ssl
from pythonjsonlogger import jsonlogger

# SSL 上下文
ssl_context = ssl.create_default_context(ssl.Purpose.SERVER_AUTH)
ssl_context.load_verify_locations('path/to/ca.crt')
ssl_context.load_cert_chain('path/to/client.crt', 'path/to/client.key')

# 配置日志处理器
handler = logging.handlers.SocketHandler('localhost', 5000)
handler.socket = ssl_context.wrap_socket(
    handler.socket,
    server_hostname='logstash'
)

formatter = jsonlogger.JsonFormatter()
handler.setFormatter(formatter)

logger = logging.getLogger()
logger.addHandler(handler)
logger.setLevel(logging.INFO)
```

### Node.js 应用配置

```javascript
const winston = require("winston");
const LogstashTransport = require("winston-logstash").Logstash;

const logger = winston.createLogger({
  transports: [
    new LogstashTransport({
      port: 5000,
      host: "localhost",
      ssl_enable: true,
      ssl_key: "path/to/client.key",
      ssl_cert: "path/to/client.crt",
      ca: "path/to/ca.crt",
      ssl_passphrase: "password",
    }),
  ],
});

logger.info("Hello from Node.js application");
```

## 🚨 故障排除

### 常见问题

1. **SSL 证书错误**

   ```bash
   # 重新生成证书
   ./start.sh certs

   # 检查证书有效性
   openssl x509 -in certs/ca/ca.crt -text -noout
   ```

2. **认证失败**

   ```bash
   # 检查环境变量
   cat .env

   # 重置密码
   docker exec -it elasticsearch-auth /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic
   ```

3. **内存不足**

   ```bash
   # 调整 JVM 堆内存
   # 编辑 docker-compose.yaml
   environment:
     - ES_JAVA_OPTS=-Xmx512m -Xms512m
     - LS_JAVA_OPTS=-Xmx1g -Xms1g
   ```

4. **端口冲突**

   ```bash
   # 检查端口占用
   netstat -tulpn | grep :9200

   # 修改端口映射
   # 编辑 docker-compose.yaml
   ports:
     - "19200:9200"
   ```

5. **网络连接问题**

   ```bash
   # 检查网络
   docker network ls
   docker network inspect elastic-auth-network

   # 重建网络
   docker network rm elastic-auth-network
   ./start.sh start
   ```

### 日志分析

```bash
# 查看详细启动日志
./start.sh logs elasticsearch

# 查看 Logstash 管道错误
./start.sh logs logstash | grep ERROR

# 查看 SSL 握手错误
./start.sh logs logstash | grep -i ssl

# 查看认证错误
./start.sh logs elasticsearch | grep -i auth
```

### 性能调优

1. **Elasticsearch 优化**

   ```yaml
   # docker-compose.yaml
   environment:
     - ES_JAVA_OPTS=-Xmx4g -Xms4g
     - bootstrap.memory_lock=true
     - indices.memory.index_buffer_size=30%
   ```

2. **Logstash 优化**

   ```yaml
   # config/logstash.yml
   pipeline.workers: 8
   pipeline.batch.size: 500
   pipeline.batch.delay: 25
   queue.max_bytes: 4gb
   ```

3. **系统优化**

   ```bash
   # 增加文件描述符限制
   echo "* soft nofile 65536" >> /etc/security/limits.conf
   echo "* hard nofile 65536" >> /etc/security/limits.conf

   # 增加虚拟内存
   echo "vm.max_map_count=262144" >> /etc/sysctl.conf
   sysctl -p
   ```

## 🔒 安全最佳实践

### 密码管理

1. **使用强密码**: 至少 16 个字符，包含大小写字母、数字和特殊字符
2. **定期更换**: 建议每 90 天更换一次密码
3. **密钥轮换**: 定期重新生成 SSL 证书和加密密钥
4. **权限最小化**: 为不同用途创建专用用户账户

### 网络安全

1. **防火墙配置**: 限制不必要的端口访问
2. **VPN 访问**: 生产环境建议通过 VPN 访问
3. **IP 白名单**: 配置允许访问的 IP 地址范围
4. **负载均衡**: 使用反向代理和负载均衡器

### 监控和审计

1. **日志监控**: 监控异常访问和错误模式
2. **性能监控**: 监控资源使用和性能指标
3. **安全扫描**: 定期进行安全漏洞扫描
4. **备份策略**: 定期备份配置和数据

### 合规性

1. **数据保护**: 遵循 GDPR、CCPA 等数据保护法规
2. **审计日志**: 保留详细的访问和操作审计日志
3. **数据加密**: 静态数据和传输数据的加密
4. **访问控制**: 基于角色的访问控制 (RBAC)

## 📚 相关文档

- [Logstash 官方文档](https://www.elastic.co/guide/en/logstash/current/index.html)
- [Elasticsearch 安全配置](https://www.elastic.co/guide/en/elasticsearch/reference/current/security-settings.html)
- [Kibana 安全配置](https://www.elastic.co/guide/en/kibana/current/security-settings.html)
- [X-Pack 监控](https://www.elastic.co/guide/en/elasticsearch/reference/current/monitoring.html)
- [SSL/TLS 配置](https://www.elastic.co/guide/en/elasticsearch/reference/current/ssl-settings.html)

## 🔄 升级指南

### 版本升级

1. **备份数据**

   ```bash
   # 创建快照
   curl -X PUT "localhost:9200/_snapshot/backup/snapshot_1"

   # 备份配置
   cp -r certs certs_backup
   cp .env .env_backup
   ```

2. **升级镜像**

   ```bash
   # 停止服务
   ./start.sh stop

   # 修改 docker-compose.yaml 中的镜像版本
   # 重新启动
   ./start.sh start
   ```

3. **验证升级**

   ```bash
   # 检查版本
   curl -k -u elastic:password https://localhost:9200/

   # 测试功能
   ./start.sh test
   ```

### 迁移到新环境

1. **导出配置**

   ```bash
   # 打包配置文件
   tar -czf logstash-config.tar.gz certs/ config/ pipeline/ .env docker-compose.yaml
   ```

2. **传输到新环境**

   ```bash
   # 解压配置
   tar -xzf logstash-config.tar.gz

   # 启动服务
   ./start.sh start
   ```

## ⚠️ 重要提醒

1. **生产环境部署**: 此配置适用于生产环境，包含完整的安全功能
2. **资源要求**: 确保有足够的内存和存储空间
3. **备份策略**: 定期备份数据和配置文件
4. **监控告警**: 配置适当的监控和告警机制
5. **安全更新**: 定期更新镜像和依赖包
6. **文档维护**: 保持部署文档的更新和准确性

## 📞 技术支持

如果在部署过程中遇到问题，请：

1. 查看日志文件获取详细错误信息
2. 检查系统资源使用情况
3. 验证网络连接和端口可用性
4. 确认 SSL 证书的有效性
5. 参考官方文档和社区资源
