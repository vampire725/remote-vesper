# �� Kibana 数据可视化平台部署指南 (带认证版本)

[![Kibana](https://img.shields.io/badge/Kibana-8.15.3-005571?style=flat-square&logo=kibana)](https://www.elastic.co/kibana/)
[![Docker](https://img.shields.io/badge/Docker-20.10+-2496ed?style=flat-square&logo=docker)](https://www.docker.com/)
[![Security](https://img.shields.io/badge/Security-Enabled-red?style=flat-square)](LICENSE)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

> 🔐 使用 Docker Compose 部署 Kibana 8.15.3 数据可视化平台的完整解决方案，启用安全认证功能，与 Elasticsearch 8.15.3 安全集成。

## 📋 目录

- [📖 项目简介](#-项目简介)
- [🔧 系统要求](#-系统要求)
- [📁 项目结构](#-项目结构)
- [🌐 网络架构](#-网络架构)
- [⚙️ 部署步骤](#️-部署步骤)
- [🔨 配置说明](#-配置说明)
- [🔐 安全配置](#-安全配置)
- [📊 监控与管理](#-监控与管理)
- [🛠️ 使用指南](#️-使用指南)
- [⚠️ 注意事项](#️-注意事项)
- [🔧 故障排除](#-故障排除)
- [📈 版本特性](#-版本特性)

## 📖 项目简介

本项目提供了一个完整的 Kibana 数据可视化解决方案，**启用了完整的安全认证功能**，主要特性包括：

- 📊 **数据可视化**: 强大的图表和仪表板功能
- 🔍 **数据探索**: 灵活的搜索和过滤功能
- 🛡️ **安全集成**: 完整的 X-Pack 安全功能和用户认证
- 🔐 **SSL/TLS 加密**: 启用 HTTPS 加密通信
- 📈 **实时监控**: 实时数据展示和告警功能
- 🌐 **网络隔离**: 独立的网络配置和安全策略
- 🔧 **易于管理**: 完善的健康检查和自动重启机制

## 🔧 系统要求

### 💻 **硬件要求**

| 组件     | 最小配置 | 推荐配置 | 生产环境 |
| -------- | -------- | -------- | -------- |
| **CPU**  | 2 核心   | 4 核心   | 8+ 核心  |
| **内存** | 2GB      | 4GB      | 8GB+     |
| **存储** | 10GB     | 50GB     | 100GB+   |
| **网络** | 100Mbps  | 1Gbps    | 1Gbps+   |

### 🐳 **软件要求**

- **Docker**: 20.10.0+
- **Docker Compose**: 2.0.0+
- **Elasticsearch**: 8.15.3 (必须先部署，且启用安全功能)
- **SSL 证书**: 由 Elasticsearch 生成的 CA 证书
- **可用端口**: 5601

## 🔐 安全配置

### 🔑 **认证要求**

此版本**必须**与启用了安全功能的 Elasticsearch 配合使用：

```yaml
# Elasticsearch 安全配置要求
xpack.security.enabled: true
xpack.security.http.ssl.enabled: true
xpack.security.transport.ssl.enabled: true
```

### 🛡️ **安全特性**

- ✅ **用户认证**: 需要 Elasticsearch 用户名和密码
- ✅ **SSL/TLS 加密**: 使用 HTTPS 协议通信
- ✅ **证书验证**: 验证 SSL 证书有效性
- ✅ **数据加密**: 保存对象和报告加密存储
- ✅ **会话管理**: 安全的用户会话管理

### 🔧 **必要的认证配置**

在部署前，请确保设置以下配置：

```bash
# 1. 设置 Elasticsearch 密码
export ELASTIC_PASSWORD="your_secure_password"

# 2. 确保 SSL 证书路径正确
export CERTS_DIR="../es/certs"

# 3. 生成安全的加密密钥（32位字符）
export ENCRYPTION_KEY=$(openssl rand -hex 32)
```

## 📁 项目结构

```
kibana/
├── docker-compose.yaml     # 主配置文件
├── README.md              # 本文档
├── config/                # 自定义配置文件
│   └── kibana.yml         # Kibana 配置文件（可选）
├── data/                  # 数据持久化目录
└── scripts/               # 辅助脚本
    ├── setup-kibana.sh    # Kibana 初始化脚本
    └── backup.sh          # 数据备份脚本
```

## 🌐 网络架构

### 🏗️ **网络拓扑图**

```
┌─────────────────────────────────────────────────────────────┐
│                    Kibana 网络架构                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │  logging-network │    │monitoring-network│               │
│  │                 │    │                 │                │
│  │  ┌──────────┐   │    │   ┌──────────┐  │                │
│  │  │ Logstash │   │    │   │  Kibana  │◄─┼─── 用户访问    │
│  │  └──────────┘   │    │   └──────────┘  │    (5601)      │
│  │       │         │    │        │        │                │
│  │       ▼         │    │        ▼        │                │
│  │  ┌──────────┐   │    │   ┌──────────┐  │                │
│  │  │    ES    │◄──┼────┼──►│    ES    │  │                │
│  │  │ Cluster  │   │    │   │ Cluster  │  │                │
│  │  └──────────┘   │    │   └──────────┘  │                │
│  └─────────────────┘    └─────────────────┘                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 🌐 **网络配置详情**

| 网络名称               | 类型     | 用途     | 连接的服务             |
| ---------------------- | -------- | -------- | ---------------------- |
| **logging-network**    | External | 数据查询 | Kibana ↔ Elasticsearch |
| **monitoring-network** | External | 监控数据 | Kibana ↔ 监控系统      |

## ⚙️ 部署步骤

### 1️⃣ **前置条件检查**

```bash
# 确保 Elasticsearch 已部署并启用安全功能
curl -k -u elastic:password https://localhost:9200/_cluster/health

# 确保 SSL 证书存在
ls -la ../es/certs/ca/ca.crt

# 确保网络已创建
docker network ls | grep -E "(logging|monitoring)"
```

### 2️⃣ **安全配置**

```bash
# 1. 修改 docker-compose.yaml 中的密码
sed -i 's/your_elastic_password/your_actual_password/g' docker-compose.yaml

# 2. 更新加密密钥（生产环境必须修改）
NEW_KEY=$(openssl rand -hex 32)
sed -i "s/a7a6311933d3503b89bc2dbc36572c33a6c10925682e591bffcab6911c06786d/$NEW_KEY/g" docker-compose.yaml

# 3. 验证证书路径
docker run --rm -v "$(pwd)/../es/certs:/certs:ro" alpine ls -la /certs/ca/
```

### 3️⃣ **启动服务**

```bash
# 启动 Kibana（带认证）
docker-compose up -d

# 查看启动日志
docker-compose logs -f kibana

# 检查认证状态
docker-compose logs elasticsearch-check
```

### 4️⃣ **验证认证功能**

```bash
# 检查 Kibana 健康状态（需要认证后才能访问完整功能）
curl -s http://localhost:5601/api/status

# 访问 Kibana Web 界面
# 浏览器访问: http://localhost:5601
# 用户名: elastic
# 密码: your_elasticsearch_password
```

## 🔨 配置说明

### ⚙️ **关键安全配置参数**

#### **认证连接配置**

```yaml
# Elasticsearch 安全连接
ELASTICSEARCH_HOSTS: "https://es01:9200"
ELASTICSEARCH_USERNAME: "elastic"
ELASTICSEARCH_PASSWORD: "your_secure_password"

# SSL 证书配置
ELASTICSEARCH_SSL_CERTIFICATEAUTHORITIES: "/usr/share/kibana/config/certs/ca/ca.crt"
```

#### **X-Pack 安全配置**

```yaml
# 启用完整安全功能
XPACK_SECURITY_ENABLED: true

# 加密密钥配置（生产环境必须修改）
XPACK_ENCRYPTEDSAVEDOBJECTS_ENCRYPTIONKEY: "your_32_char_encryption_key"
XPACK_REPORTING_ENCRYPTIONKEY: "your_32_char_encryption_key"
XPACK_SECURITY_ENCRYPTIONKEY: "your_32_char_encryption_key"
```

## 📊 监控与管理

### 🔍 **健康检查端点**

| 端点                       | 用途     | 示例                                                 |
| -------------------------- | -------- | ---------------------------------------------------- |
| `/api/status`              | 服务状态 | `curl http://localhost:5601/api/status`              |
| `/api/stats`               | 统计信息 | `curl http://localhost:5601/api/stats`               |
| `/api/saved_objects/_find` | 保存对象 | `curl http://localhost:5601/api/saved_objects/_find` |

### 📈 **监控指标**

- **服务状态**: Green/Yellow/Red
- **响应时间**: API 响应延迟
- **内存使用**: JVM 堆内存使用率
- **连接状态**: Elasticsearch 连接状态
- **用户活动**: 活跃用户数和操作统计

### 🔧 **管理命令**

```bash
# 查看服务状态
docker-compose ps

# 查看实时日志
docker-compose logs -f kibana

# 重启服务
docker-compose restart kibana

# 停止服务
docker-compose stop

# 完全清理（注意：会删除数据）
docker-compose down -v
```

## 🛠️ 使用指南

### 📊 **创建数据视图**

1. **访问 Kibana**: http://localhost:5601
2. **登录**: 使用 Elasticsearch 用户凭据
3. **创建数据视图**:
   ```
   Management → Stack Management → Data Views → Create data view
   ```
4. **配置索引模式**: 例如 `logstash-*`

### 📈 **创建可视化图表**

```bash
# 1. 进入 Visualize Library
# 2. 选择图表类型（柱状图、饼图、线图等）
# 3. 选择数据源（数据视图）
# 4. 配置聚合和指标
# 5. 保存可视化图表
```

### 🎛️ **创建仪表板**

```bash
# 1. 进入 Dashboard
# 2. 创建新仪表板
# 3. 添加可视化图表
# 4. 调整布局和大小
# 5. 保存仪表板
```

### 🔍 **数据探索**

```bash
# 1. 进入 Discover
# 2. 选择数据视图
# 3. 设置时间范围
# 4. 添加过滤条件
# 5. 分析数据模式
```

## ⚠️ 注意事项

### 🔒 **安全注意事项**

1. **密码安全**:

   - 使用强密码，至少 12 位字符
   - 定期更换密码
   - 不要在代码中硬编码密码

2. **证书管理**:

   - 定期检查证书有效期
   - 确保证书路径访问权限正确
   - 备份证书文件

3. **加密密钥**:

   - 生产环境必须使用自定义密钥
   - 密钥长度至少 32 位
   - 定期轮换加密密钥

4. **网络安全**:
   - 限制访问端口
   - 使用防火墙规则
   - 定期检查网络连接

### 💾 **数据安全**

1. **定期备份**: 备份 Kibana 配置和仪表板
2. **版本控制**: 将重要配置纳入版本控制
3. **访问日志**: 启用和监控访问日志
4. **数据保留**: 设置合适的数据保留策略

### 🚀 **性能优化**

1. **内存配置**: 根据使用情况调整内存限制
2. **缓存设置**: 优化缓存配置提升响应速度
3. **索引优化**: 合理设计索引模式
4. **查询优化**: 避免过于复杂的查询

## 🔧 故障排除

<details>
<summary>🔍 <strong>常见问题解决方案</strong></summary>

### ❌ **服务启动失败**

**问题**: Kibana 容器无法启动

```bash
# 检查日志
docker-compose logs kibana

# 常见原因和解决方案：
# 1. Elasticsearch 未启动 - 先启动 ES
# 2. 网络连接问题 - 检查网络配置
# 3. 权限问题 - 检查数据目录权限
```

### 🔐 **连接 Elasticsearch 失败**

**问题**: 无法连接到 Elasticsearch

```bash
# 检查 Elasticsearch 状态
curl -k -u elastic:password https://es01:9200/_cluster/health

# 检查网络连通性
docker exec kibana curl -k -s https://es01:9200

# 检查证书配置
docker exec kibana ls -la /usr/share/kibana/config/certs/
```

### 🌐 **Web 界面无法访问**

**问题**: 无法访问 Kibana Web 界面

```bash
# 检查端口映射
docker-compose ps

# 检查防火墙设置
sudo ufw status  # Ubuntu
sudo firewall-cmd --list-all  # CentOS

# 检查服务健康状态
curl -v http://localhost:5601/api/status
```

### 💾 **数据丢失问题**

**问题**: 仪表板和配置丢失

```bash
# 检查数据卷
docker volume ls
docker volume inspect kibana_kibana-data

# 检查目录权限
ls -la data/
sudo chown -R 1000:1000 data/
```

### 🔍 **性能问题**

**问题**: Kibana 响应缓慢

```bash
# 检查资源使用
docker stats kibana

# 检查 Elasticsearch 性能
curl -k -u elastic:password https://es01:9200/_cluster/stats

# 优化配置
# 增加超时时间、调整缓存设置
```

</details>

## 📈 版本特性

### 🆕 **Kibana 8.15.3 新特性**

- ✅ **性能提升**: 仪表板加载速度提升 20%
- 🎨 **UI 改进**: 全新的用户界面设计
- 📊 **新图表类型**: 支持更多可视化类型
- 🔧 **配置简化**: 简化的初始配置流程
- 🚀 **兼容性**: 与 Elasticsearch 8.15.3 完美兼容

### 🔄 **与 Elasticsearch 的兼容性**

| Kibana 版本 | Elasticsearch 版本 | 兼容性      | 说明     |
| ----------- | ------------------ | ----------- | -------- |
| 8.15.3      | 8.15.3             | ✅ 完全兼容 | 推荐组合 |
| 8.15.3      | 8.15.x             | ✅ 兼容     | 稳定运行 |
| 8.15.3      | 8.14.x             | ⚠️ 部分兼容 | 需要测试 |

### 📊 **功能对比**

| 功能         | Kibana 8.15.3 | 早期版本 | 改进     |
| ------------ | ------------- | -------- | -------- |
| **启动时间** | 30-45 秒      | 60-90 秒 | 50% 提升 |
| **内存使用** | 512MB-1GB     | 1GB-2GB  | 50% 减少 |
| **图表类型** | 30+           | 20+      | 50% 增加 |
| **响应速度** | <2 秒         | 3-5 秒   | 60% 提升 |

---

📝 **使用说明**: 此版本适用于生产环境和需要安全认证的场景。如需无认证版本，请参考 `kibana-no-auth` 文件夹。
