#!/bin/bash

# Kafka SASL 安全部署启动脚本
# 适用于 Linux/Mac 系统
# 版本: Apache Kafka 3.9.1 (SASL/SCRAM认证版本)

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 脚本配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yaml"
ENV_FILE="$SCRIPT_DIR/.env"
ENV_TEMPLATE="$SCRIPT_DIR/env-template.txt"
PROJECT_NAME="kafka-sasl"

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

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

log_security() {
    echo -e "${CYAN}[SECURITY]${NC} $1"
}

# 显示帮助信息
show_help() {
    echo -e "${CYAN}Kafka SASL 安全部署管理脚本${NC}"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  start           启动 Kafka 安全集群"
    echo "  stop            停止 Kafka 集群"
    echo "  restart         重启 Kafka 集群"
    echo "  status          查看服务状态"
    echo "  logs [service]  查看日志 (可选指定服务名)"
    echo "  clean           清理所有数据和容器"
    echo "  reset           重置集群 (停止、清理、启动)"
    echo "  test            测试 SASL 认证连接"
    echo "  topics          管理主题"
    echo "  users           管理 SASL 用户"
    echo "  acl             管理访问控制列表"
    echo "  ui              打开 Kafka UI"
    echo "  health          健康检查"
    echo "  security        安全配置检查"
    echo "  setup-env       设置环境变量"
    echo "  --help, -h      显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 setup-env                # 设置环境变量"
    echo "  $0 start                    # 启动安全集群"
    echo "  $0 users --list             # 列出所有用户"
    echo "  $0 test                     # 测试SASL认证"
    echo "  $0 acl --list               # 列出ACL规则"
    echo ""
}

# 检查依赖
check_dependencies() {
    log_step "检查系统依赖..."
    
    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装或不在 PATH 中"
        exit 1
    fi
    
    # 检查 Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose 未安装或不在 PATH 中"
        exit 1
    fi
    
    # 检查 Docker 服务状态
    if ! docker info &> /dev/null; then
        log_error "Docker 服务未运行，请启动 Docker"
        exit 1
    fi
    
    log_success "依赖检查通过"
}

# 设置环境变量
setup_env() {
    log_step "设置环境变量..."
    
    if [ ! -f "$ENV_FILE" ]; then
        if [ -f "$ENV_TEMPLATE" ]; then
            log_info "创建环境变量文件..."
            cp "$ENV_TEMPLATE" "$ENV_FILE"
            log_warning "请编辑 .env 文件并修改默认密码"
            log_warning "文件位置: $ENV_FILE"
            
            # 生成随机密码建议
            log_info "建议使用以下随机生成的强密码:"
            echo ""
            echo "KAFKA_ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -d '=+/' | cut -c1-12)@K$(date +%Y)"
            echo "KAFKA_USER_PASSWORD=$(openssl rand -base64 16 | tr -d '=+/' | cut -c1-12)@U$(date +%Y)"
            echo "KAFKA_PRODUCER_PASSWORD=$(openssl rand -base64 16 | tr -d '=+/' | cut -c1-12)@P$(date +%Y)"
            echo "KAFKA_CONSUMER_PASSWORD=$(openssl rand -base64 16 | tr -d '=+/' | cut -c1-12)@C$(date +%Y)"
            echo ""
            
            read -p "是否现在编辑环境变量文件? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                ${EDITOR:-nano} "$ENV_FILE"
            fi
        else
            log_error "环境变量模板文件不存在: $ENV_TEMPLATE"
            exit 1
        fi
    else
        log_info "环境变量文件已存在: $ENV_FILE"
    fi
}

# 检查环境变量
check_env() {
    if [ ! -f "$ENV_FILE" ]; then
        log_warning "环境变量文件不存在，将使用默认配置"
        log_warning "建议运行: $0 setup-env"
        return 1
    fi
    
    # 检查是否使用默认密码
    if grep -q "admin-secret\|user-secret\|producer-secret\|consumer-secret" "$ENV_FILE"; then
        log_warning "检测到默认密码，建议修改为强密码"
        log_security "在生产环境中使用默认密码存在安全风险"
    fi
    
    return 0
}

