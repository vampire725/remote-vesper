# Kafka 测试环境部署指南

本文档提供了 Kafka 测试环境的部署说明。测试环境使用单节点 Kafka，采用 KRaft 模式（无需 Zookeeper），适合开发和测试使用。

## 特点

- 单节点部署
- KRaft 模式（无 Zookeeper）
- 无认证机制
- 自动创建主题
- 最小化配置

## 部署步骤

1. 启动服务：
```bash
docker-compose up -d
```

2. 验证部署：
```bash
# 查看主题列表
docker exec -it kafka kafka-topics --bootstrap-server localhost:9092 --list
```

## 配置说明

- Kafka 端口：9092
- 控制器端口：9093
- 自动创建主题：是
- 复制因子：1

## 使用说明

1. 创建主题：
```bash
docker exec -it kafka kafka-topics --bootstrap-server localhost:9092 \
  --create --topic test-topic --partitions 1 --replication-factor 1
```

2. 发送消息：
```bash
docker exec -it kafka kafka-console-producer --bootstrap-server localhost:9092 \
  --topic test-topic
```

3. 消费消息：
```bash
docker exec -it kafka kafka-console-consumer --bootstrap-server localhost:9092 \
  --topic test-topic --from-beginning
```

## 注意事项

1. **安全**
   - 仅用于开发和测试
   - 不要在生产环境使用
   - 注意数据安全

2. **性能**
   - 单节点性能有限
   - 无数据冗余
   - 适合小规模测试

## 故障排除

1. **无法连接 Kafka**
   - 检查网络连接
   - 验证端口配置
   - 检查容器状态

2. **主题创建失败**
   - 检查权限设置
   - 验证复制因子
   - 确认分区数

3. **性能问题**
   - 检查资源使用
   - 优化配置参数
   - 调整分区策略

## 获取帮助

如果遇到问题，可以：

1. 查看 Kafka 官方文档
2. 检查 Docker 日志
3. 查看 Kafka 日志
4. 在 Kafka 社区论坛寻求帮助 