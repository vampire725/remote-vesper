#!/bin/bash

# Jaeger 链路追踪服务完全清理脚本
# 警告：此脚本将彻底删除所有相关的Docker资源

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

log_detail() {
    echo -e "${CYAN}  → ${NC}$1"
}

# 显示使用帮助
show_help() {
    cat << EOF
Jaeger 链路追踪服务完全清理脚本

⚠️  警告：此脚本将彻底删除所有相关的Docker资源，包括数据！

使用方法:
    $0 [OPTIONS]

OPTIONS:
    -h, --help          显示此帮助信息
    -f, --force         跳过确认提示，强制执行清理
    --containers-only   仅清理容器，保留镜像
    --images-only       仅清理镜像，保留容器
    --volumes-only      仅清理数据卷
    --networks-only     仅清理网络
    --dry-run           预览模式，显示将要清理的资源但不执行
    --all-unused        额外清理所有未使用的Docker资源

清理范围:
    ✓ 停止并删除相关容器
    ✓ 删除相关镜像
    ✓ 删除相关网络
    ✓ 删除相关数据卷
    ✓ 清理未使用的资源（可选）

相关资源识别标准:
    - 名称包含: jaeger, elasticsearch, otel, opentelemetry
    - 标签包含: jaeger-tracing
    - 网络: jaeger-net, jaeger-deploy_*

示例:
    $0                   # 完整清理（需要确认）
    $0 -f                # 强制完整清理
    $0 --dry-run         # 预览将要清理的资源
    $0 --containers-only # 仅清理容器
    $0 --all-unused      # 清理所有并额外清理未使用资源

EOF
}

# 显示警告信息
show_warning() {
    echo
    log_error "⚠️  警告：此操作将彻底删除以下资源 ⚠️"
    echo
    log_warning "✗ 所有 Jaeger 相关容器（包括运行中的）"
    log_warning "✗ 所有 Jaeger 相关镜像"
    log_warning "✗ 所有 Elasticsearch 数据（trace数据将永久丢失）"
    log_warning "✗ 所有相关网络和数据卷"
    echo
    log_error "此操作无法撤销！请确保你真的要执行此操作。"
    echo
}

# 检查Docker是否可用
check_docker() {
    log_info "检查Docker环境..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装或不在PATH中"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "无法连接到Docker daemon"
        exit 1
    fi
    
    log_success "Docker环境检查通过"
}

# 获取相关容器
get_related_containers() {
    docker ps -aq --filter "name=jaeger" \
                   --filter "name=elasticsearch" \
                   --filter "name=otel" \
                   --filter "name=opentelemetry" \
                   --filter "label=com.docker.compose.project=jaeger-tracing" 2>/dev/null || true
}

# 获取相关镜像
get_related_images() {
    docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" | \
    grep -E "(jaeger|elasticsearch|otel|opentelemetry)" | \
    awk '{print $2}' 2>/dev/null || true
}

# 获取相关网络
get_related_networks() {
    docker network ls --filter "name=jaeger" --format "{{.Name}}" 2>/dev/null
    docker network ls --filter "name=jaeger-deploy" --format "{{.Name}}" 2>/dev/null
}

# 获取相关数据卷
get_related_volumes() {
    docker volume ls --filter "name=elasticsearch" --format "{{.Name}}" 2>/dev/null
    docker volume ls --filter "name=jaeger" --format "{{.Name}}" 2>/dev/null
}

# 预览要清理的资源
preview_cleanup() {
    log_step "预览将要清理的资源..."
    echo
    
    # 容器
    containers=$(get_related_containers)
    if [ -n "$containers" ]; then
        log_detail "将要删除的容器:"
        for container in $containers; do
            container_info=$(docker ps -a --filter "id=$container" --format "{{.Names}} ({{.Image}}) - {{.Status}}")
            echo "    🗑️  $container_info"
        done
    else
        log_detail "没有找到相关容器"
    fi
    echo
    
    # 镜像
    images=$(get_related_images)
    if [ -n "$images" ]; then
        log_detail "将要删除的镜像:"
        for image in $images; do
            image_info=$(docker images --filter "id=$image" --format "{{.Repository}}:{{.Tag}} ({{.Size}})")
            echo "    🗑️  $image_info"
        done
    else
        log_detail "没有找到相关镜像"
    fi
    echo
    
    # 网络
    networks=$(get_related_networks)
    if [ -n "$networks" ]; then
        log_detail "将要删除的网络:"
        for network in $networks; do
            echo "    🗑️  $network"
        done
    else
        log_detail "没有找到相关网络"
    fi
    echo
    
    # 数据卷
    volumes=$(get_related_volumes)
    if [ -n "$volumes" ]; then
        log_detail "将要删除的数据卷:"
        for volume in $volumes; do
            echo "    🗑️  $volume"
        done
    else
        log_detail "没有找到相关数据卷"
    fi
    echo
}

# 停止并删除容器
cleanup_containers() {
    log_step "清理容器..."
    
    containers=$(get_related_containers)
    if [ -n "$containers" ]; then
        # 先尝试优雅停止
        log_detail "优雅停止容器..."
        echo "$containers" | xargs -r docker stop -t 10 2>/dev/null || true
        
        # 强制删除
        log_detail "删除容器..."
        echo "$containers" | xargs -r docker rm -f 2>/dev/null || true
        
        log_success "容器清理完成"
    else
        log_detail "没有找到相关容器"
    fi
}

