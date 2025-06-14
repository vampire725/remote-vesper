#!/bin/bash

# OpenTelemetry 分布式追踪系统 - 完整启动脚本
echo "=========================================="
echo "  OpenTelemetry 分布式追踪系统启动"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 错误处理
set -e
trap 'echo -e "${RED}❌ 启动过程中发生错误，正在清理...${NC}"; exit 1' ERR

echo -e "${BLUE}🚀 开始启动 OpenTelemetry 分布式追踪系统...${NC}"
echo ""

# 1. 创建共享网络
echo -e "${BLUE}📡 创建共享网络...${NC}"
if docker network ls | grep -q "tracing-network"; then
    echo -e "${YELLOW}⚠ 网络 tracing-network 已存在${NC}"
else
    docker network create tracing-network
    echo -e "${GREEN}✅ 网络 tracing-network 创建成功${NC}"
fi
echo ""

# 2. 检查目录结构
echo -e "${BLUE}📁 检查目录结构...${NC}"
required_dirs=("../prometheus" "../tempo" "../grafana" "../collector")
for dir in "${required_dirs[@]}"; do
    if [ ! -d "$dir" ]; then
        echo -e "${RED}❌ 缺少目录: $dir${NC}"
        exit 1
    fi
    if [ ! -f "$dir/docker-compose.yaml" ]; then
        echo -e "${RED}❌ 缺少文件: $dir/docker-compose.yaml${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✅ 目录结构检查完成${NC}"
echo ""

# 3. 启动服务 (按依赖顺序)
services=("../prometheus" "../tempo" "../grafana" "../collector")
service_descriptions=("Prometheus (指标收集)" "Tempo (追踪存储)" "Grafana (可视化)" "OpenTelemetry Collector (数据采集)")

for i in "${!services[@]}"; do
    service="${services[$i]}"
    description="${service_descriptions[$i]}"
    
    echo -e "${BLUE}🔄 启动 $description...${NC}"
    cd "$service"
    
    # 拉取最新镜像
    echo "   正在拉取最新镜像..."
    docker-compose pull --quiet
    
    # 启动服务
    docker-compose up -d
    
    # 等待服务启动
    echo "   等待服务启动..."
    sleep 10
    
    # 检查服务状态
    if docker-compose ps | grep -q "Up"; then
        service_name=$(basename "$service")
        echo -e "${GREEN}   ✅ $service_name 启动成功${NC}"
    else
        echo -e "${RED}   ❌ $(basename "$service") 启动失败${NC}"
        docker-compose logs --tail=20
        exit 1
    fi
    
    cd - > /dev/null
    echo ""
done

# 4. 等待所有服务就绪
echo -e "${BLUE}⏳ 等待所有服务完全就绪 (30秒)...${NC}"
sleep 30

# 5. 健康检查
echo -e "${BLUE}🏥 执行健康检查...${NC}"
health_checks=(
    "Prometheus:http://localhost:9090/healthy"
    "Tempo:http://localhost:3200/ready" 
    "Grafana:http://localhost:3000/api/health"
    "OTel Collector:http://localhost:13133/health"
)

all_healthy=true
for check in "${health_checks[@]}"; do
    service_name=$(echo "$check" | cut -d: -f1)
    url=$(echo "$check" | sed "s/^[^:]*://")
    
    echo -n "   检查 $service_name: "
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

echo ""

# 6. 显示启动结果
if [ "$all_healthy" = true ]; then
    echo -e "${GREEN}🎉 所有服务启动成功！${NC}"
    echo ""
    echo "=========================================="
    echo -e "${GREEN}📋 服务访问信息${NC}"
    echo "=========================================="
    echo -e "${BLUE}🔍 Grafana (可视化界面):${NC}     http://localhost:3000"
    echo -e "   登录信息: admin / admin"
    echo ""
    echo -e "${BLUE}📊 Prometheus (指标查询):${NC}    http://localhost:9090"
    echo ""
    echo -e "${BLUE}🔧 OTel Collector (数据采集):${NC}"
    echo "   OTLP gRPC: localhost:4316"
    echo "   OTLP HTTP: localhost:4318"
    echo "   健康检查:   http://localhost:13133"
    echo "   指标导出:   http://localhost:8889/metrics"
    echo ""
    echo -e "${BLUE}🎯 Tempo (追踪存储):${NC}         http://localhost:3200"
    echo ""
    echo "=========================================="
    echo -e "${YELLOW}💡 接下来的步骤:${NC}"
    echo "1. 访问 Grafana: http://localhost:3000"
    echo "2. 发送测试数据: ./send-test-data.sh"
    echo "3. 检查服务图: ./check-service-graph.sh"
    echo ""
    echo -e "${GREEN}✨ 系统已成功启动并准备就绪！${NC}"
else
    echo -e "${RED}⚠ 部分服务可能存在问题，请检查日志${NC}"
    echo "使用以下命令检查日志:"
    echo "  ./logs.sh [服务名]"
    exit 1
fi 