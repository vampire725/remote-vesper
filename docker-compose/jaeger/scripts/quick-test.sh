#!/bin/bash

# 快速测试脚本 - 发送几条简单的测试数据到Jaeger

echo "🚀 快速测试数据生成器"
echo "====================================="

# 配置
ENDPOINT="${1:-http://localhost:4316}"
SERVICE_NAME="quick-test-service"

echo "📍 目标端点: $ENDPOINT"
echo "🏷️  服务名称: $SERVICE_NAME"
echo

# 检查服务是否可用
echo "🔍 检查服务可用性..."
if ! curl -s --max-time 3 "$ENDPOINT" > /dev/null 2>&1; then
    echo "❌ 服务不可用: $ENDPOINT"
    echo "请确保Jaeger服务正在运行:"
    echo "  cd jaeger-deploy && ./start.sh -d"
    exit 1
fi
echo "✅ 服务可用"
echo

# 生成简单的测试数据
echo "📊 生成测试数据..."

for i in {1..3}; do
    echo "  发送测试数据 $i/3..."
    
    # 生成随机ID
    TRACE_ID=$(printf "%016x%016x" $((RANDOM * RANDOM)) $((RANDOM * RANDOM)))
    SPAN_ID=$(printf "%016x" $((RANDOM * RANDOM)))
    TIMESTAMP=$(date +%s)000000000
    END_TIME=$((TIMESTAMP + 100000000))
    
    # 创建JSON数据
    DATA='{
      "resourceSpans": [
        {
          "resource": {
            "attributes": [
              {
                "key": "service.name",
                "value": {"stringValue": "'$SERVICE_NAME'"}
              },
              {
                "key": "deployment.environment",
                "value": {"stringValue": "test"}
              }
            ]
          },
          "scopeSpans": [
            {
              "scope": {
                "name": "quick-test"
              },
              "spans": [
                {
                  "traceId": "'$TRACE_ID'",
                  "spanId": "'$SPAN_ID'",
                  "name": "quick-test-operation-'$i'",
                  "kind": "SPAN_KIND_SERVER",
                  "startTimeUnixNano": "'$TIMESTAMP'",
                  "endTimeUnixNano": "'$END_TIME'",
                  "attributes": [
                    {
                      "key": "http.method",
                      "value": {"stringValue": "GET"}
                    },
                    {
                      "key": "test.id",
                      "value": {"stringValue": "'$i'"}
                    }
                  ],
                  "status": {
                    "code": "STATUS_CODE_OK"
                  }
                }
              ]
            }
          ]
        }
      ]
    }'
    
    # 发送数据
    HTTP_CODE=$(curl -s -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "$DATA" \
        "$ENDPOINT/v1/traces" \
        -o /dev/null)
    
    if [[ "$HTTP_CODE" =~ ^2[0-9][0-9]$ ]]; then
        echo "  ✅ 成功 (HTTP $HTTP_CODE)"
    else
        echo "  ❌ 失败 (HTTP $HTTP_CODE)"
    fi
    
    sleep 0.5
done

echo
echo "🎉 快速测试完成！"
echo
echo "📋 下一步:"
echo "1. 访问 Jaeger UI: http://localhost:16686"
echo "2. 在服务下拉框中选择: $SERVICE_NAME"
echo "3. 点击 'Find Traces' 查看数据"
echo
echo "💡 提示:"
echo "- 如果没有看到数据，请等待几秒钟后刷新页面"
echo "- 确保时间范围设置正确（最近1小时）" 