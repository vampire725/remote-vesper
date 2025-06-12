# Filebeat 多源数据采集部署指南

本文档提供了使用 Docker Compose 部署 Filebeat 的详细说明，用于收集多种数据源并发送到 Kafka。

## 系统要求

- Docker 20.10.0 或更高版本
- Docker Compose 2.0.0 或更高版本
- Kafka 集群
- 足够的磁盘空间用于日志存储

## 目录结构

```
filebeat/
├── docker-compose.yml    # Docker Compose 配置文件
├── filebeat.yml         # Filebeat 配置文件
├── logs/                # 日志目录
└── README.md           # 本文档
```

## 部署步骤

### 1. 准备环境

创建日志目录：

```bash
mkdir -p logs
```

### 2. 配置 Filebeat

1. 修改 `docker-compose.yml` 中的环境变量：
   - `KAFKA_HOSTS`: Kafka 服务器地址
   - `KAFKA_TOPIC`: Kafka 主题名称
   - `KAFKA_USERNAME`: Kafka 用户名
   - `KAFKA_PASSWORD`: Kafka 密码

2. 根据需要修改 `filebeat.yml` 中的配置：
   - 数据源配置
   - 处理器配置
   - Kafka 输出配置

### 3. 启动 Filebeat

```bash
docker-compose up -d
```

## 配置说明

### 数据源配置

Filebeat 配置了多种数据源：

1. **容器日志采集**
   - 收集所有 Docker 容器的日志
   - 自动添加 Docker 元数据

2. **文件日志采集**
   - 收集 `logs` 目录下的所有 `.log` 文件
   - 支持多行日志合并
   - 添加应用标识字段

3. **系统日志采集**
   - 收集系统日志文件
   - 包括 syslog 和 auth.log

4. **系统指标采集**
   - CPU 使用率
   - 内存使用情况
   - 网络流量
   - 文件系统状态
   - 进程信息

5. **进程监控**
   - 监控所有进程
   - 收集进程状态信息

6. **网络数据包采集**
   - 监控指定端口的网络流量
   - 支持 HTTP/HTTPS 流量

### 处理器配置

配置了以下处理器：

- 主机元数据
- 云服务元数据
- Docker 元数据
- Kubernetes 元数据
- 事件过滤（丢弃 debug 和 trace 级别日志）

### Kafka 输出配置

- 启用 SASL 认证
- 使用 gzip 压缩
- 配置消息大小限制
- 使用 JSON 编码
- 轮询分区策略

### 日志配置

- 日志级别：info
- 日志文件保留：7天
- 日志文件权限：0644
- 日志文件轮转：10MB

## 使用说明

### 添加新的数据源

1. 在 `filebeat.yml` 中添加新的输入配置：

```yaml
filebeat.inputs:
- type: log  # 或其他类型
  enabled: true
  paths:
    - /path/to/your/data
  fields:
    type: your_type
  fields_under_root: true
```

2. 重启 Filebeat：

```bash
docker-compose restart
```

### 查看 Filebeat 日志

```bash
# 查看所有日志
docker-compose logs

# 实时查看日志
docker-compose logs -f
```

### 停止 Filebeat

```bash
docker-compose down
```

## 注意事项

1. **安全**
   - 妥善保管 Kafka 认证信息
   - 确保日志文件权限正确
   - 限制敏感数据采集

2. **性能**
   - 监控磁盘使用情况
   - 定期清理旧日志
   - 适当配置日志轮转
   - 注意系统资源使用

3. **维护**
   - 定期检查 Filebeat 状态
   - 更新 Filebeat 版本
   - 备份配置文件
   - 监控 Kafka 连接状态

## 故障排除

### 常见问题

1. **无法连接到 Kafka**
   - 检查网络连接
   - 验证认证信息
   - 确认主题配置

2. **数据采集失败**
   - 检查文件权限
   - 验证数据源路径
   - 查看 Filebeat 日志

3. **性能问题**
   - 检查磁盘空间
   - 调整批处理大小
   - 优化处理器配置
   - 监控系统资源

### 获取帮助

如果遇到问题，可以：

1. 查看 Filebeat 官方文档
2. 检查 Docker 日志
3. 查看 Filebeat 日志
4. 在 Elastic 社区论坛寻求帮助

## 更新记录

- 2024-03-xx: 更新版本
  - 添加多种数据源采集
  - 配置 Kafka 输出
  - 优化性能配置
  - 完善文档说明 