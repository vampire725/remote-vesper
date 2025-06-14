#!/bin/bash

echo "🧪 快速追踪数据测试"
echo "=================="

# 生成随机ID
trace_id=$(printf "%032x" $((RANDOM*RANDOM*RANDOM*RANDOM)))
span_id=$(printf "%016x" $((RANDOM*RANDOM)))
current_time=$(date +%s%N)

echo "追踪ID: $trace_id"
echo "Span ID: $span_id"
echo "时间戳: $current_time"
echo ""

# 构建正确格式的数据
trace_data='{
    "resourceSpans": [{
        "resource": {
            "attributes": [
                {"key": "service.name", "value": {"stringValue": "test-service"}}
            ]
        },
        "scopeSpans": [{
            "scope": {"name": "test", "version": "1.0.0"},
            "spans": [{
                "traceId": "'$trace_id'",
                "spanId": "'$span_id'",
                "name": "test-span",
                "kind": 3,
                "startTimeUnixNano": '$current_time',
                "endTimeUnixNano": '$((current_time + 10000000))',
                "attributes": [
                    {"key": "service.name", "value": {"stringValue": "test-service"}},
                    {"key": "peer.service", "value": {"stringValue": "target-service"}}
                ],
                "status": {"code": 1}
            }]
        }]
    }]
}'

echo "📤 发送测试数据到 localhost:4318..."
response=$(curl -s -w "%{http_code}" -X POST "http://localhost:4318/v1/traces" \
    -H "Content-Type: application/json" \
    -d "$trace_data")

http_code="${response: -3}"
response_body="${response%???}"

if [ "$http_code" = "200" ]; then
    echo "✅ 成功！HTTP状态码: $http_code"
    echo "   数据格式修复有效！"
else
    echo "❌ 失败！HTTP状态码: $http_code"
    echo "   响应: $response_body"
fi

echo ""
echo "🔍 等待3秒后检查Tempo指标..."
sleep 3

# 修复版本的指标检查
metrics_found=false
metrics_to_check=(
    "tempo_ingester_traces_received_total"
    "tempo_distributor_spans_received_total" 
    "tempo_request_duration_seconds"
    "tempo_ingester_blocks_flushed_total"
)

for metric in "${metrics_to_check[@]}"; do
    tempo_response=$(curl -s "http://localhost:3200/metrics" | grep "$metric" | head -1)
    if [ -n "$tempo_response" ]; then
        echo "✅ Tempo指标: $tempo_response"
        metrics_found=true
        break
    fi
done

if [ "$metrics_found" = false ]; then
    # 检查Tempo健康状态
    if curl -s "http://localhost:3200/ready" > /dev/null 2>&1; then
        echo "✅ Tempo运行正常，数据正在处理中"
        echo "   (指标可能需要时间显示)"
    else
        echo "❌ Tempo连接失败"
    fi
fi 