#!/bin/bash

# 测试数据生成脚本
# 向Jaeger/OpenTelemetry系统发送模拟的trace数据

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# 配置
OTLP_ENDPOINT="${OTLP_ENDPOINT:-http://localhost:4316}"
JAEGER_ENDPOINT="${JAEGER_ENDPOINT:-http://localhost:4318}"
SERVICE_NAME="${SERVICE_NAME:-test-service}"
TENANT_ID="${TENANT_ID:-123456}"
DATA_COUNT="${DATA_COUNT:-5}"

# 显示帮助信息
show_help() {
    cat << EOF
测试数据生成脚本

使用方法:
    $0 [OPTIONS]

OPTIONS:
    -h, --help              显示此帮助信息
    -e, --endpoint URL      指定OTLP端点 (默认: http://localhost:4316)
    -j, --jaeger URL        指定Jaeger端点 (默认: http://localhost:4318)
    -s, --service NAME      指定服务名称 (默认: test-service)
    -c, --count NUMBER      生成数据数量 (默认: 5)
    -t, --tenant ID         租户ID (默认: 123456)
    --use-jaeger            使用Jaeger端点而非OTLP端点
    --simple                生成简单的测试数据
    --complex               生成复杂的调用链数据
    --error                 生成包含错误的数据
    --all                   生成所有类型的数据

环境变量:
    OTLP_ENDPOINT          OTLP端点地址
    JAEGER_ENDPOINT        Jaeger端点地址
    SERVICE_NAME           服务名称
    TENANT_ID              租户ID
    DATA_COUNT             数据数量

示例:
    $0                      # 生成默认测试数据
    $0 --simple -c 10       # 生成10条简单数据
    $0 --complex            # 生成复杂调用链
    $0 --error              # 生成错误数据
    $0 --all -c 3           # 生成所有类型数据各3条

EOF
}

# 检查依赖
check_dependencies() {
    log_info "检查依赖..."
    
    if ! command -v curl &> /dev/null; then
        log_error "curl 未安装或不在PATH中"
        exit 1
    fi
    
    if ! command -v date &> /dev/null; then
        log_error "date 命令不可用"
        exit 1
    fi
    
    log_success "依赖检查通过"
}

# 检查服务可用性
check_service() {
    local endpoint=$1
    log_info "检查服务可用性: $endpoint"
    
    if curl -s --max-time 5 "$endpoint" > /dev/null 2>&1; then
        log_success "服务可用: $endpoint"
        return 0
    else
        log_warning "服务不可用: $endpoint"
        return 1
    fi
}

# 生成随机ID
generate_trace_id() {
    printf "%016x%016x" $((RANDOM * RANDOM)) $((RANDOM * RANDOM))
}

generate_span_id() {
    printf "%016x" $((RANDOM * RANDOM))
}

# 获取当前时间戳（纳秒）
get_timestamp_nano() {
    echo $(date +%s)000000000
}

# 生成简单的span数据
generate_simple_span() {
    local trace_id="$1"
    local span_id="$2"
    local parent_id="$3"
    local service_name="$4"
    local operation_name="$5"
    local start_time="$6"
    local duration_ms="${7:-100}"
    
    local end_time=$((start_time + duration_ms * 1000000))
    
    cat << EOF
{
  "resourceSpans": [
    {
      "resource": {
        "attributes": [
          {
            "key": "service.name",
            "value": {"stringValue": "$service_name"}
          },
          {
            "key": "tenant_id", 
            "value": {"stringValue": "$TENANT_ID"}
          },
          {
            "key": "deployment.environment",
            "value": {"stringValue": "test"}
          }
        ]
      },
      "scopeSpans": [
        {
          "scope": {
            "name": "test-instrumentation"
          },
          "spans": [
            {
              "traceId": "$trace_id",
              "spanId": "$span_id",
              $([ -n "$parent_id" ] && echo "\"parentSpanId\": \"$parent_id\",")
              "name": "$operation_name",
              "kind": "SPAN_KIND_SERVER",
              "startTimeUnixNano": "$start_time",
              "endTimeUnixNano": "$end_time",
              "attributes": [
                {
                  "key": "http.method",
                  "value": {"stringValue": "GET"}
                },
                {
                  "key": "http.url",
                  "value": {"stringValue": "http://localhost:8080/$operation_name"}
                },
                {
                  "key": "http.status_code",
                  "value": {"intValue": "200"}
                }
              ],
              "status": {
                "code": "STATUS_CODE_OK"
              }
            }
          ]
        }
      ]
    }
  ]
}
EOF
}

# 生成错误span数据
generate_error_span() {
    local trace_id="$1"
    local span_id="$2"
    local parent_id="$3"
    local service_name="$4"
    local operation_name="$5"
    local start_time="$6"
    local duration_ms="${7:-150}"
    
    local end_time=$((start_time + duration_ms * 1000000))
    
    cat << EOF
{
  "resourceSpans": [
    {
      "resource": {
        "attributes": [
          {
            "key": "service.name",
            "value": {"stringValue": "$service_name"}
          },
          {
            "key": "tenant_id",
            "value": {"stringValue": "$TENANT_ID"}
          },
          {
            "key": "deployment.environment",
            "value": {"stringValue": "test"}
          }
        ]
      },
      "scopeSpans": [
        {
          "scope": {
            "name": "test-instrumentation"
          },
          "spans": [
            {
              "traceId": "$trace_id",
              "spanId": "$span_id",
              $([ -n "$parent_id" ] && echo "\"parentSpanId\": \"$parent_id\",")
              "name": "$operation_name",
              "kind": "SPAN_KIND_SERVER",
              "startTimeUnixNano": "$start_time",
              "endTimeUnixNano": "$end_time",
              "attributes": [
                {
                  "key": "http.method",
                  "value": {"stringValue": "POST"}
                },
                {
                  "key": "http.url",
                  "value": {"stringValue": "http://localhost:8080/$operation_name"}
                },
                {
                  "key": "http.status_code",
                  "value": {"intValue": "500"}
                },
                {
                  "key": "error",
                  "value": {"stringValue": "true"}
                }
              ],
              "events": [
                {
                  "timeUnixNano": "$((start_time + 50000000))",
                  "name": "exception",
                  "attributes": [
                    {
                      "key": "exception.type",
                      "value": {"stringValue": "RuntimeException"}
                    },
                    {
                      "key": "exception.message",
                      "value": {"stringValue": "模拟的服务错误"}
                    }
                  ]
                }
              ],
              "status": {
                "code": "STATUS_CODE_ERROR",
                "message": "Internal Server Error"
              }
            }
          ]
        }
      ]
    }
  ]
}
EOF
}

# 发送数据到端点
send_data() {
    local endpoint="$1"
    local data="$2"
    local description="$3"
    
    log_info "发送数据: $description"
    
    local response=$(curl -s -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "$data" \
        "$endpoint/v1/traces" 2>/dev/null)
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
        log_success "✅ 发送成功: $description (HTTP $http_code)"
        return 0
    else
        log_error "❌ 发送失败: $description (HTTP $http_code)"
        [ -n "$body" ] && echo "响应: $body"
        return 1
    fi
}

# 生成简单测试数据
generate_simple_data() {
    local count="$1"
    log_step "生成简单测试数据 ($count 条)..."
    
    for i in $(seq 1 $count); do
        local trace_id=$(generate_trace_id)
        local span_id=$(generate_span_id)
        local start_time=$(get_timestamp_nano)
        local operation="simple-operation-$i"
        
        local data=$(generate_simple_span "$trace_id" "$span_id" "" "$SERVICE_NAME" "$operation" "$start_time")
        send_data "$ENDPOINT" "$data" "简单操作 $i"
        
        sleep 0.1
    done
}

# 生成复杂调用链数据
generate_complex_data() {
    local count="$1"
    log_step "生成复杂调用链数据 ($count 条)..."
    
    for i in $(seq 1 $count); do
        local trace_id=$(generate_trace_id)
        local start_time=$(get_timestamp_nano)
        
        # 根span
        local root_span_id=$(generate_span_id)
        local root_data=$(generate_simple_span "$trace_id" "$root_span_id" "" "api-gateway" "handle-request-$i" "$start_time" 200)
        send_data "$ENDPOINT" "$root_data" "复杂调用链 $i - 根span"
        
        sleep 0.05
        
        # 子span - 用户服务
        local user_span_id=$(generate_span_id)
        local user_start=$((start_time + 10000000))
        local user_data=$(generate_simple_span "$trace_id" "$user_span_id" "$root_span_id" "user-service" "get-user-info" "$user_start" 50)
        send_data "$ENDPOINT" "$user_data" "复杂调用链 $i - 用户服务"
        
        sleep 0.05
        
        # 子span - 订单服务
        local order_span_id=$(generate_span_id)
        local order_start=$((start_time + 80000000))
        local order_data=$(generate_simple_span "$trace_id" "$order_span_id" "$root_span_id" "order-service" "create-order" "$order_start" 120)
        send_data "$ENDPOINT" "$order_data" "复杂调用链 $i - 订单服务"
        
        sleep 0.05
        
        # 子span - 数据库
        local db_span_id=$(generate_span_id)
        local db_start=$((start_time + 100000000))
        local db_data=$(generate_simple_span "$trace_id" "$db_span_id" "$order_span_id" "database" "insert-order" "$db_start" 30)
        send_data "$ENDPOINT" "$db_data" "复杂调用链 $i - 数据库"
        
        sleep 0.2
    done
}

# 生成错误数据
generate_error_data() {
    local count="$1"
    log_step "生成错误数据 ($count 条)..."
    
    for i in $(seq 1 $count); do
        local trace_id=$(generate_trace_id)
        local span_id=$(generate_span_id)
        local start_time=$(get_timestamp_nano)
        local operation="error-operation-$i"
        
        local data=$(generate_error_span "$trace_id" "$span_id" "" "$SERVICE_NAME" "$operation" "$start_time")
        send_data "$ENDPOINT" "$data" "错误操作 $i"
        
        sleep 0.1
    done
}

# 生成数据库查询数据
generate_db_data() {
    local count="$1"
    log_step "生成数据库查询数据 ($count 条)..."
    
    local operations=("SELECT users" "INSERT order" "UPDATE inventory" "DELETE cache")
    
    for i in $(seq 1 $count); do
        local trace_id=$(generate_trace_id)
        local span_id=$(generate_span_id)
        local start_time=$(get_timestamp_nano)
        local operation="${operations[$((i % 4))]}"
        
        local data=$(generate_simple_span "$trace_id" "$span_id" "" "database-service" "$operation" "$start_time" $((30 + RANDOM % 100)))
        send_data "$ENDPOINT" "$data" "数据库操作: $operation"
        
        sleep 0.1
    done
}

# 主函数
main() {
    local use_jaeger=false
    local simple=false
    local complex=false
    local error=false
    local all=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -e|--endpoint)
                OTLP_ENDPOINT="$2"
                shift 2
                ;;
            -j|--jaeger)
                JAEGER_ENDPOINT="$2"
                shift 2
                ;;
            -s|--service)
                SERVICE_NAME="$2"
                shift 2
                ;;
            -c|--count)
                DATA_COUNT="$2"
                shift 2
                ;;
            -t|--tenant)
                TENANT_ID="$2"
                shift 2
                ;;
            --use-jaeger)
                use_jaeger=true
                shift
                ;;
            --simple)
                simple=true
                shift
                ;;
            --complex)
                complex=true
                shift
                ;;
            --error)
                error=true
                shift
                ;;
            --all)
                all=true
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 选择端点
    if [ "$use_jaeger" = true ]; then
        ENDPOINT="$JAEGER_ENDPOINT"
        log_info "使用Jaeger端点: $ENDPOINT"
    else
        ENDPOINT="$OTLP_ENDPOINT"
        log_info "使用OTLP端点: $ENDPOINT"
    fi
    
    # 检查依赖和服务
    check_dependencies
    
    if ! check_service "$ENDPOINT"; then
        log_error "目标服务不可用，请确保Jaeger/OTLP服务正在运行"
        exit 1
    fi
    
    echo
    log_info "🚀 开始生成测试数据..."
    log_info "📍 目标端点: $ENDPOINT"
    log_info "🏷️  服务名称: $SERVICE_NAME"
    log_info "🆔 租户ID: $TENANT_ID"
    log_info "📊 数据数量: $DATA_COUNT"
    echo
    
    # 生成数据
    if [ "$all" = true ]; then
        generate_simple_data "$DATA_COUNT"
        generate_complex_data "$DATA_COUNT"
        generate_error_data "$DATA_COUNT"
        generate_db_data "$DATA_COUNT"
    elif [ "$simple" = true ]; then
        generate_simple_data "$DATA_COUNT"
    elif [ "$complex" = true ]; then
        generate_complex_data "$DATA_COUNT"
    elif [ "$error" = true ]; then
        generate_error_data "$DATA_COUNT"
    else
        # 默认生成混合数据
        generate_simple_data $((DATA_COUNT / 2))
        generate_complex_data "1"
        generate_error_data "1"
    fi
    
    echo
    log_success "🎉 测试数据生成完成！"
    echo
    log_info "📋 下一步:"
    log_info "1. 访问 Jaeger UI: http://localhost:16686"
    log_info "2. 搜索服务: $SERVICE_NAME"
    log_info "3. 查看生成的trace数据"
    echo
}

# 执行主函数
main "$@" 