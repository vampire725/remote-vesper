#!/bin/bash

# 定义要搜索的目录列表
TARGET_DIRS=("elk-7.17" "grafana" "prometheus" "tempo-deploy")

# 递归查找并部署docker-compose.yaml文件
deploy_compose_files() {
    local base_dir="$1"

    # 查找当前目录下的docker-compose.yaml文件
    if [ -f "$base_dir/docker-compose.yaml" ] || [ -f "$base_dir/docker-compose.yml" ]; then
        local compose_file
        if [ -f "$base_dir/docker-compose.yaml" ]; then
            compose_file="$base_dir/docker-compose.yaml"
        else
            compose_file="$base_dir/docker-compose.yml"
        fi

        echo "部署 $compose_file ..."
        (cd "$base_dir" && docker-compose -f "$(basename "$compose_file")" up -d)
    fi

    # 递归处理子目录
    for dir in "$base_dir"/*; do
        if [ -d "$dir" ]; then
            deploy_compose_files "$dir"
        fi
    done
}

# 主循环，处理所有目标目录
for dir in "${TARGET_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "处理目录: $dir"
        deploy_compose_files "$dir"
    else
        echo "警告: 目录 $dir 不存在，跳过"
    fi
done

echo "所有部署完成"