#!/bin/bash

# OpenTelemetry 分布式追踪系统 - 日志查看脚本
echo "=========================================="
echo "  OpenTelemetry 日志查看工具"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 服务列表
services=("prometheus" "tempo" "grafana" "collector")
service_descriptions=("Prometheus (指标收集)" "Tempo (追踪存储)" "Grafana (可视化)" "OpenTelemetry Collector (数据采集)")

# 显示用法
show_usage() {
    echo -e "${BLUE}用法:${NC}"
    echo "  $0 [服务名] [选项]"
    echo ""
    echo -e "${BLUE}可用服务:${NC}"
    for i in "${!services[@]}"; do
        echo "  ${services[$i]} - ${service_descriptions[$i]}"
    done
    echo ""
    echo -e "${BLUE}选项:${NC}"
    echo "  -f, --follow     实时跟踪日志"
    echo "  -t, --tail N     显示最后N行 (默认50)"
    echo "  -s, --since T    显示从时间T开始的日志 (如: 2h, 30m, 2024-01-01)"
    echo "  -e, --errors     只显示错误日志"
    echo "  -h, --help       显示此帮助信息"
    echo ""
    echo -e "${BLUE}示例:${NC}"
    echo "  $0                    # 显示所有服务日志摘要"
    echo "  $0 tempo              # 显示 Tempo 日志"
    echo "  $0 tempo -f           # 实时跟踪 Tempo 日志"
    echo "  $0 collector -t 100   # 显示 Collector 最后100行日志"
    echo "  $0 grafana -e         # 只显示 Grafana 错误日志"
    echo "  $0 all -f             # 实时跟踪所有服务日志"
}

# 解析参数
service_name=""
follow_mode=false
tail_lines=50
since_time=""
errors_only=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--follow)
            follow_mode=true
            shift
            ;;
        -t|--tail)
            tail_lines="$2"
            shift 2
            ;;
        -s|--since)
            since_time="$2"
            shift 2
            ;;
        -e|--errors)
            errors_only=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            echo -e "${RED}❌ 未知选项: $1${NC}"
            show_usage
            exit 1
            ;;
        *)
            if [ -z "$service_name" ]; then
                service_name="$1"
            else
                echo -e "${RED}❌ 只能指定一个服务名${NC}"
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# 构建docker-compose logs命令选项
compose_opts=""
if [ "$follow_mode" = true ]; then
    compose_opts="$compose_opts -f"
fi
if [ -n "$tail_lines" ]; then
    compose_opts="$compose_opts --tail=$tail_lines"
fi
if [ -n "$since_time" ]; then
    compose_opts="$compose_opts --since=$since_time"
fi

# 显示单个服务日志
show_service_logs() {
    local service=$1
    local description=$2
    local service_dir="../$service"
    
    echo -e "${BLUE}📋 $description 日志:${NC}"
    
    if [ ! -d "$service_dir" ]; then
        echo -e "${RED}   ❌ 目录 $service_dir 不存在${NC}"
        return 1
    fi
    
    cd "$service_dir"
    
    if [ ! -f "docker-compose.yaml" ]; then
        echo -e "${RED}   ❌ 未找到 docker-compose.yaml${NC}"
        cd - > /dev/null
        return 1
    fi
    
    # 检查容器是否存在
    if ! docker-compose ps | grep -q .; then
        echo -e "${YELLOW}   ⚠ 容器不存在或未启动${NC}"
        cd - > /dev/null
        return 1
    fi
    
    echo ""
    
    if [ "$errors_only" = true ]; then
        # 只显示错误日志
        if [ "$follow_mode" = true ]; then
            docker-compose logs -f --tail=$tail_lines | grep -i -E "(error|fail|exception|panic|fatal)"
        else
            docker-compose logs --tail=$tail_lines | grep -i -E "(error|fail|exception|panic|fatal)"
        fi
    else
        # 显示所有日志
        docker-compose logs $compose_opts
    fi
    
    cd - > /dev/null
}

# 显示所有服务日志摘要
show_all_logs_summary() {
    echo -e "${BLUE}📊 所有服务日志摘要:${NC}"
    echo ""
    
    for i in "${!services[@]}"; do
        service="${services[$i]}"
        description="${service_descriptions[$i]}"
        service_dir="../$service"
        
        echo -e "${BLUE}▶ $description:${NC}"
        
        if [ -d "$service_dir" ]; then
            cd "$service_dir"
            
            if [ -f "docker-compose.yaml" ] && docker-compose ps | grep -q .; then
                # 显示最后5行日志
                echo "   最近日志:"
                docker-compose logs --tail=5 | sed 's/^/     /'
                
                # 统计错误
                error_count=$(docker-compose logs --tail=100 | grep -ci -E "(error|fail|exception|panic|fatal)" || echo "0")
                if [ "$error_count" -gt 0 ]; then
                    echo -e "${RED}   ⚠ 发现 $error_count 个错误${NC}"
                else
                    echo -e "${GREEN}   ✅ 无明显错误${NC}"
                fi
            else
                echo -e "${YELLOW}   ⚠ 服务未运行${NC}"
            fi
            
            cd - > /dev/null
        else
            echo -e "${RED}   ❌ 目录不存在${NC}"
        fi
        echo ""
    done
}

# 实时跟踪所有服务日志
follow_all_logs() {
    echo -e "${BLUE}🔄 实时跟踪所有服务日志 (Ctrl+C 退出):${NC}"
    echo ""
    
    # 构建所有服务的docker-compose命令
    compose_commands=()
    for service in "${services[@]}"; do
        service_dir="../$service"
        if [ -d "$service_dir" ] && [ -f "$service_dir/docker-compose.yaml" ]; then
            compose_commands+=("cd $service_dir && docker-compose logs -f --tail=10")
        fi
    done
    
    if [ ${#compose_commands[@]} -eq 0 ]; then
        echo -e "${RED}❌ 没有可用的服务${NC}"
        exit 1
    fi
    
    # 使用并行方式跟踪日志
    for cmd in "${compose_commands[@]}"; do
        eval "$cmd" &
    done
    
    # 等待用户中断
    wait
}

# 主逻辑
if [ -z "$service_name" ]; then
    # 没有指定服务，显示摘要
    show_all_logs_summary
elif [ "$service_name" = "all" ]; then
    # 显示所有服务日志
    if [ "$follow_mode" = true ]; then
        follow_all_logs
    else
        for i in "${!services[@]}"; do
            service="${services[$i]}"
            description="${service_descriptions[$i]}"
            echo ""
            show_service_logs "$service" "$description"
            echo ""
            echo "----------------------------------------"
        done
    fi
else
    # 显示指定服务日志
    found=false
    for i in "${!services[@]}"; do
        if [ "${services[$i]}" = "$service_name" ]; then
            show_service_logs "$service_name" "${service_descriptions[$i]}"
            found=true
            break
        fi
    done
    
    if [ "$found" = false ]; then
        echo -e "${RED}❌ 未知服务: $service_name${NC}"
        echo ""
        show_usage
        exit 1
    fi
fi 