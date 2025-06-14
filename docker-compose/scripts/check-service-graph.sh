#!/bin/bash

echo "=========================================="
echo "     服务图数据检查脚本"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_service() {
    local service_name=$1
    local url=$2
    local description=$3
    
    echo -n "检查 $description ($service_name): "
    if curl -s --connect-timeout 5 --max-time 10 "$url" > /dev/null; then
        echo -e "${GREEN}✓ 正常${NC}"
        return 0
    else
        echo -e "${RED}✗ 失败${NC}"
        return 1
    fi
}

# 1. 检查各服务健康状态
echo "1. 检查各服务状态:"
check_service "tempo" "http://localhost:3200/ready" "Tempo 健康检查"
check_service "prometheus" "http://localhost:9090/-/healthy" "Prometheus 健康检查"
check_service "grafana" "http://localhost:3000/api/health" "Grafana 健康检查"
check_service "otel-collector" "http://localhost:13133/" "OTel Collector 健康检查"

echo ""

# 2. 检查 Tempo 指标端点
echo "2. 检查 Tempo 指标:"
tempo_metrics=$(curl -s http://localhost:3200/metrics 2>/dev/null)
if [[ $? -eq 0 && -n "$tempo_metrics" ]]; then
    echo -e "${GREEN}✓ Tempo 指标端点可访问${NC}"
    
    # 检查服务图相关指标
    service_graph_metrics=$(echo "$tempo_metrics" | grep -E "(traces_service_graph|tempo_metrics_generator)" | head -5)
    if [[ -n "$service_graph_metrics" ]]; then
        echo -e "${GREEN}✓ 发现服务图相关指标:${NC}"
        echo "$service_graph_metrics" | sed 's/^/  /'
    else
        echo -e "${YELLOW}⚠ 未发现服务图指标 (可能需要先发送追踪数据)${NC}"
    fi
else
    echo -e "${RED}✗ Tempo 指标端点不可访问${NC}"
fi

echo ""

# 3. 检查 Prometheus 是否收到服务图指标
echo "3. 检查 Prometheus 中的服务图指标:"
prom_query="traces_service_graph_request_total"
prom_response=$(curl -s "http://localhost:9090/api/v1/query?query=$prom_query" 2>/dev/null)

if [[ $? -eq 0 ]]; then
    # 检查是否有数据
    result_count=$(echo "$prom_response" | jq -r '.data.result | length' 2>/dev/null)
    if [[ "$result_count" -gt 0 ]]; then
        echo -e "${GREEN}✓ Prometheus 中发现服务图指标数据${NC}"
        echo "  指标数量: $result_count"
    else
        echo -e "${YELLOW}⚠ Prometheus 中暂无服务图数据${NC}"
    fi
else
    echo -e "${RED}✗ 无法查询 Prometheus${NC}"
fi

echo ""

# 4. 检查 Grafana 数据源配置
echo "4. 检查 Grafana 数据源:"
grafana_auth="admin:admin"
datasources_response=$(curl -s -u "$grafana_auth" "http://localhost:3000/api/datasources" 2>/dev/null)

if [[ $? -eq 0 ]]; then
    tempo_ds=$(echo "$datasources_response" | jq -r '.[] | select(.type=="tempo") | .name' 2>/dev/null)
    prom_ds=$(echo "$datasources_response" | jq -r '.[] | select(.type=="prometheus") | .name' 2>/dev/null)
    
    if [[ -n "$tempo_ds" ]]; then
        echo -e "${GREEN}✓ Tempo 数据源已配置: $tempo_ds${NC}"
    else
        echo -e "${RED}✗ 未找到 Tempo 数据源${NC}"
    fi
    
    if [[ -n "$prom_ds" ]]; then
        echo -e "${GREEN}✓ Prometheus 数据源已配置: $prom_ds${NC}"
    else
        echo -e "${RED}✗ 未找到 Prometheus 数据源${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 无法访问 Grafana API (可能需要先登录)${NC}"
fi

echo ""

# 5. 提供解决建议
echo "=========================================="
echo "     故障排除建议"
echo "=========================================="

echo "如果没有服务图数据，请按以下步骤排查:"
echo ""
echo "1. 确保所有服务正常运行:"
echo "   docker-compose -f prometheus/docker-compose.yaml ps"
echo "   docker-compose -f tempo/docker-compose.yaml ps"
echo "   docker-compose -f grafana/docker-compose.yaml ps"
echo "   docker-compose -f collector/docker-compose.yaml ps"
echo ""
echo "2. 发送测试追踪数据:"
echo "   curl -X POST http://localhost:4318/v1/traces \\"
echo "     -H \"Content-Type: application/json\" \\"
echo "     -d '{\"resourceSpans\":[{\"resource\":{\"attributes\":[{\"key\":\"service.name\",\"value\":{\"stringValue\":\"test-service\"}}]},\"scopeSpans\":[{\"spans\":[{\"traceId\":\"5B8EFFF798038103D269B633813FC60C\",\"spanId\":\"EEE19B7EC3C1B174\",\"name\":\"test-operation\",\"kind\":1,\"startTimeUnixNano\":'$(date +%s%N)',\"endTimeUnixNano\":'$(($(date +%s%N) + 1000000000))',\"attributes\":[{\"key\":\"peer.service\",\"value\":{\"stringValue\":\"downstream-service\"}}],\"status\":{\"code\":1}}]}]}]}'"
echo ""
echo "3. 等待 1-2 分钟后再检查服务图"
echo ""
echo "4. 在 Grafana 中访问:"
echo "   - Explore → Tempo → Service Map"
echo "   - 或使用 TraceQL 查询: {service.name=\"test-service\"}"
echo ""
echo "5. 检查 Tempo 日志:"
echo "   docker-compose -f tempo/docker-compose.yaml logs tempo | grep -i \"metrics_generator\\|service_graph\"" 