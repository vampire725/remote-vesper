#!/bin/bash

echo "🔍 检查Tempo指标"
echo "==============="

echo "1. 获取所有Tempo指标..."
metrics=$(curl -s "http://localhost:3200/metrics" 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$metrics" ]; then
    echo "❌ 无法连接到Tempo指标端点"
    exit 1
fi

echo "2. 查找追踪相关指标..."
echo ""

# 查找不同的追踪指标
echo "📊 追踪接收指标:"
echo "$metrics" | grep -E "(ingester|receiver|traces).*total" | head -5

echo ""
echo "📊 OTLP相关指标:"
echo "$metrics" | grep -i "otlp" | head -5

echo ""
echo "📊 服务图指标:"
echo "$metrics" | grep -i "service_graph" | head -5

echo ""
echo "📊 HTTP接收器指标:"
echo "$metrics" | grep -E "(http|request).*total" | head -5

echo ""
echo "📊 所有包含'traces'的指标:"
echo "$metrics" | grep -i "traces" | head -10

echo ""
echo "✅ 指标检查完成" 