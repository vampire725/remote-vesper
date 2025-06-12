# Vector 部署指南

本文档提供了 Vector 在测试环境和生产环境的部署说明。

## 目录结构

```
vector/
├── dev/                # 测试环境配置
│   ├── docker-compose.yml
│   ├── vector.yaml
│   └── README.md
└── prod/              # 生产环境配置
    ├── docker-compose.yml
    ├── vector1.yaml
    ├── vector2.yaml
    └── README.md
```

## 环境说明

- `dev/`: 测试环境配置，使用单节点 Vector
- `prod/`: 生产环境配置，使用双节点 Vector 实现高可用

## 快速开始

1. 测试环境：
```bash
cd dev
docker-compose up -d
```

2. 生产环境：
```bash
cd prod
docker-compose up -d
```

## 配置说明

### 测试环境

- 单节点部署
- 基本日志收集功能
- 直接转发到 Elasticsearch
- 适合开发和测试使用

### 生产环境

- 双节点高可用部署
- 增强的日志收集功能
- 支持日志指纹识别
- 重试机制
- 适合生产环境使用

## 监控和维护

1. 检查 Vector 状态：
```bash
docker-compose ps
```

2. 查看 Vector 日志：
```bash
docker-compose logs -f vector
```

3. 验证配置：
```bash
docker exec -it vector vector validate --config-yaml /etc/vector/vector.yaml
```

## 注意事项

1. 确保 Elasticsearch 服务可用
2. 检查日志目录权限
3. 监控磁盘空间使用
4. 定期检查日志收集状态

## 故障排除

1. 如果日志收集失败：
   - 检查 Elasticsearch 连接
   - 验证日志文件权限
   - 查看 Vector 日志

2. 如果性能问题：
   - 检查资源使用情况
   - 调整批处理大小
   - 优化配置参数

## 获取帮助

如果遇到问题，可以：

1. 查看 Vector 官方文档
2. 检查 Docker 日志
3. 查看 Vector 日志
4. 在 Vector 社区论坛寻求帮助 