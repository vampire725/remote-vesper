#!/bin/bash

# OpenTelemetry 分布式追踪系统 - 快速启动脚本 (现有容器)
echo "=========================================="
echo "  OpenTelemetry 快速启动 (现有容器)"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 快速启动 OpenTelemetry 分布式追踪系统...${NC}"
echo -e "${GREEN}ℹ 使用现有容器和数据，无需重新构建${NC}"
echo ""

# 1. 检查现有容器
echo -e "${BLUE}🔍 检查现有容器...${NC}"
services=("prometheus" "tempo" "grafana" "otel-collector")
existing_containers=()
missing_containers=()

for service in "${services[@]}"; do
    if docker ps -a --format "{{.Names}}" | grep -q "^${service}$"; then
        existing_containers+=("$service")
        echo -e "${GREEN}   ✅ 找到容器: $service${NC}"
    else
        missing_containers+=("$service")
        echo -e "${YELLOW}   ⚠ 缺少容器: $service${NC}"
    fi
done

echo ""

# 2. 如果有缺少的容器，提示用户使用完整启动
if [ ${#missing_containers[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠ 发现缺少的容器: ${missing_containers[*]}${NC}"
    echo ""
    echo -e "${BLUE}💡 建议操作:${NC}"
    echo "  1. 使用完整启动: ./start-all.sh"
    echo "  2. 手动创建缺少的服务"
    echo "  3. 继续启动现有容器 (部分功能可能不可用)"
    echo ""
    read -p "是否继续启动现有容器？(y/N): " continue_start
    
    if [[ ! "$continue_start" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}ℹ 启动已取消${NC}"
        echo "请运行 ./start-all.sh 进行完整部署"
        exit 0
    fi
fi

# 3. 检查网络
echo -e "${BLUE}🌐 检查网络...${NC}"
if docker network ls | grep -q "tracing-network"; then
    echo -e "${GREEN}   ✅ 网络 tracing-network 存在${NC}"
else
    echo -e "${YELLOW}   ⚠ 创建网络 tracing-network${NC}"
    docker network create tracing-network
fi
echo ""

# 4. 按依赖顺序启动服务
startup_order=("../prometheus" "../tempo" "../grafana" "../collector")
service_descriptions=("Prometheus (指标收集)" "Tempo (追踪存储)" "Grafana (可视化)" "OpenTelemetry Collector (数据采集)")

for i in "${!startup_order[@]}"; do
    service="${startup_order[$i]}"
    description="${service_descriptions[$i]}"
    service_name=$(basename "$service")
    
    # 检查是否存在容器
    if [[ " ${existing_containers[@]} " =~ " ${service_name} " ]] || [[ "$service_name" == "collector" && " ${existing_containers[@]} " =~ " otel-collector " ]]; then
        echo -e "${BLUE}▶ 启动 $description...${NC}"
        
        if [ -d "$service" ]; then
            cd "$service"
            
            if [ -f "docker-compose.yaml" ]; then
                # 启动现有容器
                docker-compose start 2>/dev/null || docker-compose up -d
                
                # 等待服务启动
                echo "   等待服务启动..."
                sleep 5
                
                # 检查服务状态
                if docker-compose ps | grep -q "Up"; then
                    echo -e "${GREEN}   ✅ $service_name 启动成功${NC}"
                else
                    echo -e "${RED}   ❌ $service_name 启动失败${NC}"
                    docker-compose logs --tail=10
                fi
            else
                echo -e "${RED}   ❌ 未找到 docker-compose.yaml${NC}"
            fi
            
            cd - > /dev/null
        else
            echo -e "${RED}   ❌ 目录 $service 不存在${NC}"
        fi
    else
        echo -e "${YELLOW}⏭ 跳过 $description (容器不存在)${NC}"
    fi
    echo ""
done

# 5. 等待服务就绪
echo -e "${BLUE}⏳ 等待服务就绪 (30秒)...${NC}"
sleep 30

# 6. 健康检查
echo -e "${BLUE}🏥 执行健康检查...${NC}"
health_checks=(
    "Prometheus:http://localhost:9090/-/healthy"
    "Tempo:http://localhost:3200/ready" 
    "Grafana:http://localhost:3000/api/health"
    "OTel Collector:http://localhost:13133/"
)

healthy_services=0
total_checks=0

for check in "${health_checks[@]}"; do
    service_name=$(echo "$check" | cut -d: -f1)
    url=$(echo "$check" | sed "s/^[^:]*://")
    
    echo -n "   检查 $service_name: "
    if curl -s --connect-timeout 3 --max-time 5 "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ 健康${NC}"
        ((healthy_services++))
    else
        echo -e "${RED}❌ 不健康${NC}"
    fi
    ((total_checks++))
done

echo ""

# 7. 显示启动结果
echo "=========================================="
if [ $healthy_services -eq $total_checks ]; then
    echo -e "${GREEN}🎉 系统快速启动成功！${NC}"
elif [ $healthy_services -gt 0 ]; then
    echo -e "${YELLOW}⚠ 系统部分启动成功 ($healthy_services/$total_checks 服务健康)${NC}"
else
    echo -e "${RED}❌ 系统启动失败${NC}"
fi

echo "=========================================="
echo ""

if [ $healthy_services -gt 0 ]; then
    echo -e "${GREEN}📋 可用服务:${NC}"
    
    # 只显示健康的服务
    if curl -s --connect-timeout 3 --max-time 5 "http://localhost:3000/api/health" > /dev/null 2>&1; then
        echo -e "${BLUE}🔍 Grafana (可视化界面):${NC}     http://localhost:3000"
        echo -e "   登录信息: admin / admin"
        echo ""
    fi
    
    if curl -s --connect-timeout 3 --max-time 5 "http://localhost:9090/-/healthy" > /dev/null 2>&1; then
        echo -e "${BLUE}📊 Prometheus (指标查询):${NC}    http://localhost:9090"
        echo ""
    fi
    
    if curl -s --connect-timeout 3 --max-time 5 "http://localhost:13133/" > /dev/null 2>&1; then
        echo -e "${BLUE}🔧 OTel Collector (数据采集):${NC}"
        echo "   OTLP gRPC: localhost:4316"
        echo "   OTLP HTTP: localhost:4318"
        echo "   健康检查:   http://localhost:13133"
        echo "   指标导出:   http://localhost:8889/metrics"
        echo ""
    fi
    
    if curl -s --connect-timeout 3 --max-time 5 "http://localhost:3200/ready" > /dev/null 2>&1; then
        echo -e "${BLUE}🎯 Tempo (追踪存储):${NC}         http://localhost:3200"
        echo ""
    fi
    
    echo "=========================================="
    echo -e "${YELLOW}💡 接下来的步骤:${NC}"
    echo "1. 检查系统状态: ./status.sh"
    echo "2. 发送测试数据: ./send-test-data.sh"
    echo "3. 检查服务图: ./check-service-graph.sh"
    echo ""
fi

if [ $healthy_services -lt $total_checks ]; then
    echo -e "${YELLOW}🔧 故障排除:${NC}"
    echo "1. 查看服务日志: ./logs.sh [服务名]"
    echo "2. 重启特定服务: cd ../[服务目录] && docker-compose restart"
    echo "3. 完全重新部署: ./cleanup.sh && ./start-all.sh"
    echo ""
fi

echo -e "${GREEN}✨ 快速启动完成！${NC}" 