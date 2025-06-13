# OpenTelemetry Collector 部署

## 概述

本目录包含 OpenTelemetry Collector 的独立部署配置。

## 文件说明

- `docker-compose.yaml` - Docker Compose 部署配置
- `otel-collector-config.yaml` - Collector 配置文件
- `README.md` - 本说明文档

## 部署前准备

### 1. 创建共享网络
```bash
docker network create tracing-network
```

### 2. 确保Tempo服务已启动
Collector 会将追踪数据发送到 Tempo，请确保 Tempo 服务已经启动并在 `tracing-network` 网络中。

## 快速启动

```bash
# 启动服务
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down
```

## 端口说明

| 端口 | 用途 |
|------|------|
| 4316 | OTLP gRPC 接收器 |
| 4315 | OTLP HTTP 接收器 |
| 8888 | 内部指标 |
| 8889 | Prometheus 指标导出 |
| 13133 | 健康检查 |
| 1777 | pprof 性能分析 |

## 验证部署

### 1. 健康检查
```bash
curl http://localhost:13133/
```

### 2. 查看指标
```bash
curl http://localhost:8889/metrics
```

### 3. 发送测试数据
```bash
curl -X POST http://localhost:4315/v1/traces \
  -H "Content-Type: application/json" \
  -d '{
    "resourceSpans": [{
      "resource": {
        "attributes": [{
          "key": "service.name",
          "value": {"stringValue": "test-service"}
        }]
      },
      "instrumentationLibrarySpans": [{
        "spans": [{
          "traceId": "5B8EFFF798038103D269B633813FC60C",
          "spanId": "EEE19B7EC3C1B174",
          "name": "test-span",
          "kind": 1,
          "startTimeUnixNano": "'$(date +%s%N)'",
          "endTimeUnixNano": "'$(($(date +%s%N) + 1000000000))'",
          "status": {"code": 1}
        }]
      }]
    }]
  }'
```

## 配置说明

### 主要特性
- **内存限制**: 512MB 限制，防止内存溢出
- **批处理**: 优化传输性能
- **重试机制**: 处理网络故障
- **健康检查**: 监控服务状态
- **指标导出**: Prometheus 格式指标

### 处理器链
1. `memory_limiter` - 内存限制
2. `resource` - 资源属性增强
3. `batch` - 批处理优化

### 支持协议
- OTLP gRPC (推荐)
- OTLP HTTP
- 未来可扩展支持 Jaeger、Zipkin 等

## 故障排除

### 常见问题

1. **配置解析错误 - "the logging exporter has been deprecated"**

   **问题**: 在新版本的 OpenTelemetry Collector 中，`logging` exporter 已被弃用

   **解决方案**:
   ```yaml
   # ❌ 旧配置 (已弃用)
   exporters:
     logging:
       loglevel: info
   
   # ✅ 新配置 (推荐)
   exporters:
     debug:
       verbosity: detailed
       sampling_initial: 100
       sampling_thereafter: 100
   ```

   **说明**:
   - `debug` exporter 提供了更好的调试功能
   - `verbosity` 可设置为 `basic`、`normal`、`detailed`
   - 在 pipelines 中也需要相应更新：`exporters: [debug]`

2. **配置错误 - "'check_interval' must be greater than zero"**

   **问题**: `memory_limiter` 处理器缺少必需的 `check_interval` 参数

   **解决方案**:
   ```yaml
   # ❌ 错误配置 (缺少 check_interval)
   processors:
     memory_limiter:
       limit_mib: 512
       spike_limit_mib: 100
   
   # ✅ 正确配置 (包含 check_interval)
   processors:
     memory_limiter:
       check_interval: 1s        # 必需参数，内存检查间隔
       limit_mib: 512           # 内存限制
       spike_limit_mib: 100     # 峰值限制
   ```

   **参数说明**:
   - `check_interval`: 内存使用检查频率，推荐 1s
   - `limit_mib`: 软限制，达到后开始拒绝新数据
   - `spike_limit_mib`: 硬限制，超过后立即拒绝

3. **无法连接到 Tempo**
   ```bash
   # 检查网络连接
   docker exec otel-collector ping tempo
   ```

4. **内存使用过高**
   - 调整 `memory_limiter` 配置
   - 减少 `send_batch_size`

5. **数据丢失**
   - 检查 `retry_on_failure` 配置
   - 查看 Collector 日志

### 日志分析
```bash
# 查看详细日志
docker-compose logs otel-collector | grep ERROR

# 实时监控
docker-compose logs -f otel-collector
``` 