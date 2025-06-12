#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🏥 执行健康检查...${NC}"
health_checks=(
    "Prometheus:http://localhost:9090/-/healthy"
    "Tempo:http://localhost:3200/ready" 
    "Grafana:http://localhost:3000/api/health"
    "OTel Collector:http://localhost:13133/"
)

all_healthy=true
for check in "${health_checks[@]}"; do
    service_name=$(echo "$check" | cut -d: -f1)
    url=$(echo "$check" | sed "s/^[^:]*://")
    
    echo -n "   检查 $service_name: "
    echo -n "   health url $url"

    response=$(curl -s -w "\n%{http_code}" --connect-timeout 5 --max-time 10 "$url")
    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | head -n -1)
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✅ 健康${NC}"
        echo "      响应: $response_body"
    else
        echo -e "${RED}❌ 不健康 (HTTP状态码: $http_code)${NC}"
        echo "      响应: $response_body"
        all_healthy=false
    fi
done

if [ "$all_healthy" = true ]; then
    echo -e "\n${GREEN}✨ 所有服务健康检查通过！${NC}"
else
    echo -e "\n${RED}⚠ 部分服务健康检查失败${NC}"
fi 