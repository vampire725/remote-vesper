#!/bin/bash

# ===========================================
# Kibana 管理脚本
# 功能: 管理 Kibana 认证版本和无认证版本
# 版本: 1.0.0
# ===========================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 打印彩色信息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_title() {
    echo -e "${CYAN}$1${NC}"
}

# 显示帮助信息
show_help() {
    print_title "=== Kibana 管理脚本 ==="
    echo ""
    echo "用法: $0 [命令] [版本]"
    echo ""
    echo "命令:"
    echo "  start    - 启动 Kibana 服务"
    echo "  stop     - 停止 Kibana 服务"
    echo "  restart  - 重启 Kibana 服务"
    echo "  status   - 查看服务状态"
    echo "  logs     - 查看服务日志"
    echo "  clean    - 清理服务和数据"
    echo "  info     - 显示服务信息"
    echo ""
    echo "版本:"
    echo "  auth     - 认证版本 (生产环境)"
    echo "  no-auth  - 无认证版本 (开发环境)"
    echo "  both     - 两个版本 (仅适用于某些命令)"
    echo ""
    echo "示例:"
    echo "  $0 start auth      # 启动认证版本"
    echo "  $0 start no-auth   # 启动无认证版本"
    echo "  $0 stop both       # 停止所有版本"
    echo "  $0 status both     # 查看所有版本状态"
    echo ""
}

# 检查版本参数
check_version() {
    case $1 in
        auth|no-auth|both)
            return 0
            ;;
        *)
            print_error "无效的版本参数: $1"
            print_info "支持的版本: auth, no-auth, both"
            exit 1
            ;;
    esac
}

# 执行命令
execute_command() {
    local cmd=$1
    local version=$2
    local dir=""
    
    case $version in
        auth)
            dir="kibana-auth"
            ;;
        no-auth)
            dir="kibana-no-auth"
            ;;
    esac
    
    print_info "执行 $cmd 命令于 $version 版本..."
    cd $dir
    
    case $cmd in
        start)
            docker-compose up -d
            ;;
        stop)
            docker-compose down
            ;;
        restart)
            docker-compose restart
            ;;
        status)
            docker-compose ps
            ;;
        logs)
            docker-compose logs -f kibana
            ;;
        clean)
            print_warning "这将删除所有数据，是否继续？(y/N)"
            read -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                docker-compose down -v
                print_success "清理完成"
            else
                print_info "取消清理"
            fi
            ;;
    esac
    
    cd ..
}

# 显示服务信息
show_info() {
    local version=$1
    
    case $version in
        auth)
            print_title "=== Kibana 认证版本信息 ==="
            echo "📁 目录: kibana-auth/"
            echo "🌐 端口: 5601"
            echo "🔒 安全: 启用认证"
            echo "📋 用户: elastic"
            echo "🔑 密码: your_elastic_password"
            echo "🌍 访问: http://localhost:5601"
            echo "🎯 用途: 生产环境"
            ;;
        no-auth)
            print_title "=== Kibana 无认证版本信息 ==="
            echo "📁 目录: kibana-no-auth/"
            echo "🌐 端口: 5602"
            echo "🔓 安全: 禁用认证"
            echo "👤 登录: 无需登录"
            echo "🌍 访问: http://localhost:5602"
            echo "🎯 用途: 开发/测试环境"
            print_warning "⚠️  请勿在生产环境使用"
            ;;
        both)
            show_info auth
            echo ""
            show_info no-auth
            ;;
    esac
    echo ""
}

# 检查服务状态
check_status() {
    local version=$1
    
    case $version in
        auth)
            print_info "检查认证版本状态..."
            if curl -s http://localhost:5601/api/status > /dev/null 2>&1; then
                print_success "认证版本运行正常 (端口 5601)"
            else
                print_warning "认证版本未运行或无法访问"
            fi
            ;;
        no-auth)
            print_info "检查无认证版本状态..."
            if curl -s http://localhost:5602/api/status > /dev/null 2>&1; then
                print_success "无认证版本运行正常 (端口 5602)"
            else
                print_warning "无认证版本未运行或无法访问"
            fi
            ;;
        both)
            check_status auth
            check_status no-auth
            ;;
    esac
}

# 主逻辑
main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    local command=$1
    local version=${2:-""}
    
    case $command in
        help|--help|-h)
            show_help
            ;;
        info)
            if [ -z "$version" ]; then
                show_info both
            else
                check_version $version
                show_info $version
            fi
            ;;
        status)
            if [ -z "$version" ]; then
                check_status both
            else
                check_version $version
                if [ "$version" = "both" ]; then
                    check_status both
                else
                    check_status $version
                fi
            fi
            ;;
        start|stop|restart|logs|clean)
            if [ -z "$version" ]; then
                print_error "请指定版本: auth, no-auth"
                exit 1
            fi
            
            if [ "$version" = "both" ]; then
                if [ "$command" = "start" ]; then
                    print_error "不能同时启动两个版本（端口冲突）"
                    print_info "请分别启动不同的版本"
                    exit 1
                fi
                
                for v in auth no-auth; do
                    execute_command $command $v
                done
            else
                check_version $version
                execute_command $command $version
            fi
            ;;
        *)
            print_error "未知命令: $command"
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@" 