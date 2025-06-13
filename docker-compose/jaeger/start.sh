#!/bin/bash

# Jaeger 链路追踪服务启动脚本
# 使用说明：./start.sh [options]

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

# 显示帮助信息
show_help() {
    cat << EOF
Jaeger 链路追踪服务启动脚本

使用方法:
    $0 [OPTIONS]

OPTIONS:
    -h, --help              显示此帮助信息
    -d, --detach            后台运行服务（默认行为）
    -f, --foreground        前台运行服务（使用 Ctrl+C 停止）
    --force                 强制重启（清理现有服务）
    --dev                   开发模式（详细日志）
    --check                 仅检查环境要求
    --logs                  启动后显示日志

示例:
    $0                      # 后台启动所有服务
    $0 -f                   # 前台启动（查看实时日志）
    $0 --force              # 强制重启
    $0 --dev --logs         # 开发模式启动并显示日志
    $0 --check              # 仅检查环境

端口配置:
    16686 - Jaeger UI
    9200  - Elasticsearch
    4315  - OTLP gRPC (推荐)
    4316  - OTLP HTTP
    4317  - Jaeger gRPC
    4318  - Jaeger HTTP

EOF
}

# 检查Docker和Docker Compose
check_prerequisites() {
    log_info "检查环境预设条件..."
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装或不在PATH中"
        exit 1
    fi
    
    # 检查Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose 未安装或不在PATH中"
        exit 1
    fi
    
    # 检查Docker服务是否运行
    if ! docker info &> /dev/null; then
        log_error "Docker 服务未运行，请先启动Docker"
        exit 1
    fi
    
    log_success "环境检查通过"
}