# 检查端口占用
check_ports() {
    log_step "检查端口占用..."
    
    local ports=(2181 9092 9093 8080 8081 8083)
    local occupied_ports=()
    
    for port in "${ports[@]}"; do
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            occupied_ports+=($port)
        fi
    done
    
    if [ ${#occupied_ports[@]} -gt 0 ]; then
        log_warning "以下端口已被占用: ${occupied_ports[*]}"
        log_warning "这可能会导致服务启动失败"
        read -p "是否继续? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "操作已取消"
            exit 0
        fi
    else
        log_success "端口检查通过"
    fi
}

# 创建网络
create_network() {
    log_step "创建 Docker 网络..."
    
    if ! docker network ls | grep -q "kafka-sasl-network"; then
        docker network create kafka-sasl-network --driver bridge --subnet=172.21.0.0/16 || true
        log_success "网络创建成功"
    else
        log_info "网络已存在"
    fi
}

# 安全配置检查
security_check() {
    log_step "执行安全配置检查..."
    
    local security_issues=()
    
    # 检查环境变量文件权限
    if [ -f "$ENV_FILE" ]; then
        local file_perms=$(stat -c "%a" "$ENV_FILE" 2>/dev/null || stat -f "%A" "$ENV_FILE" 2>/dev/null)
        if [ "$file_perms" != "600" ] && [ "$file_perms" != "0600" ]; then
            security_issues+=("环境变量文件权限过于宽松: $file_perms")
            log_warning "建议设置文件权限: chmod 600 $ENV_FILE"
        fi
    fi
    
    # 检查默认密码
    if [ -f "$ENV_FILE" ] && grep -q "admin-secret\|user-secret" "$ENV_FILE"; then
        security_issues+=("使用默认密码")
    fi
    
    # 检查密码强度
    if [ -f "$ENV_FILE" ]; then
        while IFS= read -r line; do
            if [[ $line =~ PASSWORD.*= ]] && [[ ! $line =~ ^# ]]; then
                local password=$(echo "$line" | cut -d'=' -f2)
                if [ ${#password} -lt 8 ]; then
                    security_issues+=("密码长度不足8位: $(echo "$line" | cut -d'=' -f1)")
                fi
            fi
        done < "$ENV_FILE"
    fi
    
    # 显示安全检查结果
    if [ ${#security_issues[@]} -eq 0 ]; then
        log_success "安全配置检查通过"
    else
        log_warning "发现以下安全问题:"
        for issue in "${security_issues[@]}"; do
            echo "  - $issue"
        done
        log_security "建议在生产环境部署前解决这些问题"
    fi
}

# 启动服务
start_services() {
    log_step "启动 Kafka SASL 安全集群..."
    
    check_dependencies
    check_env
    check_ports
    create_network
    security_check
    
    # 设置环境变量文件权限
    if [ -f "$ENV_FILE" ]; then
        chmod 600 "$ENV_FILE"
        log_security "已设置环境变量文件安全权限"
    fi
    
    # 拉取镜像
    log_step "拉取 Docker 镜像..."
    if [ -f "$ENV_FILE" ]; then
        docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" -p "$PROJECT_NAME" pull
    else
        docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" pull
    fi
    
    # 启动服务
    log_step "启动服务..."
    if [ -f "$ENV_FILE" ]; then
        docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" -p "$PROJECT_NAME" up -d
    else
        docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d
    fi
    
    # 等待服务启动
    log_step "等待服务启动..."
    sleep 15
    
    # 健康检查
    wait_for_services
    
    log_success "Kafka SASL 安全集群启动成功!"
    show_access_info
    show_security_info
}

# 等待服务启动
wait_for_services() {
    log_step "等待服务健康检查..."
    
    local max_attempts=60
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "健康检查 (${attempt}/${max_attempts})..."
        
        # 检查 Zookeeper
        if docker exec kafka-zookeeper-sasl nc -z localhost 2181 2>/dev/null; then
            log_success "Zookeeper 服务正常"
        else
            log_warning "Zookeeper 服务未就绪"
            sleep 5
            ((attempt++))
            continue
        fi
        
        # 检查 Kafka (需要等待SASL用户创建完成)
        if docker exec kafka-broker-sasl /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --command-config /opt/kafka/config/sasl/client.properties --list &>/dev/null; then
            log_success "Kafka SASL 服务正常"
            break
        else
            log_warning "Kafka SASL 服务未就绪"
            sleep 5
            ((attempt++))
        fi
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_error "服务启动超时，请检查日志"
        show_logs
        exit 1
    fi
}

# 停止服务
stop_services() {
    log_step "停止 Kafka SASL 集群..."
    if [ -f "$ENV_FILE" ]; then
        docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" -p "$PROJECT_NAME" down
    else
        docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" down
    fi
    log_success "Kafka SASL 集群已停止"
}

# 重启服务
restart_services() {
    log_step "重启 Kafka SASL 集群..."
    stop_services
    sleep 3
    start_services
}

# 查看服务状态
show_status() {
    log_step "查看服务状态..."
    if [ -f "$ENV_FILE" ]; then
        docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" -p "$PROJECT_NAME" ps
    else
        docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps
    fi
    
    echo ""
    log_step "服务健康状态:"
    
    # 检查 Zookeeper
    if docker exec kafka-zookeeper-sasl nc -z localhost 2181 2>/dev/null; then
        log_success "Zookeeper: 健康"
    else
        log_error "Zookeeper: 不健康"
    fi
    
    # 检查 Kafka
    if docker exec kafka-broker-sasl /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --command-config /opt/kafka/config/sasl/client.properties --list &>/dev/null; then
        log_success "Kafka: 健康"
    else
        log_error "Kafka: 不健康"
    fi
    
    # 检查 Kafka UI
    if curl -s http://localhost:8080/actuator/health &>/dev/null; then
        log_success "Kafka UI: 健康"
    else
        log_warning "Kafka UI: 不健康或未启动"
    fi
    
    # 检查 Schema Registry
    if curl -s http://localhost:8081/subjects &>/dev/null; then
        log_success "Schema Registry: 健康"
    else
        log_warning "Schema Registry: 不健康或未启动"
    fi
    
    # 检查 Kafka Connect
    if curl -s http://localhost:8083/connectors &>/dev/null; then
        log_success "Kafka Connect: 健康"
    else
        log_warning "Kafka Connect: 不健康或未启动"
    fi
}

# 查看日志
show_logs() {
    local service=${1:-}
    
    if [ -n "$service" ]; then
        log_step "查看 $service 服务日志..."
        if [ -f "$ENV_FILE" ]; then
            docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" -p "$PROJECT_NAME" logs -f "$service"
        else
            docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" logs -f "$service"
        fi
    else
        log_step "查看所有服务日志..."
        if [ -f "$ENV_FILE" ]; then
            docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" -p "$PROJECT_NAME" logs -f
        else
            docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" logs -f
        fi
    fi
}

# 清理数据
clean_data() {
    log_step "清理 Kafka SASL 数据..."
    
    read -p "确定要清理所有数据吗? 这将删除所有主题、用户和消息 (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "操作已取消"
        return
    fi
    
    # 停止服务
    if [ -f "$ENV_FILE" ]; then
        docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" -p "$PROJECT_NAME" down -v
    else
        docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" down -v
    fi
    
    # 删除数据卷
    docker volume rm kafka-sasl-zookeeper-data kafka-sasl-zookeeper-logs kafka-sasl-zookeeper-config kafka-sasl-kafka-data kafka-sasl-kafka-logs kafka-sasl-kafka-config 2>/dev/null || true
    
    # 删除网络
    docker network rm kafka-sasl-network 2>/dev/null || true
    
    log_success "数据清理完成"
}

# 重置集群
reset_cluster() {
    log_step "重置 Kafka SASL 集群..."
    clean_data
    sleep 2
    start_services
}

# 测试 SASL 连接
test_connection() {
    log_step "测试 Kafka SASL 认证连接..."
    
    # 检查客户端配置文件是否存在
    if ! docker exec kafka-broker-sasl test -f /opt/kafka/config/sasl/client.properties 2>/dev/null; then
        log_error "SASL 客户端配置文件不存在"
        return 1
    fi
    
    # 创建测试主题
    log_info "创建测试主题..."
    docker exec kafka-broker-sasl /opt/kafka/bin/kafka-topics.sh \
        --create \
        --topic sasl-test-topic \
        --bootstrap-server localhost:9092 \
        --command-config /opt/kafka/config/sasl/client.properties \
        --partitions 3 \
        --replication-factor 1 \
        --if-not-exists
    
    # 发送测试消息
    log_info "发送测试消息..."
    echo "Hello Kafka SASL $(date)" | docker exec -i kafka-broker-sasl /opt/kafka/bin/kafka-console-producer.sh \
        --topic sasl-test-topic \
        --bootstrap-server localhost:9092 \
        --producer.config /opt/kafka/config/sasl/client.properties
    
    # 消费测试消息
    log_info "消费测试消息..."
    timeout 10s docker exec kafka-broker-sasl /opt/kafka/bin/kafka-console-consumer.sh \
        --topic sasl-test-topic \
        --bootstrap-server localhost:9092 \
        --consumer.config /opt/kafka/config/sasl/client.properties \
        --from-beginning \
        --max-messages 1 || true
    
    log_success "SASL 认证连接测试完成"
}

# 用户管理
manage_users() {
    local action=${1:-list}
    
    case $action in
        --list|list)
            log_step "列出所有 SASL 用户..."
            docker exec kafka-broker-sasl /opt/kafka/bin/kafka-configs.sh \
                --zookeeper zookeeper:2181 \
                --describe \
                --entity-type users
            ;;
        --create)
            local username=${2:-}
            local password=${3:-}
            if [ -z "$username" ] || [ -z "$password" ]; then
                log_error "请指定用户名和密码"
                echo "用法: $0 users --create <username> <password>"
                exit 1
            fi
            
            log_step "创建 SASL 用户: $username"
            docker exec kafka-broker-sasl /opt/kafka/bin/kafka-configs.sh \
                --zookeeper zookeeper:2181 \
                --alter \
                --add-config "SCRAM-SHA-256=[password=$password]" \
                --entity-type users \
                --entity-name "$username"
            ;;
        --delete)
            local username=${2:-}
            if [ -z "$username" ]; then
                log_error "请指定用户名"
                echo "用法: $0 users --delete <username>"
                exit 1
            fi
            
            log_step "删除 SASL 用户: $username"
            docker exec kafka-broker-sasl /opt/kafka/bin/kafka-configs.sh \
                --zookeeper zookeeper:2181 \
                --alter \
                --delete-config "SCRAM-SHA-256" \
                --entity-type users \
                --entity-name "$username"
            ;;
        --change-password)
            local username=${2:-}
            local new_password=${3:-}
            if [ -z "$username" ] || [ -z "$new_password" ]; then
                log_error "请指定用户名和新密码"
                echo "用法: $0 users --change-password <username> <new-password>"
                exit 1
            fi
            
            log_step "修改用户密码: $username"
            docker exec kafka-broker-sasl /opt/kafka/bin/kafka-configs.sh \
                --zookeeper zookeeper:2181 \
                --alter \
                --add-config "SCRAM-SHA-256=[password=$new_password]" \
                --entity-type users \
                --entity-name "$username"
            ;;
        *)
            log_error "未知的用户操作: $action"
            echo "可用操作: --list, --create, --delete, --change-password"
            exit 1
            ;;
    esac
}

# ACL 管理
manage_acl() {
    local action=${1:-list}
    
    case $action in
        --list|list)
            log_step "列出所有 ACL 规则..."
            docker exec kafka-broker-sasl /opt/kafka/bin/kafka-acls.sh \
                --bootstrap-server localhost:9092 \
                --command-config /opt/kafka/config/sasl/client.properties \
                --list
            ;;
        --add)
            local principal=${2:-}
            local operation=${3:-}
            local resource=${4:-}
            if [ -z "$principal" ] || [ -z "$operation" ] || [ -z "$resource" ]; then
                log_error "请指定完整的 ACL 参数"
                echo "用法: $0 acl --add <principal> <operation> <resource>"
                echo "示例: $0 acl --add User:producer Write Topic:my-topic"
                exit 1
            fi
            
            log_step "添加 ACL 规则..."
            docker exec kafka-broker-sasl /opt/kafka/bin/kafka-acls.sh \
                --bootstrap-server localhost:9092 \
                --command-config /opt/kafka/config/sasl/client.properties \
                --add \
                --allow-principal "$principal" \
                --operation "$operation" \
                --topic "${resource#Topic:}"
            ;;
        --remove)
            local principal=${2:-}
            if [ -z "$principal" ]; then
                log_error "请指定用户主体"
                echo "用法: $0 acl --remove <principal>"
                exit 1
            fi
            
            log_step "删除 ACL 规则..."
            docker exec kafka-broker-sasl /opt/kafka/bin/kafka-acls.sh \
                --bootstrap-server localhost:9092 \
                --command-config /opt/kafka/config/sasl/client.properties \
                --remove \
                --allow-principal "$principal"
            ;;
        *)
            log_error "未知的 ACL 操作: $action"
            echo "可用操作: --list, --add, --remove"
            exit 1
            ;;
    esac
}

