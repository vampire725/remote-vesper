#!/bin/bash

# OpenTelemetry 服务图数据生成器
echo "=========================================="
echo "  OpenTelemetry 服务图数据生成器"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置参数
COLLECTOR_HTTP_ENDPOINT="http://localhost:4318/v1/traces"
CYCLES=5              # 生成周期数
TRACES_PER_CYCLE=5    # 每周期追踪数
CYCLE_INTERVAL=10      # 周期间隔（秒）

# 预定义的服务拓扑 - 每个拓扑代表一个业务流程
declare -A SERVICE_TOPOLOGIES

# 电商业务流程
SERVICE_TOPOLOGIES["ecommerce"]="
frontend-web:8080 → api-gateway:8081 → user-service:8082
api-gateway:8081 → product-service:8083 → elasticsearch:9200
api-gateway:8081 → order-service:8084 → payment-service:8085
order-service:8084 → inventory-service:8086 → postgres-db:5432
payment-service:8085 → billing-service:8087 → mysql-db:3306
order-service:8084 → notification-service:8088 → rabbitmq:5672
user-service:8082 → auth-service:8089 → redis-cache:6379
"

# 微服务架构
SERVICE_TOPOLOGIES["microservices"]="
load-balancer:8080 → api-gateway:8081 → auth-service:8082
api-gateway:8081 → user-service:8083 → user-db:5432
api-gateway:8081 → content-service:8084 → content-db:5433
api-gateway:8081 → recommendation-service:8085 → redis-cache:6379
recommendation-service:8085 → ml-service:8086 → feature-store:5434
content-service:8084 → cdn-service:8087 → s3-storage:443
user-service:8083 → email-service:8088 → smtp-server:587
"

# 数据处理管道
SERVICE_TOPOLOGIES["data-pipeline"]="
data-ingestion:8080 → kafka:9092 → stream-processor:8081
stream-processor:8081 → data-validator:8082 → clean-data-topic:9092
stream-processor:8081 → data-enricher:8083 → postgres-db:5432
data-enricher:8083 → feature-extractor:8084 → feature-store:8085
feature-extractor:8084 → model-service:8086 → redis-cache:6379
model-service:8086 → prediction-api:8087 → results-db:5433
"

# 日志和监控流程
SERVICE_TOPOLOGIES["observability"]="
log-collector:8080 → log-parser:8081 → elasticsearch:9200
metric-collector:8082 → prometheus:9090 → alertmanager:9093
trace-collector:8083 → tempo:3200 → grafana:3000
elasticsearch:9200 → kibana:5601 → dashboard-service:8084
prometheus:9090 → grafana:3000 → notification-service:8085
"

# 显示用法
show_usage() {
    echo -e "${BLUE}用法:${NC}"
    echo "  $0 [选项]"
    echo ""
    echo -e "${BLUE}选项:${NC}"
    echo "  -c, --cycles N       生成周期数 (默认: $CYCLES)"
    echo "  -t, --traces N       每周期追踪数 (默认: $TRACES_PER_CYCLE)"
    echo "  -i, --interval N     周期间隔秒数 (默认: $CYCLE_INTERVAL)"
    echo "  -p, --topology TYPE  指定拓扑类型 (ecommerce|microservices|data-pipeline|observability|all)"
    echo "  -v, --verify         生成后验证服务图"
    echo "  -h, --help           显示帮助信息"
    echo ""
    echo -e "${BLUE}示例:${NC}"
    echo "  $0                          # 生成所有拓扑的服务图"
    echo "  $0 -p ecommerce             # 只生成电商拓扑"
    echo "  $0 -c 20 -t 100             # 20个周期，每周期100个追踪"
    echo "  $0 -v                       # 生成并验证服务图"
}

# 解析参数
TOPOLOGY_TYPE="all"
VERIFY_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--cycles)
            CYCLES="$2"
            shift 2
            ;;
        -t|--traces)
            TRACES_PER_CYCLE="$2"
            shift 2
            ;;
        -i|--interval)
            CYCLE_INTERVAL="$2"
            shift 2
            ;;
        -p|--topology)
            TOPOLOGY_TYPE="$2"
            shift 2
            ;;
        -v|--verify)
            VERIFY_MODE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${RED}❌ 未知选项: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
