#!/bin/bash

# ===========================================
# Grafana Tempo 部署脚本
# 文件名: deploy.sh
# 功能: 自动化部署 Tempo 分布式追踪系统
# 用途: 用于 OpenTelemetry + Tempo + Grafana 可观测性栈
# 版本: v1.0
# ===========================================

set -e  # 遇到错误立即退出
set -u  # 使用未定义变量时报错

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

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# ==========================================
# 配置变量
# ==========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="tempo"
COMPOSE_FILE="docker-compose.yaml"
TEMPO_CONFIG="tempo-single-node.yaml"
HEALTH_CHECK_URL="http://localhost:3200/ready"
MAX_HEALTH_ATTEMPTS=12
HEALTH_CHECK_INTERVAL=10

# ==========================================
# 帮助信息
# ==========================================
show_help() {
    cat << EOF
Grafana Tempo 部署脚本

用法: $0 [选项]

选项:
    -h, --help          显示帮助信息
    -v, --verbose       详细输出模式
    -c, --clean         清理现有容器和卷
    -s, --status        显示服务状态
    -l, --logs          显示服务日志
    --stop              停止服务
    --restart           重启服务

示例:
    $0                  # 部署 Tempo 服务
    $0 --clean          # 清理并重新部署
    $0 --status         # 查看服务状态
    $0 --logs           # 查看服务日志

EOF
}

# ==========================================
# 环境检查函数
# ==========================================
check_prerequisites() {
    log_step "检查前置条件..."
    
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
    if [ ! -f "$COMPOSE_FILE" ]; then
        log_error "Docker Compose 配置文件 $COMPOSE_FILE 不存在"
        exit 1
    fi
    
    if [ ! -f "$TEMPO_CONFIG" ]; then
        log_error "Tempo 配置文件 $TEMPO_CONFIG 不存在"
        exit 1
    fi
    
    log_success "前置条件检查通过"
}

# ==========================================
# 网络准备函数
# ==========================================
prepare_networks() {
    log_step "准备 Docker 网络..."
    
    # 创建追踪网络
    if ! docker network ls | grep -q "tracing-network"; then
        docker network create tracing-network
        log_success "创建 tracing-network 网络"
    else
        log_info "tracing-network 网络已存在"
    fi
    
    # 创建监控网络
    if ! docker network ls | grep -q "monitoring-network"; then
        docker network create monitoring-network
        log_success "创建 monitoring-network 网络"
    else
        log_info "monitoring-network 网络已存在"
    fi
}

# ==========================================
# 配置验证函数
# ==========================================
validate_config() {
    log_step "验证配置文件..."
    
    # 验证 Docker Compose 配置
    if ! docker-compose config > /dev/null 2>&1; then
        log_error "Docker Compose 配置文件有错误:"
        docker-compose config
        exit 1
    fi
    
    log_success "配置文件验证通过"
}

# ==========================================
# 服务部署函数
# ==========================================
deploy_services() {
    log_step "部署 Tempo 服务..."
    
    # 拉取镜像
    log_info "拉取 Docker 镜像..."
    docker-compose pull
    
    # 启动服务
    log_info "启动服务..."
    docker-compose up -d
    
    log_success "服务启动完成"
}

# ==========================================
# 健康检查函数
# ==========================================
health_check() {
    log_step "执行健康检查..."
    
    local attempt=1
    while [ $attempt -le $MAX_HEALTH_ATTEMPTS ]; do
        log_info "健康检查尝试 $attempt/$MAX_HEALTH_ATTEMPTS..."
        
        if curl -f -s "$HEALTH_CHECK_URL" > /dev/null 2>&1; then
            log_success "Tempo 服务健康检查通过！"
            return 0
        else
            if [ $attempt -eq $MAX_HEALTH_ATTEMPTS ]; then
                log_error "健康检查失败，服务可能未正常启动"
                log_info "查看服务日志:"
                docker-compose logs --tail=20 tempo
                return 1
            fi
            
            log_warning "等待服务就绪... ($HEALTH_CHECK_INTERVAL 秒后重试)"
            sleep $HEALTH_CHECK_INTERVAL
            ((attempt++))
        fi
    done
}

