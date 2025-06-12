# Nacos 单机版部署

这是一个用于测试环境的 Nacos 单机版 Docker Compose 配置。

## 配置说明

- 使用 Nacos 2.2.3 版本
- 采用单机模式（standalone）
- 使用内置 Derby 数据库
- JVM 内存配置：
  - 初始堆内存：512MB
  - 最大堆内存：512MB
  - 新生代内存：256MB

## 端口说明

- 8848：Nacos 控制台端口
- 9848/9849：Nacos 集群通信端口（单机模式下未使用）

## 数据持久化

- 日志目录：`./logs`
- 数据目录：`./data`

## 快速开始

1. 创建必要的目录：
```bash
mkdir -p logs data
```

2. 启动服务：
```bash
docker-compose up -d
```

3. 访问控制台：
- 地址：http://localhost:8848/nacos
- 默认账号：nacos
- 默认密码：nacos

## 健康检查

服务配置了健康检查，每30秒检查一次服务状态。可以通过以下命令查看服务状态：

```bash
docker-compose ps
```

## 停止服务

```bash
docker-compose down
```

## 注意事项

- 此配置仅适用于测试环境
- 生产环境建议使用集群模式并配置外部数据库
- 数据存储在本地目录，请确保有足够的磁盘空间 