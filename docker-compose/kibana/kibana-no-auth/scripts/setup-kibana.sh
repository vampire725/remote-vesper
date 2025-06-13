#!/bin/bash

# ===========================================
# Kibana 初始化设置脚本
# 文件名: setup-kibana.sh
# 功能: 自动化 Kibana 初始配置和数据视图创建
# 版本: 1.0
# ===========================================

set -e  # 遇到错误立即退出

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

# 配置变量
KIBANA_URL="http://localhost:5601"
ES_URL="https://localhost:9200"
KIBANA_USERNAME="elastic"
KIBANA_PASSWORD=""
TIMEOUT=300  # 5分钟超时
CURL_OPTS="-k"  # 默认禁用SSL验证（因为使用自签名证书）

# 显示帮助信息
show_help() {
    cat << EOF
Kibana 初始化设置脚本

用法: $0 [选项]

选项:
    -h, --help              显示此帮助信息
    -u, --username USER     Elasticsearch 用户名 (默认: elastic)
    -p, --password PASS     Elasticsearch 密码
    -k, --kibana-url URL    Kibana URL (默认: http://localhost:5601)
    -e, --es-url URL        Elasticsearch URL (默认: https://localhost:9200)
    -t, --timeout SECONDS   超时时间 (默认: 300秒)
    --no-ssl                禁用 SSL 验证
    --create-sample-data    创建示例数据视图

示例:
    $0 -p your_password
    $0 -u elastic -p password --create-sample-data
    $0 --no-ssl --kibana-url http://kibana:5601

EOF
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -u|--username)
                KIBANA_USERNAME="$2"
                shift 2
                ;;
            -p|--password)
                KIBANA_PASSWORD="$2"
                shift 2
                ;;
            -k|--kibana-url)
                KIBANA_URL="$2"
                shift 2
                ;;
            -e|--es-url)
                ES_URL="$2"
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --no-ssl)
                CURL_OPTS="-k"
                shift
                ;;
            --create-sample-data)
                CREATE_SAMPLE_DATA=true
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 检查必需的工具
check_dependencies() {
    log_info "检查依赖工具..."
    
    local missing_tools=()
    
    if ! command -v curl &> /dev/null; then
        missing_tools+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "缺少必需的工具: ${missing_tools[*]}"
        log_info "请安装缺少的工具："
        log_info "Ubuntu/Debian: sudo apt-get install curl jq"
        log_info "CentOS/RHEL: sudo yum install curl jq"
        log_info "macOS: brew install curl jq"
        exit 1
    fi
    
    log_success "依赖检查完成"
}

# 等待服务启动
wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=$((TIMEOUT / 5))
    local attempt=1
    
    log_info "等待 $service_name 启动..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s $CURL_OPTS "$url" > /dev/null 2>&1; then
            log_success "$service_name 已就绪"
            return 0
        fi
        
        log_info "等待 $service_name 启动... (尝试 $attempt/$max_attempts)"
        sleep 5
        ((attempt++))
    done
    
    log_error "$service_name 启动超时"
    return 1
}

# 检查 Elasticsearch 连接
check_elasticsearch() {
    log_info "检查 Elasticsearch 连接..."
    
    local auth_header=""
    if [ -n "$KIBANA_PASSWORD" ]; then
        auth_header="-u $KIBANA_USERNAME:$KIBANA_PASSWORD"
    fi
    
    local response
    response=$(curl -s $CURL_OPTS $auth_header "$ES_URL/_cluster/health" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        local status
        status=$(echo "$response" | jq -r '.status' 2>/dev/null)
        
        case $status in
            "green")
                log_success "Elasticsearch 集群状态: 绿色 (健康)"
                ;;
            "yellow")
                log_warning "Elasticsearch 集群状态: 黄色 (警告)"
                ;;
            "red")
                log_error "Elasticsearch 集群状态: 红色 (错误)"
                return 1
                ;;
            *)
                log_warning "无法获取 Elasticsearch 集群状态"
                ;;
        esac
    else
        log_error "无法连接到 Elasticsearch"
        return 1
    fi
}

# 检查 Kibana 状态
check_kibana() {
    log_info "检查 Kibana 状态..."
    
    local response
    response=$(curl -s $CURL_OPTS "$KIBANA_URL/api/status" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        local status
        status=$(echo "$response" | jq -r '.status.overall.state' 2>/dev/null)
        
        case $status in
            "green")
                log_success "Kibana 状态: 绿色 (健康)"
                ;;
            "yellow")
                log_warning "Kibana 状态: 黄色 (警告)"
                ;;
            "red")
                log_error "Kibana 状态: 红色 (错误)"
                return 1
                ;;
            *)
                log_warning "无法获取 Kibana 状态"
                ;;
        esac
    else
        log_error "无法连接到 Kibana"
        return 1
    fi
}