# ==========================================
# 服务信息展示函数
# ==========================================
show_service_info() {
    log_step "服务部署完成！"
    
    echo ""
    echo -e "${CYAN}📋 服务信息:${NC}"
    echo "  - Tempo HTTP API: http://localhost:3200"
    echo "  - Tempo 健康检查: http://localhost:3200/ready"
    echo "  - Tempo 指标: http://localhost:3200/metrics"
    echo "  - Tempo 配置: http://localhost:3200/config"
    echo ""
    echo -e "${CYAN}📡 数据接收端点:${NC}"
    echo "  - OTLP gRPC: localhost:4317"
    echo "  - OTLP HTTP: localhost:4318"
    echo ""
    echo -e "${CYAN}🔧 管理命令:${NC}"
    echo "  - 查看日志: docker-compose logs -f tempo"
    echo "  - 停止服务: docker-compose down"
    echo "  - 重启服务: docker-compose restart tempo"
    echo "  - 查看状态: docker-compose ps"
    echo ""
    echo -e "${CYAN}🧪 测试命令:${NC}"
    echo "  - 健康检查: curl http://localhost:3200/ready"
    echo "  - 查看指标: curl http://localhost:3200/metrics"
    echo "  - 查看配置: curl http://localhost:3200/config"
    echo ""
    echo -e "${CYAN}📚 下一步:${NC}"
    echo "  1. 部署 Prometheus: cd ../prometheus && ./deploy.sh"
    echo "  2. 部署 Grafana: cd ../grafana && ./deploy.sh"
    echo "  3. 部署 OpenTelemetry Collector: cd ../otel-collector && ./deploy.sh"
    echo ""
}

# ==========================================
# 清理函数
# ==========================================
clean_deployment() {
    log_step "清理现有部署..."
    
    # 停止并删除容器
    docker-compose down -v --remove-orphans
    
    # 删除镜像（可选）
    # docker-compose down --rmi all
    
    log_success "清理完成"
}

# ==========================================
# 状态检查函数
# ==========================================
show_status() {
    log_step "服务状态:"
    docker-compose ps
    
    echo ""
    log_step "网络状态:"
    docker network ls | grep -E "(tracing-network|monitoring-network)"
    
    echo ""
    log_step "数据卷状态:"
    docker volume ls | grep tempo
}

# ==========================================
# 日志查看函数
# ==========================================
show_logs() {
    log_step "显示服务日志:"
    docker-compose logs -f tempo
}

# ==========================================
# 主函数
# ==========================================
main() {
    local clean_mode=false
    local verbose_mode=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                verbose_mode=true
                set -x  # 启用详细输出
                shift
                ;;
            -c|--clean)
                clean_mode=true
                shift
                ;;
            -s|--status)
                show_status
                exit 0
                ;;
            -l|--logs)
                show_logs
                exit 0
                ;;
            --stop)
                docker-compose down
                exit 0
                ;;
            --restart)
                docker-compose restart
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 显示开始信息
    echo -e "${GREEN}🚀 开始部署 Grafana Tempo...${NC}"
    echo ""
    
    # 切换到脚本目录
    cd "$SCRIPT_DIR"
    
    # 执行部署流程
    check_prerequisites
    
    if [ "$clean_mode" = true ]; then
        clean_deployment
    fi
    
    prepare_networks
    validate_config
    deploy_services
    
    # 等待服务启动
    sleep 5
    
    if health_check; then
        show_service_info
        log_success "🎉 Tempo 部署成功完成！"
    else
        log_error "❌ 部署过程中出现问题，请检查日志"
        exit 1
    fi
}

# ==========================================
# 脚本入口
# ==========================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 