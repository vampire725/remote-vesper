#!/bin/bash

# 定义目标目录数组
TARGET_DIRS=("es/simple" "kibana/kibana-no-auth" "logstash/simple" "kafka/simple" "vector" "grafana" "prometheus" "otel-collector" "tempo")

# 检测使用哪个compose命令
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    echo "❌ 错误：未找到 docker compose 或 docker-compose 命令"
    exit 1
fi

echo "🔍 使用 compose 命令: $COMPOSE_CMD"

# 递归清理函数
cleanup() {
    local dir=$1
    if [ -f "$dir/docker-compose.yaml" ]; then
        echo "🟠 清理服务: $dir"
        (cd "$dir" && $COMPOSE_CMD down --volumes --remove-orphans)
    else
        for subdir in "$dir"/*; do
            if [ -d "$subdir" ]; then
                cleanup "$subdir"
            fi
        done
    fi
}

# 遍历所有目标目录
for target in "${TARGET_DIRS[@]}"; do
    if [ -d "$target" ]; then
        cleanup "$target"
    else
        echo "⚠️  目录不存在: $target"
    fi
done

echo "✅ 所有服务清理完成"