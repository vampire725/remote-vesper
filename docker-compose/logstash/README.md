# Logstash 数据处理部署指南

本文档提供了使用 Docker Compose 部署 Logstash 的详细说明，用于从 Kafka 读取数据并处理输出到 Elasticsearch。

## 系统要求

- Docker 20.10.0 或更高版本
- Docker Compose 2.0.0 或更高版本
- Kafka 集群
- Elasticsearch 集群
- 足够的磁盘空间用于日志存储

## 目录结构

```
logstash/
├── docker-compose.yml    # Docker Compose 配置文件
├── logstash.yml         # Logstash 主配置文件
├── pipelines.yml        # 管道配置文件
├── pipeline/            # 管道配置目录
│   └── main.conf       # 主管道配置文件
├── certs/              # 证书目录
└── README.md           # 本文档
```

## 部署步骤

### 1. 准备环境

创建必要的目录：

```bash
mkdir -p pipeline certs
```

### 2. 配置 Logstash

1. 修改 `docker-compose.yml` 中的环境变量：
   - `ELASTICSEARCH_*`: Elasticsearch 连接信息
   - `KAFKA_*`: Kafka 连接信息
   - `LS_JAVA_OPTS`: JVM 参数

2. 根据需要修改配置文件：
   - `logstash.yml`: 主配置
   - `pipelines.yml`: 管道配置
   - `pipeline/main.conf`: 数据处理配置

### 3. 启动 Logstash

```bash
docker-compose up -d
```

## 配置说明

### 数据处理流程

1. **输入配置**
   - 从 Kafka 读取数据
   - 支持 SASL 认证
   - 多线程消费

2. **过滤器配置**
   - JSON 解析
   - 多行日志处理
   - 时间戳处理
   - Docker 容器信息处理
   - 系统指标处理
   - 网络数据处理
   - 敏感信息过滤

3. **输出配置**
   - 输出到 Elasticsearch
   - 按日期索引
   - 错误日志记录
   - 批量处理优化

### 性能配置

- 工作线程数：2
- 批处理大小：125
- 批处理延迟：50ms
- JVM 堆内存：1GB

### 监控配置

- 启用 X-Pack 监控
- 日志级别：info
- 错误日志分离

## 使用说明

### 添加新的处理规则

1. 在 `pipeline/main.conf` 中添加新的过滤器：

```ruby
filter {
  if [type] == "your_type" {
    # 你的处理规则
  }
}
```

2. 重启 Logstash：

```bash
docker-compose restart
```

### 查看日志

```bash
# 查看所有日志
docker-compose logs

# 实时查看日志
docker-compose logs -f
```

### 停止服务

```bash
docker-compose down
```

## 注意事项

1. **安全**
   - 妥善保管认证信息
   - 确保证书安全
   - 过滤敏感数据

2. **性能**
   - 监控内存使用
   - 调整批处理参数
   - 优化过滤器配置

3. **维护**
   - 定期检查日志
   - 更新 Logstash 版本
   - 备份配置文件

## 故障排除

### 常见问题

1. **无法连接到 Kafka**
   - 检查网络连接
   - 验证认证信息
   - 确认主题配置

2. **无法连接到 Elasticsearch**
   - 检查网络连接
   - 验证认证信息
   - 确认证书配置

3. **性能问题**
   - 检查内存使用
   - 调整批处理参数
   - 优化过滤器配置

### 获取帮助

如果遇到问题，可以：

1. 查看 Logstash 官方文档
2. 检查 Docker 日志
3. 查看 Logstash 日志
4. 在 Elastic 社区论坛寻求帮助

## 更新记录

- 2024-03-xx: 初始版本
  - 创建基础配置
  - 配置数据处理流程
  - 完善文档说明 