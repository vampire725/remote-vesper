# OpenTelemetry 管理脚本使用指南

## 脚本概览

本目录包含了一套完整的 OpenTelemetry 分布式追踪系统管理脚本，让您能够轻松部署、管理和监控整个系统。

## 📁 目录结构

```
tempo-deploy/
├── scripts/                       # 管理脚本目录
│   ├── start-all.sh              # 完整启动系统
│   ├── start-existing.sh         # 快速启动已有容器
│   ├── stop-all.sh               # 停止所有服务
│   ├── cleanup.sh                # 完全清理系统
│   ├── status.sh                 # 查看系统状态
│   ├── logs.sh                   # 查看服务日志
│   ├── health-check.sh           # 系统健康检查
│   ├── send-test-data.sh         # 发送简单测试数据
│   ├── generate-trace-data.sh    # 生成大量追踪数据
│   ├── generate-service-graph.sh # 生成服务图数据
│   ├── check-service-graph.sh    # 检查服务图
│   ├── check-tempo-metrics.sh    # 检查Tempo指标
│   ├── quick-trace-test.sh       # 快速追踪测试
│   └── SCRIPTS-GUIDE.md          # 本文档
├── collector/                    # OpenTelemetry Collector
├── tempo/                        # Tempo 追踪存储
├── grafana/                      # Grafana 可视化
├── prometheus/                   # Prometheus 指标收集
└── README.md                     # 项目文档
```

## 📋 脚本清单

### 核心管理脚本
| 脚本名称 | 功能描述 | 使用场景 |
|----------|----------|----------|
| `start-all.sh` | 完整启动系统 | 从零开始部署，首次安装 |
| `start-existing.sh` | 快速启动已有容器 | 重启系统，使用现有数据 |
| `stop-all.sh` | 停止所有服务 | 暂停系统，保留数据 |
| `cleanup.sh` | 完全清理系统 | 彻底删除，重新开始 |
| `status.sh` | 查看系统状态 | 监控和诊断 |
| `logs.sh` | 查看服务日志 | 故障排除和调试 |
| `health-check.sh` | 系统健康检查 | 快速验证服务状态 |

### 数据生成和测试脚本
| 脚本名称 | 功能描述 | 使用场景 |
|----------|----------|----------|
| `send-test-data.sh` | 发送简单测试数据 | 快速验证系统功能 |
| `generate-trace-data.sh` | 生成大量追踪数据 | 压力测试、性能评估 |
| `generate-service-graph.sh` | 生成服务图数据 | 创建复杂服务拓扑 |
| `quick-trace-test.sh` | 快速追踪测试 | 验证数据格式修复 |

### 验证和检查脚本
| 脚本名称 | 功能描述 | 使用场景 |
|----------|----------|----------|
| `check-service-graph.sh` | 检查服务图 | 验证服务图生成 |
| `check-tempo-metrics.sh` | 检查Tempo指标 | 调试指标显示问题 |

## 🚀 快速开始

### 1. 进入脚本目录
```bash
cd tempo-deploy/scripts
```

### 2. 首次部署
```bash
./start-all.sh
```
这个脚本会：
- ✅ 创建 Docker 网络
- ✅ 拉取最新镜像
- ✅ 按正确顺序启动所有服务
- ✅ 执行健康检查
- ✅ 显示访问信息

### 3. 发送测试数据
```bash
./send-test-data.sh
```
发送模拟的分布式追踪数据，生成服务图用于演示。

### 4. 查看系统状态
```bash
./status.sh
```
显示完整的系统状态概览。

## 📋 详细使用说明

⚠️ **重要提醒**: 所有脚本必须在 `tempo-deploy/scripts/` 目录下执行！

### start-all.sh - 完整启动脚本
**功能**: 从零开始部署整个系统

**使用方法**:
```bash
cd tempo-deploy/scripts
./start-all.sh
```

**执行过程**:
1. 检查目录结构和配置文件
2. 创建 Docker 网络 `tracing-network`
3. 按依赖顺序启动服务：
   - Prometheus (指标收集)
   - Tempo (追踪存储)
   - Grafana (可视化)
   - OpenTelemetry Collector (数据采集)
4. 执行健康检查
5. 显示访问信息和后续步骤

**预期耗时**: 3-5分钟

### start-existing.sh - 快速启动脚本
**功能**: 启动已存在的容器，无需重新构建

**使用方法**:
```bash
cd tempo-deploy/scripts
./start-existing.sh
```

**执行过程**:
1. 检查现有容器状态
2. 提示缺少的容器
3. 按顺序启动现有容器
4. 快速健康检查

**适用场景**:
- 系统已停止，需要重新启动
- 保留现有数据和配置
- 快速恢复服务

**预期耗时**: 1-2分钟

