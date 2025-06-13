#!/bin/bash

# ===========================================
# Kibana 认证版本启动脚本
# 功能: 启动带认证的 Kibana 服务
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
print_info "启动 Kibana 认证版本..."

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

# 检查 Elasticsearch 是否运行
print_info "检查 Elasticsearch 状态..."
if ! curl -k -s -u elastic:your_elastic_password https://localhost:9200/_cluster/health > /dev/null 2>&1; then
    print_warning "Elasticsearch 可能未运行或未启用安全功能"
    print_warning "请确保 Elasticsearch 已启动并配置了安全认证"
fi

# 检查 SSL 证书
print_info "检查 SSL 证书..."
if [ ! -f "../es/certs/ca/ca.crt" ]; then
    print_error "SSL 证书文件不存在: ../es/certs/ca/ca.crt"
    print_error "请确保 Elasticsearch 已生成 SSL 证书"
    exit 1
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

# 启动服务
print_info "启动 Kibana 认证版本..."
docker-compose up -d

# 等待服务启动
print_info "等待服务启动..."
sleep 10

# 检查服务状态
print_info "检查服务状态..."
docker-compose ps

# 等待 Kibana 完全启动
print_info "等待 Kibana 完全启动（可能需要1-2分钟）..."
for i in {1..24}; do
    if curl -s http://localhost:5601/api/status > /dev/null 2>&1; then
        print_success "Kibana 启动成功！"
        break
    fi
    if [ $i -eq 24 ]; then
        print_error "Kibana 启动超时，请检查日志"
        print_info "查看日志命令: docker-compose logs kibana"
        exit 1
    fi
    echo -n "."
    sleep 5
done

# 显示访问信息
echo ""
print_success "=== Kibana 认证版本启动成功 ==="
print_info "访问地址: http://localhost:5601"
print_info "用户名: elastic"
print_info "密码: your_elastic_password"
print_warning "请确保使用正确的 Elasticsearch 密码"
echo ""
print_info "常用命令:"
print_info "  查看日志: docker-compose logs -f kibana"
print_info "  停止服务: docker-compose down"
print_info "  重启服务: docker-compose restart"
echo "" 