#!/bin/bash

# ===========================================
# Kibana 数据备份脚本
# 文件名: backup.sh
# 功能: 备份 Kibana 仪表板、数据视图、可视化等配置
# 版本: 1.0
# ===========================================

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# 配置变量
KIBANA_URL="http://localhost:5601"
KIBANA_USERNAME="elastic"
KIBANA_PASSWORD=""
BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="kibana_backup_${TIMESTAMP}"
COMPRESS=false
INCLUDE_DATA=true
CURL_OPTS=""  # SSL选项，通过--no-ssl参数设置

# 显示帮助信息
show_help() {
    cat << EOF
Kibana 数据备份脚本

用法: $0 [选项]

选项:
    -h, --help              显示此帮助信息
    -u, --username USER     Kibana 用户名 (默认: elastic)
    -p, --password PASS     Kibana 密码
    -k, --kibana-url URL    Kibana URL (默认: http://localhost:5601)
    -d, --backup-dir DIR    备份目录 (默认: ./backups)
    -n, --name NAME         备份名称 (默认: kibana_backup_TIMESTAMP)
    -c, --compress          压缩备份文件
    --no-data               不备份数据，仅备份配置
    --no-ssl                禁用 SSL 验证

备份内容:
    - 数据视图 (Data Views)
    - 仪表板 (Dashboards)
    - 可视化 (Visualizations)
    - 保存的搜索 (Saved Searches)
    - 索引模板 (Index Templates)
    - Kibana 配置 (Settings)

示例:
    $0 -p your_password
    $0 -u elastic -p password --compress
    $0 --backup-dir /backup --name my_backup

EOF
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -u|--username)
                KIBANA_USERNAME="$2"
                shift 2
                ;;
            -p|--password)
                KIBANA_PASSWORD="$2"
                shift 2
                ;;
            -k|--kibana-url)
                KIBANA_URL="$2"
                shift 2
                ;;
            -d|--backup-dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            -n|--name)
                BACKUP_NAME="$2"
                shift 2
                ;;
            -c|--compress)
                COMPRESS=true
                shift
                ;;
            --no-data)
                INCLUDE_DATA=false
                shift
                ;;
            --no-ssl)
                CURL_OPTS="-k"
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 检查必需的工具
check_dependencies() {
    log_info "检查依赖工具..."
    
    local missing_tools=()
    
    if ! command -v curl &> /dev/null; then
        missing_tools+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    if [ "$COMPRESS" = true ] && ! command -v tar &> /dev/null; then
        missing_tools+=("tar")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "缺少必需的工具: ${missing_tools[*]}"
        log_info "请安装缺少的工具："
        log_info "Ubuntu/Debian: sudo apt-get install curl jq tar"
        log_info "CentOS/RHEL: sudo yum install curl jq tar"
        log_info "macOS: brew install curl jq"
        exit 1
    fi
    
    log_success "依赖检查完成"
}