# 删除镜像
cleanup_images() {
    log_step "清理镜像..."
    
    images=$(get_related_images)
    if [ -n "$images" ]; then
        log_detail "删除镜像..."
        echo "$images" | xargs -r docker rmi -f 2>/dev/null || true
        log_success "镜像清理完成"
    else
        log_detail "没有找到相关镜像"
    fi
}

# 删除网络
cleanup_networks() {
    log_step "清理网络..."
    
    networks=$(get_related_networks)
    if [ -n "$networks" ]; then
        log_detail "删除网络..."
        for network in $networks; do
            docker network rm "$network" 2>/dev/null || true
        done
        log_success "网络清理完成"
    else
        log_detail "没有找到相关网络"
    fi
}

# 删除数据卷
cleanup_volumes() {
    log_step "清理数据卷..."
    
    volumes=$(get_related_volumes)
    if [ -n "$volumes" ]; then
        log_detail "删除数据卷..."
        for volume in $volumes; do
            docker volume rm "$volume" 2>/dev/null || true
        done
        log_success "数据卷清理完成"
    else
        log_detail "没有找到相关数据卷"
    fi
}

# 清理所有未使用的Docker资源
cleanup_unused() {
    log_step "清理未使用的Docker资源..."
    
    log_detail "清理未使用的容器..."
    docker container prune -f 2>/dev/null || true
    
    log_detail "清理未使用的镜像..."
    docker image prune -f 2>/dev/null || true
    
    log_detail "清理未使用的网络..."
    docker network prune -f 2>/dev/null || true
    
    log_detail "清理未使用的数据卷..."
    docker volume prune -f 2>/dev/null || true
    
    log_success "未使用资源清理完成"
}

# 显示清理结果
show_cleanup_result() {
    log_step "清理结果统计..."
    echo
    
    # 检查剩余资源
    remaining_containers=$(get_related_containers)
    remaining_images=$(get_related_images)
    remaining_networks=$(get_related_networks)
    remaining_volumes=$(get_related_volumes)
    
    if [ -z "$remaining_containers" ] && [ -z "$remaining_images" ] && \
       [ -z "$remaining_networks" ] && [ -z "$remaining_volumes" ]; then
        log_success "✅ 所有相关资源已完全清理"
    else
        log_warning "⚠️ 部分资源可能未完全清理："
        [ -n "$remaining_containers" ] && log_detail "剩余容器: $(echo $remaining_containers | wc -w)个"
        [ -n "$remaining_images" ] && log_detail "剩余镜像: $(echo $remaining_images | wc -w)个"
        [ -n "$remaining_networks" ] && log_detail "剩余网络: $(echo $remaining_networks | wc -w)个"
        [ -n "$remaining_volumes" ] && log_detail "剩余数据卷: $(echo $remaining_volumes | wc -w)个"
    fi
    
    echo
    log_info "💾 释放的磁盘空间信息："
    docker system df
}

# 主函数
main() {
    local force_cleanup=false
    local dry_run=false
    local containers_only=false
    local images_only=false
    local volumes_only=false
    local networks_only=false
    local all_unused=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -f|--force)
                force_cleanup=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --containers-only)
                containers_only=true
                shift
                ;;
            --images-only)
                images_only=true
                shift
                ;;
            --volumes-only)
                volumes_only=true
                shift
                ;;
            --networks-only)
                networks_only=true
                shift
                ;;
            --all-unused)
                all_unused=true
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 检查Docker环境
    check_docker
    
    # 预览模式
    if [ "$dry_run" = true ]; then
        log_info "🔍 预览模式 - 不会执行实际清理操作"
        preview_cleanup
        exit 0
    fi
    
    # 显示警告和确认
    if [ "$force_cleanup" = false ]; then
        show_warning
        read -p "你确定要执行完全清理吗？输入 'yes' 确认: " -r
        echo
        if [[ ! $REPLY == "yes" ]]; then
            log_info "操作已取消"
            exit 0
        fi
    fi
    
    echo
    log_info "🚀 开始执行清理操作..."
    echo
    
    # 先尝试使用docker-compose清理
    if [ -f "docker-compose.yml" ]; then
        log_step "使用docker-compose清理服务..."
        docker-compose down -v --remove-orphans 2>/dev/null || true
    fi
    
    # 执行特定清理操作
    if [ "$containers_only" = true ]; then
        cleanup_containers
    elif [ "$images_only" = true ]; then
        cleanup_images
    elif [ "$volumes_only" = true ]; then
        cleanup_volumes
    elif [ "$networks_only" = true ]; then
        cleanup_networks
    else
        # 完整清理
        cleanup_containers
        cleanup_images
        cleanup_networks
        cleanup_volumes
    fi
    
    # 清理未使用资源
    if [ "$all_unused" = true ]; then
        cleanup_unused
    fi
    
    # 显示结果
    show_cleanup_result
    
    echo
    log_success "🎉 清理操作完成！"
}

# 执行主函数
main "$@" 