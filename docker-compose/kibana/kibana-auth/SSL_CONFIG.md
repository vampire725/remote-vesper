# 🔓 Kibana 无 SSL 配置指南

> 📋 本文档说明当 Elasticsearch 集群不启用 SSL 加密时，如何调整 Kibana 配置以匹配无 SSL 的 Elasticsearch 环境。

## 📖 目录

- [🔍 概述](#-概述)
- [⚙️ 配置调整](#️-配置调整)
- [📁 文件修改](#-文件修改)
- [🔧 环境变量调整](#-环境变量调整)
- [🚀 启动验证](#-启动验证)
- [🛠️ 故障排除](#️-故障排除)
- [⚠️ 安全注意事项](#️-安全注意事项)

## 🔍 概述

当您的 Elasticsearch 集群运行在无 SSL 模式时，Kibana 也需要相应调整配置以正确连接。这种配置通常用于：

- 🧪 **开发测试环境**: 简化配置，快速部署
- 🏠 **内网隔离环境**: 网络已通过其他方式保护
- 🔧 **调试排错**: 便于问题定位和网络分析
- 📊 **性能测试**: 减少加密开销

⚠️ **重要提醒**: 生产环境强烈建议启用 SSL 加密！

## ⚙️ 配置调整

### 1️⃣ Docker Compose 配置修改

需要修改 `docker-compose.yaml` 文件中的 Kibana 配置：

#### 🔴 **当前配置（启用 SSL）**

```yaml
kibana:
  environment:
    # Elasticsearch 连接配置（HTTPS）
    - ELASTICSEARCH_HOSTS=https://es01:9200
    # Elasticsearch 用户认证
    - ELASTICSEARCH_USERNAME=elastic
    - ELASTICSEARCH_PASSWORD=your_elastic_password
    # SSL 证书配置
    - ELASTICSEARCH_SSL_CERTIFICATEAUTHORITIES=/usr/share/kibana/config/certs/ca/ca.crt

    # 安全配置
    - XPACK_SECURITY_ENABLED=true
    - XPACK_ENCRYPTEDSAVEDOBJECTS_ENCRYPTIONKEY=a7a6311933d3503b89bc2dbc36572c33a6c10925682e591bffcab6911c06786d

  volumes:
    # SSL 证书目录
    - ../es/certs:/usr/share/kibana/config/certs:ro
```

#### 🟢 **调整后配置（禁用 SSL）**

```yaml
kibana:
  environment:
    # Elasticsearch 连接配置（HTTP）
    - ELASTICSEARCH_HOSTS=http://es01:9200

    # 如果 Elasticsearch 完全禁用安全功能，移除用户认证
    # - ELASTICSEARCH_USERNAME=elastic
    # - ELASTICSEARCH_PASSWORD=your_elastic_password

    # 移除 SSL 证书配置
    # - ELASTICSEARCH_SSL_CERTIFICATEAUTHORITIES=/usr/share/kibana/config/certs/ca/ca.crt

    # 安全配置（可选择性禁用）
    # 方案1：完全禁用安全功能
    - XPACK_SECURITY_ENABLED=false

    # 方案2：保留 Kibana 内部安全功能（推荐）
    # - XPACK_SECURITY_ENABLED=true
    # - XPACK_ENCRYPTEDSAVEDOBJECTS_ENCRYPTIONKEY=a7a6311933d3503b89bc2dbc36572c33a6c10925682e591bffcab6911c06786d

  volumes:
    # 移除证书挂载
    # - ../es/certs:/usr/share/kibana/config/certs:ro

    # 保留数据目录
    - kibana-data:/usr/share/kibana/data
```

## 📁 文件修改

### 📝 **完整的 docker-compose.yaml 示例**

<details>
<summary>🔍 <strong>点击查看完整配置文件（无 SSL 版本）</strong></summary>

```yaml
# ===========================================
# Kibana Docker Compose 配置文件（无 SSL 版本）
# ===========================================

version: "3.8"

services:
  # ==========================================
  # Kibana 数据可视化平台（无 SSL）
  # ==========================================
  kibana:
    image: docker.elastic.co/kibana/kibana:8.15.3
    container_name: kibana

    environment:
      # ----------------------------------------
      # Elasticsearch 连接配置（HTTP）
      # ----------------------------------------
      - ELASTICSEARCH_HOSTS=http://es01:9200

      # 如果 Elasticsearch 保留用户认证，取消注释下面两行
      # - ELASTICSEARCH_USERNAME=elastic
      # - ELASTICSEARCH_PASSWORD=your_elastic_password

      # ----------------------------------------
      # Kibana 服务配置
      # ----------------------------------------
      - SERVER_NAME=kibana
      - SERVER_HOST=0.0.0.0
      - SERVER_PORT=5601
      - SERVER_PUBLICBASEURL=http://localhost:5601

      # ----------------------------------------
      # 安全配置（无 SSL）
      # ----------------------------------------
      # 方案1：完全禁用安全功能
      - XPACK_SECURITY_ENABLED=false

      # 方案2：保留 Kibana 内部安全功能（推荐）
      # - XPACK_SECURITY_ENABLED=true
      # - XPACK_ENCRYPTEDSAVEDOBJECTS_ENCRYPTIONKEY=a7a6311933d3503b89bc2dbc36572c33a6c10925682e591bffcab6911c06786d
      # - XPACK_REPORTING_ENCRYPTIONKEY=a7a6311933d3503b89bc2dbc36572c33a6c10925682e591bffcab6911c06786d
      # - XPACK_SECURITY_ENCRYPTIONKEY=a7a6311933d3503b89bc2dbc36572c33a6c10925682e591bffcab6911c06786d

      # ----------------------------------------
      # 日志配置
      # ----------------------------------------
      - LOGGING_ROOT_LEVEL=info
      - LOGGING_QUIET=true

      # ----------------------------------------
      # 性能优化配置
      # ----------------------------------------
      - DATA_VIEWS_CACHE_MAX_AGE=10m
      - ELASTICSEARCH_REQUESTTIMEOUT=90000
      - ELASTICSEARCH_SHARDTIMEOUT=30000

    volumes:
      # 移除证书挂载
      # - ../es/certs:/usr/share/kibana/config/certs:ro

      # 保留配置和数据目录
      - ./config:/usr/share/kibana/config/custom:ro
      - kibana-data:/usr/share/kibana/data

    ports:
      - "5601:5601"

    networks:
      - logging-network
      - monitoring-network

    restart: unless-stopped

    depends_on:
      - elasticsearch-check

    healthcheck:
      test: ["CMD-SHELL", "curl -s http://localhost:5601/api/status || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 120s

  # ==========================================
  # Elasticsearch 连接检查服务（无 SSL）
  # ==========================================
  elasticsearch-check:
    image: curlimages/curl:latest
    container_name: elasticsearch-check

    command: >
      sh -c "
        echo '等待 Elasticsearch 启动...'
        until curl -s http://es01:9200/_cluster/health; do
          echo '等待 Elasticsearch 响应...'
          sleep 5
        done
        echo 'Elasticsearch 已就绪！'
      "

    networks:
      - logging-network

    restart: "no"

volumes:
  kibana-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ./data

networks:
  logging-network:
    external: true
    name: logging-network
  monitoring-network:
    external: true
    name: monitoring-network
```

</details>

## 🔧 环境变量调整

### 📋 **环境变量对比**

| 配置项                                     | SSL 启用            | SSL 禁用           | 说明     |
| ------------------------------------------ | ------------------- | ------------------ | -------- |
| `ELASTICSEARCH_HOSTS`                      | `https://es01:9200` | `http://es01:9200` | 连接协议 |
| `ELASTICSEARCH_USERNAME`                   | 必需                | 可选               | 用户认证 |
| `ELASTICSEARCH_PASSWORD`                   | 必需                | 可选               | 密码认证 |
| `ELASTICSEARCH_SSL_CERTIFICATEAUTHORITIES` | 必需                | 移除               | SSL 证书 |
| `XPACK_SECURITY_ENABLED`                   | `true`              | `false` 或 `true`  | 安全功能 |
| 加密密钥配置                               | 必需                | 可选               | 数据加密 |

### 🔄 **配置方案选择**

#### **方案 1：完全禁用安全功能**

```yaml
environment:
  - ELASTICSEARCH_HOSTS=http://es01:9200
  - XPACK_SECURITY_ENABLED=false
  # 移除所有认证和加密配置
```

**优点**: 配置最简单，启动最快
**缺点**: 无任何安全保护

#### **方案 2：保留 Kibana 内部安全（推荐）**

```yaml
environment:
  - ELASTICSEARCH_HOSTS=http://es01:9200
  - XPACK_SECURITY_ENABLED=true
  - XPACK_ENCRYPTEDSAVEDOBJECTS_ENCRYPTIONKEY=your_encryption_key
  # 如果 ES 保留认证，添加用户名密码
```

**优点**: 保留 Kibana 内部数据加密
**缺点**: 配置稍复杂

## 🚀 启动验证

### 1️⃣ **启动服务**

```bash
# 进入 kibana 目录
cd kibana

# 确保 Elasticsearch 已启动（无 SSL 模式）
curl -s http://es01:9200/_cluster/health

# 启动 Kibana
docker-compose up -d

# 查看启动日志
docker-compose logs -f kibana
```

### 2️⃣ **验证连接**

```bash
# 检查 Kibana 健康状态
curl -s http://localhost:5601/api/status

# 检查 Elasticsearch 连接
docker exec kibana curl -s http://es01:9200/_cluster/health

# 访问 Kibana Web 界面
# 浏览器访问: http://localhost:5601
```

### 3️⃣ **测试功能**

```bash
# 如果完全禁用安全功能，直接访问
# 浏览器访问: http://localhost:5601

# 如果保留了认证，使用 Elasticsearch 用户登录
# 用户名: elastic
# 密码: your_elasticsearch_password（如果 ES 保留认证）
```

## 🛠️ 故障排除

### ❌ **常见问题**

#### **1. 连接 Elasticsearch 失败**

```bash
# 检查 Elasticsearch 状态
curl -s http://es01:9200/_cluster/health

# 检查网络连通性
docker exec kibana curl -s http://es01:9200

# 检查配置
docker exec kibana env | grep ELASTICSEARCH
```

#### **2. Kibana 启动失败**

```bash
# 检查日志
docker-compose logs kibana

# 常见错误：
# - 协议不匹配：确保使用 http:// 而不是 https://
# - 认证错误：检查用户名密码配置
# - 网络问题：确保网络连通性
```

#### **3. Web 界面访问问题**

```bash
# 检查端口映射
docker-compose ps

# 检查服务状态
curl -v http://localhost:5601/api/status

# 检查防火墙
sudo ufw status  # Ubuntu
```

### 🔧 **调试技巧**

#### **网络连通性测试**

```bash
# 测试容器间网络
docker exec kibana ping es01
docker exec kibana curl -s http://es01:9200

# 测试主机到容器网络
curl -s http://localhost:5601
curl -s http://localhost:9200
```

#### **配置验证**

```bash
# 检查 Kibana 配置
docker exec kibana cat /usr/share/kibana/config/kibana.yml

# 检查环境变量
docker exec kibana env | grep -E "(ELASTICSEARCH|XPACK)"
```

## ⚠️ 安全注意事项

### 🚨 **风险提醒**

1. **数据传输风险**:

   - ❌ Kibana 与 Elasticsearch 间数据明文传输
   - ❌ 用户会话可能被窃听
   - ❌ 仪表板数据可能泄露

2. **访问控制风险**:

   - ❌ 如果禁用认证，任何人都可以访问
   - ❌ 无法区分不同用户的权限
   - ❌ 数据可能被恶意修改

3. **数据安全风险**:
   - ❌ 保存的对象可能未加密
   - ❌ 敏感配置可能暴露
   - ❌ 无法审计用户操作

### 🛡️ **安全建议**

#### **网络层保护**

```bash
# 使用防火墙限制访问
sudo ufw allow from 192.168.1.0/24 to any port 5601  # 仅允许内网访问
sudo ufw deny 5601  # 拒绝其他访问

# 使用反向代理
# 配置 Nginx 或 Apache 作为前端代理
```

#### **应用层保护**

```yaml
# 保留 Kibana 内部安全功能
environment:
  - XPACK_SECURITY_ENABLED=true
  - XPACK_ENCRYPTEDSAVEDOBJECTS_ENCRYPTIONKEY=strong_encryption_key

  # 如果 ES 保留认证，配置用户认证
  - ELASTICSEARCH_USERNAME=elastic
  - ELASTICSEARCH_PASSWORD=strong_password
```

#### **监控和审计**

```bash
# 启用访问日志
# 监控异常访问模式
# 定期检查用户活动
# 备份重要仪表板和配置
```

### 📋 **安全检查清单**

- [ ] 确认网络环境安全
- [ ] 配置防火墙规则
- [ ] 设置强加密密钥
- [ ] 启用访问日志
- [ ] 定期备份配置
- [ ] 监控用户活动
- [ ] 制定应急响应计划

### 🎯 **最佳实践**

1. **开发环境**: 可以完全禁用安全功能以简化开发
2. **测试环境**: 建议保留 Kibana 内部安全功能
3. **预生产环境**: 必须启用完整的安全配置
4. **生产环境**: 强制要求 SSL 和完整认证

---

## 📝 总结

禁用 SSL 可以简化 Kibana 的配置和部署，但需要注意安全风险。请根据您的环境选择合适的配置方案：

### ✅ **适合禁用 SSL 的场景**

- 🧪 开发测试环境
- 🏠 完全隔离的内网环境
- 🔧 问题调试和排错
- 📊 性能基准测试

### ❌ **不适合禁用 SSL 的场景**

- 🌐 生产环境
- ☁️ 云环境部署
- 🔒 处理敏感数据
- 📋 需要合规认证

**💡 建议**: 在开发阶段可以禁用 SSL 以简化配置，但在部署到生产环境前务必重新启用完整的安全配置！
