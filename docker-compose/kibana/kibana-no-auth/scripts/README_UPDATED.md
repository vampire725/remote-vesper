# 📜 Kibana 脚本使用指南 (无认证版本)

[![Kibana](https://img.shields.io/badge/Kibana-8.15.3-005571?style=flat-square&logo=kibana)](https://www.elastic.co/kibana/)
[![Environment](https://img.shields.io/badge/Environment-Development-yellow?style=flat-square)](LICENSE)

> 🔧 Kibana 无认证版本的管理和维护脚本集合，适用于开发环境快速部署和数据管理。

## 📋 脚本概览

| 脚本名称          | 功能       | 用途                       |
| ----------------- | ---------- | -------------------------- |
| `setup-kibana.sh` | 初始化配置 | 自动创建数据视图和基本配置 |
| `backup.sh`       | 数据备份   | 备份仪表板、可视化和配置   |
| `start.sh`        | 服务启动   | 一键启动 Kibana 无认证版本 |

## 🛠️ 脚本详细说明

### 🎯 setup-kibana.sh

**功能**: Kibana 初始化和配置脚本

**用途**:

- 等待 Kibana 服务完全启动
- 自动创建常用数据视图（Data Views）
- 配置默认设置和时间字段
- 验证服务状态和连接

**使用方法**:

```bash
# 基本初始化（无认证模式）
./scripts/setup-kibana.sh

# 创建示例数据视图
./scripts/setup-kibana.sh --create-sample-data

# 自定义 Kibana URL
./scripts/setup-kibana.sh -k http://localhost:5602

# 指定超时时间
./scripts/setup-kibana.sh -t 600
```

**参数说明**:

- `-h, --help`: 显示帮助信息
- `-k, --kibana-url`: Kibana URL（默认: http://localhost:5602）
- `-e, --es-url`: Elasticsearch URL（默认: http://localhost:9200）
- `-t, --timeout`: 超时时间（默认: 300 秒）
- `--create-sample-data`: 创建示例数据视图

### 💾 backup.sh

**功能**: Kibana 数据备份脚本

**用途**:

- 备份仪表板、可视化图表
- 备份数据视图和保存的搜索
- 备份 Kibana 配置和设置
- 支持压缩备份文件

**使用方法**:

```bash
# 基本备份（无认证模式）
./scripts/backup.sh

# 压缩备份
./scripts/backup.sh --compress

# 自定义备份目录和名称
./scripts/backup.sh -d /backup --name my_backup

# 仅备份配置（不备份数据）
./scripts/backup.sh --no-data
```

**参数说明**:

- `-h, --help`: 显示帮助信息
- `-k, --kibana-url`: Kibana URL（默认: http://localhost:5602）
- `-d, --backup-dir`: 备份目录（默认: ./backups）
- `-n, --name`: 备份名称（默认: kibana_backup_TIMESTAMP）
- `-c, --compress`: 压缩备份文件
- `--no-data`: 不备份数据，仅备份配置

### 🚀 start.sh

**功能**: 一键启动脚本

**用途**:

- 检查前置条件（Docker、网络等）
- 启动 Kibana 无认证版本
- 等待服务完全启动
- 显示访问信息

**使用方法**:

```bash
# 直接启动
./scripts/start.sh

# 查看启动过程
./scripts/start.sh --verbose
```

## 🔧 使用前准备

### 1. 安装依赖工具

**Ubuntu/Debian**:

```bash
sudo apt-get update
sudo apt-get install curl jq
```

**CentOS/RHEL**:

```bash
sudo yum install curl jq
```

**macOS**:

```bash
brew install curl jq
```

**Windows (WSL)**:

```bash
sudo apt update && sudo apt install curl jq
```

### 2. 设置执行权限

```bash
chmod +x scripts/*.sh
```

### 3. 确保服务运行

```bash
# 检查 Elasticsearch（无认证模式）
curl -s http://localhost:9200/_cluster/health

# 检查 Kibana（无认证版本）
curl -s http://localhost:5602/api/status
```

## 📊 脚本功能详解

### 🎯 setup-kibana.sh 详细功能

#### **服务检查**

- 等待 Elasticsearch 和 Kibana 服务启动
- 检查集群健康状态（Green/Yellow/Red）
- 验证 API 连接（无认证模式）

#### **数据视图创建**

自动创建以下数据视图：

- `logstash-*` - Logstash 日志
- `filebeat-*` - Filebeat 日志
- `metricbeat-*` - Metricbeat 指标
- `auditbeat-*` - Auditbeat 审计
- `packetbeat-*` - Packetbeat 网络
- `app-logs-*` - 应用日志
- `nginx-*` - Nginx 日志
- `apache-*` - Apache 日志
- `docker-*` - Docker 容器日志

#### **默认设置**

- 设置 `logstash-*` 为默认数据视图
- 配置时间字段为 `@timestamp`
- 设置开发环境友好的默认配置

### 💾 backup.sh 详细功能

#### **备份内容**

- **数据视图** (Data Views): 索引模式和字段映射
- **仪表板** (Dashboards): 完整的仪表板配置
- **可视化** (Visualizations): 图表和可视化配置
- **保存的搜索** (Saved Searches): 查询和过滤器
- **Lens 可视化**: 新版本的可视化图表
- **地图** (Maps): 地理数据可视化
- **Canvas 工作簿**: Canvas 画布配置
- **Kibana 配置**: 系统设置和配置

#### **备份格式**

- **JSON 格式**: 分类保存各种对象类型
- **NDJSON 格式**: Kibana 标准导出格式
- **元数据**: 备份信息和版本记录

#### **恢复方法**

1. 访问 Kibana: http://localhost:5602
2. 进入 **Stack Management** > **Saved Objects**
3. 点击 **Import** 导入 `kibana_export.ndjson` 文件

### 🚀 start.sh 详细功能

#### **前置条件检查**

- Docker 服务状态
- Docker Compose 可用性
- 网络连通性
- 端口占用检查

#### **启动流程**

- 创建必要的目录
- 检查 Docker 网络
- 启动 Kibana 容器
- 等待服务就绪
- 显示访问信息

## 🚨 注意事项

### ⚠️ **安全注意事项**

1. **开发环境专用**: 这些脚本仅适用于开发和测试环境
2. **无认证访问**: 所有操作都无需认证，注意数据安全
3. **网络访问**: 确保只在受信任的网络环境中使用
4. **数据保护**: 定期备份重要的仪表板和配置

### 💡 **最佳实践**

1. **定期备份**: 建议每日自动备份重要配置
2. **版本控制**: 将重要脚本纳入版本控制
3. **测试验证**: 在使用前先验证脚本功能
4. **日志记录**: 保留脚本执行日志便于问题排查

### 🔍 **故障排除**

1. **连接失败**: 检查服务状态和网络连通性

   ```bash
   # 检查 Kibana 状态
   curl -s http://localhost:5602/api/status

   # 检查容器状态
   docker-compose ps
   ```

2. **端口冲突**: 确认端口 5602 未被占用

   ```bash
   netstat -tlnp | grep 5602
   ```

3. **权限问题**: 确保脚本具有执行权限

   ```bash
   chmod +x scripts/*.sh
   ```

4. **超时问题**: 根据系统性能调整超时时间
   ```bash
   ./scripts/setup-kibana.sh -t 600  # 设置10分钟超时
   ```

## 📝 示例用法

### 🚀 **完整部署流程**

```bash
# 1. 启动服务
./scripts/start.sh

# 2. 等待服务就绪并初始化
./scripts/setup-kibana.sh --create-sample-data

# 3. 创建备份
./scripts/backup.sh --compress
```

### 🔄 **开发环境自动化脚本**

```bash
#!/bin/bash
# 开发环境 Kibana 自动化脚本

# 设置变量
KIBANA_URL="http://localhost:5602"
BACKUP_DIR="./backups"

echo "启动 Kibana 开发环境..."

# 启动服务
./scripts/start.sh

# 等待启动完成
sleep 30

# 初始化配置
./scripts/setup-kibana.sh -k "$KIBANA_URL" --create-sample-data

# 创建备份
./scripts/backup.sh -k "$KIBANA_URL" -d "$BACKUP_DIR" --compress

echo "✅ Kibana 开发环境准备完成"
echo "🌍 访问地址: $KIBANA_URL"
```

### 📋 **定期备份脚本**

```bash
#!/bin/bash
# 定期备份脚本（适用于开发环境）

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="dev_backup_$DATE"

./scripts/backup.sh \
  -k http://localhost:5602 \
  -d ./backups \
  -n "$BACKUP_NAME" \
  --compress

echo "✅ 备份完成: $BACKUP_NAME"
```

## 🔗 相关文档

- 📖 [无认证版本部署指南](../README.md)
- 🔒 [认证版本对比](../../kibana-auth/README.md)
- 🐳 [Docker Compose 配置](../docker-compose.yaml)
- 🌐 [Kibana 官方文档](https://www.elastic.co/guide/en/kibana/current/index.html)

---

📝 **提醒**: 此版本适用于开发环境，如需生产环境部署，请使用认证版本的脚本。