# 检查 Kibana 连接
check_kibana_connection() {
    log_info "检查 Kibana 连接..."
    
    local auth_header=""
    if [ -n "$KIBANA_PASSWORD" ]; then
        auth_header="-u $KIBANA_USERNAME:$KIBANA_PASSWORD"
    fi
    
    local response
    response=$(curl -s $CURL_OPTS $auth_header "$KIBANA_URL/api/status" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        local status
        status=$(echo "$response" | jq -r '.status.overall.state' 2>/dev/null)
        
        if [ "$status" = "green" ]; then
            log_success "Kibana 连接正常"
        else
            log_warning "Kibana 状态: $status"
        fi
    else
        log_error "无法连接到 Kibana"
        exit 1
    fi
}

# 创建备份目录
create_backup_directory() {
    local full_backup_path="$BACKUP_DIR/$BACKUP_NAME"
    
    log_info "创建备份目录: $full_backup_path"
    
    if [ -d "$full_backup_path" ]; then
        log_warning "备份目录已存在，将覆盖现有内容"
        rm -rf "$full_backup_path"
    fi
    
    mkdir -p "$full_backup_path"
    
    if [ $? -eq 0 ]; then
        log_success "备份目录创建成功"
        echo "$full_backup_path"
    else
        log_error "创建备份目录失败"
        exit 1
    fi
}

# 备份保存的对象
backup_saved_objects() {
    local backup_path=$1
    local object_type=$2
    local filename=$3
    
    log_info "备份 $object_type..."
    
    local auth_header=""
    if [ -n "$KIBANA_PASSWORD" ]; then
        auth_header="-u $KIBANA_USERNAME:$KIBANA_PASSWORD"
    fi
    
    local response
    response=$(curl -s $CURL_OPTS $auth_header \
        "$KIBANA_URL/api/saved_objects/_find?type=$object_type&per_page=10000" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        local count
        count=$(echo "$response" | jq -r '.total' 2>/dev/null)
        
        if [ "$count" != "null" ] && [ "$count" -gt 0 ]; then
            echo "$response" | jq '.' > "$backup_path/$filename"
            log_success "$object_type 备份完成 ($count 个对象)"
        else
            log_warning "未找到 $object_type 对象"
            echo '{"saved_objects":[],"total":0}' > "$backup_path/$filename"
        fi
    else
        log_error "备份 $object_type 失败"
        return 1
    fi
}

# 备份所有保存的对象
backup_all_saved_objects() {
    local backup_path=$1
    
    log_info "开始备份所有保存的对象..."
    
    # 备份各种类型的对象
    backup_saved_objects "$backup_path" "index-pattern" "data_views.json"
    backup_saved_objects "$backup_path" "dashboard" "dashboards.json"
    backup_saved_objects "$backup_path" "visualization" "visualizations.json"
    backup_saved_objects "$backup_path" "search" "saved_searches.json"
    backup_saved_objects "$backup_path" "lens" "lens_visualizations.json"
    backup_saved_objects "$backup_path" "map" "maps.json"
    backup_saved_objects "$backup_path" "canvas-workpad" "canvas_workpads.json"
    backup_saved_objects "$backup_path" "config" "kibana_config.json"
    
    log_success "保存的对象备份完成"
}

# 导出所有保存的对象（使用导出 API）
export_all_objects() {
    local backup_path=$1
    
    log_info "使用导出 API 备份所有对象..."
    
    local auth_header=""
    if [ -n "$KIBANA_PASSWORD" ]; then
        auth_header="-u $KIBANA_USERNAME:$KIBANA_PASSWORD"
    fi
    
    # 导出所有对象
    local export_payload='{"type":"*","includeReferencesDeep":true}'
    
    local response
    response=$(curl -s $CURL_OPTS $auth_header \
        -X POST \
        -H "Content-Type: application/json" \
        -H "kbn-xsrf: true" \
        -d "$export_payload" \
        "$KIBANA_URL/api/saved_objects/_export" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "$response" > "$backup_path/kibana_export.ndjson"
        
        # 统计导出的对象数量
        local count
        count=$(echo "$response" | wc -l)
        log_success "导出完成 ($count 行数据)"
    else
        log_error "导出失败"
        return 1
    fi
}

# 备份 Kibana 设置
backup_kibana_settings() {
    local backup_path=$1
    
    log_info "备份 Kibana 设置..."
    
    local auth_header=""
    if [ -n "$KIBANA_PASSWORD" ]; then
        auth_header="-u $KIBANA_USERNAME:$KIBANA_PASSWORD"
    fi
    
    local response
    response=$(curl -s $CURL_OPTS $auth_header \
        "$KIBANA_URL/api/kibana/settings" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "$response" | jq '.' > "$backup_path/kibana_settings.json"
        log_success "Kibana 设置备份完成"
    else
        log_warning "备份 Kibana 设置失败"
    fi
}

# 创建备份元数据
create_backup_metadata() {
    local backup_path=$1
    
    log_info "创建备份元数据..."
    
    local metadata
    metadata=$(cat << EOF
{
  "backup_info": {
    "timestamp": "$TIMESTAMP",
    "backup_name": "$BACKUP_NAME",
    "kibana_url": "$KIBANA_URL",
    "backup_version": "1.0",
    "created_by": "$(whoami)",
    "hostname": "$(hostname)",
    "include_data": $INCLUDE_DATA
  },
  "kibana_info": {
    "version": "$(curl -s $CURL_OPTS "$KIBANA_URL/api/status" | jq -r '.version.number' 2>/dev/null || echo 'unknown')",
    "build_number": "$(curl -s $CURL_OPTS "$KIBANA_URL/api/status" | jq -r '.version.build_number' 2>/dev/null || echo 'unknown')"
  }
}
EOF
)
    
    echo "$metadata" | jq '.' > "$backup_path/backup_metadata.json"
    log_success "备份元数据创建完成"
}

# 压缩备份
compress_backup() {
    local backup_path=$1
    local backup_dir=$(dirname "$backup_path")
    local backup_name=$(basename "$backup_path")
    
    log_info "压缩备份文件..."
    
    cd "$backup_dir"
    tar -czf "${backup_name}.tar.gz" "$backup_name"
    
    if [ $? -eq 0 ]; then
        rm -rf "$backup_name"
        log_success "备份压缩完成: ${backup_name}.tar.gz"
        echo "${backup_dir}/${backup_name}.tar.gz"
    else
        log_error "备份压缩失败"
        return 1
    fi
}

# 显示备份摘要
show_backup_summary() {
    local backup_path=$1
    
    log_info "备份摘要:"
    echo "  备份名称: $BACKUP_NAME"
    echo "  备份时间: $TIMESTAMP"
    echo "  备份路径: $backup_path"
    echo "  Kibana URL: $KIBANA_URL"
    
    if [ -f "$backup_path/backup_metadata.json" ]; then
        local kibana_version
        kibana_version=$(jq -r '.kibana_info.version' "$backup_path/backup_metadata.json" 2>/dev/null)
        echo "  Kibana 版本: $kibana_version"
    fi
    
    # 统计备份文件
    if [ -d "$backup_path" ]; then
        local file_count
        file_count=$(find "$backup_path" -type f | wc -l)
        echo "  备份文件数: $file_count"
        
        local total_size
        total_size=$(du -sh "$backup_path" | cut -f1)
        echo "  备份大小: $total_size"
    fi
    
    echo ""
}

# 主函数
main() {
    echo "========================================"
    echo "         Kibana 数据备份脚本"
    echo "========================================"
    echo ""
    
    # 解析参数
    parse_args "$@"
    
    # 检查依赖
    check_dependencies
    
    # 检查 Kibana 连接
    check_kibana_connection
    
    # 创建备份目录
    local backup_path
    backup_path=$(create_backup_directory)
    
    # 创建备份元数据
    create_backup_metadata "$backup_path"
    
    # 备份 Kibana 设置
    backup_kibana_settings "$backup_path"
    
    # 备份保存的对象
    if [ "$INCLUDE_DATA" = true ]; then
        backup_all_saved_objects "$backup_path"
        export_all_objects "$backup_path"
    else
        log_info "跳过数据备份（仅备份配置）"
    fi
    
    # 压缩备份（如果指定）
    if [ "$COMPRESS" = true ]; then
        backup_path=$(compress_backup "$backup_path")
    fi
    
    # 显示备份摘要
    show_backup_summary "$backup_path"
    
    log_success "备份完成！"
    log_info "备份位置: $backup_path"
    
    echo ""
    echo "恢复备份请使用 Kibana 的导入功能："
    echo "  1. 访问 Kibana: $KIBANA_URL"
    echo "  2. 进入 Stack Management > Saved Objects"
    echo "  3. 点击 Import 导入 kibana_export.ndjson 文件"
    echo ""
    echo "========================================"
}

# 执行主函数
main "$@" 