# 主题管理
manage_topics() {
    local action=${1:-list}
    
    case $action in
        --list|list)
            log_step "列出所有主题..."
            docker exec kafka-broker-sasl /opt/kafka/bin/kafka-topics.sh \
                --list \
                --bootstrap-server localhost:9092 \
                --command-config /opt/kafka/config/sasl/client.properties
            ;;
        --create)
            local topic_name=${2:-}
            if [ -z "$topic_name" ]; then
                log_error "请指定主题名称"
                echo "用法: $0 topics --create <topic-name> [partitions] [replication-factor]"
                exit 1
            fi
            local partitions=${3:-3}
            local replication=${4:-1}
            
            log_step "创建主题: $topic_name"
            docker exec kafka-broker-sasl /opt/kafka/bin/kafka-topics.sh \
                --create \
                --topic "$topic_name" \
                --bootstrap-server localhost:9092 \
                --command-config /opt/kafka/config/sasl/client.properties \
                --partitions "$partitions" \
                --replication-factor "$replication"
            ;;
        --delete)
            local topic_name=${2:-}
            if [ -z "$topic_name" ]; then
                log_error "请指定主题名称"
                echo "用法: $0 topics --delete <topic-name>"
                exit 1
            fi
            
            log_step "删除主题: $topic_name"
            docker exec kafka-broker-sasl /opt/kafka/bin/kafka-topics.sh \
                --delete \
                --topic "$topic_name" \
                --bootstrap-server localhost:9092 \
                --command-config /opt/kafka/config/sasl/client.properties
            ;;
        --describe)
            local topic_name=${2:-}
            if [ -z "$topic_name" ]; then
                log_step "描述所有主题..."
                docker exec kafka-broker-sasl /opt/kafka/bin/kafka-topics.sh \
                    --describe \
                    --bootstrap-server localhost:9092 \
                    --command-config /opt/kafka/config/sasl/client.properties
            else
                log_step "描述主题: $topic_name"
                docker exec kafka-broker-sasl /opt/kafka/bin/kafka-topics.sh \
                    --describe \
                    --topic "$topic_name" \
                    --bootstrap-server localhost:9092 \
                    --command-config /opt/kafka/config/sasl/client.properties
            fi
            ;;
        *)
            log_error "未知的主题操作: $action"
            echo "可用操作: --list, --create, --delete, --describe"
            exit 1
            ;;
    esac
}

