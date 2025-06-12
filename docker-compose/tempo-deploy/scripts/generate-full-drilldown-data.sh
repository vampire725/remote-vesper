#!/bin/bash

echo "🎯 生成Grafana Drilldown全量演示数据"
echo "===================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}本脚本将生成Grafana Drilldown Traces页面的全量数据${NC}"
echo -e "${CYAN}包含: Span Rate, Breakdown, Service Structure, Comparison, Traces${NC}"
echo ""

# 检查服务状态
echo -e "${BLUE}1. 检查服务状态...${NC}"
echo "===================="

services=("tempo:3200" "prometheus:9090" "grafana:3000" "otel-collector:4318")
all_services_ok=true

for service in "${services[@]}"; do
    name=$(echo $service | cut -d: -f1)
    port=$(echo $service | cut -d: -f2)
    
    if curl -s "http://localhost:$port" > /dev/null 2>&1 || curl -s "http://localhost:$port/ready" > /dev/null 2>&1; then
        echo -e "   ${GREEN}✅ $name (端口 $port) - 运行正常${NC}"
    else
        echo -e "   ${RED}❌ $name (端口 $port) - 不可访问${NC}"
        all_services_ok=false
    fi
done

if [ "$all_services_ok" = false ]; then
    echo -e "\n${RED}⚠ 发现服务异常，请先运行: ./start-all.sh${NC}"
    exit 1
fi

# 数据生成配置
BATCHES=30              # 批次数量
TRACES_PER_BATCH=8      # 每批次追踪数
BATCH_INTERVAL=2        # 批次间隔（秒）

echo ""
echo -e "${BLUE}2. 开始生成全量数据...${NC}"
echo "===================="
echo -e "${YELLOW}配置: $BATCHES 批次 × $TRACES_PER_BATCH 追踪/批次 = $((BATCHES * TRACES_PER_BATCH)) 个追踪${NC}"
echo ""

# 服务定义 - 用于Service Structure
services_config=(
    "frontend-web:api-gateway"
    "api-gateway:user-service,order-service,payment-service,notification-service"
    "user-service:user-database,redis-cache"
    "order-service:order-database,inventory-service"
    "payment-service:payment-gateway,billing-service"
    "notification-service:email-service,sms-service"
    "inventory-service:inventory-database"
    "billing-service:billing-database"
    "email-service:smtp-server"
    "sms-service:sms-gateway"
)

# 操作类型定义 - 用于Breakdown
operations=(
    "GET:/api/users"
    "POST:/api/users"
    "GET:/api/orders"
    "POST:/api/orders"
    "PUT:/api/orders"
    "GET:/api/payments"
    "POST:/api/payments"
    "GET:/api/notifications"
    "POST:/api/notifications"
    "GET:/api/inventory"
    "PUT:/api/inventory"
    "DELETE:/api/users"
)

# HTTP状态码分布 - 用于Breakdown错误分析
status_codes=(200 200 200 200 201 201 400 404 500 503)

# 响应时间范围 - 用于Breakdown性能分析
response_times=(50 80 120 150 200 300 500 800 1200 2000)

