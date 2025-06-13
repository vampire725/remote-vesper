# 🔍 Kibana 双版本部署指南

[![Kibana](https://img.shields.io/badge/Kibana-8.15.3-005571?style=flat-square&logo=kibana)](https://www.elastic.co/kibana/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=flat-square&logo=docker)](https://www.docker.com/)
[![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen?style=flat-square)](LICENSE)

> 🚀 **一键部署双版本 Kibana**：同时提供带认证的生产环境版本和无认证的开发环境版本，满足不同使用场景需求。

## 📋 项目概述

本项目提供了 **Kibana 双版本部署方案**，支持在同一环境中并行运行两个版本：

- **🔒 认证版本** (`kibana-auth/`): 适用于生产环境，具备完整的安全机制
- **🔓 无认证版本** (`kibana-no-auth/`): 适用于开发环境，快速启动免登录

## 🚀 快速开始

### 1️⃣ 一键测试配置

```bash
bash test-kibana-setup.sh
```

### 2️⃣ 启动服务

```bash
# 启动认证版本 (生产环境)
bash manage-kibana.sh start auth

# 启动无认证版本 (开发环境)
bash manage-kibana.sh start no-auth

# 查看状态
bash manage-kibana.sh status
```

## 🌍 访问地址

| 版本              | 地址                  | 端口 | 认证        | 用途     |
| ----------------- | --------------------- | ---- | ----------- | -------- |
| 🔒 **认证版本**   | http://localhost:5601 | 5601 | ✅ 需要登录 | 生产环境 |
| 🔓 **无认证版本** | http://localhost:5602 | 5602 | ❌ 免登录   | 开发环境 |

## 🆚 版本对比

| 特性         | 🔒 认证版本         | 🔓 无认证版本     |
| ------------ | ------------------- | ----------------- |
| **端口**     | 5601                | 5602              |
| **认证**     | ✅ X-Pack 安全认证  | ❌ 禁用认证       |
| **SSL/TLS**  | ✅ HTTPS 连接       | ❌ HTTP 连接      |
| **适用环境** | 🏢 生产环境         | 🛠️ 开发/测试环境  |
| **启动速度** | 较慢 (需要证书验证) | 快速 (无安全检查) |

## 🛠️ 管理命令

```bash
# 启动服务
bash manage-kibana.sh start auth      # 启动认证版本
bash manage-kibana.sh start no-auth   # 启动无认证版本

# 停止服务
bash manage-kibana.sh stop all        # 停止所有版本

# 查看状态
bash manage-kibana.sh status          # 查看所有版本状态
bash manage-kibana.sh logs auth       # 查看认证版本日志
```

## 📁 项目结构

```
📦 docker-compose/
├── 🔒 kibana-auth/              # 认证版本 (生产环境)
├── 🔓 kibana-no-auth/          # 无认证版本 (开发环境)
├── 🛠️ manage-kibana.sh         # 跨平台管理脚本
├── 🧪 test-kibana-setup.sh     # 配置测试脚本
└── 📖 KIBANA_README.md         # 本文档
```

## 🔗 详细文档

- [🔒 认证版本详细说明](kibana-auth/README.md)
- [🔓 无认证版本详细说明](kibana-no-auth/README.md)
- [🛡️ SSL 配置指南](kibana-auth/SSL_CONFIG.md)

## 🚨 注意事项

⚠️ **无认证版本仅适用于开发环境，不要在生产环境使用**

---

🎉 **祝您使用愉快！** 完整功能已通过测试验证。
