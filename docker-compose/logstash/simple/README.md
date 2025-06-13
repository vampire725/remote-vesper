# Logstash 简单部署

这是一个适用于开发和测试环境的 Logstash 简单部署配置，不包含认证和 SSL 配置，便于快速启动和测试。

## 🚀 快速开始

### 前置要求

- Docker 20.10+
- Docker Compose 2.0+
- 可用端口：5044, 9600, 5000, 5001, 8080

### 启动服务

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
./start.sh test

# 查看日志
./start.sh logs
```

## 📋 服务配置

### 端口映射

| 端口 | 用途       | 协议 |
| ---- | ---------- | ---- |
| 5044 | Beats 输入 | TCP  |
| 9600 | HTTP API   | HTTP |
| 5000 | TCP 输入   | TCP  |
| 5001 | UDP 输入   | UDP  |
| 8080 | HTTP 输入  | HTTP |

### 环境变量

| 变量                     | 默认值        | 说明             |
| ------------------------ | ------------- | ---------------- |
| LS_JAVA_OPTS             | -Xmx1g -Xms1g | JVM 堆内存设置   |
| LOG_LEVEL                | info          | 日志级别         |
| xpack.monitoring.enabled | false         | 禁用 X-Pack 监控 |

### 数据卷

- `logstash_simple_logs`: 日志文件存储
- `logstash_simple_data`: 数据文件存储
- `./pipeline`: 管道配置文件（只读）
- `./config`: Logstash 配置文件（只读）

## 🔧 配置说明

### 管道配置 (pipeline/main.conf)

支持多种输入源：

1. **Beats 输入** (端口 5044)

   - 接收 Filebeat、Metricbeat 等数据
   - 自动解析 JSON 格式

2. **TCP 输入** (端口 5000)

   - 接收 TCP 连接的 JSON 数据
   - 适用于应用程序直接发送日志

3. **UDP 输入** (端口 5001)

   - 接收 UDP 数据包
   - 适用于高频率日志传输

4. **HTTP 输入** (端口 8080)
   - 接收 HTTP POST 请求
   - 适用于 Web 应用程序和测试

### 过滤器功能

- **时间戳处理**: 自动添加处理时间戳
- **主机信息**: 添加处理主机信息
- **JSON 解析**: 自动解析 JSON 格式消息
- **日志格式识别**: 支持 Nginx、Apache 日志格式
- **地理位置解析**: 基于 IP 地址的地理位置信息
- **用户代理解析**: 解析 HTTP User-Agent 字符串

### 输出配置

- **Elasticsearch**: 默认输出到 `http://elasticsearch:9200`
- **索引模式**: `logstash-simple-YYYY.MM.dd`
- **错误处理**: 解析失败的日志记录到文件

## 🛠️ 管理命令

### 启动脚本选项

```bash
./start.sh [选项]
```

| 选项    | 说明             |
| ------- | ---------------- |
| start   | 启动服务（默认） |
| stop    | 停止服务         |
| restart | 重启服务         |
| status  | 显示服务状态     |
| logs    | 查看服务日志     |
| test    | 测试服务连接     |
| cleanup | 清理所有数据     |
| help    | 显示帮助信息     |

### 常用操作

```bash
# 启动服务
./start.sh start

# 查看实时日志
./start.sh logs

# 检查服务状态
./start.sh status

# 测试连接
./start.sh test

# 重启服务
./start.sh restart

# 停止服务
./start.sh stop

# 清理数据（危险操作）
./start.sh cleanup
```

## 📊 测试和验证

### API 测试

```bash
# 检查节点状态
curl http://localhost:9600/_node/stats

# 检查管道状态
curl http://localhost:9600/_node/pipelines

# 检查插件信息
curl http://localhost:9600/_node/plugins
```

### 数据发送测试

**HTTP 输入测试:**

```bash
curl -X POST -H "Content-Type: application/json" \
  -d '{"message":"Hello Logstash","level":"info","timestamp":"2024-01-01T12:00:00Z"}' \
  http://localhost:8080
```

