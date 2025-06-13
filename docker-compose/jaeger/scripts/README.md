# 测试数据生成器

这个目录包含用于向Jaeger链路追踪系统生成测试数据的脚本。

## 📁 文件说明

### 🚀 `quick-test.sh` - 快速测试脚本
简单快速的测试脚本，发送3条基本的测试数据。

**特点：**
- 🏃‍♂️ 快速执行（约2秒）
- 📊 生成3条简单trace数据
- ✅ 自动服务可用性检查
- 💡 提供清晰的使用指导

**使用方法：**
```bash
# 使用默认端点 (OTLP Collector)
./quick-test.sh

# 指定自定义端点
./quick-test.sh http://localhost:4318

# 使用Jaeger直连端点
./quick-test.sh http://localhost:4318
```

### 🛠️ `generate-test-data.sh` - 完整测试数据生成器
功能强大的测试数据生成器，支持多种数据类型和自定义配置。

**特点：**
- 🎯 多种数据类型（简单、复杂、错误、数据库）
- 🔧 高度可配置
- 📈 支持大量数据生成
- 🔍 服务健康检查
- 📊 详细的执行反馈

**数据类型：**
- **简单数据** - 基础的HTTP请求trace
- **复杂调用链** - 多服务调用的完整链路
- **错误数据** - 包含异常和错误状态的trace
- **数据库操作** - 模拟数据库查询操作

## 🚀 快速开始

### 1. 启动Jaeger服务

首先确保Jaeger服务正在运行：

```bash
# 进入Jaeger部署目录
cd ../jaeger-deploy

# 启动服务
./start.sh -d

# 验证服务状态
docker-compose ps
```

### 2. 运行快速测试

```bash
# 进入测试数据目录
cd ../test-data

# 运行快速测试
./quick-test.sh
```

### 3. 查看结果

访问 [Jaeger UI](http://localhost:16686)：
1. 在服务下拉框中选择 `quick-test-service`
2. 点击 "Find Traces"
3. 查看生成的trace数据

## 📊 生成不同类型的测试数据

### 简单测试数据
```bash
# 生成5条简单数据
./generate-test-data.sh --simple -c 5

# 生成10条简单数据到指定服务
./generate-test-data.sh --simple -c 10 -s my-service
```

### 复杂调用链数据
```bash
# 生成复杂的微服务调用链
./generate-test-data.sh --complex -c 3

# 生成包含api-gateway、user-service、order-service、database的完整调用链
```

### 错误数据
```bash
# 生成包含错误的trace数据
./generate-test-data.sh --error -c 5

# 包含HTTP 500错误、异常事件等
```

### 所有类型数据
```bash
# 生成所有类型的测试数据
./generate-test-data.sh --all -c 2

# 生成简单、复杂、错误、数据库操作各2条
```

## ⚙️ 高级配置

### 环境变量配置
```bash
# 设置环境变量
export OTLP_ENDPOINT="http://localhost:4316"
export SERVICE_NAME="my-custom-service"
export TENANT_ID="123456"
export DATA_COUNT="10"

# 运行脚本
./generate-test-data.sh
```

### 自定义端点
```bash
# 使用OTLP端点（推荐）
./generate-test-data.sh -e http://localhost:4316

# 使用Jaeger直连端点
./generate-test-data.sh --use-jaeger -j http://localhost:4318

# 自定义远程端点
./generate-test-data.sh -e http://remote-server:4316
```

### 批量数据生成
```bash
# 生成大量测试数据
./generate-test-data.sh --simple -c 100

# 生成不同服务的数据
for service in user-svc order-svc payment-svc; do
    ./generate-test-data.sh --simple -s $service -c 20
done
```

## 🔍 故障排除

### 常见问题

#### 1. 服务连接失败
```
❌ 服务不可用: http://localhost:4316
```

**解决方案：**
- 确保Jaeger服务正在运行：`cd ../jaeger-deploy && ./start.sh -d`
- 检查端口是否正确：默认OTLP端口4316，Jaeger端口4318
- 等待服务完全启动（约1-2分钟）

#### 2. 数据发送失败
```
❌ 发送失败: HTTP 404
```

**解决方案：**
- 检查端点URL是否正确
- 确认使用正确的API路径：`/v1/traces`
- 验证Content-Type设置为`application/json`

#### 3. 数据不显示在UI中
**解决方案：**
- 检查Jaeger UI的时间范围设置
- 确认服务名称匹配
- 等待几秒钟后刷新页面
- 查看浏览器开发者工具的网络请求

### 调试模式
```bash
# 启用详细日志
set -x
./generate-test-data.sh --simple -c 1

# 检查curl详细输出
curl -v -X POST \
    -H "Content-Type: application/json" \
    -d '{"test": "data"}' \
    http://localhost:4316/v1/traces
```

## 📈 性能测试

### 压力测试
```bash
# 生成大量数据进行压力测试
./generate-test-data.sh --all -c 50

# 并发生成数据
for i in {1..5}; do
    ./generate-test-data.sh --simple -s "load-test-$i" -c 20 &
done
wait
```

### 监控资源使用
```bash
# 监控Jaeger服务资源使用
docker stats jaeger-collector jaeger-query elasticsearch

# 查看服务日志
docker-compose logs -f jaeger-collector
```

## 🛠️ 自定义开发

### 添加新的数据类型
在`generate-test-data.sh`中添加新的生成函数：

```bash
generate_custom_data() {
    local count="$1"
    log_step "生成自定义数据 ($count 条)..."
    
    # 你的自定义逻辑
}
```

### 修改数据格式
根据需要调整JSON结构：

```bash
# 修改span属性
"attributes": [
    {
        "key": "custom.field",
        "value": {"stringValue": "custom-value"}
    }
]
```

## 📋 使用场景

### 开发环境测试
```bash
# 快速验证Jaeger部署
./quick-test.sh

# 测试基本功能
./generate-test-data.sh --simple -c 5
```

### 演示和培训
```bash
# 生成丰富的演示数据
./generate-test-data.sh --all -c 10

# 创建复杂的调用链用于演示
./generate-test-data.sh --complex -c 5
```

### 性能测试
```bash
# 生成大量数据测试系统性能
./generate-test-data.sh --simple -c 1000

# 测试错误处理
./generate-test-data.sh --error -c 100
```

### CI/CD集成
```bash
# 在CI流水线中验证Jaeger功能
if ./quick-test.sh; then
    echo "Jaeger健康检查通过"
else
    echo "Jaeger健康检查失败"
    exit 1
fi
```

## 🔗 相关链接

- [Jaeger UI](http://localhost:16686) - Web界面
- [OpenTelemetry文档](https://opentelemetry.io/docs/)
- [Jaeger文档](https://www.jaegertracing.io/docs/)
- [OTLP协议规范](https://github.com/open-telemetry/opentelemetry-proto) 