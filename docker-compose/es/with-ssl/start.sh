#!/bin/bash

# ===========================================
# Elasticsearch SSL 安全环境启动脚本
# 文件名: start.sh
# 功能: 启动带SSL加密和认证的 Elasticsearch 服务
# 特点: 完整SSL加密，用户认证，生产级安全
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
Elasticsearch SSL 安全环境启动脚本

用法: $0 [选项]

选项:
    -h, --help          显示帮助信息
    -s, --status        显示服务状态
    -l, --logs          显示服务日志
    -t, --test          测试连接
    --setup             仅运行证书生成
    --stop              停止服务
    --restart           重启服务
    --clean             清理数据并重启
    --reset-certs       重新生成证书

特点:
    - 完整SSL加密
    - 用户认证保护
    - 自动证书生成
    - 生产级安全配置

示例:
    $0                  # 启动服务
    $0 --status         # 查看状态
    $0 --test           # 测试连接
    $0 --clean          # 清理重启

安全提示:
    - 首次运行前请设置 .env 文件中的密码
    - 使用 HTTPS 访问: https://localhost:9200
    - 默认用户名: elastic

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
    
    # 检查环境变量文件
    if [ ! -f ".env" ]; then
        log_warning ".env 文件不存在"
        log_info "请根据 env-template.txt 创建 .env 文件并设置密码"
        
        if [ -f "env-template.txt" ]; then
            log_info "创建默认 .env 文件..."
            grep "^ELASTIC_PASSWORD\|^KIBANA_PASSWORD" env-template.txt > .env
            log_warning "已创建默认 .env 文件，请修改其中的密码！"
        else
            log_error "缺少环境变量配置，请手动创建 .env 文件"
            exit 1
        fi
    fi
    
    # 检查密码设置
    source .env
    if [ -z "$ELASTIC_PASSWORD" ] || [ "$ELASTIC_PASSWORD" = "ElasticSearch2024!" ]; then
        log_warning "检测到默认密码，建议修改 .env 文件中的密码"
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
# 证书生成函数
# ==========================================
setup_certificates() {
    log_header "生成 SSL 证书"
    
    log_info "启动证书生成服务..."
    docker-compose up setup
    
    if [ $? -eq 0 ]; then
        log_success "SSL 证书生成完成"
    else
        log_error "SSL 证书生成失败"
        exit 1
    fi
}

# ==========================================
# 启动服务函数
# ==========================================
start_service() {
    log_header "启动 Elasticsearch SSL 安全环境"
    
    check_prerequisites
    prepare_networks
    
    log_info "启动所有服务..."
    docker-compose up -d
    
    log_info "等待服务启动..."
    sleep 15
    
    # 健康检查
    local attempt=1
    local max_attempts=15
    
    while [ $attempt -le $max_attempts ]; do
        log_info "健康检查尝试 $attempt/$max_attempts..."
        
        # 检查 Elasticsearch
        if curl -s --cacert <(docker-compose exec -T es01 cat /usr/share/elasticsearch/config/certs/ca/ca.crt) \
               -u "elastic:${ELASTIC_PASSWORD}" \
               https://localhost:9200/_cluster/health > /dev/null 2>&1; then
            log_success "Elasticsearch 服务启动成功！"
            show_service_info
            return 0
        else
            if [ $attempt -eq $max_attempts ]; then
                log_error "服务启动失败，请检查日志"
                docker-compose logs --tail=20
                return 1
            fi
            
            log_info "等待 15 秒后重试..."
            sleep 15
        fi
        
        ((attempt++))
    done
}

# ==========================================
# 显示服务信息
# ==========================================
show_service_info() {
    log_header "服务信息"
    
    # 获取密码
    source .env 2>/dev/null || true
    
    cat << EOF
${GREEN}Elasticsearch SSL 安全环境启动成功！${NC}

${BLUE}服务访问信息:${NC}
- Elasticsearch HTTPS API: ${YELLOW}https://localhost:9200${NC}
- Kibana HTTPS 界面: ${YELLOW}https://localhost:5601${NC}
- 用户名: ${YELLOW}elastic${NC}
- 密码: ${YELLOW}${ELASTIC_PASSWORD:-请检查.env文件}${NC}

${BLUE}SSL 证书信息:${NC}
- CA 证书: 自动生成并存储在 Docker 卷中
- 节点证书: 自动为 es01 和 kibana 生成
- 证书验证: 启用完整证书验证

${BLUE}安全连接示例:${NC}
# 获取 CA 证书（用于客户端连接）
docker-compose exec es01 cat /usr/share/elasticsearch/config/certs/ca/ca.crt > ca.crt

# 使用 CA 证书访问 API
curl --cacert ca.crt -u elastic:${ELASTIC_PASSWORD:-YOUR_PASSWORD} https://localhost:9200/_cluster/health?pretty

# 查看集群状态
curl --cacert ca.crt -u elastic:${ELASTIC_PASSWORD:-YOUR_PASSWORD} https://localhost:9200/_cluster/health?pretty

# 查看节点信息
curl --cacert ca.crt -u elastic:${ELASTIC_PASSWORD:-YOUR_PASSWORD} https://localhost:9200/_nodes?pretty

${BLUE}管理命令:${NC}
./start.sh --status      # 查看服务状态
./start.sh --logs        # 查看服务日志
./start.sh --test        # 测试连接
./start.sh --stop        # 停止服务

${GREEN}安全提示:${NC}
- 所有通信均已加密
- 启用了用户认证
- 证书自动管理
- 适合生产环境使用

EOF
}