done

# 检查 OTel Collector
echo -e "${BLUE}🔍 检查 OpenTelemetry Collector...${NC}"
if ! curl -s --connect-timeout 3 --max-time 5 "http://localhost:13133/" > /dev/null; then
    echo -e "${RED}❌ OTel Collector 不可用，请先启动系统${NC}"
    echo "运行: ./start-all.sh"
    exit 1
fi
echo -e "${GREEN}✅ OTel Collector 正常运行${NC}"
echo ""

# 生成随机ID
generate_trace_id() {
    echo $(openssl rand -hex 16 | tr '[:lower:]' '[:upper:]')
}

generate_span_id() {
    echo $(openssl rand -hex 8 | tr '[:lower:]' '[:upper:]')
}

# 解析服务拓扑
parse_topology() {
    local topology=$1
    local chains=()
    
    # 解析每一行（每行代表一个调用链）
    while IFS= read -r line; do
        if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*$ ]]; then
            chains+=("$line")
        fi
    done <<< "$topology"
    
    echo "${chains[@]}"
}

# 创建服务间调用span
create_service_span() {
    local trace_id=$1
    local span_id=$2
    local parent_span_id=$3
    local service_name=$4
    local service_port=$5
    local target_service=$6
    local target_port=$7
    local start_time=$8
    local duration=$9
    local status_code=${10:-200}
    
    local end_time=$((start_time + duration))
    local span_status="1"  # OK
    local error_message=""
    
    if [ $status_code -ge 400 ]; then
        span_status="2"  # ERROR
        error_message="Service call failed"
    fi
    
    # 构建span JSON
    local span_json="{
        \"traceId\": \"$trace_id\",
        \"spanId\": \"$span_id\",
        \"name\": \"$service_name → $target_service\",
        \"kind\": 3,
        \"startTimeUnixNano\": $start_time,
        \"endTimeUnixNano\": $end_time,
        \"attributes\": [
            {\"key\": \"service.name\", \"value\": {\"stringValue\": \"$service_name\"}},
            {\"key\": \"peer.service\", \"value\": {\"stringValue\": \"$target_service\"}},
            {\"key\": \"server.address\", \"value\": {\"stringValue\": \"$target_service\"}},
            {\"key\": \"server.port\", \"value\": {\"intValue\": $target_port}},
            {\"key\": \"client.address\", \"value\": {\"stringValue\": \"$service_name\"}},
            {\"key\": \"client.port\", \"value\": {\"intValue\": $service_port}},
            {\"key\": \"http.method\", \"value\": {\"stringValue\": \"POST\"}},
            {\"key\": \"http.url\", \"value\": {\"stringValue\": \"http://$target_service:$target_port/api/call\"}},
            {\"key\": \"http.status_code\", \"value\": {\"intValue\": $status_code}},
            {\"key\": \"rpc.service\", \"value\": {\"stringValue\": \"$target_service\"}},
            {\"key\": \"rpc.method\", \"value\": {\"stringValue\": \"ProcessRequest\"}},
            {\"key\": \"span.kind\", \"value\": {\"stringValue\": \"client\"}}
        ],
        \"status\": {\"code\": $span_status$([ -n "$error_message" ] && echo ", \"message\": \"$error_message\"" || echo "")}
    }"
    
    # 添加parent span ID
    if [ -n "$parent_span_id" ]; then
        span_json=$(echo "$span_json" | sed "s/\"name\":/\"parentSpanId\": \"$parent_span_id\", \"name\":/")
    fi
    
    echo "$span_json"
}

# 生成调用链追踪
generate_call_chain_trace() {
    local chain=$1
    local trace_id=$(generate_trace_id)
    local current_time_ns=$(date +%s%N)
    
    # 解析调用链：service1:port1 → service2:port2 → service3:port3
    IFS=' → ' read -ra SERVICES <<< "$chain"
    local resource_spans=()
    local parent_span_id=""
    local current_start_time=$current_time_ns
    
    for ((i=0; i<${#SERVICES[@]}-1; i++)); do
        local source_service=$(echo "${SERVICES[$i]}" | cut -d':' -f1)
        local source_port=$(echo "${SERVICES[$i]}" | cut -d':' -f2)
        local target_service=$(echo "${SERVICES[$((i+1))]}" | cut -d':' -f1)
        local target_port=$(echo "${SERVICES[$((i+1))]}" | cut -d':' -f2)
        
        local span_id=$(generate_span_id)
        local duration=$((RANDOM % 500 + 100))  # 100-600ms
        local duration_ns=$((duration * 1000000))
        
        # 随机添加一些错误（5%概率）
        local status_code=200
        if [ $((RANDOM % 100)) -lt 5 ]; then
            status_code=$((400 + RANDOM % 100))
        fi
        
        local span=$(create_service_span "$trace_id" "$span_id" "$parent_span_id" \
            "$source_service" "$source_port" "$target_service" "$target_port" \
            "$current_start_time" "$duration_ns" "$status_code")
        
        # 为每个源服务创建单独的资源span
        local resource_span="{
            \"resource\": {
                \"attributes\": [
                    {\"key\": \"service.name\", \"value\": {\"stringValue\": \"$source_service\"}},
                    {\"key\": \"service.version\", \"value\": {\"stringValue\": \"2.0.0\"}},
                    {\"key\": \"deployment.environment\", \"value\": {\"stringValue\": \"production\"}},
                    {\"key\": \"topology.type\", \"value\": {\"stringValue\": \"$TOPOLOGY_TYPE\"}}
                ]
            },
            \"scopeSpans\": [{
                \"scope\": {
                    \"name\": \"service-graph-generator\",
                    \"version\": \"1.0.0\"
                },
                \"spans\": [$span]
            }]
        }"
        
        resource_spans+=("$resource_span")
        parent_span_id=$span_id
        current_start_time=$((current_start_time + duration_ns + (RANDOM % 10000000)))  # 添加小延迟
    done
    
    # 构建完整的追踪数据，包含多个资源span
    echo "{\"resourceSpans\": [$(IFS=','; echo "${resource_spans[*]}")]}"
}

# 生成拓扑数据
generate_topology_data() {
    local topology_name=$1
    local topology_data=$2
    local cycle_number=$3
    
    echo -e "${BLUE}🔗 生成 $topology_name 拓扑数据 (周期 $cycle_number)...${NC}"
    
    # 解析拓扑中的所有调用链
    local chains=($(parse_topology "$topology_data"))
    local total_traces=0
    
    for ((i=1; i<=TRACES_PER_CYCLE; i++)); do
        # 随机选择一个调用链
        local chain_index=$((RANDOM % ${#chains[@]}))
        local selected_chain="${chains[$chain_index]}"
        
        # 生成该调用链的追踪数据
        local trace_data=$(generate_call_chain_trace "$selected_chain")
        
        # 发送数据
        local response=$(curl -s -w "%{http_code}" -X POST "$COLLECTOR_HTTP_ENDPOINT" \
            -H "Content-Type: application/json" \
            -d "$trace_data")
        
        local http_code="${response: -3}"
        if [ "$http_code" = "200" ]; then
            ((total_traces++))
        fi
        
        # 小延迟避免过快发送
        sleep 0.1
    done
    
    echo -e "${GREEN}   ✅ $topology_name: 发送 $total_traces/$TRACES_PER_CYCLE 个追踪${NC}"
}

# 验证服务图生成
verify_service_graph() {
    echo -e "${BLUE}🔍 验证服务图生成...${NC}"
    echo ""
    
    # 等待数据处理
    echo "等待服务图数据处理 (60秒)..."
    sleep 60
    
    # 检查Tempo指标
    echo "检查Tempo服务图指标..."
    local tempo_metrics=$(curl -s "http://localhost:3200/metrics" | grep "traces_service_graph_request_total" | wc -l)
    if [ "$tempo_metrics" -gt 0 ]; then
        echo -e "${GREEN}✅ Tempo已生成 $tempo_metrics 个服务图指标${NC}"
    else
        echo -e "${YELLOW}⚠ Tempo服务图指标为空${NC}"
    fi
    
    # 检查Prometheus指标
    echo "检查Prometheus服务图数据..."
    local prom_response=$(curl -s "http://localhost:19090/api/v1/query?query=traces_service_graph_request_total")
    local result_count=$(echo "$prom_response" | jq -r '.data.result | length' 2>/dev/null || echo "0")
    
    if [ "$result_count" -gt 0 ]; then
        echo -e "${GREEN}✅ Prometheus中有 $result_count 个服务图指标${NC}"
        
        # 显示服务关系
        echo ""
        echo "检测到的服务关系："
        echo "$prom_response" | jq -r '.data.result[] | "\(.metric.client) → \(.metric.server)"' 2>/dev/null | sort | uniq | head -10
    else
        echo -e "${YELLOW}⚠ Prometheus中暂无服务图数据${NC}"
    fi
    
    echo ""
}

# 显示配置信息
echo -e "${BLUE}🔧 生成配置:${NC}"
echo "  拓扑类型: $TOPOLOGY_TYPE"
echo "  生成周期: $CYCLES"
echo "  每周期追踪数: $TRACES_PER_CYCLE"
echo "  周期间隔: ${CYCLE_INTERVAL}秒"
echo "  验证模式: $([ "$VERIFY_MODE" = true ] && echo "是" || echo "否")"
echo "  总计追踪: $((CYCLES * TRACES_PER_CYCLE))"
echo ""

# 选择要生成的拓扑
SELECTED_TOPOLOGIES=()
if [ "$TOPOLOGY_TYPE" = "all" ]; then
    SELECTED_TOPOLOGIES=("ecommerce" "microservices" "data-pipeline" "observability")
else
    if [[ -n "${SERVICE_TOPOLOGIES[$TOPOLOGY_TYPE]}" ]]; then
        SELECTED_TOPOLOGIES=("$TOPOLOGY_TYPE")
    else
        echo -e "${RED}❌ 未知的拓扑类型: $TOPOLOGY_TYPE${NC}"
        echo "可用类型: ecommerce, microservices, data-pipeline, observability, all"
        exit 1
    fi
fi

echo -e "${YELLOW}🚀 开始生成服务图数据...${NC}"
echo ""

# 开始生成数据
start_time=$(date +%s)
total_generated_traces=0

for ((cycle=1; cycle<=CYCLES; cycle++)); do
    echo -e "${BLUE}📊 周期 $cycle/$CYCLES${NC}"
    
    for topology_name in "${SELECTED_TOPOLOGIES[@]}"; do
        topology_data="${SERVICE_TOPOLOGIES[$topology_name]}"
        generate_topology_data "$topology_name" "$topology_data" "$cycle"
        total_generated_traces=$((total_generated_traces + TRACES_PER_CYCLE))
    done
    
    if [ $cycle -lt $CYCLES ]; then
        echo -e "${BLUE}   等待 ${CYCLE_INTERVAL}秒...${NC}"
        sleep $CYCLE_INTERVAL
    fi
    echo ""
done

end_time=$(date +%s)
duration=$((end_time - start_time))

echo "=========================================="
echo -e "${GREEN}🎉 服务图数据生成完成！${NC}"
echo "=========================================="
echo ""
echo -e "${GREEN}📊 生成统计:${NC}"
echo "  拓扑类型: ${SELECTED_TOPOLOGIES[*]}"
echo "  总计追踪: $total_generated_traces"
echo "  生成周期: $CYCLES"
echo "  耗时: ${duration}秒"
echo "  平均速率: $((total_generated_traces / duration)) 追踪/秒"
echo ""

# 验证服务图
if [ "$VERIFY_MODE" = true ]; then
    verify_service_graph
fi

echo -e "${BLUE}💡 查看服务图:${NC}"
echo "1. 访问 Grafana: http://localhost:13000"
echo "2. 进入 Explore → Tempo 数据源"
echo "3. 点击 'Service Map' 标签页"
echo "4. 等待1-2分钟让服务图加载"
echo "5. 运行检查脚本: ./check-service-graph.sh"
echo ""
echo -e "${YELLOW}📈 生成的服务拓扑:${NC}"
for topology_name in "${SELECTED_TOPOLOGIES[@]}"; do
    echo ""
    echo "📋 $topology_name 拓扑:"
    echo "${SERVICE_TOPOLOGIES[$topology_name]}" | grep -v '^[[:space:]]*$' | sed 's/^/  /'
done 