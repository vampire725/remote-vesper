#!/bin/bash

# Logstash 简单部署启动脚本
# 适用于开发和测试环境
# 支持 Linux 和 macOS

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 脚本配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="logstash-simple"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yaml"
NETWORK_NAME="logging-network"

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

# 检查依赖
check_dependencies() {
    log_info "检查系统依赖..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装或不在 PATH 中"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose 未安装或不在 PATH 中"
        exit 1
    fi
    
    log_success "系统依赖检查完成"
}

# 检查端口占用
check_ports() {
    log_info "检查端口占用情况..."
    
    local ports=(5044 9600 5000 5001 8080)
    local occupied_ports=()
    
    for port in "${ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
            occupied_ports+=($port)
        fi
    done
    
    if [ ${#occupied_ports[@]} -gt 0 ]; then
        log_warning "以下端口已被占用: ${occupied_ports[*]}"
        log_warning "请确保这些端口可用或修改 docker-compose.yaml 中的端口映射"
    else
        log_success "端口检查完成，所有端口可用"
    fi
}

# 创建网络
create_network() {
    log_info "创建 Docker 网络..."
    
    if ! docker network ls | grep -q "$NETWORK_NAME"; then
        docker network create "$NETWORK_NAME" --driver bridge
        log_success "网络 $NETWORK_NAME 创建成功"
    else
        log_info "网络 $NETWORK_NAME 已存在"
    fi
}

# 启动服务
start_services() {
    log_info "启动 Logstash 服务..."
    
    cd "$SCRIPT_DIR"
    
    # 使用 docker-compose 或 docker compose
    if command -v docker-compose &> /dev/null; then
        docker-compose up -d
    else
        docker compose up -d
    fi
    
    log_success "Logstash 服务启动完成"
}

# 等待服务就绪
wait_for_services() {
    log_info "等待 Logstash 服务就绪..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f http://localhost:9600/_node/stats > /dev/null 2>&1; then
            log_success "Logstash 服务已就绪"
            return 0
        fi
        
        log_info "等待 Logstash 启动... ($attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    log_error "Logstash 服务启动超时"
    return 1
}

# 显示服务状态
show_status() {
    log_info "服务状态:"
    
    cd "$SCRIPT_DIR"
    
    if command -v docker-compose &> /dev/null; then
        docker-compose ps
    else
        docker compose ps
    fi
    
    echo
    log_info "服务访问地址:"
    echo "  - Logstash API: http://localhost:9600"
    echo "  - Beats 输入端口: 5044"
    echo "  - TCP 输入端口: 5000"
    echo "  - UDP 输入端口: 5001"
    echo "  - HTTP 输入端口: 8080"
}

# 查看日志
show_logs() {
    log_info "显示 Logstash 日志..."
    
    cd "$SCRIPT_DIR"
    
    if command -v docker-compose &> /dev/null; then
        docker-compose logs -f logstash
    else
        docker compose logs -f logstash
    fi
}

# 停止服务
stop_services() {
    log_info "停止 Logstash 服务..."
    
    cd "$SCRIPT_DIR"
    
    if command -v docker-compose &> /dev/null; then
        docker-compose down
    else
        docker compose down
    fi
    
    log_success "Logstash 服务已停止"
}

# 重启服务
restart_services() {
    log_info "重启 Logstash 服务..."
    stop_services
    sleep 5
    start_services
    wait_for_services
    show_status
}

# 清理数据
cleanup() {
    log_warning "这将删除所有 Logstash 数据和日志！"
    read -p "确认继续？(y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "清理 Logstash 数据..."
        
        cd "$SCRIPT_DIR"
        
        if command -v docker-compose &> /dev/null; then
            docker-compose down -v
        else
            docker compose down -v
        fi
        
        # 删除命名卷
        docker volume rm -f logstash_simple_logs logstash_simple_data 2>/dev/null || true
        
        log_success "数据清理完成"
    else
        log_info "取消清理操作"
    fi
}

# 测试连接
test_connection() {
    log_info "测试 Logstash 连接..."
    
    # 测试 API 端点
    if curl -s -f http://localhost:9600/_node/stats > /dev/null; then
        log_success "Logstash API 连接正常"
    else
        log_error "Logstash API 连接失败"
        return 1
    fi
    
    # 测试 HTTP 输入
    log_info "测试 HTTP 输入端点..."
    if curl -s -X POST -H "Content-Type: application/json" \
        -d '{"message":"test","timestamp":"'$(date -Iseconds)'"}' \
        http://localhost:8080 > /dev/null; then
        log_success "HTTP 输入端点测试成功"
    else
        log_warning "HTTP 输入端点测试失败（可能端口未开放）"
    fi
    
    # 显示节点信息
    log_info "Logstash 节点信息:"
    curl -s http://localhost:9600/_node/stats | jq -r '.host, .version, .pipeline.workers' 2>/dev/null || \
    curl -s http://localhost:9600/_node/stats
}

# 显示帮助信息
show_help() {
    echo "Logstash 简单部署管理脚本"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  start     启动 Logstash 服务"
    echo "  stop      停止 Logstash 服务"
    echo "  restart   重启 Logstash 服务"
    echo "  status    显示服务状态"
    echo "  logs      查看服务日志"
    echo "  test      测试服务连接"
    echo "  cleanup   清理所有数据（危险操作）"
    echo "  help      显示此帮助信息"
    echo
    echo "示例:"
    echo "  $0 start    # 启动服务"
    echo "  $0 logs     # 查看日志"
    echo "  $0 test     # 测试连接"
}

# 主函数
main() {
    case "${1:-start}" in
        start)
            check_dependencies
            check_ports
            create_network
            start_services
            wait_for_services
            show_status
            ;;
        stop)
            stop_services
            ;;
        restart)
            restart_services
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs
            ;;
        test)
            test_connection
            ;;
        cleanup)
            cleanup
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@" 