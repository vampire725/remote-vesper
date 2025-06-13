#!/bin/bash

# ===========================================
# Kibana 无认证版本启动脚本
# 功能: 启动无认证的 Kibana 服务（开发环境）
# 版本: 1.0.0
# ===========================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# 脚本开始
print_info "启动 Kibana 无认证版本（开发环境）..."

# 安全警告
print_warning "⚠️  警告: 此版本禁用了所有安全功能"
print_warning "⚠️  仅适用于开发和测试环境"
print_warning "⚠️  请勿在生产环境中使用"

# 检查前置条件
print_info "检查前置条件..."

# 检查 Docker 是否运行
if ! docker info > /dev/null 2>&1; then
    print_error "Docker 未运行，请启动 Docker 服务"
    exit 1
fi

# 检查 Docker Compose 是否可用
if ! command -v docker-compose > /dev/null 2>&1; then
    print_error "Docker Compose 未安装"
    exit 1
fi

# 检查 Elasticsearch 是否运行（无认证模式）
print_info "检查 Elasticsearch 状态..."
if ! curl -s http://localhost:9200/_cluster/health > /dev/null 2>&1; then
    print_warning "Elasticsearch 可能未运行或仍启用了安全功能"
    print_warning "请确保 Elasticsearch 已启动并禁用了安全认证"
    print_info "Elasticsearch 应配置为: xpack.security.enabled=false"
fi

# 检查网络
print_info "检查 Docker 网络..."
if ! docker network ls | grep -q "logging-network"; then
    print_warning "logging-network 网络不存在，正在创建..."
    docker network create logging-network
fi

if ! docker network ls | grep -q "monitoring-network"; then
    print_warning "monitoring-network 网络不存在，正在创建..."
    docker network create monitoring-network
fi

# 创建必要的目录
print_info "创建必要的目录..."
mkdir -p config data
chmod 755 config data

# 检查端口占用
print_info "检查端口 5602..."
if netstat -tuln 2>/dev/null | grep -q ":5602 "; then
    print_warning "端口 5602 已被占用"
    read -p "是否继续启动？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "取消启动"
        exit 0
    fi
fi

# 启动服务
print_info "启动 Kibana 无认证版本..."
docker-compose up -d

# 等待服务启动
print_info "等待服务启动..."
sleep 5

# 检查服务状态
print_info "检查服务状态..."
docker-compose ps

# 等待 Kibana 完全启动
print_info "等待 Kibana 完全启动（通常30-60秒）..."
for i in {1..12}; do
    if curl -s http://localhost:5602/api/status > /dev/null 2>&1; then
        print_success "Kibana 启动成功！"
        break
    fi
    if [ $i -eq 12 ]; then
        print_error "Kibana 启动超时，请检查日志"
        print_info "查看日志命令: docker-compose logs kibana"
        exit 1
    fi
    echo -n "."
    sleep 5
done

# 显示访问信息
echo ""
print_success "=== Kibana 无认证版本启动成功 ==="
print_info "🌐 访问地址: http://localhost:5602"
print_success "✅ 无需登录，直接访问"
print_warning "⚠️  此版本禁用了所有安全功能"
echo ""
print_info "常用命令:"
print_info "  查看日志: docker-compose logs -f kibana"
print_info "  停止服务: docker-compose down"
print_info "  重启服务: docker-compose restart"
echo ""
print_warning "如需生产环境部署，请使用认证版本: ../kibana-auth/"
echo "" 