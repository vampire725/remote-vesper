# Jaeger 链路追踪部署

基于 OpenTelemetry 标准的 Jaeger 分布式链路追踪系统部署方案，使用 Elasticsearch 作为存储后端。

## 架构组件

### 核心服务

1. **Elasticsearch** - 链路数据存储后端
2. **Jaeger Collector** - 收集和处理trace数据，支持OTLP标准
3. **Jaeger Query** - 提供查询API和Web UI
4. **OpenTelemetry Collector** - 统一的遥测数据收集器
5. **Jaeger Agent** (可选) - 本地代理，用于缓冲和批处理

### 管理脚本

- **`start.sh`** - 智能启动脚本，包含环境检查和健康监测
- **`stop.sh`** - 优雅停止脚本，支持数据保留或清理选项
- **`cleanup.sh`** - 完全清理脚本，彻底删除所有相关资源

## 端口映射

### 对外服务端口

| 服务 | 端口 | 协议 | 说明 |
|------|------|------|------|
| Jaeger UI | 16686 | HTTP | Web界面 |
| Elasticsearch | 9200 | HTTP | ES REST API |
| OTel Collector | 4315 | gRPC | OTLP gRPC (推荐) |
| OTel Collector | 4316 | HTTP | OTLP HTTP |
| Jaeger Collector | 4317 | gRPC | OTLP gRPC (直连) |
| Jaeger Collector | 4318 | HTTP | OTLP HTTP (直连) |
| Jaeger Collector | 14268 | HTTP | Jaeger HTTP |
| Jaeger Agent | 6831 | UDP | Jaeger compact |
| Jaeger Agent | 6832 | UDP | Jaeger binary |
| Jaeger Agent | 5778 | HTTP | 配置端口 |

### 监控端口

| 服务 | 端口 | 说明 |
|------|------|------|
| OTel Collector | 8888 | Prometheus指标 |
| OTel Collector | 8889 | 导出器指标 |
| OTel Collector | 13133 | 健康检查 |
| OTel Collector | 55679 | zPages调试 |
| OTel Collector | 1777 | PProf性能分析 |

## 快速开始

### 1. 启动服务

```bash
# 进入部署目录
cd jaeger-deploy

# 使用启动脚本（推荐）
./start.sh -d                  # 后台启动所有服务

# 或使用docker-compose
docker-compose up -d           # 直接启动

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f
```

### 2. 停止服务

```bash
# 使用停止脚本（推荐）
./stop.sh                      # 优雅停止服务

# 停止并删除数据
./stop.sh -v                   # 警告：会删除所有trace数据

# 或使用docker-compose
docker-compose down            # 直接停止
```

### 3. 完全清理

⚠️ **警告：此操作将永久删除所有数据，无法恢复！**

```bash
# 预览将要清理的资源
./cleanup.sh --dry-run

# 完全清理（需要确认）
./cleanup.sh

# 强制清理（跳过确认）
./cleanup.sh -f

# 仅清理特定资源
./cleanup.sh --containers-only   # 仅清理容器
./cleanup.sh --images-only       # 仅清理镜像
./cleanup.sh --volumes-only      # 仅清理数据卷
./cleanup.sh --networks-only     # 仅清理网络

# 清理所有并额外清理未使用资源
./cleanup.sh --all-unused
```

### 4. 验证部署

等待所有服务启动后（大约1-2分钟），访问以下地址验证：

- **Jaeger UI**: http://localhost:16686
- **Elasticsearch**: http://localhost:9200/_cluster/health
- **OTel Collector健康检查**: http://localhost:13133
- **OTel Collector调试页面**: http://localhost:55679/debug/tracez

### 5. 应用程序接入

#### 方式一：通过OTel Collector（推荐）

配置你的应用程序将OTLP数据发送到：
- **gRPC**: `localhost:4315`
- **HTTP**: `localhost:4316`

#### 方式二：直连Jaeger Collector

配置你的应用程序将OTLP数据发送到：
- **gRPC**: `localhost:4317`
- **HTTP**: `localhost:4318`

## 管理脚本详解

### start.sh - 启动脚本

**功能特性：**
- 🔍 环境预检查（Docker、端口、资源）
- 🚀 多种启动模式（前台/后台、开发模式）
- ⏳ 服务健康检查和等待
- 📊 服务状态显示
- 📋 详细的端点信息

**使用示例：**
```bash
./start.sh                     # 前台启动所有服务
./start.sh -d                  # 后台启动
./start.sh -d --logs           # 后台启动并显示日志
./start.sh -f -d               # 强制重启并后台运行
./start.sh --check             # 仅检查环境，不启动
./start.sh --dev               # 开发模式（详细日志）
```

### stop.sh - 停止脚本

**功能特性：**
- 🛑 优雅停止所有服务
- 🗑️ 可选数据卷清理
- ⚡ 强制停止选项
- 📋 剩余资源检查

**使用示例：**
```bash
./stop.sh                      # 停止服务，保留数据
./stop.sh -v                   # 停止服务并删除数据卷
./stop.sh --clean              # 完全清理所有资源
./stop.sh --force              # 强制停止容器
```

### cleanup.sh - 完全清理脚本

**功能特性：**
- 🔍 资源预览模式
- 🗑️ 彻底清理所有相关资源
- ⚠️ 多重安全确认机制
- 🎯 选择性清理选项
- 📊 清理结果统计

**清理范围：**
- ✅ 停止并删除所有相关容器
- ✅ 删除所有相关镜像
- ✅ 删除所有相关网络
- ✅ 删除所有相关数据卷
- ✅ 可选清理未使用的Docker资源

