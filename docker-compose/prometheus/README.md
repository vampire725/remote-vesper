# Prometheus 指标收集平台部署

## 概述

本目录包含 Prometheus 指标收集和存储平台的独立部署配置，用于监控整个 OpenTelemetry 观测性技术栈。

## 文件说明

- `docker-compose.yaml` - Docker Compose 部署配置
- `prometheus.yml` - Prometheus 主配置文件
- `rules/` - 告警和记录规则目录
  - `otel-alerts.yml` - OpenTelemetry 相关告警规则
- `README.md` - 本说明文档

## 功能特性

### 监控目标
- **OpenTelemetry Collector**: 采集器性能和健康状态
- **Tempo**: 追踪后端指标和性能
- **Grafana**: 可视化平台监控
- **Prometheus**: 自身监控

### 告警规则
- 服务下线检测
- 性能异常告警
- 错误率监控
- 资源使用监控

## 部署前准备

### 1. 创建共享网络
```bash
docker network create tracing-network
```

### 2. 确保监控目标运行
- OpenTelemetry Collector (端口 8889)
- Tempo (端口 3200)
- Grafana (端口 3000)

## 快速启动

```bash
# 启动 Prometheus
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down
```

## 访问和使用

### 访问界面
- **URL**: http://localhost:9090
- **状态页面**: http://localhost:9090/targets
- **配置页面**: http://localhost:9090/config

### 主要功能
1. **指标查询**: 使用 PromQL 查询语言
2. **目标监控**: 查看各个监控目标状态
3. **告警规则**: 配置和管理告警
4. **服务发现**: 自动发现监控目标

## PromQL 查询示例

### 基础查询
```promql
# 查看所有 UP 状态的服务
up

# OTel Collector 接收的 span 速率
rate(otelcol_receiver_accepted_spans_total[5m])

# Tempo 接收的 span 速率
rate(tempo_distributor_spans_received_total[5m])

# 查看内存使用情况
otelcol_process_memory_rss
```

### 高级查询
```promql
# 计算 span 丢失率
(
  rate(otelcol_processor_dropped_spans_total[5m]) /
  rate(otelcol_receiver_accepted_spans_total[5m])
) * 100

# 99th 百分位延迟
histogram_quantile(0.99, rate(tempo_request_duration_seconds_bucket[5m]))

# 服务可用性计算
avg_over_time(up{job="otel-collector"}[1h]) * 100
```

### 聚合查询
```promql
# 按 job 分组的总 span 数
sum by (job) (rate(otelcol_receiver_accepted_spans_total[5m]))

# 计算错误率
sum(rate(otelcol_exporter_send_failed_spans_total[5m])) /
sum(rate(otelcol_exporter_sent_spans_total[5m]))
```

## 配置说明

### 采集配置
```yaml
scrape_configs:
  - job_name: 'otel-collector'
    static_configs:
      - targets: ['otel-collector:8889']
    scrape_interval: 15s        # 采集间隔
    metrics_path: '/metrics'    # 指标路径
    honor_labels: true          # 保留原始标签
```

### 存储配置
```yaml
--storage.tsdb.retention.time=7d    # 数据保留7天
--storage.tsdb.retention.size=10GB  # 最大存储10GB
```

### 性能配置
```yaml
--query.max-concurrency=50         # 最大并发查询数
--query.timeout=2m                 # 查询超时时间
--web.max-connections=512          # 最大连接数
```

## 告警规则详解

### 服务状态告警
```yaml
- alert: OTelCollectorDown
  expr: up{job="otel-collector"} == 0
  for: 1m                          # 持续1分钟
  labels:
    severity: critical             # 严重级别
```

### 性能告警
```yaml
- alert: HighErrorRate
  expr: |
    (
      sum(rate(otelcol_exporter_send_failed_spans_total[5m])) /
      sum(rate(otelcol_exporter_sent_spans_total[5m]))
    ) > 0.1                        # 错误率超过10%
  for: 3m
```

### 记录规则
```yaml
- record: otel:span_rate_5m
  expr: rate(otelcol_receiver_accepted_spans_total[5m])
  # 预计算5分钟 span 速率，提高查询性能
```

## 监控指标说明

### OTel Collector 指标
| 指标名称 | 说明 |
|----------|------|
| `otelcol_receiver_accepted_spans_total` | 接收的 span 总数 |
| `otelcol_exporter_sent_spans_total` | 成功导出的 span 总数 |
| `otelcol_exporter_send_failed_spans_total` | 导出失败的 span 总数 |
| `otelcol_processor_dropped_spans_total` | 处理器丢弃的 span 总数 |
| `otelcol_process_memory_rss` | 内存使用量 |

