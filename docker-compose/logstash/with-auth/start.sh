#!/bin/bash

# Logstash 企业级部署启动脚本
# 包含完整的SSL证书管理和认证配置
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
PROJECT_NAME="logstash-auth"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yaml"
ENV_FILE="$SCRIPT_DIR/.env"
ENV_TEMPLATE="$SCRIPT_DIR/env-template.txt"
CERTS_DIR="$SCRIPT_DIR/certs"

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
    
    if ! command -v openssl &> /dev/null; then
        log_error "OpenSSL 未安装或不在 PATH 中"
        exit 1
    fi
    
    log_success "系统依赖检查完成"
}

# 检查环境变量文件
check_env_file() {
    log_info "检查环境变量配置..."
    
    if [ ! -f "$ENV_FILE" ]; then
        log_warning ".env 文件不存在，正在从模板创建..."
        
        if [ -f "$ENV_TEMPLATE" ]; then
            cp "$ENV_TEMPLATE" "$ENV_FILE"
            log_warning "请编辑 $ENV_FILE 文件并设置所有必需的密码"
            
            # 生成随机密码建议
            log_info "建议的随机密码："
            echo "  ELASTIC_PASSWORD=$(openssl rand -base64 32)"
            echo "  KIBANA_PASSWORD=$(openssl rand -base64 32)"
            echo "  LOGSTASH_KEYSTORE_PASS=$(openssl rand -base64 32)"
            echo "  KIBANA_ENCRYPTION_KEY=$(openssl rand -hex 32)"
            
            exit 1
        else
            log_error "环境变量模板文件不存在: $ENV_TEMPLATE"
            exit 1
        fi
    fi
    
    log_success "环境变量配置检查完成"
}

# 生成SSL证书
generate_certificates() {
    log_info "检查SSL证书..."
    
    if [ -d "$CERTS_DIR" ] && [ -f "$CERTS_DIR/ca/ca.crt" ]; then
        log_info "SSL证书已存在，跳过生成"
        return 0
    fi
    
    log_info "生成SSL证书..."
    
    # 创建证书目录
    mkdir -p "$CERTS_DIR"/{ca,elasticsearch,kibana,logstash}
    
    # 生成CA私钥和证书
    openssl genrsa -out "$CERTS_DIR/ca/ca.key" 4096
    openssl req -new -x509 -days 365 -key "$CERTS_DIR/ca/ca.key" \
        -out "$CERTS_DIR/ca/ca.crt" \
        -subj "/C=CN/ST=Beijing/L=Beijing/O=Logstash/OU=IT/CN=Logstash-CA"
    
    # 为每个服务生成证书
    for service in elasticsearch kibana logstash; do
        log_info "生成 $service 证书..."
        
        openssl genrsa -out "$CERTS_DIR/$service/$service.key" 2048
        openssl req -new -key "$CERTS_DIR/$service/$service.key" \
            -out "$CERTS_DIR/$service/$service.csr" \
            -subj "/C=CN/ST=Beijing/L=Beijing/O=Logstash/OU=IT/CN=$service"
        openssl x509 -req -days 365 \
            -in "$CERTS_DIR/$service/$service.csr" \
            -CA "$CERTS_DIR/ca/ca.crt" \
            -CAkey "$CERTS_DIR/ca/ca.key" \
            -CAcreateserial \
            -out "$CERTS_DIR/$service/$service.crt"
        
        rm "$CERTS_DIR/$service/$service.csr"
    done
    
    # 设置证书权限
    find "$CERTS_DIR" -type f -exec chmod 644 {} \;
    find "$CERTS_DIR" -name "*.key" -exec chmod 600 {} \;
    
    log_success "SSL证书生成完成"
}

# 启动服务
start_services() {
    log_info "启动 Logstash 企业级服务..."
    
    cd "$SCRIPT_DIR"
    
    if command -v docker-compose &> /dev/null; then
        docker-compose --env-file "$ENV_FILE" up -d
    else
        docker compose --env-file "$ENV_FILE" up -d
    fi
    
    log_success "Logstash 企业级服务启动完成"
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
    echo "  - Elasticsearch: https://localhost:9200"
    echo "  - Kibana: https://localhost:5601"
    echo "  - Logstash API: https://localhost:9600"
    echo "  - Logstash Beats: ssl://localhost:5044"
}

# 停止服务
stop_services() {
    log_info "停止 Logstash 企业级服务..."
    
    cd "$SCRIPT_DIR"
    
    if command -v docker-compose &> /dev/null; then
        docker-compose down
    else
        docker compose down
    fi
    
    log_success "Logstash 企业级服务已停止"
}

# 显示帮助信息
show_help() {
    echo "Logstash 企业级部署管理脚本"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  start     启动所有服务"
    echo "  stop      停止所有服务"
    echo "  status    显示服务状态"
    echo "  help      显示此帮助信息"
}

# 主函数
main() {
    case "${1:-start}" in
        start)
            check_dependencies
            check_env_file
            generate_certificates
            start_services
            show_status
            ;;
        stop)
            stop_services
            ;;
        status)
            show_status
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