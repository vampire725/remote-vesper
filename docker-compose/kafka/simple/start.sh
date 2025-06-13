#!/bin/bash

# Kafka 简单部署启动脚本
# 适用于 Linux/Mac 系统
# 版本: Apache Kafka 3.9.1 (简单版本 - 不带SASL认证)

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
PROJECT_NAME="kafka-simple"

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

# 显示帮助信息
show_help() {
    echo -e "${CYAN}Kafka 简单部署管理脚本${NC}"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  start           启动 Kafka 集群"
    echo "  stop            停止 Kafka 集群"
    echo "  restart         重启 Kafka 集群"
    echo "  status          查看服务状态"
    echo "  logs [service]  查看日志 (可选指定服务名)"
    echo "  clean           清理所有数据和容器"
    echo "  reset           重置集群 (停止、清理、启动)"
    echo "  test            测试 Kafka 连接"
    echo "  topics          管理主题"
    echo "  ui              打开 Kafka UI"
    echo "  health          健康检查"
    echo "  --help, -h      显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 start                    # 启动集群"
    echo "  $0 logs kafka               # 查看 Kafka 日志"
    echo "  $0 test                     # 测试连接"
    echo "  $0 topics --list            # 列出所有主题"
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

# 检查端口占用
check_ports() {
    log_step "检查端口占用..."
    
    local ports=(2181 9092 8080)
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
    
    if ! docker network ls | grep -q "kafka-simple-network"; then
        docker network create kafka-simple-network --driver bridge --subnet=172.20.0.0/16 || true
        log_success "网络创建成功"
    else
        log_info "网络已存在"
    fi
}

# 启动服务
start_services() {
    log_step "启动 Kafka 集群..."
    
    check_dependencies
    check_ports
    create_network
    
    # 拉取镜像
    log_step "拉取 Docker 镜像..."
    docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" pull
    
    # 启动服务
    log_step "启动服务..."
    docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d
    
    # 等待服务启动
    log_step "等待服务启动..."
    sleep 10
    
    # 健康检查
    wait_for_services
    
    log_success "Kafka 集群启动成功!"
    show_access_info
}

# 等待服务启动
wait_for_services() {
    log_step "等待服务健康检查..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "健康检查 (${attempt}/${max_attempts})..."
        
        # 检查 Zookeeper
        if docker exec kafka-zookeeper nc -z localhost 2181 2>/dev/null; then
            log_success "Zookeeper 服务正常"
        else
            log_warning "Zookeeper 服务未就绪"
            sleep 5
            ((attempt++))
            continue
        fi
        
        # 检查 Kafka
        if docker exec kafka-broker /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092 &>/dev/null; then
            log_success "Kafka 服务正常"
            break
        else
            log_warning "Kafka 服务未就绪"
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
    log_step "停止 Kafka 集群..."
    docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" down
    log_success "Kafka 集群已停止"
}

# 重启服务
restart_services() {
    log_step "重启 Kafka 集群..."
    stop_services
    sleep 3
    start_services
}

# 查看服务状态
show_status() {
    log_step "查看服务状态..."
    docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps
    
    echo ""
    log_step "服务健康状态:"
    
    # 检查 Zookeeper
    if docker exec kafka-zookeeper nc -z localhost 2181 2>/dev/null; then
        log_success "Zookeeper: 健康"
    else
        log_error "Zookeeper: 不健康"
    fi
    
    # 检查 Kafka
    if docker exec kafka-broker /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092 &>/dev/null; then
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
}

# 查看日志
show_logs() {
    local service=${1:-}
    
    if [ -n "$service" ]; then
        log_step "查看 $service 服务日志..."
        docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" logs -f "$service"
    else
        log_step "查看所有服务日志..."
        docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" logs -f
    fi
}

# 清理数据
clean_data() {
    log_step "清理 Kafka 数据..."
    
    read -p "确定要清理所有数据吗? 这将删除所有主题和消息 (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "操作已取消"
        return
    fi
    
    # 停止服务
    docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" down -v
    
    # 删除数据卷
    docker volume rm kafka-simple-zookeeper-data kafka-simple-zookeeper-logs kafka-simple-kafka-data kafka-simple-kafka-logs 2>/dev/null || true
    
    # 删除网络
    docker network rm kafka-simple-network 2>/dev/null || true
    
    log_success "数据清理完成"
}

# 重置集群
reset_cluster() {
    log_step "重置 Kafka 集群..."
    clean_data
    sleep 2
    start_services
}

# 测试连接
test_connection() {
    log_step "测试 Kafka 连接..."
    
    # 创建测试主题
    log_info "创建测试主题..."
    docker exec kafka-broker /opt/kafka/bin/kafka-topics.sh \
        --create \
        --topic test-topic \
        --bootstrap-server localhost:9092 \
        --partitions 3 \
        --replication-factor 1 \
        --if-not-exists
    
    # 发送测试消息
    log_info "发送测试消息..."
    echo "Hello Kafka $(date)" | docker exec -i kafka-broker /opt/kafka/bin/kafka-console-producer.sh \
        --topic test-topic \
        --bootstrap-server localhost:9092
    
    # 消费测试消息
    log_info "消费测试消息..."
    timeout 10s docker exec kafka-broker /opt/kafka/bin/kafka-console-consumer.sh \
        --topic test-topic \
        --bootstrap-server localhost:9092 \
        --from-beginning \
        --max-messages 1 || true
    
    log_success "连接测试完成"
}

# 主题管理
manage_topics() {
    local action=${1:-list}
    
    case $action in
        --list|list)
            log_step "列出所有主题..."
            docker exec kafka-broker /opt/kafka/bin/kafka-topics.sh \
                --list \
                --bootstrap-server localhost:9092
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
            docker exec kafka-broker /opt/kafka/bin/kafka-topics.sh \
                --create \
                --topic "$topic_name" \
                --bootstrap-server localhost:9092 \
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
            docker exec kafka-broker /opt/kafka/bin/kafka-topics.sh \
                --delete \
                --topic "$topic_name" \
                --bootstrap-server localhost:9092
            ;;
        --describe)
            local topic_name=${2:-}
            if [ -z "$topic_name" ]; then
                log_step "描述所有主题..."
                docker exec kafka-broker /opt/kafka/bin/kafka-topics.sh \
                    --describe \
                    --bootstrap-server localhost:9092
            else
                log_step "描述主题: $topic_name"
                docker exec kafka-broker /opt/kafka/bin/kafka-topics.sh \
                    --describe \
                    --topic "$topic_name" \
                    --bootstrap-server localhost:9092
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
    if ! docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps | grep -q "Up"; then
        log_error "部分或全部容器未运行"
        all_healthy=false
    else
        log_success "所有容器正在运行"
    fi
    
    # 检查 Zookeeper
    log_info "检查 Zookeeper 连接..."
    if docker exec kafka-zookeeper nc -z localhost 2181 2>/dev/null; then
        log_success "Zookeeper 连接正常"
    else
        log_error "Zookeeper 连接失败"
        all_healthy=false
    fi
    
    # 检查 Kafka
    log_info "检查 Kafka 连接..."
    if docker exec kafka-broker /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092 &>/dev/null; then
        log_success "Kafka 连接正常"
    else
        log_error "Kafka 连接失败"
        all_healthy=false
    fi
    
    # 检查主题创建
    log_info "检查主题操作..."
    if docker exec kafka-broker /opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092 &>/dev/null; then
        log_success "主题操作正常"
    else
        log_error "主题操作失败"
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
    log_success "=== Kafka 集群访问信息 ==="
    echo -e "${CYAN}Kafka Broker:${NC}     localhost:9092"
    echo -e "${CYAN}Zookeeper:${NC}       localhost:2181"
    echo -e "${CYAN}Kafka UI:${NC}        http://localhost:8080"
    echo ""
    echo -e "${YELLOW}常用命令:${NC}"
    echo "  查看状态:     $0 status"
    echo "  查看日志:     $0 logs"
    echo "  测试连接:     $0 test"
    echo "  管理主题:     $0 topics --list"
    echo "  打开UI:       $0 ui"
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
        ui)
            open_ui
            ;;
        health)
            health_check
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