# 检查端口占用
check_ports() {
    log_info "检查端口占用情况..."
    
    ports=(9200 16686 16685 4315 4316 4317 4318 14268 6831 6832 5778 8888 13133)
    occupied_ports=()
    
    for port in "${ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            occupied_ports+=($port)
        elif ss -tuln 2>/dev/null | grep -q ":$port "; then
            occupied_ports+=($port)
        fi
    done
    
    if [ ${#occupied_ports[@]} -gt 0 ]; then
        log_warning "以下端口已被占用: ${occupied_ports[*]}"
        log_warning "这可能会导致服务启动失败"
        read -p "是否继续？(y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        log_success "所有必需端口都可用"
    fi
}

# 检查系统资源
check_resources() {
    log_info "检查系统资源..."
    
    # 检查内存
    total_mem=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    if [ "$total_mem" -lt 4096 ]; then
        log_warning "系统内存少于4GB ($total_mem MB)，Elasticsearch可能无法正常运行"
    fi
    
    # 检查磁盘空间
    available_space=$(df . | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 5242880 ]; then  # 5GB in KB
        log_warning "可用磁盘空间少于5GB，可能影响日志存储"
    fi
    
    # 检查vm.max_map_count (Linux)
    if [ "$(uname)" = "Linux" ]; then
        max_map_count=$(cat /proc/sys/vm/max_map_count 2>/dev/null || echo "0")
        if [ "$max_map_count" -lt 262144 ]; then
            log_warning "vm.max_map_count ($max_map_count) 小于推荐值 262144"
            log_info "建议运行: sudo sysctl -w vm.max_map_count=262144"
        fi
    fi
    
    log_success "资源检查完成"
}

# 清理现有服务
cleanup_services() {
    log_info "清理现有服务..."
    docker-compose down -v 2>/dev/null || true
    log_success "清理完成"
}

# 启动服务
start_services() {
    local detach_mode=$1
    local dev_mode=$2
    
    log_info "启动 Jaeger 链路追踪服务..."
    
    # 设置环境变量
    export COMPOSE_PROJECT_NAME="jaeger-tracing"
    
    if [ "$dev_mode" = true ]; then
        export LOG_LEVEL="debug"
        log_info "启用开发模式（详细日志）"
    fi
    
    # 启动服务
    if [ "$detach_mode" = true ]; then
        log_info "在后台启动服务..."
        docker-compose up -d
        log_success "✅ 服务已在后台启动"
    else
        log_info "在前台启动服务（使用 Ctrl+C 停止）..."
        log_warning "注意：前台模式会阻塞终端，建议使用 -d 参数后台运行"
        echo "按 Enter 键继续，或使用 Ctrl+C 取消..."
        read -r
        docker-compose up
    fi
}

# 等待服务就绪
wait_for_services() {
    log_info "等待服务启动..."
    
    # 等待Elasticsearch
    log_info "等待 Elasticsearch 启动..."
    timeout=120
    counter=0
    while [ $counter -lt $timeout ]; do
        if curl -s http://localhost:9200/_cluster/health &>/dev/null; then
            log_success "Elasticsearch 已就绪"
            break
        fi
        sleep 2
        counter=$((counter + 2))
        if [ $((counter % 10)) -eq 0 ]; then
            log_info "等待中... ($counter/$timeout 秒)"
        fi
    done
    
    if [ $counter -ge $timeout ]; then
        log_error "Elasticsearch 启动超时"
        return 1
    fi
    
    # 等待Jaeger Collector
    log_info "等待 Jaeger Collector 启动..."
    counter=0
    while [ $counter -lt 60 ]; do
        if curl -s http://localhost:14268 &>/dev/null; then
            log_success "Jaeger Collector 已就绪"
            break
        fi
        sleep 2
        counter=$((counter + 2))
    done
    
    # 等待OTel Collector
    log_info "等待 OpenTelemetry Collector 启动..."
    counter=0
    while [ $counter -lt 60 ]; do
        if curl -s http://localhost:13133 &>/dev/null; then
            log_success "OpenTelemetry Collector 已就绪"
            break
        fi
        sleep 2
        counter=$((counter + 2))
    done
    
    log_success "所有服务已启动完成"
}

# 显示服务状态
show_status() {
    log_info "服务状态："
    docker-compose ps
    
    echo
    log_info "服务访问地址："
    echo "  🌐 Jaeger UI:           http://localhost:16686"
    echo "  📊 Elasticsearch:      http://localhost:9200"
    echo "  🔍 OTel Collector:     http://localhost:13133"
    echo "  📈 OTel Debug:         http://localhost:55679/debug/tracez"
    echo
    log_info "OTLP 数据接入端点："
    echo "  📡 gRPC (推荐):        localhost:4315"
    echo "  📡 HTTP:               localhost:4316"
    echo "  📡 Jaeger gRPC:        localhost:4317"
    echo "  📡 Jaeger HTTP:        localhost:4318"
}

# 显示日志
show_logs() {
    log_info "显示服务日志（使用 Ctrl+C 退出）..."
    docker-compose logs -f
}

# 主函数
main() {
    local detach_mode=true  # 默认后台运行
    local foreground_mode=false
    local force_restart=false
    local dev_mode=false
    local check_only=false
    local show_logs_after=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--detach)
                detach_mode=true
                foreground_mode=false
                shift
                ;;
            -f|--foreground)
                detach_mode=false
                foreground_mode=true
                shift
                ;;
            --force)
                force_restart=true
                shift
                ;;
            --dev)
                dev_mode=true
                shift
                ;;
            --check)
                check_only=true
                shift
                ;;
            --logs)
                show_logs_after=true
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 环境检查
    check_prerequisites
    check_ports
    check_resources
    
    if [ "$check_only" = true ]; then
        log_success "环境检查完成，所有条件满足"
        exit 0
    fi
    
    # 强制重启
    if [ "$force_restart" = true ]; then
        cleanup_services
    fi
    
    # 启动服务
    start_services "$detach_mode" "$dev_mode"
    
    # 如果是后台模式，等待服务就绪并显示状态
    if [ "$detach_mode" = true ]; then
        wait_for_services
        show_status
        
        echo
        log_success "🎉 Jaeger 服务启动完成！"
        echo
        log_info "📋 下一步:"
        echo "  1. 访问 Jaeger UI: http://localhost:16686"
        echo "  2. 运行测试数据: cd ../test-data && ./quick-test.sh"
        echo "  3. 查看服务状态: docker-compose ps"
        echo "  4. 停止服务: ./stop.sh"
        echo
        
        if [ "$show_logs_after" = true ]; then
            show_logs
        fi
    fi
}

# 执行主函数
main "$@" 