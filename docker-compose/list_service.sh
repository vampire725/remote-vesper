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

echo "🔍 正在检查以下目录的容器服务:"
printf "  - %s\n" "${TARGET_DIRS[@]}"
echo ""

# 递归查找并列出服务
list_services() {
    local dir=$1
    if [ -f "$dir/docker-compose.yaml" ] || [ -f "$dir/docker-compose.yml" ]; then
        echo "📁 项目目录: $dir"

        # 获取服务列表
        services=$($COMPOSE_CMD -f "$dir/docker-compose.yaml" config --services 2>/dev/null ||
                   $COMPOSE_CMD -f "$dir/docker-compose.yml" config --services 2>/dev/null)

        if [ -z "$services" ]; then
            echo "   ⚠️  未找到服务或配置文件无效"
        else
            echo "   🐳 服务列表:"
            for service in $services; do
                # 检查容器状态
                container_id=$(docker ps -q --filter "label=com.docker.compose.project=$(basename $dir)" \
                                              --filter "name=${service}")
                if [ -n "$container_id" ]; then
                    status="(运行中 🟢)"
                else
                    status="(未运行 ⚪)"
                fi
                echo "     - ${service} ${status}"
            done
        fi
        echo ""
    else
        for subdir in "$dir"/*; do
            if [ -d "$subdir" ]; then
                list_services "$subdir"
            fi
        done
    fi
}

# 遍历所有目标目录
for target in "${TARGET_DIRS[@]}"; do
    if [ -d "$target" ]; then
        list_services "$target"
    else
        echo "⚠️  目录不存在: $target"
    fi
done

echo "✅ 服务列表检查完成"