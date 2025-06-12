# Tempo + Grafana + Prometheus 部署

## 概述

本目录包含 Tempo 分布式追踪后端及其相关组件的部署配置。

## 组件说明

### Tempo
- 高性能分布式追踪后端
- 支持 OTLP、Jaeger、Zipkin 协议
- 本地文件存储，适合开发和测试环境

### Grafana
- 统一可视化平台
- 预配置 Tempo 和 Prometheus 数据源
- 支持 TraceQL 查询语言

### Prometheus
- 指标收集和存储
- 支持服务依赖图生成
- 监控系统组件健康状态

## 文件说明

- `docker-compose.yaml` - Docker Compose 部署配置
- `tempo.yaml` - Tempo 配置文件
- `grafana-datasources.yaml` - Grafana 数据源配置
- `prometheus.yml` - Prometheus 配置文件
- `README.md` - 本说明文档

## 部署前准备

### 1. 创建共享网络
```bash
docker network create tracing-network
```

### 2. 系统要求
- Docker: 20.0+
- Docker Compose: 1.29+
- 可用内存: 至少 2GB
- 磁盘空间: 至少 5GB (用于数据存储)

## 快速启动

```bash
# 启动所有服务
docker-compose up -d

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down

# 停止并删除数据卷
docker-compose down -v
```

## 端口说明

| 服务 | 端口 | 用途 |
|------|------|------|
| Tempo | 3200 | HTTP API |
| Tempo | 4317 | OTLP gRPC |
| Tempo | 4318 | OTLP HTTP |
| Grafana | 3000 | Web UI |
| Prometheus | 9090 | Web UI |

## 验证部署

### 1. 健康检查
```bash
# Tempo 健康检查
curl http://localhost:3200/ready

# Grafana 健康检查
curl http://localhost:3000/api/health

# Prometheus 健康检查
curl http://localhost:9090/-/healthy
```

### 2. 访问界面
- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090

### 3. 验证数据源
在 Grafana 中：
1. 进入 "Configuration" → "Data sources"
2. 验证 Tempo 和 Prometheus 数据源状态为绿色

## 使用指南

### 在 Grafana 中查看追踪数据

1. **Explore 页面**
   - 选择 Tempo 数据源
   - 使用 TraceQL 查询: `{service.name="your-service"}`

2. **服务依赖图**
   - 进入 "Explore" → "Service Map"
   - 查看服务间调用关系

3. **追踪查询**
   - 按服务名称查询
   - 按操作名称查询
   - 按标签查询

### TraceQL 查询示例
```traceql
# 查询特定服务
{service.name="api-gateway"}

# 查询慢请求 (>1s)
{duration > 1s}

# 查询错误
{status=error}

# 组合查询
{service.name="user-service" && duration > 500ms}
```

## 配置说明

### Tempo 特性
- **本地存储**: 适合开发环境
- **指标生成**: 自动生成服务图谱数据
- **多协议支持**: OTLP、Jaeger、Zipkin
- **压缩和清理**: 自动数据压缩和过期清理

### 存储配置
```yaml
storage:
  trace:
    backend: local          # 本地文件存储
    block_retention: 24h    # 数据保留24小时
```

### 指标生成器
```yaml
metrics_generator:
  processors: [service-graphs, span-metrics]  # 生成服务图和span指标
```

## 性能调优

### 1. 内存优化
```yaml
ingester:
  max_block_bytes: 1_000_000      # 减少内存使用
  max_block_duration: 5m          # 更频繁地刷盘
```

### 2. 存储优化
```yaml
compactor:
  block_retention: 24h            # 数据保留时间
  compacted_block_retention: 1h   # 压缩块保留时间
```

### 3. 查询优化
```yaml
query_frontend:
  search:
    duration_slo: 5s              # 搜索超时时间
```

## 故障排除

### 常见问题

1. **Tempo 无法启动**
   ```bash
   # 检查配置文件语法
   docker run --rm -v $(pwd)/tempo.yaml:/tempo.yaml grafana/tempo:latest -config.file=/tempo.yaml -config.expand-env=true -dry-run
   ```

2. **Grafana 无法连接 Tempo**
   ```bash
   # 检查网络连接
   docker exec grafana curl tempo:3200/ready
   ```

3. **无追踪数据显示**
   - 检查 OTel Collector 是否正常运行
   - 验证网络连接
   - 查看 Tempo 日志

4. **磁盘空间不足**
   ```bash
   # 检查数据卷使用情况
   docker system df -v
   
   # 清理旧数据
   docker-compose down -v
   ```

### 日志分析
```bash
# 查看 Tempo 日志
docker-compose logs tempo | grep ERROR

# 查看 Grafana 日志
docker-compose logs grafana | grep ERROR

# 实时监控所有服务
docker-compose logs -f
```

### 数据备份
```bash
# 备份配置文件
tar -czf tempo-config-backup.tar.gz *.yaml *.yml

# 备份数据卷
docker run --rm -v tempo_tempo-data:/data -v $(pwd):/backup alpine tar czf /backup/tempo-data-backup.tar.gz /data
```

## 生产环境建议

1. **使用外部存储**: 配置 S3、GCS 或其他对象存储
2. **高可用部署**: 部署多个 Tempo 实例
3. **监控告警**: 配置 Prometheus 告警规则
4. **安全配置**: 启用 HTTPS 和身份验证
5. **资源限制**: 设置适当的 CPU 和内存限制 