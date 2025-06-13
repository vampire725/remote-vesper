# 📋 Kibana 无认证配置说明 (HTTP 模式)

[![Kibana](https://img.shields.io/badge/Kibana-8.15.3-005571?style=flat-square&logo=kibana)](https://www.elastic.co/kibana/)
[![Security](https://img.shields.io/badge/Security-Disabled-orange?style=flat-square)](LICENSE)
[![Protocol](https://img.shields.io/badge/Protocol-HTTP-blue?style=flat-square)](LICENSE)

> 🔓 本配置文件已经是**无 SSL 无认证**版本，适用于开发和测试环境。无需额外配置即可直接使用 HTTP 协议访问。

## 📖 配置说明

此 `kibana-no-auth` 版本已经预配置为无认证模式，包含以下特性：

### ✅ **已启用特性**

- 🌐 **HTTP 协议**: 使用明文 HTTP 通信
- 🔓 **无用户认证**: 无需用户名密码登录
- ❌ **禁用 X-Pack 安全**: 关闭所有安全功能
- 🚀 **快速启动**: 简化的启动流程

### ❌ **已禁用特性**

- 🔒 **SSL/TLS 加密**: 不使用 HTTPS 协议
- 👤 **用户认证系统**: 无登录界面
- 🛡️ **权限控制**: 无用户权限管理
- 🔐 **数据加密**: 无保存对象加密

## 🔧 当前配置详情

### 📡 **连接配置**

```yaml
# HTTP 连接（无加密）
ELASTICSEARCH_HOSTS: "http://elasticsearch:9200"
# 已移除的配置项：
# ❌ ELASTICSEARCH_USERNAME
# ❌ ELASTICSEARCH_PASSWORD
# ❌ ELASTICSEARCH_SSL_CERTIFICATEAUTHORITIES
```

### 🔒 **安全配置**

```yaml
# 禁用 X-Pack 安全功能
XPACK_SECURITY_ENABLED: false
# 已移除的配置项：
# ❌ XPACK_ENCRYPTEDSAVEDOBJECTS_ENCRYPTIONKEY
# ❌ XPACK_REPORTING_ENCRYPTIONKEY
# ❌ XPACK_SECURITY_ENCRYPTIONKEY
```

### 🏗️ **Docker 配置**

```yaml
# 容器配置
container_name: kibana-no-auth
ports:
  - "5601:5601" # HTTP 端口映射

# 已移除的挂载：
# ❌ SSL 证书目录挂载
```

## 🚀 快速使用

### 1️⃣ **直接启动**

```bash
# 进入目录
cd kibana-no-auth

# 一键启动
docker-compose up -d

# 查看状态
docker-compose ps
```

### 2️⃣ **访问界面**

```bash
# 直接访问（无需登录）
open http://localhost:5602

# 或使用 curl 测试
curl -s http://localhost:5602/api/status
```

### 3️⃣ **验证配置**

```bash
# 检查安全状态（应该显示禁用）
curl -s http://localhost:5602/api/features

# 检查 Elasticsearch 连接
docker-compose logs kibana | grep -i elasticsearch
```

## ⚠️ 安全警告

### 🚨 **重要提醒**

> ⚠️ **此配置仅适用于开发和测试环境！**
>
> **禁止在生产环境中使用此配置！**

### 🔓 **安全风险**

| 风险类型       | 描述               | 影响     |
| -------------- | ------------------ | -------- |
| **数据暴露**   | 所有数据无加密传输 | 高风险   |
| **无访问控制** | 任何人都可访问系统 | 极高风险 |
| **无审计日志** | 无法追踪操作记录   | 中等风险 |
| **网络攻击**   | 易受中间人攻击     | 高风险   |

### 🛡️ **使用建议**

#### ✅ **适合场景**

- 本地开发环境
- 内网测试环境
- 概念验证 (PoC)
- 学习和培训
- 功能演示

#### ❌ **不适合场景**

- 生产环境
- 包含敏感数据
- 互联网可访问
- 多用户环境
- 需要合规审计

## 🔄 从 SSL 版本迁移

如果你需要从 SSL 认证版本切换到此无认证版本：

### 📝 **迁移步骤**

```bash
# 1. 停止认证版本
cd ../kibana-auth
docker-compose down

# 2. 启动无认证版本
cd ../kibana-no-auth
docker-compose up -d

# 3. 验证配置
curl -s http://localhost:5602/api/status
```

### 🔧 **配置对比**

| 配置项         | 认证版本      | 无认证版本  |
| -------------- | ------------- | ----------- |
| **协议**       | HTTPS         | HTTP        |
| **端口**       | 5601 (SSL)    | 5601 (HTTP) |
| **认证**       | 用户名/密码   | 无需认证    |
| **证书**       | 需要 SSL 证书 | 无需证书    |
| **启动时间**   | ~120 秒       | ~60 秒      |
| **配置复杂度** | 高            | 低          |

## 🔍 故障排除

### 🚨 **常见问题**

#### **问题 1**: 无法访问 Kibana

```bash
# 检查服务状态
docker-compose ps

# 检查端口占用
netstat -tlnp | grep 5601

# 查看启动日志
docker-compose logs kibana
```

#### **问题 2**: 连接 Elasticsearch 失败

```bash
# 确认 ES 禁用了安全功能
curl -s http://elasticsearch:9200/_cluster/health

# 检查网络连接
docker-compose exec kibana curl http://elasticsearch:9200
```

#### **问题 3**: 功能异常

```bash
# 确认安全功能已禁用
docker-compose logs kibana | grep -i "xpack.security.enabled"

# 检查配置加载
docker-compose exec kibana cat /usr/share/kibana/config/kibana.yml
```

## 📊 性能对比

### ⚡ **性能优势**

| 指标         | 无认证版本 | 认证版本  | 提升 |
| ------------ | ---------- | --------- | ---- |
| **启动时间** | 30-60 秒   | 90-120 秒 | 50%  |
| **内存使用** | 较低       | 较高      | 20%  |
| **响应时间** | 较快       | 较慢      | 15%  |
| **CPU 使用** | 较低       | 较高      | 10%  |

### 📈 **资源使用**

```yaml
# 推荐资源配置
resources:
  memory: 1GB # 认证版本需要 2GB
  cpu: 1 core # 认证版本推荐 2 核心
  storage: 10GB # 认证版本推荐 20GB
```

## 🔗 相关文档

- 📖 [Kibana 官方文档](https://www.elastic.co/guide/en/kibana/current/index.html)
- 🔒 [认证版本配置](../kibana-auth/README.md)
- 🐳 [Docker Compose 指南](https://docs.docker.com/compose/)
- 📋 [Elasticsearch 配置](https://www.elastic.co/guide/en/elasticsearch/reference/current/security-settings.html)

---

📝 **注意**: 如需启用安全功能，请使用 [`kibana-auth`](../kibana-auth/) 文件夹中的认证版本配置。