# 创建数据视图
create_data_view() {
    local index_pattern=$1
    local data_view_name=$2
    local time_field=${3:-"@timestamp"}
    
    log_info "创建数据视图: $data_view_name ($index_pattern)"
    
    local auth_header=""
    if [ -n "$KIBANA_PASSWORD" ]; then
        auth_header="-u $KIBANA_USERNAME:$KIBANA_PASSWORD"
    fi
    
    local payload
    payload=$(cat << EOF
{
  "data_view": {
    "title": "$index_pattern",
    "name": "$data_view_name",
    "timeFieldName": "$time_field"
  }
}
EOF
)
    
    local response
    response=$(curl -s $CURL_OPTS $auth_header \
        -X POST \
        -H "Content-Type: application/json" \
        -H "kbn-xsrf: true" \
        -d "$payload" \
        "$KIBANA_URL/api/data_views/data_view" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        local id
        id=$(echo "$response" | jq -r '.data_view.id' 2>/dev/null)
        
        if [ "$id" != "null" ] && [ -n "$id" ]; then
            log_success "数据视图创建成功: $data_view_name (ID: $id)"
        else
            local error_message
            error_message=$(echo "$response" | jq -r '.message // .error // "未知错误"' 2>/dev/null)
            log_warning "数据视图创建失败: $error_message"
        fi
    else
        log_error "创建数据视图时发生网络错误"
    fi
}

# 创建示例数据视图
create_sample_data_views() {
    log_info "创建示例数据视图..."
    
    # 常见的日志索引模式
    create_data_view "logstash-*" "Logstash 日志" "@timestamp"
    create_data_view "filebeat-*" "Filebeat 日志" "@timestamp"
    create_data_view "metricbeat-*" "Metricbeat 指标" "@timestamp"
    create_data_view "auditbeat-*" "Auditbeat 审计" "@timestamp"
    create_data_view "packetbeat-*" "Packetbeat 网络" "@timestamp"
    create_data_view "winlogbeat-*" "Winlogbeat Windows日志" "@timestamp"
    
    # 应用日志模式
    create_data_view "app-logs-*" "应用日志" "@timestamp"
    create_data_view "nginx-*" "Nginx 日志" "@timestamp"
    create_data_view "apache-*" "Apache 日志" "@timestamp"
    
    log_success "示例数据视图创建完成"
}

# 设置默认数据视图
set_default_data_view() {
    local pattern=$1
    
    log_info "设置默认数据视图: $pattern"
    
    local auth_header=""
    if [ -n "$KIBANA_PASSWORD" ]; then
        auth_header="-u $KIBANA_USERNAME:$KIBANA_PASSWORD"
    fi
    
    # 获取数据视图列表
    local response
    response=$(curl -s $CURL_OPTS $auth_header \
        "$KIBANA_URL/api/data_views" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        local data_view_id
        data_view_id=$(echo "$response" | jq -r ".data_view[] | select(.title==\"$pattern\") | .id" 2>/dev/null)
        
        if [ -n "$data_view_id" ] && [ "$data_view_id" != "null" ]; then
            # 设置为默认数据视图
            local payload
            payload=$(cat << EOF
{
  "value": "$data_view_id"
}
EOF
)
            
            curl -s $CURL_OPTS $auth_header \
                -X POST \
                -H "Content-Type: application/json" \
                -H "kbn-xsrf: true" \
                -d "$payload" \
                "$KIBANA_URL/api/kibana/settings/defaultIndex" > /dev/null 2>&1
            
            if [ $? -eq 0 ]; then
                log_success "默认数据视图设置成功: $pattern"
            else
                log_warning "设置默认数据视图失败"
            fi
        else
            log_warning "未找到数据视图: $pattern"
        fi
    else
        log_error "获取数据视图列表失败"
    fi
}

# 显示系统信息
show_system_info() {
    log_info "系统信息:"
    echo "  Kibana URL: $KIBANA_URL"
    echo "  Elasticsearch URL: $ES_URL"
    echo "  用户名: $KIBANA_USERNAME"
    echo "  超时时间: ${TIMEOUT}秒"
    echo ""
}

# 主函数
main() {
    echo "========================================"
    echo "       Kibana 初始化设置脚本"
    echo "========================================"
    echo ""
    
    # 解析参数
    parse_args "$@"
    
    # 显示系统信息
    show_system_info
    
    # 检查依赖
    check_dependencies
    
    # 等待服务启动
    wait_for_service "$ES_URL" "Elasticsearch" || exit 1
    wait_for_service "$KIBANA_URL/api/status" "Kibana" || exit 1
    
    # 检查服务状态
    check_elasticsearch || exit 1
    check_kibana || exit 1
    
    # 创建示例数据视图（如果指定）
    if [ "$CREATE_SAMPLE_DATA" = true ]; then
        create_sample_data_views
        set_default_data_view "logstash-*"
    fi
    
    echo ""
    log_success "Kibana 初始化完成！"
    log_info "访问地址: $KIBANA_URL"
    
    if [ -n "$KIBANA_PASSWORD" ]; then
        log_info "用户名: $KIBANA_USERNAME"
        log_info "密码: [已设置]"
    else
        log_info "无需认证（安全功能已禁用）"
    fi
    
    echo ""
    echo "========================================"
}

# 执行主函数
main "$@" 