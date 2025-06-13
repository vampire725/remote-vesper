# �� Kibana 数据可视化平台部署指南 (无认证版本)

[![Kibana](https://img.shields.io/badge/Kibana-8.15.3-005571?style=flat-square&logo=kibana)](https://www.elastic.co/kibana/)
[![Docker](https://img.shields.io/badge/Docker-20.10+-2496ed?style=flat-square&logo=docker)](https://www.docker.com/)
[![Security](https://img.shields.io/badge/Security-Disabled-orange?style=flat-square)](LICENSE)
[![Environment](https://img.shields.io/badge/Environment-Development-yellow?style=flat-square)](LICENSE)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

> 🚀 使用 Docker Compose 部署 Kibana 8.15.3 数据可视化平台的简化版本，**禁用安全认证功能**，适用于开发和测试环境。

## 📋 目录

- [📖 项目简介](#-项目简介)
- [🔧 系统要求](#-系统要求)
- [📁 项目结构](#-项目结构)
- [🌐 网络架构](#-网络架构)
- [⚙️ 部署步骤](#️-部署步骤)
- [🔨 配置说明](#-配置说明)
- [🚀 快速开始](#-快速开始)
- [📊 监控与管理](#-监控与管理)
- [🛠️ 使用指南](#️-使用指南)
- [⚠️ 注意事项](#️-注意事项)
- [🔧 故障排除](#-故障排除)
- [📈 版本特性](#-版本特性)

## 📖 项目简介

本项目提供了一个**简化的** Kibana 数据可视化解决方案，**禁用了安全认证功能**，适用于开发和测试环境，主要特性包括：

- 📊 **数据可视化**: 强大的图表和仪表板功能
- 🔍 **数据探索**: 灵活的搜索和过滤功能
- 🚀 **快速部署**: 无需复杂的认证配置
- 🔓 **无认证访问**: 直接访问，无需用户名密码
- 📈 **实时监控**: 实时数据展示功能
- 🌐 **网络隔离**: 独立的网络配置
- 🔧 **易于管理**: 完善的健康检查和自动重启机制
- 🧪 **开发友好**: 适合开发环境和概念验证

## 🔧 系统要求

### 💻 **硬件要求**

| 组件     | 最小配置 | 推荐配置 | 开发环境 |
| -------- | -------- | -------- | -------- |
| **CPU**  | 1 核心   | 2 核心   | 4+ 核心  |
| **内存** | 1GB      | 2GB      | 4GB+     |
| **存储** | 5GB      | 20GB     | 50GB+    |
| **网络** | 100Mbps  | 1Gbps    | 1Gbps+   |

### 🐳 **软件要求**

- **Docker**: 20.10.0+
- **Docker Compose**: 2.0.0+
- **Elasticsearch**: 8.15.3 (必须先部署，且**禁用安全功能**)
- **可用端口**: 5601

## 🚀 快速开始

### ⚡ **一键启动**

```bash
# 克隆并启动（假设 Elasticsearch 已运行）
cd kibana-no-auth
docker-compose up -d

# 立即访问 Kibana
echo "Kibana 已启动: http://localhost:5602"
```

### 🔓 **无认证特性**

- ❌ **无需用户名密码**: 直接访问 Web 界面
- ❌ **无 SSL 证书**: 使用 HTTP 协议通信
- ❌ **无加密配置**: 简化的配置文件
- ❌ **无权限管理**: 所有功能直接可用
- ✅ **快速启动**: 通常 30 秒内完成启动

## 📁 项目结构

```
kibana-no-auth/
├── docker-compose.yaml     # 简化的主配置文件
├── README.md              # 本文档（无认证版本）
├── config/                # 简化配置文件
├── data/                  # 数据持久化目录
└── scripts/               # 辅助脚本
    ├── setup-kibana.sh    # 简化初始化脚本
    └── backup.sh          # 数据备份脚本
```

## 🌐 网络架构

### 🏗️ **简化网络拓扑图**

```
┌─────────────────────────────────────────────────────────────┐
│                Kibana 无认证网络架构                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │  logging-network │    │monitoring-network│               │
│  │                 │    │                 │                │
│  │  ┌──────────┐   │    │   ┌──────────┐  │                │
│  │  │ Logstash │   │    │   │  Kibana  │◄─┼─── 直接访问    │
│  │  └──────────┘   │    │   │(无认证)  │  │    (5601)      │
│  │       │         │    │   └──────────┘  │                │
│  │       ▼         │    │        │        │                │
│  │  ┌──────────┐   │    │        ▼        │                │
│  │  │    ES    │◄──┼────┼─── HTTP 连接    │                │
│  │  │(无认证)  │   │    │   (无加密)      │                │
│  │  └──────────┘   │    │                 │                │
│  └─────────────────┘    └─────────────────┘                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## ⚙️ 部署步骤

### 1️⃣ **前置条件检查**

```bash
# 确保 Elasticsearch 已部署并禁用安全功能
curl -s http://localhost:9200/_cluster/health

# 检查 Elasticsearch 安全状态（应该返回错误或显示禁用）
curl -s http://localhost:9200/_xpack/security/_authenticate

# 确保网络已创建
docker network ls | grep -E "(logging|monitoring)"

# 如果网络不存在，创建网络
docker network create logging-network
docker network create monitoring-network
```

### 2️⃣ **直接启动**

```bash
# 进入目录
cd kibana-no-auth

# 启动 Kibana（无认证）
docker-compose up -d

# 查看启动日志
docker-compose logs -f kibana

# 检查服务状态
docker-compose ps
```

### 3️⃣ **验证部署**

```bash
# 检查 Kibana 健康状态
curl -s http://localhost:5602/api/status

# 直接访问 Kibana Web 界面（无需登录）
echo "访问 Kibana: http://localhost:5602"
```

## 🔨 配置说明

### ⚙️ **简化配置参数**

#### **无认证连接配置**

```yaml
# Elasticsearch HTTP 连接（无认证）
ELASTICSEARCH_HOSTS: "http://elasticsearch:9200"
# 无需用户名密码
# ELASTICSEARCH_USERNAME: 已移除
# ELASTICSEARCH_PASSWORD: 已移除

# 无需 SSL 证书
# ELASTICSEARCH_SSL_CERTIFICATEAUTHORITIES: 已移除
```

#### **安全功能禁用**

```yaml
# 禁用 X-Pack 安全功能
XPACK_SECURITY_ENABLED: false
# 无需加密密钥
# XPACK_ENCRYPTEDSAVEDOBJECTS_ENCRYPTIONKEY: 已移除
```

#### **性能配置**

```yaml
# 搜索超时时间（毫秒）
ELASTICSEARCH_REQUESTTIMEOUT: 90000

# 分片超时时间（毫秒）
ELASTICSEARCH_SHARDTIMEOUT: 30000

# 数据视图缓存时间
DATA_VIEWS_CACHE_MAX_AGE: "10m"
```

### 📊 **配置对比**

| 配置项         | 认证版本 | 无认证版本 | 说明       |
| -------------- | -------- | ---------- | ---------- |
| **连接协议**   | HTTPS    | HTTP       | 通信协议   |
| **用户认证**   | 必需     | 禁用       | 登录要求   |
| **SSL 证书**   | 必需     | 无需       | 加密证书   |
| **启动时间**   | 120s     | 60s        | 启动速度   |
| **配置复杂度** | 高       | 低         | 配置复杂度 |

## 📊 监控与管理

### 🔍 **健康检查端点**

| 端点                       | 用途     | 示例                                                 |
| -------------------------- | -------- | ---------------------------------------------------- |
| `/api/status`              | 服务状态 | `curl http://localhost:5602/api/status`              |
| `/api/stats`               | 统计信息 | `curl http://localhost:5602/api/stats`               |
| `/api/saved_objects/_find` | 保存对象 | `curl http://localhost:5602/api/saved_objects/_find` |

### 📈 **监控指标**

- **服务状态**: Green/Yellow/Red
- **响应时间**: API 响应延迟
- **内存使用**: JVM 堆内存使用率
- **连接状态**: Elasticsearch 连接状态
- **用户活动**: 访问统计（无用户认证）

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

# 完全清理
docker-compose down -v
```

## 🛠️ 使用指南

### 🌟 **开始使用**

1. **访问 Kibana**:

   - 打开浏览器访问 `http://localhost:5602`
   - **无需登录**，直接进入主界面

2. **创建索引模式**:

   - 导航到 "Stack Management" > "Index Patterns"
   - 创建你的第一个索引模式

3. **探索数据**:
   - 使用 "Discover" 功能探索数据
   - 创建可视化图表
   - 构建仪表板

### 🎯 **开发环境优势**

- **快速迭代**: 无需每次重新配置认证
- **调试友好**: 所有 API 都可直接访问测试
- **团队协作**: 无需共享登录凭据
- **原型开发**: 快速构建概念验证

## ⚠️ 注意事项

### 🚨 **安全警告**

> ⚠️ **重要**: 此版本**仅适用于开发和测试环境**，请勿在生产环境中使用！

### 🔓 **安全风险**

1. **无访问控制**: 任何人都可以访问和修改数据
2. **数据传输**: 使用明文 HTTP 传输，可能被截获
3. **无审计日志**: 无法追踪用户操作记录
4. **网络暴露**: 如果端口对外开放，存在安全风险

### 🛡️ **防护建议**

```bash
# 1. 限制网络访问
iptables -A INPUT -p tcp --dport 5601 -s 127.0.0.1 -j ACCEPT
iptables -A INPUT -p tcp --dport 5601 -j DROP

# 2. 使用内网环境
# 确保只在内网或本地开发环境中使用

# 3. 定期清理数据
docker-compose down -v  # 清理测试数据
```

### 💻 **适用场景**

✅ **适合使用**:

- 本地开发环境
- 概念验证 (PoC)
- 功能测试
- 学习和培训
- 内网演示环境

❌ **不适合使用**:

- 生产环境
- 包含敏感数据的环境
- 对外提供服务
- 需要审计的环境
- 多用户协作的正式环境

## 🔧 故障排除

### 🚨 **常见问题**

1. **无法连接 Elasticsearch**:

   ```bash
   # 检查 Elasticsearch 是否禁用了安全功能
   curl -s http://elasticsearch:9200/_cluster/health

   # 检查网络连接
   docker-compose exec kibana curl http://elasticsearch:9200
   ```

2. **启动缓慢**:

   ```bash
   # 检查系统资源
   docker stats kibana-no-auth

   # 查看详细日志
   docker-compose logs -f kibana
   ```

3. **端口冲突**:

   ```bash
   # 检查端口占用
   netstat -tlnp | grep 5601

   # 修改端口映射
   # ports: - "5602:5601"
   ```

### 🔄 **从认证版本迁移**

如果需要从认证版本切换到无认证版本：

```bash
# 1. 停止认证版本
cd ../kibana-auth
docker-compose down

# 2. 启动无认证版本
cd ../kibana-no-auth
docker-compose up -d

# 3. 注意：数据可能需要重新索引
```

---

📝 **使用说明**: 此版本仅适用于开发环境和测试场景。如需生产环境部署，请使用 `kibana-auth` 文件夹中的认证版本。

🔗 **相关链接**:

- [Kibana 官方文档](https://www.elastic.co/guide/en/kibana/current/index.html)
- [Docker 官方文档](https://docs.docker.com/)
- [Elasticsearch 配置指南](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
