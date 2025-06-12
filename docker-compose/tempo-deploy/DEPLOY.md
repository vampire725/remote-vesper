# OpenTelemetry 分布式追踪系统部署指南

## 目录结构

```
otel-signal/
├── collector/                    # OpenTelemetry Collector
│   ├── docker-compose.yaml
│   ├── otel-collector-config.yaml
│   └── README.md
├── tempo/                        # Tempo 追踪存储
│   ├── docker-compose.yaml
│   ├── tempo.yaml
│   └── README.md
├── grafana/                      # Grafana 可视化
│   ├── docker-compose.yaml
│   ├── grafana-datasources.yaml
│   ├── grafana-dashboards.yaml
│   ├── dashboards/
│   └── README.md
├── prometheus/                   # Prometheus 指标收集
│   ├── docker-compose.yaml
│   ├── prometheus.yml
│   ├── rules/
│   └── README.md
└── DEPLOY.md                     # 本文档
```

## 部署架构

```
应用程序
    ↓ (OTLP)
OpenTelemetry Collector (4316/4315)
    ↓ (OTLP)
Tempo (4317)
    ↓ (指标)
Prometheus (9090) ← → Grafana (3000)
```

## 完全分离式部署

### 优势
- **独立管理**: 每个组件可以独立启停、升级、扩展
- **资源隔离**: 各组件资源使用互不影响
- **配置独立**: 每个组件有独立的配置文件和文档
- **故障隔离**: 单个组件故障不影响其他组件

## 快速部署

### 1. 创建共享网络
```bash
docker network create tracing-network
```

### 2. 分步启动服务（推荐顺序）

#### 第一步：启动 Prometheus（指标收集）
```bash
cd prometheus
docker-compose up -d
cd ..
```

#### 第二步：启动 Tempo（追踪存储）
```bash
cd tempo
docker-compose up -d
cd ..
```

#### 第三步：启动 Grafana（可视化）
```bash
cd grafana
docker-compose up -d
cd ..
```

#### 第四步：启动 Collector（数据采集）
```bash
cd collector
docker-compose up -d
cd ..
```

### 3. 一键启动（高级用户）
```bash
# 创建启动脚本
cat > start-all.sh << 'EOF'
#!/bin/bash
docker network create tracing-network 2>/dev/null || true
cd prometheus && docker-compose up -d && cd ..
sleep 10
cd tempo && docker-compose up -d && cd ..
sleep 10
cd grafana && docker-compose up -d && cd ..
sleep 10
cd collector && docker-compose up -d && cd ..
echo "所有服务已启动完成！"
EOF

chmod +x start-all.sh
./start-all.sh
```

## 验证部署

### 健康检查
```bash
# Prometheus
curl http://localhost:9090/-/healthy

# Tempo
curl http://localhost:3200/ready

# Grafana 
curl http://localhost:3000/api/health

# OTel Collector
curl http://localhost:13133/
```

### 查看所有容器状态
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### 访问界面
- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **Collector Metrics**: http://localhost:8889/metrics

## 发送测试数据

### 方法1：使用 curl
```bash
curl -X POST http://localhost:4315/v1/traces \
  -H "Content-Type: application/json" \
  -d '{
    "resourceSpans": [{
      "resource": {
        "attributes": [{
          "key": "service.name",
          "value": {"stringValue": "test-service"}
        }, {
          "key": "service.version",
          "value": {"stringValue": "1.0.0"}
        }]
      },
      "instrumentationLibrarySpans": [{
        "instrumentationLibrary": {
          "name": "manual-test"
        },
        "spans": [{
          "traceId": "5B8EFFF798038103D269B633813FC60C",
          "spanId": "EEE19B7EC3C1B174",
          "name": "test-operation",
          "kind": 1,
          "startTimeUnixNano": "'$(date +%s%N)'",
          "endTimeUnixNano": "'$(($(date +%s%N) + 1000000000))'",
          "attributes": [{
            "key": "http.method",
            "value": {"stringValue": "GET"}
          }, {
            "key": "http.url",
            "value": {"stringValue": "http://example.com/api"}
          }],
          "status": {"code": 1}
        }]
      }]
    }]
  }'
```

### 方法2：使用 PowerShell
```powershell
$body = @{
    resourceSpans = @(
        @{
            resource = @{
                attributes = @(
                    @{
                        key = "service.name"
                        value = @{ stringValue = "powershell-test" }
                    }
                )
            }
            instrumentationLibrarySpans = @(
                @{
                    spans = @(
                        @{
                            traceId = "5B8EFFF798038103D269B633813FC60C"
                            spanId = "EEE19B7EC3C1B174"
                            name = "powershell-span"
                            kind = 1
                            startTimeUnixNano = "$(([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()) * 1000000)"
                            endTimeUnixNano = "$((([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()) + 1000) * 1000000)"
                            status = @{ code = 1 }
                        }
                    )
                }
            )
        }
    )
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri "http://localhost:4315/v1/traces" -Method POST -Body $body -ContentType "application/json"
```

## 查看追踪数据

### 在 Grafana 中
1. 访问 http://localhost:3000
2. 登录 (admin/admin)
3. 进入 "Explore"
4. 选择 "Tempo" 数据源
5. 查询: `{service.name="test-service"}`