# 生成追踪数据的函数
generate_trace() {
    local batch_num=$1
    local trace_num=$2
    local base_time=$3
    
    # 时间偏移，用于Comparison时间对比
    local time_offset=$((batch_num * BATCH_INTERVAL))
    local current_time=$((base_time + time_offset))
    
    # 随机选择服务链
    local service_chain=${services_config[$((RANDOM % ${#services_config[@]}))]}
    local source_service=$(echo $service_chain | cut -d: -f1)
    local target_services=$(echo $service_chain | cut -d: -f2)
    local target_service=$(echo $target_services | cut -d, -f$((RANDOM % $(echo $target_services | tr ',' '\n' | wc -l) + 1)))
    
    # 随机选择操作
    local operation=${operations[$((RANDOM % ${#operations[@]}))]}
    local http_method=$(echo $operation | cut -d: -f1)
    local http_path=$(echo $operation | cut -d: -f2)
    
    # 随机选择状态码和响应时间
    local status_code=${status_codes[$((RANDOM % ${#status_codes[@]}))]}
    local response_time=${response_times[$((RANDOM % ${#response_times[@]}))]}
    
    # 生成ID
    local trace_id=$(openssl rand -hex 16)
    local span_id=$(openssl rand -hex 8)
    local parent_span_id=$(openssl rand -hex 8)
    
    # 预处理条件表达式，避免JSON构建时的语法错误
    local status_status_code
    local status_message=""
    if [[ $status_code -ge 400 ]]; then
        status_status_code=2
        status_message=', "message": "HTTP Error '$status_code'"'
    else
        status_status_code=1
    fi
    
    # 数据库系统类型
    local db_system
    if [[ $target_service == *"database"* ]]; then
        db_system="postgresql"
    else
        db_system="redis"
    fi
    
    # 业务单元
    local business_unit_rand=$((RANDOM % 3))
    local business_unit
    if [[ $business_unit_rand -eq 0 ]]; then
        business_unit="retail"
    elif [[ $business_unit_rand -eq 1 ]]; then
        business_unit="enterprise"
    else
        business_unit="mobile"
    fi
    
    # A/B测试组
    local ab_test_group
    if [[ $((RANDOM % 2)) -eq 0 ]]; then
        ab_test_group="control"
    else
        ab_test_group="experiment"
    fi
    
    # 特性标志
    local feature_flag
    if [[ $((RANDOM % 2)) -eq 0 ]]; then
        feature_flag="true"
    else
        feature_flag="false"
    fi
    
    # 构建追踪数据
    local trace_data='{
        "resourceSpans": [
            {
                "resource": {
                    "attributes": [
                        {"key": "service.name", "value": {"stringValue": "'$source_service'"}},
                        {"key": "service.version", "value": {"stringValue": "1.2.'$((batch_num % 5))'"}},
                        {"key": "service.namespace", "value": {"stringValue": "production"}},
                        {"key": "deployment.environment", "value": {"stringValue": "prod"}},
                        {"key": "k8s.pod.name", "value": {"stringValue": "'$source_service'-pod-'$((RANDOM % 5))'"}}
                    ]
                },
                "scopeSpans": [
                    {
                        "scope": {"name": "'$source_service'-tracer", "version": "1.0.0"},
                        "spans": [
                            {
                                "traceId": "'$trace_id'",
                                "spanId": "'$span_id'",
                                "parentSpanId": "'$parent_span_id'",
                                "name": "'$http_method' '$http_path'",
                                "kind": 2,
                                "startTimeUnixNano": '$(($current_time * 1000000000))',
                                "endTimeUnixNano": '$(($current_time * 1000000000 + $response_time * 1000000))',
                                "status": {"code": '$status_status_code''$status_message'},
                                "attributes": [
                                    {"key": "http.method", "value": {"stringValue": "'$http_method'"}},
                                    {"key": "http.url", "value": {"stringValue": "https://api.example.com'$http_path'"}},
                                    {"key": "http.status_code", "value": {"intValue": '$status_code'}},
                                    {"key": "http.user_agent", "value": {"stringValue": "Mozilla/5.0 (API Client)"}},
                                    {"key": "peer.service", "value": {"stringValue": "'$target_service'"}},
                                    {"key": "peer.hostname", "value": {"stringValue": "'$target_service'.internal"}},
                                    {"key": "rpc.service", "value": {"stringValue": "'$target_service'"}},
                                    {"key": "db.system", "value": {"stringValue": "'$db_system'"}},
                                    {"key": "user.id", "value": {"stringValue": "user_'$((RANDOM % 1000))'"}},
                                    {"key": "session.id", "value": {"stringValue": "session_'$trace_id'"}},
                                    {"key": "request.size", "value": {"intValue": '$((RANDOM % 10000 + 500))'}},
                                    {"key": "response.size", "value": {"intValue": '$((RANDOM % 50000 + 1000))'}},
                                    {"key": "custom.business_unit", "value": {"stringValue": "'$business_unit'"}},
                                    {"key": "custom.feature_flag", "value": {"boolValue": '$feature_flag'}},
                                    {"key": "custom.ab_test_group", "value": {"stringValue": "'$ab_test_group'"}}
                                ]
                            }
                        ]
                    }
                ]
            }
        ]
    }'
    
    echo "$trace_data"
}

# 批量发送数据
echo -e "${PURPLE}开始生成数据批次...${NC}"

base_timestamp=$(date +%s)
total_sent=0
total_failed=0

for batch in $(seq 1 $BATCHES); do
    echo -ne "${YELLOW}📦 批次 $batch/$BATCHES: ${NC}"
    
    batch_sent=0
    batch_failed=0
    
    for trace in $(seq 1 $TRACES_PER_BATCH); do
        trace_data=$(generate_trace $batch $trace $base_timestamp)
        
        # 发送数据
        response=$(echo "$trace_data" | curl -X POST "http://localhost:4318/v1/traces" \
            -H "Content-Type: application/json" \
            -d @- -w "%{http_code}" -s -o /dev/null)
        
        if [ "$response" = "200" ]; then
            batch_sent=$((batch_sent + 1))
            total_sent=$((total_sent + 1))
        else
            batch_failed=$((batch_failed + 1))
            total_failed=$((total_failed + 1))
        fi
    done
    
    echo -e "${GREEN}✅ 成功: $batch_sent${NC} ${RED}失败: $batch_failed${NC}"
    
    # 批次间隔
    if [ $batch -lt $BATCHES ]; then
        sleep $BATCH_INTERVAL
    fi
done

echo ""
echo -e "${BLUE}3. 数据发送汇总${NC}"
echo "=================="
echo -e "${GREEN}✅ 总成功: $total_sent 个追踪${NC}"
echo -e "${RED}❌ 总失败: $total_failed 个追踪${NC}"
echo -e "${YELLOW}📊 成功率: $(( total_sent * 100 / (total_sent + total_failed) ))%${NC}"

# 等待数据处理
echo ""
echo -e "${BLUE}4. 等待数据处理...${NC}"
echo "=================="
echo -e "${YELLOW}⏱️ 等待180秒让数据完全处理...${NC}"

for i in {180..1}; do
    if [ $((i % 30)) -eq 0 ] || [ $i -le 10 ]; then
        echo -ne "${GRAY}剩余 $i 秒...\r${NC}"
    fi
    sleep 1
done
echo -e "${GREEN}✅ 数据处理等待完成${NC}"

# 验证数据生成结果
echo ""
echo -e "${BLUE}5. 验证数据生成结果...${NC}"
echo "===================="

# 检查Tempo指标
echo -e "${YELLOW}📊 检查Tempo接收指标...${NC}"
tempo_metrics=$(curl -s "http://localhost:3200/metrics" | grep -E "tempo.*received|distributor.*spans" | head -3)
if [ -n "$tempo_metrics" ]; then
    echo -e "${GREEN}✅ Tempo接收指标:${NC}"
    echo "$tempo_metrics" | while read line; do
        echo -e "   ${GRAY}$line${NC}"
    done
else
    echo -e "${RED}❌ 未发现Tempo接收指标${NC}"
fi

# 检查服务图指标
echo -e "\n${YELLOW}🌐 检查服务图指标...${NC}"
service_graph_response=$(curl -s "http://localhost:9090/api/v1/query?query=traces_service_graph_request_total")
service_graph_count=$(echo "$service_graph_response" | grep -o '"result":\[.*\]' | grep -c '{' 2>/dev/null || echo "0")

if [ "$service_graph_count" -gt 0 ]; then
    echo -e "${GREEN}✅ 发现 $service_graph_count 个服务图指标${NC}"
else
    echo -e "${YELLOW}⚠ 服务图指标还在生成中，请等待2-3分钟${NC}"
fi

# 生成使用指南
echo ""
echo -e "${BLUE}6. Grafana Drilldown使用指南${NC}"
echo "===================="
echo ""
echo -e "${CYAN}🎯 现在您可以在Grafana中查看所有模块的数据:${NC}"
echo ""

echo -e "${PURPLE}📍 访问路径:${NC}"
echo "1. 打开浏览器访问: http://localhost:3000"
echo "2. 登录: admin/admin"
echo "3. 导航: Menu → Drilldown → Traces"
echo "4. 数据源: 选择 'Tempo'"
echo "5. 时间范围: 设置为 'Last 1 hour'"
echo ""

echo -e "${GREEN}📊 1. Span Rate 模块:${NC}"
echo "   - 显示span接收速率随时间变化"
echo "   - 可以看到$total_sent个spans的分布情况"
echo "   - 查看峰值和低谷时段"
echo ""

echo -e "${GREEN}📈 2. Breakdown 模块:${NC}"
echo "   - 服务分布: 查看frontend-web, api-gateway, user-service等服务"
echo "   - 操作分析: GET/POST/PUT/DELETE操作统计"
echo "   - 状态码分布: 200/201成功 vs 400/404/500错误"
echo "   - 响应时间: P50/P90/P95/P99延迟分析"
echo "   - 错误率: 按服务和操作类型分析"
echo ""

echo -e "${GREEN}🏗️ 3. Service Structure 模块:${NC}"
echo "   - 服务拓扑图: 显示完整的微服务调用关系"
echo "   - 依赖分析: frontend-web → api-gateway → 各业务服务"
echo "   - 调用量热力图: 识别高流量服务"
echo "   - 性能瓶颈: 找出响应最慢的服务连接"
echo ""

echo -e "${GREEN}⚖️ 4. Comparison 模块:${NC}"
echo "   - 时间对比: 比较不同时间段的性能"
echo "   - 服务对比: 对比不同服务的表现"
echo "   - 版本对比: 1.2.0 vs 1.2.1 vs 其他版本"
echo "   - 环境对比: 生产环境数据分析"
echo ""

echo -e "${GREEN}🔍 5. Traces 模块:${NC}"
echo "   - 具体追踪列表: 查看所有$total_sent个追踪"
echo "   - TraceQL查询示例:"
echo "     * {service.name=\"api-gateway\"}"
echo "     * {http.status_code>=400}"
echo "     * {duration>500ms}"
echo "     * {peer.service=\"user-service\"}"
echo ""

echo -e "${YELLOW}💡 使用技巧:${NC}"
echo "1. 在Service Structure中点击节点查看详细信息"
echo "2. 在Breakdown中按服务名或操作类型筛选"
echo "3. 在Comparison中尝试不同的时间范围对比"
echo "4. 在Traces中点击具体追踪查看完整调用链"
echo "5. 使用TraceQL精确过滤所需数据"
echo ""

echo -e "${BLUE}🔧 故障排除:${NC}"
echo "如果某个模块显示'No Data':"
echo "1. 确保时间范围设置为'Last 1 hour'或更长"
echo "2. 等待2-3分钟让数据完全处理"
echo "3. 刷新页面 (Ctrl+F5)"
echo "4. 检查数据源选择为'Tempo'"
echo "5. TraceQL查询框留空或使用简单查询"
echo ""

echo -e "${GREEN}🎉 全量数据生成完成！${NC}"
echo -e "${CYAN}开始探索Grafana Drilldown的强大功能吧！${NC}" 