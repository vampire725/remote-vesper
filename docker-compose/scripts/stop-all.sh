#!/bin/bash

# OpenTelemetry 分布式追踪系统 - 快速关闭脚本 (保留数据)
echo "=========================================="
echo "  OpenTelemetry 系统关闭"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🛑 开始关闭 OpenTelemetry 分布式追踪系统...${NC}"
echo -e "${GREEN}ℹ 数据和配置将被保留，稍后可以快速重启${NC}"
echo ""

# 按反向依赖顺序停止服务
services=("../collector" "../grafana" "../tempo" "../prometheus")
service_descriptions=("OpenTelemetry Collector" "Grafana" "Tempo" "Prometheus")

for i in "${!services[@]}"; do
    service="${services[$i]}"
    description="${service_descriptions[$i]}"
    
    echo -e "${BLUE}⏹ 停止 $description...${NC}"
    
    if [ -d "$service" ]; then
        cd "$service"
        
        if [ -f "docker-compose.yaml" ]; then
            # 只停止服务，不删除容器和数据卷
            docker-compose stop 2>/dev/null || true
            service_name=$(basename "$service")
            echo -e "${GREEN}   ✅ $service_name 已停止${NC}"
        else
            echo -e "${YELLOW}   ⚠ 未找到 docker-compose.yaml${NC}"
        fi
        
        cd - > /dev/null
    else
        echo -e "${YELLOW}   ⚠ 目录 $service 不存在${NC}"
    fi
    echo ""
done

# 验证停止状态
echo -e "${BLUE}🔍 验证停止状态...${NC}"

# 检查相关容器状态
running_containers=$(docker ps --format "{{.Names}}" | grep -E "(prometheus|tempo|grafana|otel-collector)" 2>/dev/null || true)
stopped_containers=$(docker ps -a --filter "status=exited" --format "{{.Names}}" | grep -E "(prometheus|tempo|grafana|otel-collector)" 2>/dev/null || true)

if [ -z "$running_containers" ]; then
    echo -e "${GREEN}   ✅ 所有服务已停止${NC}"
else
    echo -e "${YELLOW}   ⚠ 仍有运行中的容器: $running_containers${NC}"
fi

if [ -n "$stopped_containers" ]; then
    echo -e "${BLUE}   ℹ 已停止的容器: $stopped_containers${NC}"
fi

echo ""

# 显示数据卷状态
echo -e "${BLUE}📂 数据卷状态:${NC}"
volumes=$(docker volume ls --format "{{.Name}}" | grep -E "(prometheus|tempo|grafana|otel|collector)" 2>/dev/null || true)
if [ -n "$volumes" ]; then
    echo -e "${GREEN}   ✅ 数据卷已保留:${NC}"
    echo "$volumes" | sed 's/^/     /'
else
    echo -e "${YELLOW}   ⚠ 未找到相关数据卷${NC}"
fi

echo ""

# 显示关闭结果
echo "=========================================="
echo -e "${GREEN}✅ 系统关闭完成！${NC}"
echo "=========================================="
echo ""
echo -e "${BLUE}📊 当前状态:${NC}"
echo "  🛑 所有服务已停止"
echo "  💾 数据和配置已保留"
echo "  🔗 网络连接已保留"
echo ""
echo -e "${GREEN}💡 下次启动选项:${NC}"
echo "  ./start-existing.sh    # 快速启动 (使用现有容器)"
echo "  ./start-all.sh         # 完全重新构建启动"
echo ""
echo -e "${YELLOW}🔧 其他选项:${NC}"
echo "  ./status.sh            # 查看系统状态"
echo "  ./logs.sh [服务名]     # 查看服务日志"
echo "  ./cleanup.sh           # 完全清理 (删除所有数据)" 