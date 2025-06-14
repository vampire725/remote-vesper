# Scripts 目录概览

这个目录包含了管理 OpenTelemetry 分布式追踪系统的所有脚本。

## 🚀 快速开始

```bash
# 1. 进入scripts目录
cd tempo-deploy/scripts

# 2. 启动系统
./start-all.sh

# 3. 发送测试数据
./send-test-data.sh

# 4. 查看状态
./status.sh
```

## 📋 脚本分类

### 🏗️ 系统管理
- `start-all.sh` - 完整启动系统
- `start-existing.sh` - 快速启动已有容器  
- `stop-all.sh` - 停止所有服务
- `cleanup.sh` - 完全清理系统

### 📊 监控检查
- `status.sh` - 查看系统状态
- `health-check.sh` - 健康检查
- `logs.sh` - 查看服务日志

### 🧪 数据测试
- `send-test-data.sh` - 发送简单测试数据
- `generate-trace-data.sh` - 生成大量追踪数据
- `generate-service-graph.sh` - 生成服务图数据
- `quick-trace-test.sh` - 快速追踪测试

### 🔍 验证工具
- `check-service-graph.sh` - 检查服务图
- `check-tempo-metrics.sh` - 检查Tempo指标
- `check-grafana-config.sh` - 检查Grafana配置 🆕

## 📖 详细文档

完整的使用指南请查看：[SCRIPTS-GUIDE.md](./SCRIPTS-GUIDE.md)

**新版Grafana用户请查看：** [GRAFANA-DRILLDOWN-GUIDE.md](./GRAFANA-DRILLDOWN-GUIDE.md) 🆕

## ⚠️ 重要提醒

**所有脚本必须在 `tempo-deploy/scripts/` 目录下执行！** 