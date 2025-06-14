#!/bin/bash

echo "🎯 生成TraceQL Metrics连续数据"
echo "================================"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 数据生成配置 - 扩展时间窗口
TOTAL_MINUTES=60        # 生成60分钟的数据
TRACES_PER_MINUTE=10    # 每分钟10个追踪
SEND_INTERVAL=6         # 每6秒发送一次（每分钟10次）

echo -e "${YELLOW}配置: $TOTAL_MINUTES 分钟 × $TRACES_PER_MINUTE 追踪/分钟 = $((TOTAL_MINUTES * TRACES_PER_MINUTE)) 个追踪${NC}"
echo -e "${YELLOW}时间跨度: $TOTAL_MINUTES 分钟（满足3小时窗口查看需求）${NC}"
echo ""

# 检查端口 4317 (OTLP gRPC) 是否可用
echo -e "${BLUE}检查Tempo OTLP端口...${NC}"
if curl -s "http://localhost:4317" > /dev/null 2>&1; then
    ENDPOINT="http://localhost:4317"
    echo -e "${GREEN}✅ 使用OTLP gRPC端口 4317${NC}"
elif curl -s "http://localhost:4318/v1/traces" > /dev/null 2>&1; then
    ENDPOINT="http://localhost:4318/v1/traces"
    echo -e "${GREEN}✅ 使用OTLP HTTP端口 4318${NC}"
else
    echo -e "${RED}❌ Tempo OTLP端口不可访问${NC}"
    exit 1
fi

# 服务和操作配置
services=("frontend-web" "api-gateway" "user-service" "order-service" "payment-service")
operations=("GET:/api/users" "POST:/api/orders" "GET:/api/payments" "PUT:/api/inventory")
status_codes=(200 200 200 201 400 404 500)

# 生成历史数据函数
generate_historical_trace() {
    local minutes_ago=$1
    local trace_num=$2
    
    # 计算历史时间戳
    local current_timestamp=$(date +%s)
    local historical_timestamp=$((current_timestamp - minutes_ago * 60))
    
    # 随机选择服务和操作
    local service=${services[$((RANDOM % ${#services[@]}))]}
    local operation=${operations[$((RANDOM % ${#operations[@]}))]}
    local status_code=${status_codes[$((RANDOM % ${#status_codes[@]}))]}
    local response_time=$((RANDOM % 1000 + 50))
    
    # 生成ID
    local trace_id=$(openssl rand -hex 16)
    local span_id=$(openssl rand -hex 8)
    
    # HTTP方法和路径
    local http_method=$(echo $operation | cut -d: -f1)
    local http_path=$(echo $operation | cut -d: -f2)
    
    # 状态码处理
    local status_status_code=1
    if [[ $status_code -ge 400 ]]; then
        status_status_code=2
    fi
    
    # 构建追踪数据
    local trace_data='{
        "resourceSpans": [
            {
                "resource": {
                    "attributes": [
                        {"key": "service.name", "value": {"stringValue": "'$service'"}},
                        {"key": "service.version", "value": {"stringValue": "1.0.0"}},
                        {"key": "deployment.environment", "value": {"stringValue": "production"}}
                    ]
                },
                "scopeSpans": [
                    {
                        "scope": {"name": "'$service'-tracer", "version": "1.0.0"},
                        "spans": [
                            {
                                "traceId": "'$trace_id'",
                                "spanId": "'$span_id'",
                                "name": "'$http_method' '$http_path'",
                                "kind": 2,
                                "startTimeUnixNano": '$(($historical_timestamp * 1000000000))',
                                "endTimeUnixNano": '$(($historical_timestamp * 1000000000 + $response_time * 1000000))',
                                "status": {"code": '$status_status_code'},
                                "attributes": [
                                    {"key": "http.method", "value": {"stringValue": "'$http_method'"}},
                                    {"key": "http.url", "value": {"stringValue": "https://api.example.com'$http_path'"}},
                                    {"key": "http.status_code", "value": {"intValue": '$status_code'}},
                                    {"key": "span.kind", "value": {"stringValue": "server"}}
                                ]
                            }
                        ]
                    }
                ]
            }
        ]
    }'
    
    echo "$trace_data"
}

# 开始生成历史数据
echo -e "${PURPLE}开始生成历史数据...${NC}"

total_sent=0
total_failed=0
current_minute=0

for minute in $(seq $TOTAL_MINUTES -1 1); do
    current_minute=$((current_minute + 1))
    echo -ne "${YELLOW}📦 进度 $current_minute/$TOTAL_MINUTES 分钟: ${NC}"
    
    minute_sent=0
    minute_failed=0
    
    for trace in $(seq 1 $TRACES_PER_MINUTE); do
        trace_data=$(generate_historical_trace $minute $trace)
        
        # 发送数据到Tempo
        if [[ $ENDPOINT == *"4318"* ]]; then
            # OTLP HTTP
            response=$(echo "$trace_data" | curl -X POST "$ENDPOINT" \
                -H "Content-Type: application/json" \
                -d @- -w "%{http_code}" -s -o /dev/null 2>/dev/null)
        else
            # OTLP gRPC (简化为HTTP方式)
            response=$(echo "$trace_data" | curl -X POST "http://localhost:4318/v1/traces" \
                -H "Content-Type: application/json" \
                -d @- -w "%{http_code}" -s -o /dev/null 2>/dev/null)
        fi
        
        if [ "$response" = "200" ]; then
            minute_sent=$((minute_sent + 1))
            total_sent=$((total_sent + 1))
        else
            minute_failed=$((minute_failed + 1))
            total_failed=$((total_failed + 1))
        fi
        
        # 控制发送频率
        sleep 0.1
    done
    
    echo -e "${GREEN}✅ $minute_sent${NC} ${RED}❌ $minute_failed${NC}"
    
    # 每分钟之间稍作停顿
    sleep 1
done

echo ""
echo -e "${BLUE}数据发送完成${NC}"
echo "================"
echo -e "${GREEN}✅ 总成功: $total_sent 个追踪${NC}"
echo -e "${RED}❌ 总失败: $total_failed 个追踪${NC}"
echo -e "${YELLOW}📊 时间跨度: $TOTAL_MINUTES 分钟${NC}"

# 等待metrics生成
echo ""
echo -e "${BLUE}等待TraceQL Metrics生成...${NC}"
echo "=========================="
echo -e "${YELLOW}⏱️ 等待300秒让local-blocks处理器生成metrics...${NC}"

for i in {300..1}; do
    if [ $((i % 60)) -eq 0 ] || [ $i -le 10 ]; then
        echo -ne "${GRAY}剩余 $i 秒...\r${NC}"
    fi
    sleep 1
done

echo -e "\n${GREEN}✅ 数据处理完成！${NC}"
echo ""
echo -e "${CYAN}现在您可以在Grafana中查看TraceQL Metrics:${NC}"
echo "1. 时间范围: 设置为 'Last 1 hour' 或 'Last 3 hours'"
echo "2. 数据源: 确保选择 'Tempo'"
echo "3. 刷新页面 (Ctrl+F5)"
echo "4. 查看 Span Rate, Breakdown, Service Structure 等模块"
echo ""
echo -e "${GREEN}🎉 TraceQL Metrics数据生成完成！${NC}" 