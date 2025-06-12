# Kafka 部署指南

本文档提供了 Kafka 在测试环境和生产环境的部署说明。

## 目录结构

```
kafka/
├── dev/                # 测试环境配置
│   ├── docker-compose.yml
│   └── README.md
└── prod/              # 生产环境配置
    ├── docker-compose.yml
    ├── kafka_server_jaas.conf
    └── README.md
```

## 环境说明

- `dev/`: 测试环境配置，使用单节点 Kafka，采用 KRaft 模式（无需 Zookeeper）
- `prod/`: 生产环境配置，使用三节点 Kafka 集群，采用 KRaft 模式，包含安全认证

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

详细说明请参考各环境目录下的 README.md 文件。 