**安全特性：**
- 🔒 需要输入 `yes` 确认执行
- 🔍 `--dry-run` 预览模式
- ⚡ `--force` 跳过确认
- 🎯 分类清理选项

**使用示例：**
```bash
./cleanup.sh --dry-run         # 预览要清理的资源
./cleanup.sh                   # 完整清理（需要确认）
./cleanup.sh -f                # 强制清理
./cleanup.sh --containers-only # 仅清理容器
./cleanup.sh --all-unused      # 清理所有+未使用资源
```

## 配置说明

### 环境变量

可以通过修改`docker-compose.yml`中的环境变量来调整配置：

#### Elasticsearch
- `ES_JAVA_OPTS`: JVM参数，默认512MB堆内存
- `bootstrap.memory_lock=true`: 锁定内存避免交换

#### Jaeger
- `ES_NUM_SHARDS`: ES分片数，默认1
- `ES_NUM_REPLICAS`: ES副本数，默认0
- `LOG_LEVEL`: 日志级别，默认info

### OTel Collector配置

配置文件: `otel-collector-config.yml`

主要配置项：
- **receivers**: 配置数据接收器（OTLP、Jaeger、Zipkin）
- **processors**: 数据处理器（批处理、内存限制、属性修改）
- **exporters**: 数据导出器（Jaeger、日志、Prometheus）

## 数据流向

```
应用程序 → OTel Collector → Jaeger Collector → Elasticsearch → Jaeger Query → Jaeger UI
```

## 存储管理

### Elasticsearch数据

数据存储在Docker volume `elasticsearch_data`中：

```bash
# 查看volume
docker volume ls | grep elasticsearch

# 清理数据（注意：会删除所有trace数据）
docker-compose down -v

# 使用清理脚本
./cleanup.sh --volumes-only
```

### 索引管理

Jaeger会自动在Elasticsearch中创建以下索引：
- `jaeger-service-*`: 服务信息
- `jaeger-span-*`: Span数据
- `jaeger-dependencies-*`: 服务依赖关系

## 性能调优

### 1. Elasticsearch

```yaml
environment:
  - "ES_JAVA_OPTS=-Xms1g -Xmx1g"  # 增加堆内存
```

### 2. OTel Collector

```yaml
# 在otel-collector-config.yml中调整
processors:
  batch:
    send_batch_size: 2048  # 增加批处理大小
    timeout: 2s            # 增加超时时间
```

### 3. Jaeger Collector

```yaml
environment:
  - ES_NUM_SHARDS=2      # 增加分片数
  - ES_NUM_REPLICAS=1    # 增加副本数
```

## 故障排除

### 1. 检查服务状态

```bash
# 查看所有服务状态
docker-compose ps

# 查看特定服务日志
docker-compose logs jaeger-collector
docker-compose logs elasticsearch

# 使用脚本检查
./start.sh --check
```

### 2. 常见问题

#### Elasticsearch启动失败
- 检查内存设置
- 确保vm.max_map_count设置足够大（Linux）:
  ```bash
  sudo sysctl -w vm.max_map_count=262144
  ```

#### Jaeger Collector连接ES失败
- 等待ES完全启动
- 检查网络连接：`docker exec jaeger-collector curl -f http://elasticsearch:9200`

#### 数据不显示在UI中
- 检查时间范围设置
- 验证数据是否正确发送到collector
- 查看collector和query服务日志

#### 端口冲突
```bash
# 检查端口占用
./start.sh --check

# 或手动检查
netstat -tuln | grep :16686
```

#### 完全重置环境
```bash
# 完全清理并重新开始
./cleanup.sh -f
./start.sh -d
```

## 监控和告警

### Prometheus指标

OTel Collector暴露Prometheus指标在端口8888和8889：

- `otelcol_receiver_accepted_spans`: 接收的span数量
- `otelcol_processor_batch_batch_send_size`: 批处理大小
- `otelcol_exporter_sent_spans`: 导出的span数量

### 健康检查

```bash
# OTel Collector健康检查
curl http://localhost:13133

# Elasticsearch健康检查
curl http://localhost:9200/_cluster/health

# 使用脚本检查
./start.sh --check
```

## 高可用部署

对于生产环境，建议：

1. **Elasticsearch集群**: 部署多节点ES集群
2. **多个Collector实例**: 使用负载均衡器分发流量
3. **Jaeger组件分离**: 将collector和query分离部署
4. **数据备份**: 配置ES数据备份策略

## 安全配置

生产环境建议启用：

1. **Elasticsearch安全**:
   ```yaml
   environment:
     - xpack.security.enabled=true
     - ELASTIC_PASSWORD=your_password
   ```

2. **TLS加密**:
   - 配置collector和jaeger之间的TLS
   - 使用HTTPS访问Jaeger UI

3. **网络隔离**:
   - 使用内部网络
   - 限制对外暴露的端口

## 升级和维护

### 升级步骤

1. 备份ES数据
2. 更新镜像版本
3. 重新部署服务
4. 验证功能正常

```bash
# 停止服务
./stop.sh

# 拉取新镜像
docker-compose pull

# 启动服务
./start.sh -d
```

### 维护操作

```bash
# 查看资源使用情况
docker system df

# 清理未使用资源
./cleanup.sh --all-unused

# 查看服务日志
docker-compose logs -f [服务名]

# 重启特定服务
docker-compose restart [服务名]
```