# ==========================================
# 显示服务状态
# ==========================================
show_status() {
    log_header "Elasticsearch SSL 服务状态"
    
    # Docker Compose 服务状态
    log_info "Docker Compose 服务状态:"
    docker-compose ps
    
    echo ""
    
    # 容器资源使用情况
    if docker ps | grep -q "es01\|kibana"; then
        log_info "容器资源使用情况:"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" | grep -E "es01|kibana"
        
        echo ""
        
        # 集群健康状态
        log_info "集群健康状态:"
        source .env 2>/dev/null || true
        if curl -s --cacert <(docker-compose exec -T es01 cat /usr/share/elasticsearch/config/certs/ca/ca.crt) \
               -u "elastic:${ELASTIC_PASSWORD}" \
               https://localhost:9200/_cluster/health?pretty 2>/dev/null; then
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
    log_header "测试 Elasticsearch SSL 连接"
    
    source .env 2>/dev/null || true
    
    if [ -z "$ELASTIC_PASSWORD" ]; then
        log_error "未找到 ELASTIC_PASSWORD 环境变量"
        return 1
    fi
    
    # 获取 CA 证书
    log_info "获取 CA 证书..."
    if ! docker-compose exec -T es01 cat /usr/share/elasticsearch/config/certs/ca/ca.crt > /tmp/ca.crt 2>/dev/null; then
        log_error "无法获取 CA 证书，请确保服务正在运行"
        return 1
    fi
    
    # 基础连接测试
    log_info "测试 HTTPS 基础连接..."
    if curl -s --cacert /tmp/ca.crt -u "elastic:${ELASTIC_PASSWORD}" https://localhost:9200 > /dev/null; then
        log_success "HTTPS 基础连接测试通过"
    else
        log_error "HTTPS 基础连接测试失败"
        rm -f /tmp/ca.crt
        return 1
    fi
    
    # 集群健康测试
    log_info "测试集群健康..."
    local health=$(curl -s --cacert /tmp/ca.crt -u "elastic:${ELASTIC_PASSWORD}" https://localhost:9200/_cluster/health | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    if [ "$health" = "green" ] || [ "$health" = "yellow" ]; then
        log_success "集群健康状态: $health"
    else
        log_error "集群健康状态异常: $health"
        rm -f /tmp/ca.crt
        return 1
    fi
    
    # 认证测试
    log_info "测试用户认证..."
    if curl -s --cacert /tmp/ca.crt -u "elastic:${ELASTIC_PASSWORD}" https://localhost:9200/_security/_authenticate | grep -q "elastic"; then
        log_success "用户认证测试通过"
    else
        log_error "用户认证测试失败"
        rm -f /tmp/ca.crt
        return 1
    fi
    
    # 创建测试索引
    log_info "创建测试索引..."
    if curl -s --cacert /tmp/ca.crt -u "elastic:${ELASTIC_PASSWORD}" -X PUT https://localhost:9200/ssl-connection-test > /dev/null; then
        log_success "测试索引创建成功"
    else
        log_error "测试索引创建失败"
        rm -f /tmp/ca.crt
        return 1
    fi
    
    # 删除测试索引
    log_info "清理测试索引..."
    curl -s --cacert /tmp/ca.crt -u "elastic:${ELASTIC_PASSWORD}" -X DELETE https://localhost:9200/ssl-connection-test > /dev/null
    
    # 清理临时文件
    rm -f /tmp/ca.crt
    
    log_success "SSL 连接测试完成！"
    
    # 显示连接信息
    echo ""
    log_info "连接信息:"
    echo "URL: https://localhost:9200"
    echo "用户名: elastic"
    echo "密码: ${ELASTIC_PASSWORD}"
    echo "Kibana: https://localhost:5601"
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
        --setup)
            check_prerequisites
            prepare_networks
            setup_certificates
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
        --reset-certs)
            log_info "重新生成证书..."
            docker-compose down
            docker volume rm $(docker volume ls -q | grep certs) 2>/dev/null || true
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