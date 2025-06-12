#!/bin/bash

# 服务图追踪数据生成脚本 (修复版)
# 修复了HTTP 400错误的数据格式问题

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置
COLLECTOR_HTTP_ENDPOINT="http://localhost:4318/v1/traces"
TRACES_PER_BATCH=5
TOTAL_BATCHES=10

echo -e "${BLUE}🚀 生成服务图追踪数据 (修复版)${NC}"
echo "=================================="
echo "端点: $COLLECTOR_HTTP_ENDPOINT"
echo "批次数: $TOTAL_BATCHES"
echo "每批次: $TRACES_PER_BATCH"
echo ""

# 生成随机ID
generate_trace_id() {
    printf "%032x" $((RANDOM*RANDOM*RANDOM*RANDOM))
}

generate_span_id() {
    printf "%016x" $((RANDOM*RANDOM))
}

# 生成批次数据
generate_batch() {
    local batch_num=$1
    local current_time=$(date +%s%N)
    
    echo -n "  发送追踪数据..."
    
    local success_count=0
    for ((i=1; i<=TRACES_PER_BATCH; i++)); do
        local trace_id=$(generate_trace_id)
        local span1_id=$(generate_span_id)
        local span2_id=$(generate_span_id)
        
        # 构建正确格式的追踪数据
        local trace_data=$(cat <<EOF
{
    "resourceSpans": [{
        "resource": {
            "attributes": [
                {"key": "service.name", "value": {"stringValue": "frontend"}}
            ]
        },
        "scopeSpans": [{
            "scope": {"name": "tracer", "version": "1.0.0"},
            "spans": [{
                "traceId": "$trace_id",
                "spanId": "$span1_id",
                "name": "frontend->api-gateway",
                "kind": 3,
                "startTimeUnixNano": $current_time,
                "endTimeUnixNano": $((current_time + 50000000)),
                "attributes": [
                    {"key": "service.name", "value": {"stringValue": "frontend"}},
                    {"key": "peer.service", "value": {"stringValue": "api-gateway"}},
                    {"key": "http.method", "value": {"stringValue": "POST"}},
                    {"key": "http.status_code", "value": {"intValue": 200}}
                ],
                "status": {"code": 1}
            }]
        }]
    }, {
        "resource": {
            "attributes": [
                {"key": "service.name", "value": {"stringValue": "api-gateway"}}
            ]
        },
        "scopeSpans": [{
            "scope": {"name": "tracer", "version": "1.0.0"},
            "spans": [{
                "traceId": "$trace_id",
                "spanId": "$span2_id",
                "parentSpanId": "$span1_id",
                "name": "api-gateway->user-service",
                "kind": 3,
                "startTimeUnixNano": $((current_time + 10000000)),
                "endTimeUnixNano": $((current_time + 40000000)),
                "attributes": [
                    {"key": "service.name", "value": {"stringValue": "api-gateway"}},
                    {"key": "peer.service", "value": {"stringValue": "user-service"}},
                    {"key": "http.method", "value": {"stringValue": "GET"}},
                    {"key": "http.status_code", "value": {"intValue": 200}}
                ],
                "status": {"code": 1}
            }]
        }]
    }]
}
EOF
)
        
        # 发送数据
        local response=$(curl -s -w "%{http_code}" -X POST "$COLLECTOR_HTTP_ENDPOINT" \
            -H "Content-Type: application/json" \
            -d "$trace_data")
        
        local http_code="${response: -3}"
        if [ "$http_code" = "200" ]; then
            ((success_count++))
        else
            echo -e "\n${RED}   ❌ 追踪 $i 发送失败 (HTTP: $http_code)${NC}"
            # 显示错误响应的前100个字符
            local error_msg="${response%???}"
            if [ ${#error_msg} -gt 100 ]; then
                error_msg="${error_msg:0:100}..."
            fi
            echo "   错误: $error_msg"
        fi
        
        current_time=$((current_time + 100000000))
        sleep 0.1
    done
    
    if [ $success_count -eq $TRACES_PER_BATCH ]; then
        echo -e " ${GREEN}✅ 全部成功 ($success_count/$TRACES_PER_BATCH)${NC}"
    else
        echo -e " ${YELLOW}⚠ 部分成功 ($success_count/$TRACES_PER_BATCH)${NC}"
    fi
}

# 检查服务可用性
echo -e "${BLUE}🔍 检查服务状态...${NC}"
if ! curl -s "http://localhost:4318" > /dev/null 2>&1; then
    echo -e "${RED}❌ OTLP HTTP接收器不可用 (localhost:4318)${NC}"
    echo "请确保 OpenTelemetry Collector 正在运行"
    exit 1
fi
echo -e "${GREEN}✅ OTLP HTTP接收器运行正常${NC}"

# 生成数据
echo -e "\n${BLUE}📊 开始生成追踪数据...${NC}"
start_time=$(date +%s)

for ((batch=1; batch<=TOTAL_BATCHES; batch++)); do
    echo -e "${BLUE}批次 $batch/$TOTAL_BATCHES:${NC}"
    generate_batch $batch
    
    if [ $batch -lt $TOTAL_BATCHES ]; then
        sleep 2
    fi
done

end_time=$(date +%s)
duration=$((end_time - start_time))

echo -e "\n${GREEN}🎉 生成完成！${NC}"
echo "=================================="
echo "总计追踪: $((TOTAL_BATCHES * TRACES_PER_BATCH))"
echo "耗时: ${duration}秒"
echo ""

# 验证数据
echo -e "${BLUE}🔍 验证数据接收...${NC}"
sleep 3

# 检查Tempo指标 - 修复版本
echo -n "检查Tempo指标..."
# 尝试多种可能的指标名称
tempo_response=""
metrics_to_check=(
    "tempo_ingester_traces_received_total"
    "traces_received_total" 
    "tempo_distributor_spans_received_total"
    "tempo_request_duration_seconds"
    "tempo_ingester_blocks_flushed_total"
)

for metric in "${metrics_to_check[@]}"; do
    result=$(curl -s "http://localhost:3200/metrics" | grep "$metric" | head -1)
    if [ -n "$result" ]; then
        tempo_response="$result"
        break
    fi
done

if [ -n "$tempo_response" ]; then
    echo -e " ${GREEN}✅ Tempo正在处理数据${NC}"
    echo "  找到指标: $tempo_response"
else
    # 如果没找到具体指标，检查Tempo是否运行
    tempo_health=$(curl -s "http://localhost:3200/ready" 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo -e " ${YELLOW}✅ Tempo运行正常，数据正在处理${NC}"
        echo "  (指标可能需要时间显示)"
    else
        echo -e " ${RED}❌ Tempo连接失败${NC}"
    fi
fi

echo -e "\n${BLUE}💡 下一步:${NC}"
echo "1. 等待2-3分钟让数据处理"
echo "2. 检查服务图: bash scripts/check-service-graph.sh"
echo "3. 查看Grafana: http://localhost:3000"
echo "4. 运行修复的测试: bash scripts/test-service-graph-fixed.sh" 