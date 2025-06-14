#!/bin/bash

# OpenTelemetry 测试数据发送脚本
echo "=========================================="
echo "  OpenTelemetry 测试数据发送"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查 OTel Collector 是否可用
echo -e "${BLUE}🔍 检查 OpenTelemetry Collector 状态...${NC}"
if ! curl -s --connect-timeout 5 --max-time 10 "http://localhost:13133/" > /dev/null; then
    echo -e "${RED}❌ OTel Collector 不可用，请先启动系统${NC}"
    echo "运行: ./start-all.sh 或 ./start-existing.sh"
    exit 1
fi
echo -e "${GREEN}✅ OTel Collector 正常运行${NC}"
echo ""

# 生成当前时间戳
current_time_ns=$(date +%s%N)
trace_id="5B8EFFF798038103D269B633813FC60C"

echo -e "${BLUE}🚀 开始发送测试追踪数据...${NC}"
echo "追踪ID: $trace_id"
echo ""

# 1. 发送前端服务数据 (API Gateway)
echo -e "${BLUE}📤 发送前端服务追踪数据...${NC}"
frontend_response=$(curl -s -w "%{http_code}" -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d "{
    \"resourceSpans\": [{
      \"resource\": {
        \"attributes\": [{
          \"key\": \"service.name\",
          \"value\": {\"stringValue\": \"frontend-api\"}
        }, {
          \"key\": \"service.version\",
          \"value\": {\"stringValue\": \"1.0.0\"}
        }, {
          \"key\": \"deployment.environment\",
          \"value\": {\"stringValue\": \"demo\"}
        }]
      },
      \"instrumentationLibrarySpans\": [{
        \"instrumentationLibrary\": {
          \"name\": \"demo-instrumentation\",
          \"version\": \"1.0.0\"
        },
        \"spans\": [{
          \"traceId\": \"$trace_id\",
          \"spanId\": \"EEE19B7EC3C1B174\",
          \"name\": \"GET /api/users\",
          \"kind\": 2,
          \"startTimeUnixNano\": \"$current_time_ns\",
          \"endTimeUnixNano\": \"$((current_time_ns + 800000000))\",
          \"attributes\": [{
            \"key\": \"http.method\",
            \"value\": {\"stringValue\": \"GET\"}
          }, {
            \"key\": \"http.url\",
            \"value\": {\"stringValue\": \"http://frontend-api/api/users\"}
          }, {
            \"key\": \"http.status_code\",
            \"value\": {\"intValue\": 200}
          }, {
            \"key\": \"server.address\",
            \"value\": {\"stringValue\": \"user-service\"}
          }, {
            \"key\": \"user.id\",
            \"value\": {\"stringValue\": \"user123\"}
          }],
          \"status\": {\"code\": 1}
        }]
      }]
    }]
  }")

http_code="${frontend_response: -3}"
if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}   ✅ 前端服务数据发送成功${NC}"
else
    echo -e "${RED}   ❌ 前端服务数据发送失败 (HTTP $http_code)${NC}"
fi

sleep 1

# 2. 发送用户服务数据
echo -e "${BLUE}📤 发送用户服务追踪数据...${NC}"
user_service_response=$(curl -s -w "%{http_code}" -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d "{
    \"resourceSpans\": [{
      \"resource\": {
        \"attributes\": [{
          \"key\": \"service.name\",
          \"value\": {\"stringValue\": \"user-service\"}
        }, {
          \"key\": \"service.version\",
          \"value\": {\"stringValue\": \"2.1.0\"}
        }, {
          \"key\": \"deployment.environment\",
          \"value\": {\"stringValue\": \"demo\"}
        }]
      },
      \"instrumentationLibrarySpans\": [{
        \"instrumentationLibrary\": {
          \"name\": \"demo-instrumentation\",
          \"version\": \"1.0.0\"
        },
        \"spans\": [{
          \"traceId\": \"$trace_id\",
          \"spanId\": \"ABC19B7EC3C1B175\",
          \"parentSpanId\": \"EEE19B7EC3C1B174\",
          \"name\": \"get_user_profile\",
          \"kind\": 3,
          \"startTimeUnixNano\": \"$((current_time_ns + 100000000))\",
          \"endTimeUnixNano\": \"$((current_time_ns + 600000000))\",
          \"attributes\": [{
            \"key\": \"user.id\",
            \"value\": {\"stringValue\": \"user123\"}
          }, {
            \"key\": \"db.operation\",
            \"value\": {\"stringValue\": \"SELECT\"}
          }, {
            \"key\": \"server.address\",
            \"value\": {\"stringValue\": \"database\"}
          }],
          \"status\": {\"code\": 1}
        }]
      }]
    }]
  }")