### Tempo 指标
| 指标名称 | 说明 |
|----------|------|
| `tempo_distributor_spans_received_total` | 分发器接收的 span 总数 |
| `tempo_ingester_blocks_flushed_total` | 刷新的块总数 |
| `tempo_request_duration_seconds` | 请求耗时分布 |

### 系统指标
| 指标名称 | 说明 |
|----------|------|
| `up` | 服务存活状态 |
| `scrape_duration_seconds` | 采集耗时 |
| `scrape_samples_scraped` | 采集的样本数 |

## 数据管理

### 数据保留策略
```yaml
# 时间保留：7天
--storage.tsdb.retention.time=7d

# 大小保留：10GB
--storage.tsdb.retention.size=10GB
```

### 数据备份
```bash
# 备份数据目录
docker run --rm -v prometheus_prometheus-storage:/data -v $(pwd):/backup alpine tar czf /backup/prometheus-backup.tar.gz /data

# 恢复数据
docker run --rm -v prometheus_prometheus-storage:/data -v $(pwd):/backup alpine tar xzf /backup/prometheus-backup.tar.gz -C /
```

### 数据清理
```bash
# 手动触发压缩
curl -X POST http://localhost:9090/api/v1/admin/tsdb/snapshot

# 删除指定时间范围的数据
curl -X POST http://localhost:9090/api/v1/admin/tsdb/delete_series?match[]={__name__=~".*"}&start=2024-01-01T00:00:00Z&end=2024-01-02T00:00:00Z
```

## API 使用

### 查询 API
```bash
# 即时查询
curl 'http://localhost:9090/api/v1/query?query=up'

# 范围查询
curl 'http://localhost:9090/api/v1/query_range?query=rate(otelcol_receiver_accepted_spans_total[5m])&start=2024-01-01T00:00:00Z&end=2024-01-01T01:00:00Z&step=15s'

# 查询标签值
curl 'http://localhost:9090/api/v1/label/job/values'
```

### 管理 API
```bash
# 重新加载配置
curl -X POST http://localhost:9090/-/reload

# 健康检查
curl http://localhost:9090/-/healthy

# 准备状态检查
curl http://localhost:9090/-/ready
```

## 故障排除

### 常见问题

1. **目标无法访问**
   ```bash
   # 检查网络连接
   docker exec prometheus ping otel-collector
   docker exec prometheus ping tempo
   ```

2. **配置文件错误**
   ```bash
   # 验证配置语法
   docker run --rm -v $(pwd)/prometheus.yml:/prometheus.yml prom/prometheus:latest promtool check config /prometheus.yml
   ```

3. **告警规则错误**
   ```bash
   # 验证告警规则
   docker run --rm -v $(pwd)/rules:/rules prom/prometheus:latest promtool check rules /rules/*.yml
   ```

4. **存储空间不足**
   ```bash
   # 检查磁盘使用情况
   docker exec prometheus df -h /prometheus
   
   # 查看数据大小
   docker exec prometheus du -sh /prometheus
   ```

### 日志分析
```bash
# 查看详细日志
docker-compose logs prometheus

# 查看启动日志
docker-compose logs prometheus | grep -E "(Starting|Config|Error)"

# 实时监控日志
docker-compose logs -f prometheus
```

## 性能优化

### 查询优化
```promql
# 使用记录规则预计算
otel:span_rate_5m  # 而不是 rate(otelcol_receiver_accepted_spans_total[5m])

# 限制查询范围
up{job="otel-collector"}  # 而不是 up

# 使用聚合减少数据点
sum by (job) (rate(metric[5m]))
```

### 存储优化
```yaml
# 调整采集间隔
scrape_interval: 30s  # 从15s调整到30s

# 减少保留时间
--storage.tsdb.retention.time=3d  # 从7天减少到3天
```

### 内存优化
```yaml
# 限制内存使用
--storage.tsdb.head-chunks-write-queue-size=1000
--query.max-samples=50000000
```

## 集成配置

### Grafana 集成
Prometheus 作为 Grafana 数据源，提供指标查询能力。

### Alertmanager 集成 (可选)
```yaml
# 在 prometheus.yml 中添加
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
```

### 外部存储集成 (可选)
```yaml
remote_write:
  - url: "https://prometheus-remote-write-endpoint/api/v1/write"
```

这个独立的 Prometheus 部署提供了完整的指标收集和监控功能！