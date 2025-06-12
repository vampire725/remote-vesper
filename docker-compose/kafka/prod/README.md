# Kafka 生产环境部署指南

本文档提供了 Kafka 生产环境的部署说明。生产环境使用三节点 Kafka 集群，采用 KRaft 模式（无需 Zookeeper），包含安全认证，适合生产使用。

## 特点

- 三节点集群
- KRaft 模式（无 Zookeeper）
- SASL/PLAIN 认证
- ACL 授权
- 数据持久化
- 高可用配置

## 部署步骤

1. 修改认证配置：
   - 编辑 `kafka_server_jaas.conf`
   - 设置安全的用户名和密码

2. 启动服务：
```bash
docker-compose up -d
```

3. 创建主题：
```bash
# 创建主题
docker exec -it kafka1 kafka-topics --bootstrap-server localhost:9092 \
  --create --topic your-topic \
  --partitions 3 --replication-factor 3
```

4. 设置 ACL：
```bash
# 设置主题权限
docker exec -it kafka1 kafka-acls --bootstrap-server localhost:9092 \
  --add --allow-principal User:alice \
  --operation Read --topic your-topic
```

## 配置说明

### 端口配置

- kafka1:
  - 客户端端口：9092
  - 外部端口：29092
  - SASL 端口：9093
  - 控制器端口：9094

- kafka2:
  - 客户端端口：9092
  - 外部端口：29093
  - SASL 端口：9093
  - 控制器端口：9094

- kafka3:
  - 客户端端口：9092
  - 外部端口：29094
  - SASL 端口：9093
  - 控制器端口：9094

### 其他配置

- 复制因子：3
- 最小 ISR：2
- 认证机制：SASL/PLAIN
- 授权：ACL
- 自动创建主题：否

## 使用说明

1. 创建主题：
```bash
docker exec -it kafka1 kafka-topics --bootstrap-server localhost:9092 \
  --create --topic prod-topic \
  --partitions 3 --replication-factor 3
```

2. 发送消息（带认证）：
```bash
docker exec -it kafka1 kafka-console-producer --bootstrap-server localhost:9092 \
  --topic prod-topic \
  --producer-property security.protocol=SASL_PLAINTEXT \
  --producer-property sasl.mechanism=PLAIN \
  --producer-property sasl.jaas.config="org.apache.kafka.common.security.plain.PlainLoginModule required username=\"alice\" password=\"alice-secret\";"
```

3. 消费消息（带认证）：
```bash
docker exec -it kafka1 kafka-console-consumer --bootstrap-server localhost:9092 \
  --topic prod-topic --from-beginning \
  --consumer-property security.protocol=SASL_PLAINTEXT \
  --consumer-property sasl.mechanism=PLAIN \
  --consumer-property sasl.jaas.config="org.apache.kafka.common.security.plain.PlainLoginModule required username=\"alice\" password=\"alice-secret\";"
```

## 注意事项

1. **安全**
   - 定期更新密码
   - 严格控制 ACL
   - 监控访问日志
   - 使用强密码
   - 限制网络访问

2. **性能**
   - 监控集群状态
   - 调整分区数
   - 优化副本配置
   - 监控资源使用
   - 定期性能评估

3. **维护**
   - 定期备份数据
   - 监控磁盘使用
   - 更新安全配置
   - 检查日志文件
   - 更新软件版本

## 故障排除

1. **无法连接 Kafka**
   - 检查网络连接
   - 验证端口配置
   - 确认认证信息
   - 检查防火墙设置
   - 验证 ACL 配置

2. **主题创建失败**
   - 检查权限设置
   - 验证复制因子
   - 确认分区数
   - 检查集群状态
   - 验证节点健康

3. **性能问题**
   - 检查资源使用
   - 优化配置参数
   - 调整分区策略
   - 监控网络延迟
   - 检查磁盘 I/O

## 监控和维护

1. **日常监控**
   - 集群健康状态
   - 主题分区状态
   - 消费者组状态
   - 资源使用情况
   - 错误日志分析

2. **定期维护**
   - 日志轮转
   - 数据清理
   - 配置检查
   - 安全审计
   - 性能优化

## 获取帮助

如果遇到问题，可以：

1. 查看 Kafka 官方文档
2. 检查 Docker 日志
3. 查看 Kafka 日志
4. 在 Kafka 社区论坛寻求帮助
5. 联系技术支持团队 