http_code="${user_service_response: -3}"
if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}   ✅ 用户服务数据发送成功${NC}"
else
    echo -e "${RED}   ❌ 用户服务数据发送失败 (HTTP $http_code)${NC}"
fi

sleep 1

# 3. 发送数据库服务数据
echo -e "${BLUE}📤 发送数据库服务追踪数据...${NC}"
database_response=$(curl -s -w "%{http_code}" -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d "{
    \"resourceSpans\": [{
      \"resource\": {
        \"attributes\": [{
          \"key\": \"service.name\",
          \"value\": {\"stringValue\": \"database\"}
        }, {
          \"key\": \"service.version\",
          \"value\": {\"stringValue\": \"5.7.0\"}
        }, {
          \"key\": \"deployment.environment\",
          \"value\": {\"stringValue\": \"demo\"}
        }]
      },
      \"instrumentationLibrarySpans\": [{
        \"instrumentationLibrary\": {
          \"name\": \"demo-instrumentation\",
          \"version\": \"1.0.0\"
        },
        \"spans\": [{
          \"traceId\": \"$trace_id\",
          \"spanId\": \"DEF19B7EC3C1B176\",
          \"parentSpanId\": \"ABC19B7EC3C1B175\",
          \"name\": \"SELECT users WHERE id = ?\",
          \"kind\": 1,
          \"startTimeUnixNano\": \"$((current_time_ns + 200000000))\",
          \"endTimeUnixNano\": \"$((current_time_ns + 500000000))\",
          \"attributes\": [{
            \"key\": \"db.system\",
            \"value\": {\"stringValue\": \"mysql\"}
          }, {
            \"key\": \"db.name\",
            \"value\": {\"stringValue\": \"users_db\"}
          }, {
            \"key\": \"db.statement\",
            \"value\": {\"stringValue\": \"SELECT * FROM users WHERE id = 'user123'\"}
          }, {
            \"key\": \"db.rows_affected\",
            \"value\": {\"intValue\": 1}
          }],
          \"status\": {\"code\": 1}
        }]
      }]
    }]
  }")

http_code="${database_response: -3}"
if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}   ✅ 数据库服务数据发送成功${NC}"
else
    echo -e "${RED}   ❌ 数据库服务数据发送失败 (HTTP $http_code)${NC}"
fi

sleep 1

# 4. 发送一个带错误的追踪
echo -e "${BLUE}📤 发送错误追踪数据 (用于演示错误处理)...${NC}"
error_trace_id="5B8EFFF798038103D269B633813FC60D"
error_response=$(curl -s -w "%{http_code}" -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d "{
    \"resourceSpans\": [{
      \"resource\": {
        \"attributes\": [{
          \"key\": \"service.name\",
          \"value\": {\"stringValue\": \"payment-service\"}
        }, {
          \"key\": \"service.version\",
          \"value\": {\"stringValue\": \"1.5.0\"}
        }]
      },
      \"instrumentationLibrarySpans\": [{
        \"spans\": [{
          \"traceId\": \"$error_trace_id\",
          \"spanId\": \"ERR19B7EC3C1B177\",
          \"name\": \"process_payment\",
          \"kind\": 1,
          \"startTimeUnixNano\": \"$((current_time_ns + 1000000000))\",
          \"endTimeUnixNano\": \"$((current_time_ns + 1500000000))\",
          \"attributes\": [{
            \"key\": \"payment.amount\",
            \"value\": {\"doubleValue\": 99.99}
          }, {
            \"key\": \"payment.currency\",
            \"value\": {\"stringValue\": \"USD\"}
          }, {
            \"key\": \"error.type\",
            \"value\": {\"stringValue\": \"InsufficientFundsError\"}
          }],
          \"status\": {
            \"code\": 2,
            \"message\": \"Insufficient funds in account\"
          }
        }]
      }]
    }]
  }")

