# OpenTelemetry 分布式追踪系统

一套完整的 OpenTelemetry 分布式追踪系统 Docker 部署方案，包含 Collector、Tempo、Grafana 和 Prometheus。

## 📁 项目结构

```
tempo-deploy/
├── scripts/                      # 🔧 管理脚本目录
│   ├── start-all.sh              # 完整启动系统
│   ├── start-existing.sh         # 快速启动已有容器
│   ├── stop-all.sh               # 停止所有服务
│   ├── cleanup.sh                # 完全清理系统
│   ├── status.sh                 # 查看系统状态
│   ├── logs.sh                   # 查看服务日志
│   ├── send-test-data.sh         # 发送简单测试数据
│   ├── generate-trace-data.sh    # 生成大量追踪数据 🆕
│   ├── generate-service-graph.sh # 生成服务图数据 🆕
│   ├── check-service-graph.sh    # 检查服务图
│   └── SCRIPTS-GUIDE.md          # 详细脚本使用指南
├── collector/                    # OpenTelemetry Collector 配置
├── tempo/                        # Tempo 追踪存储配置
├── grafana/                      # Grafana 可视化配置
├── prometheus/                   # Prometheus 指标收集配置
└── README.md                     # 本文档
```

## 🚀 快速开始

### 1. 进入脚本目录
```bash
cd tempo-deploy/scripts
```

### 2. 一键启动系统
```bash
./start-all.sh
```

### 3. 发送测试数据
```bash
./send-test-data.sh
```

### 4. 访问服务
- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **Tempo**: http://localhost:3200

## 📖 使用说明

### 🎯 常用命令
```bash
# 进入脚本目录（必须！）
cd tempo-deploy/scripts

# 完整启动
./start-all.sh

# 快速启动（使用现有容器）
./start-existing.sh

# 查看状态
./status.sh

# 查看日志
./logs.sh [服务名]

# 停止服务（保留数据）
./stop-all.sh

# 完全清理（删除所有数据）
./cleanup.sh
```

### 🆕 数据生成命令
```bash
# 快速验证系统
./send-test-data.sh

# 生成大量追踪数据（压力测试）
./generate-trace-data.sh -b 50 -s 20

# 生成服务图数据（拓扑演示）
./generate-service-graph.sh -p ecommerce

# 持续数据生成（演示模式）
./generate-trace-data.sh -c &

# 检查服务图状态
./check-service-graph.sh
```

### ⚠️ 重要提醒
- **所有脚本必须在 `scripts/` 目录下执行**
- 确保 Docker 已启动
- 端口 3000、3200、4315、4316、8889、9090、13133 需要空闲

## 🔧 故障排除

1. **脚本无法执行**: 检查是否在 `scripts/` 目录中
2. **端口被占用**: 运行 `./stop-all.sh` 停止服务
3. **服务启动失败**: 运行 `./logs.sh [服务名]` 查看日志
4. **服务图不显示**: 运行 `./check-service-graph.sh` 诊断

## 📚 详细文档

查看 [`scripts/SCRIPTS-GUIDE.md`](scripts/SCRIPTS-GUIDE.md) 获取完整的脚本使用指南。

## 🎉 系统特性

- ✅ 完全容器化部署
- ✅ 一键启动和停止
- ✅ 自动健康检查
- ✅ 服务图可视化
- ✅ 分布式追踪收集
- ✅ 指标监控集成
- ✅ 简单测试数据生成
- ✅ 大量追踪数据生成 🆕
- ✅ 复杂服务拓扑生成 🆕
- ✅ 详细故障排除

## 🆕 数据生成器功能

### generate-trace-data.sh - 追踪数据生成器
- 📊 支持批量生成大量追踪数据
- 🎯 包含14种不同类型的服务
- 🔄 模拟18种真实API操作
- ⚡ 可配置错误率和生成频率
- 🔄 支持持续生成模式

### generate-service-graph.sh - 服务图生成器
- 🏗️ 4种预定义业务拓扑（电商、微服务、数据管道、可观测性）
- 🔗 真实的服务间调用关系
- 📊 自动验证服务图生成
- ⚙️ 灵活的配置选项
- 📈 实时生成进度监控

### 使用场景
- **快速验证**: `./send-test-data.sh`
- **压力测试**: `./generate-trace-data.sh -b 100 -s 50 -c`
- **架构演示**: `./generate-service-graph.sh -p ecommerce -v`
- **长期监控**: `./generate-trace-data.sh -c &` 