### health-check.sh - 健康检查脚本
**功能**: 快速检查所有服务健康状态

**使用方法**:
```bash
cd tempo-deploy/scripts
./health-check.sh
```

**检查项目**:
- 🏥 服务运行状态
- 🌐 网络连接性
- 📊 端点响应性
- 🔄 服务图功能

### 数据生成脚本详解

#### send-test-data.sh - 基础测试数据
**功能**: 发送预定义的测试追踪数据

**使用方法**:
```bash
cd tempo-deploy/scripts
./send-test-data.sh
```

**生成数据**:
- 前端服务 → API网关
- 用户服务 → 数据库
- 错误追踪示例

#### generate-trace-data.sh - 批量数据生成
**功能**: 生成大量测试追踪数据

**使用方法**:
```bash
cd tempo-deploy/scripts
./generate-trace-data.sh                # 使用默认参数
./generate-trace-data.sh -b 20 -s 10   # 20批次，每批次10个追踪
./generate-trace-data.sh -c             # 持续生成模式
```

**参数说明**:
- `-b, --batches N`: 批次数量 (默认: 10)
- `-s, --size N`: 每批次追踪数 (默认: 5)
- `-c, --continuous`: 持续生成模式
- `-h, --help`: 显示帮助信息

#### generate-service-graph.sh - 服务图数据生成
**功能**: 生成复杂的服务拓扑追踪数据

**使用方法**:
```bash
cd tempo-deploy/scripts
./generate-service-graph.sh                        # 生成所有拓扑
./generate-service-graph.sh -p ecommerce          # 生成电商拓扑
./generate-service-graph.sh -c 20 -t 100          # 20周期，每周期100追踪
./generate-service-graph.sh -v                    # 生成并验证
```

**参数说明**:
- `-c, --cycles N`: 生成周期数 (默认: 5)
- `-t, --traces N`: 每周期追踪数 (默认: 5)
- `-i, --interval N`: 周期间隔秒数 (默认: 10)
- `-p, --topology TYPE`: 拓扑类型 (ecommerce|microservices|data-pipeline|observability|all)
- `-v, --verify`: 生成后验证服务图

**可用拓扑类型**:
- `ecommerce`: 电商业务流程
- `microservices`: 微服务架构
- `data-pipeline`: 数据处理管道
- `observability`: 监控和日志流程

#### quick-trace-test.sh - 快速验证
**功能**: 快速验证追踪数据格式和发送

**使用方法**:
```bash
cd tempo-deploy/scripts
./quick-trace-test.sh
```

### 验证脚本详解

#### check-service-graph.sh - 服务图验证
**功能**: 检查服务图生成状态

**使用方法**:
```bash
cd tempo-deploy/scripts
./check-service-graph.sh
```

**检查项目**:
- Tempo服务图指标
- Prometheus数据可用性
- Grafana仪表板状态
- 服务关系展示

#### check-tempo-metrics.sh - 指标检查
**功能**: 检查Tempo暴露的指标

**使用方法**:
```bash
cd tempo-deploy/scripts
./check-tempo-metrics.sh
```

**输出信息**:
- 追踪接收指标
- OTLP相关指标
- 服务图指标
- HTTP接收器指标

## 🌐 服务访问信息

启动成功后，可以通过以下地址访问各服务：

| 服务 | 地址 | 用途 | 登录信息 |
|------|------|------|----------|
| Grafana | http://localhost:3000 | 可视化界面 | admin/admin |
| Prometheus | http://localhost:9090 | 指标查询 | 无需登录 |
| OTel Collector | http://localhost:13133 | 健康检查 | 无需登录 |
| Tempo | http://localhost:3200 | 追踪API | 无需登录 |

### 数据端点

| 端点 | 协议 | 用途 |
|------|------|------|
| localhost:4316 | OTLP gRPC | 发送追踪数据 |
| localhost:4318 | OTLP HTTP | 发送追踪数据 |
| localhost:8889 | HTTP | Collector 指标 |

### 🆕 新版Grafana界面使用指南

如果您在Grafana中看到 "Explore Metrics, Logs, Traces and Profiles have moved!" 的提示，说明您使用的是较新版本的Grafana。

**新版本访问方式:**
1. 登录Grafana: http://localhost:3000 (admin/admin)
2. 查找以下菜单选项之一：
   - 左侧菜单 → **Drilldown** 
   - 左侧菜单 → **Drilldown apps**
   - 左侧菜单 → **Apps** → **Drilldown**
3. 在Drilldown界面中：
   - 选择 **Tempo** 数据源
   - 点击 **Service Map** 标签查看服务图
   - 使用TraceQL查询追踪数据

**检查新版本配置:**
```bash
cd tempo-deploy/scripts
./check-grafana-config.sh  # 检查Grafana配置和版本兼容性
```

