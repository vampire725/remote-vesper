# Grafana Tempo 分布式追踪系统部署指南

## 📋 项目概述

本项目提供了完整的 Grafana Tempo 分布式追踪系统的 Docker 容器化部署方案，支持 OpenTelemetry 协议，适用于微服务架构的可观测性建设。

### 🏗️ 架构组件

- **Grafana Tempo 2.6.0**: 高性能分布式追踪后端
- **Docker Compose**: 容器编排和服务管理
- **自动化脚本**: 一键部署和运维管理

## 📁 项目文件结构

```
tempo/
├── docker-compose.yaml          # Docker Compose 主配置文件
├── deploy.sh                    # 自动化部署脚本
├── tempo.yaml                   # Tempo 基础配置（开发/测试）
├── tempo-with-metrics.yaml      # Tempo 完整配置（生产环境）
├── tempo-single-node.yaml       # Tempo 单节点配置（生产级）
├── prometheus.yml               # Prometheus 监控配置
├── grafana-datasources.yaml     # Grafana 数据源配置
└── README.md                    # 本文档
```

## 🚀 快速开始

### 1. 环境要求

#### 系统要求

```bash
操作系统: Linux/macOS/Windows
Docker: 20.0+
Docker Compose: 2.0+
内存: 最少 2GB 可用
磁盘: 最少 5GB 可用空间
```

#### 端口要求

确保以下端口未被占用：

- `3200`: Tempo HTTP API
- `4317`: OTLP gRPC 接收
- `4318`: OTLP HTTP 接收

### 2. 一键部署

```bash
# 克隆或下载项目文件到本地
cd tempo

# 给部署脚本执行权限
chmod +x deploy.sh

# 执行一键部署
./deploy.sh
```

### 3. 验证部署

```bash
# 检查服务状态
./deploy.sh --status

# 查看服务日志
./deploy.sh --logs

# 手动健康检查
curl http://localhost:3200/ready
```

## 🔧 配置文件详解

### Docker Compose 配置 (`docker-compose.yaml`)

#### 服务配置

```yaml
services:
  tempo:
    image: grafana/tempo:2.6.0
    container_name: tempo
    command: ["-config.file=/etc/tempo.yaml"]

    # 端口映射
    ports:
      - "3200:3200" # HTTP API
      - "4317:4317" # OTLP gRPC
      - "4318:4318" # OTLP HTTP

    # 配置挂载
    volumes:
      - ./tempo-single-node.yaml:/etc/tempo.yaml:ro
      - tempo-data:/tmp/tempo
      - /etc/localtime:/etc/localtime:ro
```

#### 网络配置

```yaml
networks:
  tracing-network:
    external: true # 追踪服务网络
  monitoring-network:
    external: true # 监控服务网络
```

#### 资源限制

```yaml
deploy:
  resources:
    limits:
      cpus: "2.0" # CPU 限制 2 核
      memory: 2G # 内存限制 2GB
    reservations:
      cpus: "0.5" # CPU 预留 0.5 核
      memory: 512M # 内存预留 512MB
```

### Tempo 配置选择

#### 1. 基础配置 (`tempo.yaml`)

**适用场景**: 开发环境、功能测试

```yaml
# 特点
- 配置简单，启动快速
- 资源占用少（~200MB 内存）
- 仅支持基础追踪功能
- 不包含指标生成器
```

#### 2. 完整配置 (`tempo-with-metrics.yaml`)

**适用场景**: 生产环境、完整监控

```yaml
# 特点
- 包含指标生成器
- 支持服务图谱生成
- Prometheus 集成
- 集群支持（memberlist）
- 资源占用中等（~1GB 内存）
```

#### 3. 单节点配置 (`tempo-single-node.yaml`)

**适用场景**: 生产单节点部署

```yaml
# 特点
- 生产级配置优化
- 单节点性能优化
- 完整的压缩策略
- 资源占用适中（~800MB 内存）
```

## 🛠️ 部署脚本功能 (`deploy.sh`)

### 主要功能

#### 基础操作

```bash
./deploy.sh                # 标准部署
./deploy.sh --help         # 显示帮助
./deploy.sh --verbose      # 详细输出模式
```

#### 服务管理

```bash
./deploy.sh --status       # 查看服务状态
./deploy.sh --logs         # 查看服务日志
./deploy.sh --stop         # 停止服务
./deploy.sh --restart      # 重启服务
```

#### 清理操作

```bash
./deploy.sh --clean        # 清理并重新部署
```

### 自动化功能

1. **环境检查**: 自动检查 Docker、Docker Compose 和配置文件
2. **网络准备**: 自动创建所需的 Docker 网络
3. **配置验证**: 验证 Docker Compose 配置文件语法
4. **服务部署**: 拉取镜像并启动服务
5. **健康检查**: 自动验证服务是否正常启动

## 📊 监控和集成

### Prometheus 集成

#### 配置文件 (`prometheus.yml`)

```yaml
# 全局配置
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: "tempo-cluster"
    environment: "production"

# 抓取配置
scrape_configs:
  - job_name: "tempo"
    static_configs:
      - targets: ["tempo:3200"]
    scrape_interval: 30s
    metrics_path: "/metrics"
```

### Grafana 数据源配置

#### 数据源文件 (`grafana-datasources.yaml`)

