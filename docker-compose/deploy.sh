#!/bin/bash

# 定义目标目录数组
TARGET_DIRS=("es/simple" "kibana/kibana-no-auth" "logstash/simple" "kafka/simple" "vector" "grafana" "prometheus" "otel-collector" "tempo")

# 递归部署函数
deploy() {
    local dir=$1
    if [ -f "$dir/docker-compose.yaml" ]; then
        echo "🟢 部署服务: $dir"
        (cd "$dir" && docker compose up -d)
    else
        for subdir in "$dir"/*; do
            if [ -d "$subdir" ]; then
                deploy "$subdir"
            fi
        done
    fi
}

# 创建Docker网络（幂等操作）
networks=("monitoring-network" "tracing-network" "logging-network" "kafka" "nacos")
for network in "${networks[@]}"; do
    if docker network inspect "$network" &>/dev/null; then
        echo "网络已存在: $network"
    else
        docker network create "$network"
        echo "已创建网络: $network"
    fi
done

# 遍历所有目标目录
for target in "${TARGET_DIRS[@]}"; do
    if [ -d "$target" ]; then
        deploy "$target"
    else
        echo "⚠️  目录不存在: $target"
    fi
done

echo "✅ 所有服务部署完成"