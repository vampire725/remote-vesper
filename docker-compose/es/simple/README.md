# Elasticsearch 简化部署环境

## 概述

这是一个简化的 Elasticsearch 部署配置，专为开发和测试环境设计。该配置禁用了 SSL 加密和用户认证，提供最简单的部署方式。

## 特点

- ✅ **无 SSL 加密** - 简化配置，适合开发环境
- ✅ **无用户认证** - 直接访问，无需密码
- ✅ **单节点模式** - 资源占用少，启动快
- ✅ **自动化脚本** - 一键启动和管理
- ✅ **健康检查** - 自动监控服务状态
- ✅ **资源限制** - 防止过度占用系统资源

## 快速开始

### 1. 启动服务

```bash
# 进入 simple 目录
cd es/simple

# 启动服务（Linux/Mac）
./start.sh

# 或者直接使用 Docker Compose
docker-compose up -d
```

### 2. 验证服务

```bash
# 检查服务状态
./start.sh --status

# 测试连接
./start.sh --test

# 或者直接访问
curl http://localhost:9200
```

### 3. 访问服务

- **HTTP API**: http://localhost:9200
- **集群健康**: http://localhost:9200/\_cluster/health
- **节点信息**: http://localhost:9200/\_nodes

## 脚本使用说明

### 基本命令

```bash
# 启动服务
./start.sh

# 显示帮助
./start.sh --help

# 查看服务状态
./start.sh --status

# 查看服务日志
./start.sh --logs

# 测试连接
./start.sh --test
```

### 管理命令

```bash
# 停止服务
./start.sh --stop

# 重启服务
./start.sh --restart

# 清理数据并重启
./start.sh --clean
```

## 配置说明

### 核心配置

| 配置项                                 | 值            | 说明           |
| -------------------------------------- | ------------- | -------------- |
| `xpack.security.enabled`               | `false`       | 禁用安全功能   |
| `xpack.security.http.ssl.enabled`      | `false`       | 禁用 HTTP SSL  |
| `xpack.security.transport.ssl.enabled` | `false`       | 禁用传输层 SSL |
| `discovery.type`                       | `single-node` | 单节点模式     |
| `bootstrap.memory_lock`                | `false`       | 禁用内存锁定   |

### 资源配置

| 配置项     | 值  | 说明            |
| ---------- | --- | --------------- |
| JVM 堆内存 | 1GB | 适合开发环境    |
| 内存限制   | 2GB | Docker 容器限制 |
| 内存预留   | 1GB | Docker 容器预留 |

### 端口映射

| 端口 | 协议 | 用途     |
| ---- | ---- | -------- |
| 9200 | HTTP | REST API |
| 9300 | TCP  | 集群通信 |

## 常用操作

### 集群管理

```bash
# 查看集群健康状态
curl http://localhost:9200/_cluster/health?pretty

# 查看节点信息
curl http://localhost:9200/_nodes?pretty

# 查看集群统计信息
curl http://localhost:9200/_cluster/stats?pretty
```

### 索引管理

```bash
# 查看所有索引
curl http://localhost:9200/_cat/indices?v

# 创建索引
curl -X PUT http://localhost:9200/my-index

# 删除索引
curl -X DELETE http://localhost:9200/my-index

# 查看索引设置
curl http://localhost:9200/my-index/_settings?pretty
```

### 文档操作

```bash
# 创建文档
curl -X POST http://localhost:9200/my-index/_doc/1 \
  -H "Content-Type: application/json" \
  -d '{"title": "测试文档", "content": "这是一个测试文档"}'

# 获取文档
curl http://localhost:9200/my-index/_doc/1?pretty

# 搜索文档
curl -X GET http://localhost:9200/my-index/_search?pretty \
  -H "Content-Type: application/json" \
  -d '{"query": {"match_all": {}}}'

# 删除文档
curl -X DELETE http://localhost:9200/my-index/_doc/1
```

## 故障排除

### 常见问题

#### 1. 服务启动失败

**症状**: 容器启动后立即退出

**解决方案**:

```bash
# 查看详细日志
./start.sh --logs

# 或者
docker-compose logs elasticsearch

# 检查端口占用
netstat -tlnp | grep 9200
```

#### 2. 内存不足

**症状**: 容器因内存不足被杀死

**解决方案**:

```bash
# 修改 JVM 堆内存设置（在 docker-compose.yaml 中）
- "ES_JAVA_OPTS=-Xms512m -Xmx512m"  # 减少到 512MB

# 或者增加系统内存
```

#### 3. 网络连接问题

**症状**: 无法访问 http://localhost:9200

**解决方案**:

```bash
# 检查容器状态
docker ps | grep elasticsearch

# 检查网络配置
docker network ls
docker network inspect logging-network

# 重新创建网络
docker network rm logging-network kafka
./start.sh
```

#### 4. 数据持久化问题

**症状**: 重启后数据丢失

**解决方案**:

```bash
# 检查数据卷
docker volume ls | grep es-simple-data

# 查看数据卷详情
docker volume inspect es-simple-data

# 如果需要清理数据
./start.sh --clean
```

### 性能优化

#### 1. 内存优化

```bash
# 根据系统内存调整 JVM 堆内存
# 建议设置为系统内存的 25-50%
# 在 docker-compose.yaml 中修改:
- "ES_JAVA_OPTS=-Xms2g -Xmx2g"  # 4GB 系统内存
```

#### 2. 磁盘优化

```bash
# 使用 SSD 存储
# 确保有足够的磁盘空间（至少 10GB）
df -h
```

## 安全注意事项

⚠️ **重要警告**: 此配置仅适用于开发和测试环境！

### 安全风险

- 无用户认证 - 任何人都可以访问
- 无 SSL 加密 - 数据传输未加密
- 无访问控制 - 可以执行任何操作

### 生产环境建议

如需部署到生产环境，请：

1. 启用 X-Pack 安全功能
2. 配置 SSL/TLS 加密
3. 设置用户认证和授权
4. 配置防火墙规则
5. 启用审计日志

## 网络配置

### 网络依赖

此配置依赖以下 Docker 网络：

- `logging-network` - 用于日志处理服务通信
- `kafka` - 用于与 Kafka 服务通信

### 网络创建

脚本会自动创建所需网络，也可以手动创建：

```bash
# 创建网络
docker network create logging-network
docker network create kafka

# 查看网络
docker network ls
```

## 监控和日志

### 日志查看

```bash
# 实时查看日志
./start.sh --logs

# 查看最近的日志
docker-compose logs --tail=100 elasticsearch

# 查看特定时间的日志
docker-compose logs --since="2024-01-01T00:00:00" elasticsearch
```

### 监控指标

```bash
# 节点统计信息
curl http://localhost:9200/_nodes/stats?pretty

# 索引统计信息
curl http://localhost:9200/_stats?pretty

# 集群统计信息
curl http://localhost:9200/_cluster/stats?pretty
```

## 版本信息

- **Elasticsearch**: 8.15.3
- **Docker Compose**: 3.8
- **支持的操作系统**: Linux, macOS, Windows

## 更新日志

### v1.0.0 (2024-01-01)

- 初始版本
- 基础的单节点 Elasticsearch 配置
- 自动化启动脚本
- 完整的文档说明

## 许可证

此配置遵循 Elasticsearch 的开源许可证。

## 支持

如有问题，请检查：

1. [故障排除](#故障排除)部分
2. Elasticsearch 官方文档
3. Docker 和 Docker Compose 文档

---

**注意**: 请确保在生产环境中使用适当的安全配置！