# 打开 Kafka UI
open_ui() {
    log_step "打开 Kafka UI..."
    
    if command -v xdg-open &> /dev/null; then
        xdg-open http://localhost:8080
    elif command -v open &> /dev/null; then
        open http://localhost:8080
    else
        log_info "请在浏览器中打开: http://localhost:8080"
    fi
}

# 健康检查
health_check() {
    log_step "执行健康检查..."
    
    local all_healthy=true
    
    # 检查容器状态
    log_info "检查容器状态..."
    if [ -f "$ENV_FILE" ]; then
        compose_cmd="docker-compose -f $COMPOSE_FILE --env-file $ENV_FILE -p $PROJECT_NAME"
    else
        compose_cmd="docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME"
    fi
    
    if ! $compose_cmd ps | grep -q "Up"; then
        log_error "部分或全部容器未运行"
        all_healthy=false
    else
        log_success "所有容器正在运行"
    fi
    
    # 检查 Zookeeper
    log_info "检查 Zookeeper 连接..."
    if docker exec kafka-zookeeper-sasl nc -z localhost 2181 2>/dev/null; then
        log_success "Zookeeper 连接正常"
    else
        log_error "Zookeeper 连接失败"
        all_healthy=false
    fi
    
    # 检查 Kafka SASL
    log_info "检查 Kafka SASL 连接..."
    if docker exec kafka-broker-sasl /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --command-config /opt/kafka/config/sasl/client.properties --list &>/dev/null; then
        log_success "Kafka SASL 连接正常"
    else
        log_error "Kafka SASL 连接失败"
        all_healthy=false
    fi
    
    # 检查 SASL 用户
    log_info "检查 SASL 用户配置..."
    if docker exec kafka-broker-sasl /opt/kafka/bin/kafka-configs.sh --zookeeper zookeeper:2181 --describe --entity-type users | grep -q "SCRAM-SHA-256"; then
        log_success "SASL 用户配置正常"
    else
        log_error "SASL 用户配置失败"
        all_healthy=false
    fi
    
    if $all_healthy; then
        log_success "所有健康检查通过"
    else
        log_error "部分健康检查失败"
        exit 1
    fi
}

