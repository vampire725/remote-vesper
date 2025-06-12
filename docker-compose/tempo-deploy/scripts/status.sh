#!/bin/bash

# OpenTelemetry 分布式追踪系统 - 状态查看脚本
echo "=========================================="
echo "  OpenTelemetry 系统状态"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 1. 容器状态
echo -e "${BLUE}📦 容器状态:${NC}"
containers=$(docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(prometheus|tempo|grafana|otel-collector)" 2>/dev/null || true)

if [ -n "$containers" ]; then
    echo "$containers"
else
    echo -e "${YELLOW}   ⚠ 未找到相关容器${NC}"
fi
echo ""

# 2. 网络状态
echo -e "${BLUE}🌐 网络状态:${NC}"
if docker network ls | grep -q "tracing-network"; then
    echo -e "${GREEN}   ✅ tracing-network 网络存在${NC}"
    
    # 显示网络中的容器
    network_containers=$(docker network inspect tracing-network --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null || true)
    if [ -n "$network_containers" ]; then
        echo "   连接的容器: $network_containers"
    fi
else
    echo -e "${RED}   ❌ tracing-network 网络不存在${NC}"
fi
echo ""

# 3. 数据卷状态
echo -e "${BLUE}💾 数据卷状态:${NC}"
volumes=$(docker volume ls --format "table {{.Name}}\t{{.Driver}}" | grep -E "(prometheus|tempo|grafana|otel|collector)" 2>/dev/null || true)

if [ -n "$volumes" ]; then
    echo "$volumes"
else
    echo -e "${YELLOW}   ⚠ 未找到相关数据卷${NC}"
fi
echo ""

# 4. 服务健康检查
echo -e "${BLUE}🏥 服务健康状态:${NC}"
health_checks=(
    "Prometheus:http://localhost:9090/-/healthy"
    "Tempo:http://localhost:3200/ready" 
    "Grafana:http://localhost:3000/api/health"
    "OTel Collector:http://localhost:13133/"
)

for check in "${health_checks[@]}"; do
    service_name=$(echo "$check" | cut -d: -f1)
    url=$(echo "$check" | cut -d: -f2-3)
    
    echo -n "   $service_name: "
    if curl -s --connect-timeout 3 --max-time 5 "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ 健康${NC}"
    else
        echo -e "${RED}❌ 不健康${NC}"
    fi
done
echo ""

# 5. 端口占用情况
echo -e "${BLUE}🔌 端口占用情况:${NC}"
ports=("3000:Grafana" "3200:Tempo" "4318:OTel-HTTP" "4316:OTel-gRPC" "8889:Collector-Metrics" "9090:Prometheus" "13133:Collector-Health")

for port_info in "${ports[@]}"; do
    port=$(echo "$port_info" | cut -d: -f1)
    service=$(echo "$port_info" | cut -d: -f2)
    
    if netstat -an 2>/dev/null | grep -q ":$port " || ss -ln 2>/dev/null | grep -q ":$port "; then
        echo -e "${GREEN}   ✅ $port ($service) - 占用中${NC}"
    else
        echo -e "${RED}   ❌ $port ($service) - 空闲${NC}"
    fi
done
echo ""

# 6. 资源使用情况
echo -e "${BLUE}📊 资源使用情况:${NC}"
container_stats=$(docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null | grep -E "(prometheus|tempo|grafana|otel-collector)" || true)

if [ -n "$container_stats" ]; then
    echo "$container_stats"
else
    echo -e "${YELLOW}   ⚠ 无法获取资源使用数据${NC}"
fi
echo ""

# 7. 磁盘使用情况
echo -e "${BLUE}💿 磁盘使用情况:${NC}"
volume_usage=$(docker system df -v 2>/dev/null | grep -E "(prometheus|tempo|grafana|otel|collector)" || true)

if [ -n "$volume_usage" ]; then
    echo "$volume_usage"
else
    echo -e "${YELLOW}   ⚠ 无法获取磁盘使用数据${NC}"
fi
echo ""

# 8. 系统总结
echo "=========================================="
echo -e "${BLUE}📋 系统总结${NC}"
echo "=========================================="

# 统计运行中的容器
running_count=$(docker ps --format "{{.Names}}" | grep -cE "(prometheus|tempo|grafana|otel-collector)" 2>/dev/null || echo "0")
total_count=$(docker ps -a --format "{{.Names}}" | grep -cE "(prometheus|tempo|grafana|otel-collector)" 2>/dev/null || echo "0")

echo "容器状态: $running_count/$total_count 运行中"

# 统计健康的服务
healthy_count=0
for check in "${health_checks[@]}"; do
    url=$(echo "$check" | cut -d: -f2-3)
    if curl -s --connect-timeout 3 --max-time 5 "$url" > /dev/null 2>&1; then
        ((healthy_count++))
    fi
done

echo "服务健康: $healthy_count/${#health_checks[@]} 健康"

# 数据卷数量
volume_count=$(docker volume ls --format "{{.Name}}" | grep -cE "(prometheus|tempo|grafana|otel|collector)" 2>/dev/null || echo "0")
echo "数据卷: $volume_count 个"

# 网络状态
if docker network ls | grep -q "tracing-network"; then
    echo -e "网络: ${GREEN}正常${NC}"
else
    echo -e "网络: ${RED}缺失${NC}"
fi

echo ""
echo -e "${YELLOW}💡 管理命令:${NC}"
echo "  ./start-all.sh        # 完整启动"
echo "  ./start-existing.sh   # 快速启动"
echo "  ./stop-all.sh         # 停止服务"
echo "  ./cleanup.sh          # 完全清理"
echo "  ./logs.sh [服务名]    # 查看日志" 