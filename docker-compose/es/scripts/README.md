# 🛠️ Elasticsearch 辅助脚本说明

> 📋 本目录包含了用于管理和维护 Elasticsearch 集群的实用脚本工具。

## 📖 目录

- [📁 脚本概览](#-脚本概览)
- [🔐 setup-certs.sh](#-setup-certssh)
- [🔑 setup-passwords.sh](#-setup-passwordssh)
- [🔍 check-ports.sh](#-check-portssh)
- [🚀 使用流程](#-使用流程)
- [⚠️ 注意事项](#️-注意事项)
- [🔧 故障排除](#-故障排除)

## 📁 脚本概览

| 脚本名称               | 功能描述      | 使用场景          | 依赖条件             |
| ---------------------- | ------------- | ----------------- | -------------------- |
| **setup-certs.sh**     | 生成 SSL 证书 | 首次部署/证书更新 | Docker               |
| **setup-passwords.sh** | 设置用户密码  | 安全配置          | Elasticsearch 运行中 |
| **check-ports.sh**     | 检查端口冲突  | 部署前检查        | 系统命令             |

## 🔐 setup-certs.sh

### 📋 **功能说明**

自动生成 Elasticsearch 集群所需的 SSL 证书，包括 CA 证书和各节点证书。

### 🎯 **主要功能**

- 🏛️ 生成 CA 根证书
- 🔑 为每个节点生成独立证书
- 🔄 自动转换证书格式（PKCS12 → PEM）
- 🔒 设置合适的文件权限

### 💻 **使用方法**

```bash
# 进入 es 目录
cd es

# 给脚本执行权限
chmod +x scripts/setup-certs.sh

# 运行脚本
./scripts/setup-certs.sh
```

### 📁 **生成的文件**

```
certs/
├── ca/
│   ├── ca.p12          # CA 证书（PKCS12 格式）
│   └── ca.crt          # CA 证书（PEM 格式）
├── es01/
│   ├── es01.p12        # 节点1 证书（PKCS12 格式）
│   ├── es01.crt        # 节点1 证书（PEM 格式）
│   └── es01.key        # 节点1 私钥
├── es02/
│   ├── es02.p12        # 节点2 证书（PKCS12 格式）
│   ├── es02.crt        # 节点2 证书（PEM 格式）
│   └── es02.key        # 节点2 私钥
└── es03/
    ├── es03.p12        # 节点3 证书（PKCS12 格式）
    ├── es03.crt        # 节点3 证书（PEM 格式）
    └── es03.key        # 节点3 私钥
```

### ⚠️ **注意事项**

- 🐳 需要 Docker 运行环境
- 📁 会自动创建 `certs` 目录
- 🔒 私钥文件权限设置为 600
- ⏱️ 证书默认有效期为 3 年

---

## 🔑 setup-passwords.sh

### 📋 **功能说明**

为 Elasticsearch 内置用户设置密码，并创建 Logstash 专用用户和角色。

### 🎯 **主要功能**

- 🔐 设置 `elastic` 超级用户密码
- 👤 设置 `kibana_system` 用户密码
- 🔧 设置 `logstash_system` 用户密码
- 📝 创建 `logstash_writer` 角色
- 👥 创建专用 `logstash` 用户

### 💻 **使用方法**

```bash
# 确保 Elasticsearch 已启动
docker-compose up -d

# 等待服务完全启动（约 1-2 分钟）
docker-compose logs -f es01

# 给脚本执行权限
chmod +x scripts/setup-passwords.sh

# 运行脚本
./scripts/setup-passwords.sh
```

### 🔐 **创建的用户和角色**

#### **内置用户**

| 用户名            | 角色            | 用途              |
| ----------------- | --------------- | ----------------- |
| `elastic`         | superuser       | 超级管理员        |
| `kibana_system`   | kibana_system   | Kibana 系统用户   |
| `logstash_system` | logstash_system | Logstash 系统用户 |

#### **自定义用户**

| 用户名     | 角色            | 用途              |
| ---------- | --------------- | ----------------- |
| `logstash` | logstash_writer | Logstash 数据写入 |

#### **自定义角色权限**

```json
{
  "logstash_writer": {
    "cluster": ["manage_index_templates", "monitor", "manage_ilm"],
    "indices": [
      {
        "names": ["logstash-*"],
        "privileges": [
          "write",
          "create",
          "create_index",
          "manage",
          "manage_ilm"
        ]
      }
    ]
  }
}
```

### ⚠️ **注意事项**

- 🚀 需要 Elasticsearch 服务运行中
- 🔐 密码输入时不会显示字符
- 📝 记录好设置的密码
- 🔄 设置后需要重启服务应用新密码

---

## 🔍 check-ports.sh

### 📋 **功能说明**

检查 Elasticsearch 和 Kibana 所需端口是否被占用，并进行系统资源检查。

### 🎯 **主要功能**

- 🔍 检查端口占用情况（9200, 9300, 5601）
- 🐳 检查 Docker 容器端口占用
- 💾 检查系统内存资源
- 💿 检查磁盘空间
- 🖥️ 跨平台支持（Linux/macOS/Windows）

### 💻 **使用方法**

```bash
# 给脚本执行权限
chmod +x scripts/check-ports.sh

# 运行检查
./scripts/check-ports.sh
```

### 📊 **检查项目**

#### **端口检查**

| 端口 | 服务          | 用途       |
| ---- | ------------- | ---------- |
| 9200 | Elasticsearch | HTTP API   |
| 9300 | Elasticsearch | 传输层通信 |
| 5601 | Kibana        | Web 界面   |

#### **系统资源检查**

- 💾 **内存检查**: 总内存和可用内存
- 💿 **磁盘检查**: 当前目录可用空间
- 🐳 **Docker 检查**: Docker 服务状态

### 🔧 **解决端口冲突**

#### **Linux 系统**

```bash
# 查看端口占用
sudo netstat -tlnp | grep :9200

# 杀死占用进程
sudo kill -9 <进程ID>
```

#### **macOS 系统**

```bash
# 查看端口占用
lsof -i :9200

# 杀死占用进程
kill -9 <进程ID>
```

#### **Windows 系统**

```cmd
# 查看端口占用
netstat -an | findstr :9200

# 在任务管理器中结束相关进程
```

### ⚠️ **注意事项**

- 🖥️ 支持多种操作系统
- 🔍 会显示占用进程的详细信息
- ⚡ 发现冲突时脚本会以错误码退出
- 💡 提供具体的解决建议

---

## 🚀 使用流程

### 📋 **完整部署流程**

```bash
# 1. 进入 es 目录
cd es

# 2. 检查端口和系统资源
chmod +x scripts/check-ports.sh
./scripts/check-ports.sh

# 3. 生成 SSL 证书
chmod +x scripts/setup-certs.sh
./scripts/setup-certs.sh

# 4. 创建 Docker 网络
docker network create logging-network
docker network create monitoring-network

# 5. 启动 Elasticsearch 集群
docker-compose up -d

# 6. 等待服务启动完成
docker-compose logs -f es01

# 7. 设置用户密码
chmod +x scripts/setup-passwords.sh
./scripts/setup-passwords.sh

# 8. 验证部署
curl -k -u elastic:your_password https://localhost:9200/_cluster/health
```

### 🔄 **维护流程**

#### **证书更新**

```bash
# 备份旧证书
cp -r certs certs.backup.$(date +%Y%m%d)

# 重新生成证书
./scripts/setup-certs.sh

# 重启服务
docker-compose restart
```

#### **密码重置**

```bash
# 重新设置密码
./scripts/setup-passwords.sh

# 更新配置文件中的密码
# 重启相关服务
```

#### **端口冲突解决**

```bash
# 检查端口状态
./scripts/check-ports.sh

# 根据提示解决冲突
# 重新启动服务
```

---

## ⚠️ 注意事项

### 🔒 **安全注意事项**

1. **证书安全**:

   - 🔐 私钥文件权限设置为 600
   - 📁 证书目录不要提交到版本控制
   - 🔄 定期更新证书（建议每年）

2. **密码安全**:

   - 🔐 使用强密码（至少 8 位，包含大小写字母、数字、特殊字符）
   - 📝 安全存储密码（使用密码管理器）
   - 🔄 定期更换密码

3. **权限管理**:
   - 👤 遵循最小权限原则
   - 🔍 定期审查用户权限
   - 📊 监控用户活动

### 💾 **数据安全**

1. **备份策略**:

   - 📅 定期备份证书和配置
   - 💾 备份 Elasticsearch 数据
   - 🔄 测试恢复流程

2. **监控告警**:
   - 📊 监控服务状态
   - 🚨 设置资源使用告警
   - 📈 监控性能指标

### 🖥️ **系统要求**

1. **操作系统兼容性**:

   - ✅ Linux (推荐)
   - ✅ macOS
   - ✅ Windows (WSL 推荐)

2. **依赖软件**:
   - 🐳 Docker 20.10+
   - 🔧 Docker Compose 2.0+
   - 🌐 curl (用于 API 测试)

---

## 🔧 故障排除

### ❌ **常见问题**

#### **1. 证书生成失败**

```bash
# 问题：Docker 镜像拉取失败
# 解决：检查网络连接，使用镜像加速器

# 问题：权限不足
# 解决：确保当前用户有 Docker 权限
sudo usermod -aG docker $USER
```

#### **2. 密码设置失败**

```bash
# 问题：Elasticsearch 未启动
# 解决：检查服务状态
docker-compose ps
docker-compose logs es01

# 问题：默认密码错误
# 解决：检查环境变量配置
grep ELASTIC_PASSWORD docker-compose.yaml
```

#### **3. 端口检查异常**

```bash
# 问题：命令不存在
# 解决：安装必要工具
# Ubuntu/Debian
sudo apt-get install net-tools

# CentOS/RHEL
sudo yum install net-tools

# macOS
# 通常已预装，如有问题可重新安装 Xcode Command Line Tools
```

### 🆘 **获取帮助**

如果遇到问题，可以：

1. 📖 查看 [Elasticsearch 官方文档](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
2. 🔍 检查 Docker 容器日志：`docker-compose logs -f`
3. 💬 在项目 Issue 中提问
4. 📧 联系技术支持

---

**💡 提示**: 建议在生产环境部署前，先在测试环境中验证所有脚本的功能！