**TCP 输入测试:**

```bash
echo '{"message":"TCP test","source":"tcp"}' | nc localhost 5000
```

**UDP 输入测试:**

```bash
echo '{"message":"UDP test","source":"udp"}' | nc -u localhost 5001
```

## 🔗 与其他服务集成

### 连接 Elasticsearch

确保 Elasticsearch 服务在同一网络中运行：

```yaml
# 在 docker-compose.yaml 中添加 Elasticsearch
elasticsearch:
  image: docker.elastic.co/elasticsearch/elasticsearch:8.17.1
  environment:
    - discovery.type=single-node
    - xpack.security.enabled=false
  ports:
    - "9200:9200"
  networks:
    - logging-network
```

### 连接 Kibana

```yaml
# 在 docker-compose.yaml 中添加 Kibana
kibana:
  image: docker.elastic.co/kibana/kibana:8.17.1
  environment:
    - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
  ports:
    - "5601:5601"
  networks:
    - logging-network
```

### Filebeat 配置示例

```yaml
# filebeat.yml
output.logstash:
  hosts: ["localhost:5044"]

filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - /var/log/*.log
    fields:
      log_type: system
```

## 🚨 故障排除

### 常见问题

1. **端口占用**

   ```bash
   # 检查端口占用
   netstat -tulpn | grep :5044

   # 修改 docker-compose.yaml 中的端口映射
   ports:
     - "15044:5044"  # 使用其他端口
   ```

2. **内存不足**

   ```bash
   # 调整 JVM 堆内存
   environment:
     - LS_JAVA_OPTS=-Xmx512m -Xms512m
   ```

3. **配置文件错误**

   ```bash
   # 检查配置语法
   docker exec logstash-simple /usr/share/logstash/bin/logstash --config.test_and_exit
   ```

4. **网络连接问题**
   ```bash
   # 检查网络
   docker network ls
   docker network inspect logging-network
   ```

### 日志分析

```bash
# 查看详细日志
./start.sh logs

# 查看特定时间段的日志
docker logs --since="1h" logstash-simple

# 查看错误日志
docker logs logstash-simple 2>&1 | grep ERROR
```

### 性能调优

1. **调整工作线程数**

   ```yaml
   # config/logstash.yml
   pipeline.workers: 4 # 根据 CPU 核心数调整
   ```

2. **调整批处理大小**

   ```yaml
   # config/logstash.yml
   pipeline.batch.size: 250
   pipeline.batch.delay: 50
   ```

3. **启用持久化队列**
   ```yaml
   # config/logstash.yml
   queue.type: persisted
   queue.max_bytes: 2gb
   ```

## 📚 相关文档

- [Logstash 官方文档](https://www.elastic.co/guide/en/logstash/current/index.html)
- [Logstash 配置参考](https://www.elastic.co/guide/en/logstash/current/configuration.html)
- [Logstash 插件文档](https://www.elastic.co/guide/en/logstash/current/input-plugins.html)
- [Docker Compose 文档](https://docs.docker.com/compose/)

## ⚠️ 注意事项

1. **安全警告**: 此配置适用于开发环境，生产环境请使用 `with-auth` 版本
2. **数据持久化**: 重要数据请定期备份
3. **资源监控**: 监控内存和 CPU 使用情况
4. **网络安全**: 确保端口访问控制适当配置

## 🔄 升级指南

### 升级 Logstash 版本

1. 停止当前服务

   ```bash
   ./start.sh stop
   ```

2. 修改 `docker-compose.yaml` 中的镜像版本

   ```yaml
   image: docker.elastic.co/logstash/logstash:8.18.0 # 新版本
   ```

3. 重新启动服务
   ```bash
   ./start.sh start
   ```

### 迁移到认证版本

参考 `../with-auth/README.md` 了解如何迁移到带认证的部署版本。
