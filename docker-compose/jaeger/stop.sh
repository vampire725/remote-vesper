#!/bin/bash

# Jaeger 链路追踪服务停止脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示使用帮助
show_help() {
    cat << EOF
Jaeger 链路追踪服务停止脚本

使用方法:
    $0 [OPTIONS]

OPTIONS:
    -h, --help          显示此帮助信息
    -v, --volumes       同时删除数据卷（会丢失所有trace数据）
    --clean             清理所有相关容器和网络
    --force             强制停止容器

示例:
    $0                  # 停止服务
    $0 -v               # 停止服务并删除数据
    $0 --clean          # 完全清理
    $0 --force          # 强制停止

EOF
}

# 停止服务
stop_services() {
    local remove_volumes=$1
    local clean_all=$2
    local force_stop=$3
    
    log_info "停止 Jaeger 链路追踪服务..."
    
    if [ "$force_stop" = true ]; then
        log_warning "强制停止容器..."
        docker ps -q --filter "name=jaeger" | xargs -r docker kill
        docker ps -q --filter "name=otel" | xargs -r docker kill
        docker ps -q --filter "name=elasticsearch" | xargs -r docker kill
    fi
    
    # 停止服务
    if [ "$remove_volumes" = true ]; then
        log_warning "停止服务并删除数据卷（会丢失所有trace数据）"
        docker-compose down -v
    elif [ "$clean_all" = true ]; then
        log_warning "停止服务并清理所有资源"
        docker-compose down -v --remove-orphans
        # 清理相关镜像（可选）
        read -p "是否删除相关Docker镜像？(y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker images | grep -E "(jaeger|elasticsearch|otel)" | awk '{print $3}' | xargs -r docker rmi
        fi
    else
        docker-compose down
    fi
    
    log_success "服务已停止"
}

# 显示状态
show_status() {
    log_info "检查剩余容器..."
    
    running_containers=$(docker ps --filter "name=jaeger" --filter "name=otel" --filter "name=elasticsearch" --format "table {{.Names}}\t{{.Status}}")
    
    if [ -n "$running_containers" ]; then
        echo "$running_containers"
        log_warning "仍有相关容器在运行"
    else
        log_success "所有相关容器已停止"
    fi
    
    # 检查数据卷
    volumes=$(docker volume ls --filter "name=elasticsearch" --format "{{.Name}}")
    if [ -n "$volumes" ]; then
        log_info "数据卷: $volumes"
    fi
}

# 主函数
main() {
    local remove_volumes=false
    local clean_all=false
    local force_stop=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--volumes)
                remove_volumes=true
                shift
                ;;
            --clean)
                clean_all=true
                shift
                ;;
            --force)
                force_stop=true
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 确认危险操作
    if [ "$remove_volumes" = true ] || [ "$clean_all" = true ]; then
        log_warning "此操作将删除所有trace数据，无法恢复！"
        read -p "确定要继续吗？(y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "操作已取消"
            exit 0
        fi
    fi
    
    # 停止服务
    stop_services "$remove_volumes" "$clean_all" "$force_stop"
    
    # 显示状态
    show_status
}

# 执行主函数
main "$@" 