http_code="${error_response: -3}"
if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}   ✅ 错误追踪数据发送成功${NC}"
else
    echo -e "${RED}   ❌ 错误追踪数据发送失败 (HTTP $http_code)${NC}"
fi

echo ""
echo -e "${GREEN}🎉 测试数据发送完成！${NC}"
echo ""

# 5. 等待数据处理
echo -e "${BLUE}⏳ 等待数据处理和服务图生成 (2分钟)...${NC}"
echo "在此期间，系统正在:"
echo "  1. 处理追踪数据"
echo "  2. 生成服务图指标"
echo "  3. 将指标推送到 Prometheus"
echo ""

# 显示进度条
for i in {1..24}; do
    echo -n "▓"
    sleep 5
done
echo ""
echo ""

# 6. 验证数据
echo -e "${BLUE}🔍 验证数据接收情况...${NC}"

# 检查 Tempo 指标
echo "检查 Tempo 服务图指标..."
tempo_metrics=$(curl -s "http://localhost:3200/metrics" | grep "traces_service_graph_request_total" | head -3)
if [ -n "$tempo_metrics" ]; then
    echo -e "${GREEN}   ✅ Tempo 已生成服务图指标${NC}"
    echo "$tempo_metrics" | sed 's/^/     /'
else
    echo -e "${YELLOW}   ⚠ Tempo 服务图指标暂未生成${NC}"
fi

echo ""

# 检查 Prometheus 指标
echo "检查 Prometheus 中的服务图数据..."
prom_query="traces_service_graph_request_total"
prom_response=$(curl -s "http://localhost:9090/api/v1/query?query=$prom_query")
result_count=$(echo "$prom_response" | jq -r '.data.result | length' 2>/dev/null || echo "0")

if [ "$result_count" -gt 0 ]; then
    echo -e "${GREEN}   ✅ Prometheus 中发现 $result_count 个服务图指标${NC}"
else
    echo -e "${YELLOW}   ⚠ Prometheus 中暂无服务图数据，请稍等片刻${NC}"
fi

echo ""

# 7. 显示查看指导
echo "=========================================="
echo -e "${GREEN}📋 数据查看指南${NC}"
echo "=========================================="
echo ""
echo -e "${BLUE}🔍 在 Grafana 中查看数据:${NC}"
echo "1. 访问: http://localhost:3000"
echo "2. 登录: admin / admin"
echo "3. 进入 Explore 页面"
echo "4. 选择 Tempo 数据源"
echo ""
echo -e "${BLUE}📊 查看服务图:${NC}"
echo "1. 在 Tempo 数据源中点击 'Service Map' 标签"
echo "2. 等待服务图加载 (可能需要1-2分钟)"
echo "3. 应该能看到 frontend-api → user-service → database 的调用关系"
echo ""
echo -e "${BLUE}🔎 查看具体追踪:${NC}"
echo "使用 TraceQL 查询:"
echo "  {service.name=\"frontend-api\"}     # 查看前端服务追踪"
echo "  {service.name=\"user-service\"}    # 查看用户服务追踪"
echo "  {status=error}                     # 查看错误追踪"
echo "  {duration > 500ms}                 # 查看慢请求"
echo ""
echo -e "${BLUE}📈 查看指标:${NC}"
echo "1. 访问 Prometheus: http://localhost:9090"
echo "2. 查询服务图指标: traces_service_graph_request_total"
echo "3. 查看 OTel Collector 指标: otelcol_receiver_accepted_spans_total"
echo ""
echo -e "${YELLOW}🔧 故障排除:${NC}"
echo "如果看不到数据:"
echo "1. 运行: ./check-service-graph.sh"
echo "2. 检查日志: ./logs.sh"
echo "3. 重新发送数据: ./send-test-data.sh"
echo ""
echo -e "${GREEN}✨ 测试数据发送和验证完成！${NC}" 