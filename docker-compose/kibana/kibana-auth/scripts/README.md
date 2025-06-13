# 📜 Kibana 辅助脚本说明

本目录包含用于 Kibana 管理和维护的辅助脚本。

## 📁 脚本列表

### 🚀 setup-kibana.sh

**功能**: Kibana 初始化设置脚本

**用途**:

- 等待 Elasticsearch 和 Kibana 服务启动
- 检查服务健康状态
- 自动创建常用数据视图
- 设置默认数据视图

**使用方法**:

```bash
# 基本使用（无认证）
./scripts/setup-kibana.sh

# 使用认证
./scripts/setup-kibana.sh -p your_password

# 创建示例数据视图
./scripts/setup-kibana.sh -p your_password --create-sample-data

# 自定义 URL
./scripts/setup-kibana.sh -k http://kibana:5601 -e http://es01:9200
```

**参数说明**:

- `-h, --help`: 显示帮助信息
- `-u, --username`: Elasticsearch 用户名（默认: elastic）
- `-p, --password`: Elasticsearch 密码
- `-k, --kibana-url`: Kibana URL（默认: http://localhost:5601）
- `-e, --es-url`: Elasticsearch URL（默认: http://localhost:9200）
- `-t, --timeout`: 超时时间（默认: 300 秒）
- `--no-ssl`: 禁用 SSL 验证
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
# 基本备份
./scripts/backup.sh -p your_password

# 压缩备份
./scripts/backup.sh -p your_password --compress

# 自定义备份目录和名称
./scripts/backup.sh -d /backup --name my_backup

# 仅备份配置（不备份数据）
./scripts/backup.sh --no-data
```

**参数说明**:

- `-h, --help`: 显示帮助信息
- `-u, --username`: Kibana 用户名（默认: elastic）
- `-p, --password`: Kibana 密码
- `-k, --kibana-url`: Kibana URL（默认: http://localhost:5601）
- `-d, --backup-dir`: 备份目录（默认: ./backups）
- `-n, --name`: 备份名称（默认: kibana_backup_TIMESTAMP）
- `-c, --compress`: 压缩备份文件
- `--no-data`: 不备份数据，仅备份配置
- `--no-ssl`: 禁用 SSL 验证

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

### 2. 设置执行权限

```bash
chmod +x scripts/*.sh
```

### 3. 确保服务运行

```bash
# 检查 Elasticsearch
curl -k -u elastic:password https://localhost:9200/_cluster/health

# 检查 Kibana
curl -s http://localhost:5601/api/status
```

## 📊 脚本功能详解

### 🎯 setup-kibana.sh 详细功能

#### **服务检查**

- 等待 Elasticsearch 和 Kibana 服务启动
- 检查集群健康状态（Green/Yellow/Red）
- 验证 API 连接和认证

#### **数据视图创建**

自动创建以下数据视图：

- `logstash-*` - Logstash 日志
- `filebeat-*` - Filebeat 日志
- `metricbeat-*` - Metricbeat 指标
- `auditbeat-*` - Auditbeat 审计
- `packetbeat-*` - Packetbeat 网络
- `winlogbeat-*` - Windows 日志
- `app-logs-*` - 应用日志
- `nginx-*` - Nginx 日志
- `apache-*` - Apache 日志

#### **默认设置**

- 设置 `logstash-*` 为默认数据视图
- 配置时间字段为 `@timestamp`

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

1. 访问 Kibana: http://localhost:5601
2. 进入 **Stack Management** > **Saved Objects**
3. 点击 **Import** 导入 `kibana_export.ndjson` 文件

## 🚨 注意事项

### ⚠️ **安全注意事项**

1. **密码保护**: 不要在命令行中明文传递密码
2. **权限控制**: 确保脚本文件权限设置正确
3. **网络安全**: 在生产环境中限制脚本访问权限

### 💡 **最佳实践**

1. **定期备份**: 建议每日自动备份重要配置
2. **版本控制**: 将重要脚本纳入版本控制
3. **测试验证**: 在生产环境使用前先在测试环境验证
4. **日志记录**: 保留脚本执行日志便于问题排查

### 🔍 **故障排除**

1. **连接失败**: 检查服务状态和网络连通性
2. **认证错误**: 验证用户名密码正确性
3. **权限问题**: 确保用户具有相应的操作权限
4. **超时问题**: 根据网络情况调整超时时间

## 📝 示例用法

### 🚀 **完整部署流程**

```bash
# 1. 启动服务
docker-compose up -d

# 2. 等待服务就绪并初始化
./scripts/setup-kibana.sh -p your_password --create-sample-data

# 3. 创建定期备份
./scripts/backup.sh -p your_password --compress
```

### 🔄 **自动化脚本**

```bash
#!/bin/bash
# 自动化 Kibana 管理脚本

# 设置变量
KIBANA_PASSWORD="your_password"
BACKUP_DIR="/backup/kibana"

# 检查并初始化
./scripts/setup-kibana.sh -p "$KIBANA_PASSWORD"

# 创建备份
./scripts/backup.sh -p "$KIBANA_PASSWORD" -d "$BACKUP_DIR" --compress

echo "Kibana 管理任务完成"
```

---

## 📞 获取帮助

如果在使用脚本过程中遇到问题：

1. 查看脚本帮助信息: `./script_name.sh --help`
2. 检查服务日志: `docker-compose logs kibana`
3. 验证网络连接: `curl -v http://localhost:5601/api/status`
4. 查看 Kibana 官方文档: https://www.elastic.co/guide/en/kibana/current/

**💡 提示**: 所有脚本都支持 `--help` 参数查看详细使用说明！