```yaml
apiVersion: 1
datasources:
  # Tempo 数据源
  - name: Tempo
    type: tempo
    access: proxy
    url: http://tempo:3200
    isDefault: true

  # Prometheus 数据源
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
```

## 🔍 使用指南

### 发送追踪数据

#### OTLP gRPC 方式

```bash
# 使用 OpenTelemetry SDK
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"
export OTEL_EXPORTER_OTLP_PROTOCOL="grpc"
```

#### OTLP HTTP 方式

```bash
# 使用 OpenTelemetry SDK
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4318"
export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
```

### 查询追踪数据

#### HTTP API 查询

```bash
# 按 Trace ID 查询
curl "http://localhost:3200/api/traces/{trace_id}"

# 搜索追踪
curl "http://localhost:3200/api/search?tags=service.name=my-service"
```

#### TraceQL 查询示例

```traceql
# 查询特定服务
{service.name="user-service"}

# 查询慢请求
{duration > 1s}

# 查询错误
{status=error}

# 复合查询
{service.name="api-gateway" && http.status_code >= 400}
```

## 🚨 故障排除

### 常见问题

#### 1. 服务无法启动

```bash
# 检查端口占用
netstat -tlnp | grep -E '(3200|4317|4318)'

# 检查 Docker 状态
docker info

# 查看详细日志
./deploy.sh --logs
```

#### 2. 无法接收追踪数据

```bash
# 测试 OTLP 端点
curl -v http://localhost:4318/v1/traces

# 检查网络连接
docker exec tempo netstat -tlnp

# 查看摄取日志
docker-compose logs tempo | grep -i distributor
```

#### 3. 查询性能问题

```bash
# 监控资源使用
docker stats tempo

# 检查存储使用
docker exec tempo df -h /tmp/tempo

# 调整查询超时
# 在配置文件中修改 duration_slo 参数
```

### 日志分析

#### 启用调试日志

```yaml
# 在 tempo 配置中添加
server:
  log_level: debug
```

#### 关键日志模式

```bash
# 摄取错误
docker-compose logs tempo | grep -i "failed to push"

# 查询错误
docker-compose logs tempo | grep -i "query failed"

# 存储错误
docker-compose logs tempo | grep -i "storage error"
```

## ⚡ 性能优化

### 内存优化

```yaml
# 在 tempo 配置中调整
ingester:
  max_block_bytes: 500_000 # 减少内存使用
  max_block_duration: 3m # 更频繁刷盘

compactor:
  compaction:
    block_retention: 12h # 减少数据保留时间
```

### 查询优化

```yaml
# 在 tempo 配置中调整
query_frontend:
  search:
    duration_slo: 3s # 降低查询超时
    concurrent_jobs: 500 # 调整并发作业数

querier:
  max_concurrent_queries: 10 # 增加并发查询数
```

### 存储优化

```yaml
# 在 tempo 配置中调整
compactor:
  compaction:
    compaction_window: 2h # 调整压缩窗口
    max_block_bytes: 50_000_000 # 调整块大小
```

## 🔒 生产环境部署

### 安全配置

#### 1. 网络安全

```yaml
# 限制端口暴露
ports:
  - "127.0.0.1:3200:3200" # 仅本地访问
```

#### 2. 资源限制

```yaml
# 严格的资源限制
deploy:
  resources:
    limits:
      cpus: "1.0"
      memory: 1G
    reservations:
      cpus: "0.25"
      memory: 256M
```

### 高可用配置

#### 1. 外部存储

```yaml
# 使用对象存储
storage:
  trace:
    backend: s3
    s3:
      bucket: tempo-traces
      region: us-east-1
      access_key_id: ${AWS_ACCESS_KEY_ID}
      secret_access_key: ${AWS_SECRET_ACCESS_KEY}
```

#### 2. 多节点部署

```yaml
# 集群配置
memberlist:
  join_members:
    - tempo-1:7946
    - tempo-2:7946
    - tempo-3:7946
```

### 监控告警

#### Prometheus 告警规则

```yaml
groups:
  - name: tempo.rules
    rules:
      - alert: TempoDown
        expr: up{job="tempo"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Tempo 服务不可用"

      - alert: TempoHighMemory
        expr: container_memory_usage_bytes{name="tempo"} > 1.5e9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Tempo 内存使用过高"
```

## 📚 最佳实践

### 1. 配置管理

- 使用环境变量管理敏感配置
- 定期备份配置文件
- 版本控制配置变更

### 2. 数据管理

- 设置合理的数据保留策略
- 定期清理过期数据
- 监控存储使用情况

### 3. 性能监控

- 监控关键指标（摄取速率、查询延迟）
- 设置合理的告警阈值
- 定期性能测试和调优

### 4. 运维管理

- 使用自动化脚本进行部署
- 建立标准化的运维流程
- 定期进行灾难恢复演练

## 🆘 技术支持

### 官方资源

- **官方文档**: https://grafana.com/docs/tempo/
- **GitHub 仓库**: https://github.com/grafana/tempo
- **社区论坛**: https://community.grafana.com/

### 问题反馈

如遇到问题，请提供以下信息：

1. 系统环境信息
2. 错误日志
3. 配置文件内容
4. 复现步骤

---

## 📄 许可证

本项目基于 Apache 2.0 许可证开源。

## 🔄 更新日志

- **v1.0**: 初始版本，支持基础部署功能
- 支持多种配置模式
- 提供自动化部署脚本
- 完整的监控集成