# 显示访问信息
show_access_info() {
    echo ""
    log_success "=== Kafka SASL 安全集群访问信息 ==="
    echo -e "${CYAN}Kafka Broker (内部):${NC}  kafka:9092"
    echo -e "${CYAN}Kafka Broker (外部):${NC}  localhost:9093"
    echo -e "${CYAN}Zookeeper:${NC}           zookeeper:2181"
    echo -e "${CYAN}Kafka UI:${NC}            http://localhost:8080"
    echo -e "${CYAN}Schema Registry:${NC}     http://localhost:8081"
    echo -e "${CYAN}Kafka Connect:${NC}       http://localhost:8083"
    echo ""
    echo -e "${YELLOW}认证信息:${NC}"
    echo "  协议: SASL_PLAINTEXT"
    echo "  机制: SCRAM-SHA-256"
    echo "  管理员: admin / admin-secret"
    echo ""
    echo -e "${YELLOW}常用命令:${NC}"
    echo "  查看状态:     $0 status"
    echo "  查看日志:     $0 logs"
    echo "  测试连接:     $0 test"
    echo "  管理用户:     $0 users --list"
    echo "  管理ACL:      $0 acl --list"
    echo "  管理主题:     $0 topics --list"
    echo ""
}

# 显示安全信息
show_security_info() {
    echo ""
    log_security "=== 安全配置信息 ==="
    echo -e "${CYAN}认证机制:${NC} SASL/SCRAM-SHA-256"
    echo -e "${CYAN}访问控制:${NC} ACL (默认拒绝)"
    echo -e "${CYAN}超级用户:${NC} admin"
    echo -e "${CYAN}加密传输:${NC} 明文 (SASL_PLAINTEXT)"
    echo ""
    echo -e "${YELLOW}安全建议:${NC}"
    echo "  1. 修改默认密码"
    echo "  2. 定期轮换密码"
    echo "  3. 配置适当的 ACL 规则"
    echo "  4. 监控访问日志"
    echo "  5. 限制网络访问"
    echo ""
}

# 主函数
main() {
    case ${1:-start} in
        start)
            start_services
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
            show_logs "$2"
            ;;
        clean)
            clean_data
            ;;
        reset)
            reset_cluster
            ;;
        test)
            test_connection
            ;;
        topics)
            manage_topics "$2" "$3" "$4" "$5"
            ;;
        users)
            manage_users "$2" "$3" "$4"
            ;;
        acl)
            manage_acl "$2" "$3" "$4" "$5"
            ;;
        ui)
            open_ui
            ;;
        health)
            health_check
            ;;
        security)
            security_check
            ;;
        setup-env)
            setup_env
            ;;
        --help|-h|help)
            show_help
            ;;
        *)
            log_error "未知命令: $1"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@" 