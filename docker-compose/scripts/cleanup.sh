#!/bin/bash

# OpenTelemetry 分布式追踪系统 - 完全清理脚本
echo "=========================================="
echo "  OpenTelemetry 系统完全清理"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 确认清理操作
echo -e "${YELLOW}⚠ 警告: 此操作将完全删除所有容器、数据卷和配置！${NC}"
echo -e "${YELLOW}   这将丢失所有存储的追踪数据、指标数据和 Grafana 配置！${NC}"
echo ""
read -p "确定要继续吗？(输入 'yes' 确认): " confirm

if [ "$confirm" != "yes" ]; then
    echo -e "${BLUE}ℹ 清理操作已取消${NC}"
    exit 0
fi

echo ""
echo -e "${RED}🧹 开始完全清理...${NC}"
echo ""

# 1. 停止并删除所有服务容器和数据卷
services=("../collector" "../grafana" "../tempo" "../prometheus")
service_descriptions=("OpenTelemetry Collector" "Grafana" "Tempo" "Prometheus")

for i in "${!services[@]}"; do
    service="${services[$i]}"
    description="${service_descriptions[$i]}"
    
    echo -e "${BLUE}🛑 清理 $description...${NC}"
    
    if [ -d "$service" ]; then
        cd "$service"
        
        # 停止并删除容器和数据卷
        if [ -f "docker-compose.yaml" ]; then
            echo "   停止服务..."
            docker-compose down -v --remove-orphans 2>/dev/null || true
            
            echo "   删除未使用的镜像..."
            docker-compose down --rmi local 2>/dev/null || true
        fi
        
        cd - > /dev/null
        service_name=$(basename "$service")
        echo -e "${GREEN}   ✅ $service_name 清理完成${NC}"
    else
        echo -e "${YELLOW}   ⚠ 目录 $service 不存在${NC}"
    fi
    echo ""
done

# 2. 删除相关的 Docker 数据卷
echo -e "${BLUE}🗂 清理 Docker 数据卷...${NC}"
volumes_to_remove=(
    "prometheus_prometheus-storage"
    "tempo_tempo-data" 
    "grafana_grafana-storage"
    "collector_otel-data"
)

for volume in "${volumes_to_remove[@]}"; do
    if docker volume ls | grep -q "$volume"; then
        echo "   删除数据卷: $volume"
        docker volume rm "$volume" 2>/dev/null || true
    fi
done

# 查找并删除所有相关数据卷
echo "   查找并删除所有相关数据卷..."
docker volume ls --format "{{.Name}}" | grep -E "(prometheus|tempo|grafana|otel|collector)" | xargs -r docker volume rm 2>/dev/null || true
echo -e "${GREEN}   ✅ 数据卷清理完成${NC}"
echo ""

# 3. 删除网络
echo -e "${BLUE}🌐 删除网络...${NC}"
if docker network ls | grep -q "tracing-network"; then
    docker network rm tracing-network 2>/dev/null || true
    echo -e "${GREEN}   ✅ 网络 tracing-network 已删除${NC}"
else
    echo -e "${YELLOW}   ⚠ 网络 tracing-network 不存在${NC}"
fi
echo ""

# 4. 清理未使用的 Docker 资源
echo -e "${BLUE}🧽 清理未使用的 Docker 资源...${NC}"
echo "   清理未使用的容器..."
docker container prune -f 2>/dev/null || true

echo "   清理未使用的镜像..."
docker image prune -f 2>/dev/null || true

echo "   清理未使用的网络..."
docker network prune -f 2>/dev/null || true

echo "   清理未使用的数据卷..."
docker volume prune -f 2>/dev/null || true

echo -e "${GREEN}   ✅ Docker 资源清理完成${NC}"
echo ""

# 5. 验证清理结果
echo -e "${BLUE}🔍 验证清理结果...${NC}"

# 检查容器
remaining_containers=$(docker ps -a --format "{{.Names}}" | grep -E "(prometheus|tempo|grafana|otel-collector)" 2>/dev/null || true)
if [ -z "$remaining_containers" ]; then
    echo -e "${GREEN}   ✅ 所有相关容器已清理${NC}"
else
    echo -e "${YELLOW}   ⚠ 仍有残留容器: $remaining_containers${NC}"
fi

# 检查数据卷
remaining_volumes=$(docker volume ls --format "{{.Name}}" | grep -E "(prometheus|tempo|grafana|otel|collector)" 2>/dev/null || true)
if [ -z "$remaining_volumes" ]; then
    echo -e "${GREEN}   ✅ 所有相关数据卷已清理${NC}"
else
    echo -e "${YELLOW}   ⚠ 仍有残留数据卷: $remaining_volumes${NC}"
fi

# 检查网络
if ! docker network ls | grep -q "tracing-network"; then
    echo -e "${GREEN}   ✅ 追踪网络已清理${NC}"
else
    echo -e "${YELLOW}   ⚠ 追踪网络仍然存在${NC}"
fi

echo ""

# 6. 显示清理结果
echo "=========================================="
echo -e "${GREEN}🎯 清理完成！${NC}"
echo "=========================================="
echo ""
echo -e "${GREEN}已清理的组件:${NC}"
echo "  ✅ 所有容器 (prometheus, tempo, grafana, otel-collector)"
echo "  ✅ 所有数据卷 (追踪数据、指标数据、Grafana 配置)"
echo "  ✅ 共享网络 (tracing-network)"
echo "  ✅ 未使用的 Docker 资源"
echo ""
echo -e "${BLUE}💡 重新开始部署:${NC}"
echo "  ./start-all.sh     # 从零开始部署"
echo ""
echo -e "${YELLOW}⚠ 注意: 所有历史数据已永久删除！${NC}" 