## ⚠️ 注意事项

### 执行目录要求
**所有脚本必须在 `tempo-deploy/scripts/` 目录下执行**，因为脚本中使用了相对路径来访问各个服务的配置目录。

错误示例：
```bash
# ❌ 错误 - 在根目录执行
cd tempo-deploy
./scripts/start-all.sh  # 会找不到服务目录
```

正确示例：
```bash
# ✅ 正确 - 在scripts目录执行
cd tempo-deploy/scripts
./start-all.sh          # 正常工作
```

### Windows 用户
在 Windows 上运行这些脚本需要：
1. Git Bash 或 WSL 环境
2. Docker Desktop 已安装并运行
3. curl 命令可用

### 端口占用
确保以下端口未被占用：
- 3000 (Grafana)
- 3200 (Tempo)
- 4318/4316 (OTel Collector)
- 8889 (Collector Metrics)
- 9090 (Prometheus)
- 13133 (Collector Health)

### 资源要求
- 最少 4GB 内存
- 2GB 可用磁盘空间
- Docker 引擎正常运行

## 🔧 常见问题解决

### 问题：HTTP 400错误 🆕
**症状**: 生成追踪数据时出现"批次 X 发送失败 (HTTP 400)"

**解决方案**:
```bash
# 1. 使用修复版本的测试脚本
./quick-trace-test.sh

# 2. 检查数据格式
./check-tempo-metrics.sh

# 3. 如果仍有问题，重启Collector
cd ../collector && docker-compose restart otel-collector
```

**原因**: 数据格式问题已在最新版本中修复

### 问题：服务图不显示数据 🆕
**症状**: Grafana服务图为空

**解决方案**:
```bash
# 1. 检查服务图状态
./check-service-graph.sh

# 2. 重新生成服务图数据
./generate-service-graph.sh -p ecommerce -v

# 3. 等待数据处理
sleep 120

# 4. 检查Tempo配置
cd ../tempo && docker-compose logs tempo | tail -20
```

### 问题：指标显示"未找到" 🆕
**症状**: 验证脚本显示"未在Tempo中找到追踪指标"

**解决方案**:
```bash
# 1. 检查实际指标名称
./check-tempo-metrics.sh

# 2. 如果Tempo运行正常，这只是显示问题
curl -s http://localhost:3200/ready
```

**说明**: 这通常是显示问题，如果HTTP返回200且Tempo健康检查通过，数据已正确处理

### 问题：TraceQL metrics not configured 🆕
**症状**: 在Grafana Drilldown > Traces中出现错误："localblocks processor not found"

**解决方案**:
```bash
# 自动修复local-blocks处理器配置
./fix-drilldown-traceql.sh
```

**原因**: 新版Grafana Drilldown需要Tempo配置local-blocks处理器来支持TraceQL metrics查询

## 🎯 推荐工作流程

### 日常开发流程
```bash
# 1. 启动系统
cd tempo-deploy/scripts
./start-existing.sh

# 2. 健康检查
./health-check.sh

# 3. 生成测试数据
./send-test-data.sh

# 4. 检查服务图
./check-service-graph.sh
```

### 演示准备流程
```bash
# 1. 完整部署
cd tempo-deploy/scripts
./cleanup.sh && ./start-all.sh

# 2. 生成丰富的服务图数据
./generate-service-graph.sh -p all -c 10 -v

# 3. 等待数据处理
sleep 180

# 4. 验证展示效果
./check-service-graph.sh
```

### 故障排除流程
```bash
# 1. 查看系统状态
cd tempo-deploy/scripts
./status.sh

# 2. 检查健康状态
./health-check.sh

# 3. 查看服务日志
./logs.sh all -e

# 4. 如果问题严重，重新部署
./cleanup.sh && ./start-all.sh
```

## 🚀 快速命令参考

```bash
# 完整部署流程
cd tempo-deploy/scripts && \
./start-all.sh && \
sleep 60 && \
./send-test-data.sh

# 快速重启流程
cd tempo-deploy/scripts && \
./stop-all.sh && \
./start-existing.sh

# 服务图演示流程
cd tempo-deploy/scripts && \
./generate-service-graph.sh -p ecommerce -c 20 && \
./check-service-graph.sh

# 故障诊断流程
cd tempo-deploy/scripts && \
./status.sh && \
./health-check.sh && \
./logs.sh all -e

# 数据生成测试流程
cd tempo-deploy/scripts && \
./quick-trace-test.sh && \
./generate-trace-data.sh -b 10 -s 5

# 检查Grafana新版本配置
cd tempo-deploy/scripts && \
./check-grafana-config.sh

# 完全重置流程
cd tempo-deploy/scripts && \
./cleanup.sh && \
./start-all.sh
```