### 使用 TraceQL 查询
```traceql
# 查询所有 test-service 的追踪
{service.name="test-service"}

# 查询耗时超过100ms的请求
{duration > 100ms}

# 查询包含错误的追踪
{status=error}

# 组合查询
{service.name="test-service" && duration > 100ms}
```

## 网络配置说明

### 共享网络
- **网络名称**: `tracing-network`
- **驱动**: bridge
- **用途**: 容器间通信

### 容器通信
- Collector → Tempo: `tempo:4317`
- Grafana → Tempo: `tempo:3200`
- Grafana → Prometheus: `prometheus:9090`
- Prometheus → Collector: `otel-collector:8889`
- Tempo → Prometheus: `prometheus:9090`

### 端口映射
| 服务 | 宿主机端口 | 容器端口 | 用途 |
|------|------------|----------|------|
| Collector | 4316 | 4317 | OTLP gRPC |
| Collector | 4315 | 4318 | OTLP HTTP |
| Collector | 13133 | 13133 | 健康检查 |
| Collector | 8889 | 8889 | Prometheus 指标 |
| Tempo | 3200 | 3200 | HTTP API |
| Tempo | 4317 | 4317 | OTLP gRPC |
| Grafana | 3000 | 3000 | Web UI |
| Prometheus | 9090 | 9090 | Web UI |

## 部署顺序详解

### 推荐启动顺序
1. **Prometheus** - 指标收集基础设施
2. **Tempo** - 追踪数据存储
3. **Grafana** - 可视化界面（依赖前两者）
4. **Collector** - 数据采集（依赖 Tempo）

### 依赖关系图
```
              ┌─────────────┐
              │ Application │
              └─────────────┘
                     │ OTLP
                     ▼
              ┌─────────────┐
              │  Collector  │◄────┐
              └─────────────┘     │ metrics
                     │ OTLP       │
                     ▼            │
              ┌─────────────┐     │
              │    Tempo    │────►│
              └─────────────┘     │ metrics
                     ▲            │
                     │ query      │
              ┌─────────────┐     │
              │   Grafana   │     │
              └─────────────┘     │
                     ▲            │
                     │ query      │
              ┌─────────────┐     │
              │ Prometheus  │◄────┘
              └─────────────┘
```

## 组件管理

### 独立操作
```bash
# 单独重启某个组件
cd grafana
docker-compose restart

# 单独查看日志
cd collector
docker-compose logs -f

# 单独更新某个组件
cd tempo
docker-compose pull
docker-compose up -d
```

### 批量操作
```bash
# 查看所有服务状态
for service in prometheus tempo grafana collector; do
  echo "=== $service ==="
  cd $service && docker-compose ps && cd ..
done

# 停止所有服务
for service in collector grafana tempo prometheus; do
  cd $service && docker-compose down && cd ..
done
```

## 停止和清理

### 优雅停止（推荐顺序）
```bash
# 按依赖关系反向停止
cd collector && docker-compose down && cd ..
cd grafana && docker-compose down && cd ..
cd tempo && docker-compose down && cd ..
cd prometheus && docker-compose down && cd ..
```

### 完全清理
```bash
# 停止并删除数据卷
cd collector && docker-compose down -v && cd ..
cd grafana && docker-compose down -v && cd ..
cd tempo && docker-compose down -v && cd ..
cd prometheus && docker-compose down -v && cd ..

# 删除网络
docker network rm tracing-network
```

### 清理脚本
```bash
cat > cleanup-all.sh << 'EOF'
#!/bin/bash
echo "停止所有服务..."
for service in collector grafana tempo prometheus; do
  echo "停止 $service..."
  cd $service && docker-compose down -v && cd .. 2>/dev/null
done

echo "删除网络..."
docker network rm tracing-network 2>/dev/null || true

echo "清理完成！"
EOF

chmod +x cleanup-all.sh
./cleanup-all.sh
```

## 故障排除

### 组件间连接问题
```bash
# 检查网络连接
docker exec grafana ping tempo
docker exec grafana ping prometheus
docker exec otel-collector ping tempo
docker exec prometheus ping otel-collector
```

### 启动顺序问题
```bash
# 如果 Grafana 无法连接数据源，重启 Grafana
cd grafana
docker-compose restart

# 如果 Collector 无法连接 Tempo，检查 Tempo 状态
cd tempo
docker-compose logs tempo
```

### 端口冲突检查
```bash
# 检查所有占用的端口
netstat -an | grep -E ":3000|:3200|:4315|:4316|:8889|:9090"
```

## 监控和告警

### Prometheus 监控
- 访问 http://localhost:9090/targets 查看监控目标
- 查看预配置的告警规则
- 监控各组件健康状态

### Grafana 仪表板
- **OpenTelemetry Overview**: 预配置概览仪表板
- 自定义仪表板创建
- 多数据源关联查询

## 扩展配置

### 添加新的数据源
在相应组件目录中修改配置：
- **Collector**: 添加新的 receiver/exporter
- **Grafana**: 添加新的数据源配置
- **Prometheus**: 添加新的 scrape 目标

### 高可用部署
- 部署多个 Tempo 实例
- 配置 Prometheus 联邦
- 使用负载均衡器

## 性能优化建议

### 开发环境
- 使用较小的数据保留时间
- 降低采集频率
- 限制资源使用

### 生产环境
- 配置外部存储（S3、GCS）
- 启用数据压缩
- 配置合适的资源限制
- 启用监控告警

这个完全分离式的部署方案提供了最大的灵活性和可维护性！ 