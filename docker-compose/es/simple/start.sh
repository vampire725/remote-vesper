#!/bin/bash

# ===========================================
# Elasticsearch 简化环境启动脚本
# 文件名: start.sh
# 功能: 启动简化的 Elasticsearch 服务
# 特点: 无SSL，无认证，适合开发测试
# ===========================================

set -e  # 遇到错误立即退出

# ==========================================
# 颜色定义
# ==========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ==========================================
# 日志函数
# ==========================================
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

log_header() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

# ==========================================
# 帮助信息
# ==========================================
show_help() {
    cat << EOF
Elasticsearch 简化环境启动脚本

用法: $0 [选项]

选项:
    -h, --help          显示帮助信息
    -s, --status        显示服务状态
    -l, --logs          显示服务日志
    -t, --test          测试连接
    --stop              停止服务
    --restart           重启服务
    --clean             清理数据并重启

特点:
    - 无SSL加密
    - 无用户认证
    - 单节点模式
    - 适合开发测试

示例:
    $0                  # 启动服务
    $0 --status         # 查看状态
    $0 --test           # 测试连接
    $0 --clean          # 清理重启

EOF
}

# ==========================================
# 环境检查函数
# ==========================================
check_prerequisites() {
    log_info "检查前置条件..."
    
    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    # 检查 Docker 是否运行
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker 未运行，请先启动 Docker"
        exit 1
    fi
    
    # 检查 Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose 未安装"
        exit 1
    fi
    
    # 检查配置文件
    if [ ! -f "docker-compose.yaml" ]; then
        log_error "配置文件 docker-compose.yaml 不存在"
        exit 1
    fi
    
    log_success "前置条件检查通过"
}

# ==========================================
# 网络准备函数
# ==========================================
prepare_networks() {
    log_info "准备 Docker 网络..."
    
    # 创建 logging-network 网络
    if ! docker network ls | grep -q "logging-network"; then
        docker network create logging-network
        log_success "创建 logging-network 网络"
    else
        log_info "logging-network 网络已存在"
    fi
    
    # 创建 kafka 网络
    if ! docker network ls | grep -q "kafka"; then
        docker network create kafka
        log_success "创建 kafka 网络"
    else
        log_info "kafka 网络已存在"
    fi
}

# ==========================================
# 启动服务函数
# ==========================================
start_service() {
    log_header "启动 Elasticsearch 简化环境"
    
    check_prerequisites
    prepare_networks
    
    log_info "启动 Elasticsearch 服务..."
    docker-compose up -d
    
    log_info "等待服务启动..."
    sleep 10
    
    # 健康检查
    local attempt=1
    local max_attempts=10
    
    while [ $attempt -le $max_attempts ]; do
        log_info "健康检查尝试 $attempt/$max_attempts..."
        
        if curl -s http://localhost:9200/_cluster/health > /dev/null 2>&1; then
            log_success "Elasticsearch 服务启动成功！"
            show_service_info
            return 0
        else
            if [ $attempt -eq $max_attempts ]; then
                log_error "服务启动失败，请检查日志"
                docker-compose logs --tail=20
                return 1
            fi
            
            log_info "等待 10 秒后重试..."
            sleep 10
        fi
        
        ((attempt++))
    done
}

# ==========================================
# 显示服务信息
# ==========================================
show_service_info() {
    log_header "服务信息"
    
    cat << EOF
${GREEN}Elasticsearch 简化环境启动成功！${NC}

${BLUE}服务访问信息:${NC}
- HTTP API: ${YELLOW}http://localhost:9200${NC}
- 集群健康: ${YELLOW}http://localhost:9200/_cluster/health${NC}
- 节点信息: ${YELLOW}http://localhost:9200/_nodes${NC}

${BLUE}常用命令:${NC}
# 查看集群状态
curl http://localhost:9200/_cluster/health?pretty

# 查看节点信息
curl http://localhost:9200/_nodes?pretty

# 创建索引
curl -X PUT http://localhost:9200/test-index

# 查看所有索引
curl http://localhost:9200/_cat/indices?v

${BLUE}管理命令:${NC}
./start.sh --status      # 查看服务状态
./start.sh --logs        # 查看服务日志
./start.sh --test        # 测试连接
./start.sh --stop        # 停止服务

${YELLOW}注意: 此配置禁用了SSL和认证，仅适用于开发环境${NC}

EOF
}

# ==========================================
# 显示服务状态
# ==========================================
show_status() {
    log_header "Elasticsearch 服务状态"
    
    # Docker Compose 服务状态
    log_info "Docker Compose 服务状态:"
    docker-compose ps
    
    echo ""
    
    # 容器资源使用情况
    if docker ps | grep -q "elasticsearch"; then
        log_info "容器资源使用情况:"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" | grep elasticsearch
        
        echo ""
        
        # 集群健康状态
        log_info "集群健康状态:"
        if curl -s http://localhost:9200/_cluster/health?pretty 2>/dev/null; then
            log_success "集群连接正常"
        else
            log_error "集群连接失败"
        fi
    else
        log_warning "没有运行中的 Elasticsearch 容器"
    fi
}

# ==========================================
# 测试连接函数
# ==========================================
test_connection() {
    log_header "测试 Elasticsearch 连接"
    
    # 基础连接测试
    log_info "测试基础连接..."
    if curl -s http://localhost:9200 > /dev/null; then
        log_success "基础连接测试通过"
    else
        log_error "基础连接测试失败"
        return 1
    fi
    
    # 集群健康测试
    log_info "测试集群健康..."
    local health=$(curl -s http://localhost:9200/_cluster/health | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    if [ "$health" = "green" ] || [ "$health" = "yellow" ]; then
        log_success "集群健康状态: $health"
    else
        log_error "集群健康状态异常: $health"
        return 1
    fi
    
    # 创建测试索引
    log_info "创建测试索引..."
    if curl -s -X PUT http://localhost:9200/connection-test > /dev/null; then
        log_success "测试索引创建成功"
    else
        log_error "测试索引创建失败"
        return 1
    fi
    
    # 删除测试索引
    log_info "清理测试索引..."
    curl -s -X DELETE http://localhost:9200/connection-test > /dev/null
    
    log_success "连接测试完成！"
}

# ==========================================
# 主函数
# ==========================================
main() {
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        -s|--status)
            show_status
            exit 0
            ;;
        -l|--logs)
            log_info "显示服务日志 (Ctrl+C 退出):"
            docker-compose logs -f
            exit 0
            ;;
        -t|--test)
            test_connection
            exit 0
            ;;
        --stop)
            log_info "停止服务..."
            docker-compose down
            log_success "服务已停止"
            exit 0
            ;;
        --restart)
            log_info "重启服务..."
            docker-compose restart
            log_success "服务已重启"
            exit 0
            ;;
        --clean)
            log_info "清理数据并重启..."
            docker-compose down -v
            start_service
            exit 0
            ;;
        "")
            start_service
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