# Grafana 可视化平台部署

## 概述

本目录包含 Grafana 可视化平台的独立部署配置，用于查看和分析分布式追踪数据。

## 文件说明

- `docker-compose.yaml` - Docker Compose 部署配置
- `grafana-datasources.yaml` - 数据源配置
- `grafana-dashboards.yaml` - 仪表板提供者配置
- `dashboards/` - 预配置仪表板目录
  - `otel-overview.json` - OpenTelemetry 概览仪表板
- `README.md` - 本说明文档

## 功能特性

### 数据源集成
- **Tempo**: 分布式追踪数据查询
- **Prometheus**: 指标数据和服务图谱
- **OTel Collector**: 采集器指标监控

### 预配置功能
- TraceQL 查询编辑器
- 服务依赖图可视化
- 追踪到日志关联
- 指标到追踪关联

## 部署前准备

### 1. 创建共享网络
```bash
docker network create tracing-network
```

### 2. 确保依赖服务运行
- Tempo (端口 3200)
- Prometheus (端口 9090)
- OTel Collector (端口 8889)

## 快速启动

```bash
# 启动 Grafana
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down
```

## 访问和配置

### 登录信息
- **URL**: http://localhost:3000
- **用户名**: admin
- **密码**: admin

### 首次登录
1. 访问 http://localhost:3000
2. 使用 admin/admin 登录
3. 系统会提示更改密码（可跳过）
4. 数据源会自动配置

## 主要功能

### 1. Explore 页面
```
左侧菜单 → Explore
```
- **Tempo**: 查询追踪数据
- **Prometheus**: 查询指标数据
- **OTel Collector**: 监控采集器状态

### 2. 仪表板
```
左侧菜单 → Dashboards
```
- **OpenTelemetry Overview**: 系统概览
- 可以导入更多社区仪表板

### 3. 服务图谱
```
Explore → Tempo → Service Map
```
- 查看服务间调用关系
- 识别性能瓶颈
- 分析错误传播路径

## TraceQL 查询示例

### 基础查询
```traceql
# 查询所有追踪
{}

# 查询特定服务
{service.name="your-service"}

# 查询慢请求
{duration > 1s}

# 查询错误
{status=error}
```

### 高级查询
```traceql
# 组合条件
{service.name="api-gateway" && duration > 500ms}

# 查询特定操作
{span.name="GET /api/users"}

# 查询包含特定属性
{http.status_code=500}

# 时间范围查询
{service.name="user-service"} | rate() by (service.name)
```

## 数据源配置

### Tempo 配置
```yaml
url: http://tempo:3200
serviceMap:
  datasourceUid: prometheus  # 启用服务图谱
search:
  hide: false                # 启用搜索功能
nodeGraph:
  enabled: true             # 启用节点图
```

### Prometheus 配置
```yaml
url: http://prometheus:9090
exemplarTraceIdDestinations:
  - name: trace_id
    datasourceUid: tempo     # 指标到追踪关联
```

## 仪表板说明

### OpenTelemetry Overview
预配置仪表板包含：
- **Traces Received**: 接收的追踪数量
- **Traces Exported**: 导出的追踪数量
- **Service Map**: 服务依赖关系图
- **Recent Traces**: 最近的追踪数据

### 自定义仪表板
1. 点击 "+" → "Dashboard"
2. 添加面板 (Panel)
3. 选择数据源和查询
4. 配置可视化类型

## 插件管理

### 预装插件
- Clock Panel
- Simple JSON Datasource

### 安装额外插件
```bash
# 进入容器
docker exec -it grafana bash

# 安装插件
grafana-cli plugins install <plugin-name>

# 重启容器
docker-compose restart
```

## 数据持久化

### 数据卷
- `grafana-storage`: 存储配置、仪表板、用户数据

### 备份配置
```bash
# 备份数据卷
docker run --rm -v grafana_grafana-storage:/data -v $(pwd):/backup alpine tar czf /backup/grafana-backup.tar.gz /data

# 恢复数据
docker run --rm -v grafana_grafana-storage:/data -v $(pwd):/backup alpine tar xzf /backup/grafana-backup.tar.gz -C /
```

## 故障排除

### 常见问题

1. **无法连接数据源**
   ```bash
   # 检查网络连接
   docker exec grafana ping tempo
   docker exec grafana ping prometheus
   ```

2. **数据源显示红色**
   - 检查目标服务是否运行
   - 验证网络配置
   - 查看 Grafana 日志

3. **仪表板不显示数据**
   - 确认数据源有数据
   - 检查时间范围设置
   - 验证查询语法

4. **登录问题**
   ```bash
   # 重置管理员密码
   docker exec -it grafana grafana-cli admin reset-admin-password newpassword
   ```

### 日志分析
```bash
# 查看详细日志
docker-compose logs grafana

# 实时监控
docker-compose logs -f grafana

# 查看特定错误
docker-compose logs grafana | grep ERROR
```

## 性能优化

### 内存配置
```yaml
environment:
  - GF_DATABASE_MAX_OPEN_CONN=300
  - GF_DATABASE_MAX_IDLE_CONN=300
```

### 查询优化
- 使用合适的时间范围
- 避免过于复杂的查询
- 合理设置刷新间隔

## 安全配置

### 生产环境建议
```yaml
environment:
  - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
  - GF_SECURITY_SECRET_KEY=${SECRET_KEY}
  - GF_USERS_ALLOW_SIGN_UP=false
  - GF_AUTH_ANONYMOUS_ENABLED=false
```

### HTTPS 配置
```yaml
environment:
  - GF_SERVER_PROTOCOL=https
  - GF_SERVER_CERT_FILE=/etc/ssl/certs/grafana.crt
  - GF_SERVER_CERT_KEY=/etc/ssl/certs/grafana.key
```

这个独立的 Grafana 部署提供了完整的可视化功能，便于独立管理和扩展！ 