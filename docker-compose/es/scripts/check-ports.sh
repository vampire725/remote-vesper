#!/bin/bash

# ===========================================
# Elasticsearch 端口冲突检查脚本
# 文件名: check-ports.sh
# 功能: 检查 Elasticsearch 和 Kibana 所需端口是否被占用
# ===========================================

set -e

echo "🔍 开始检查 Elasticsearch 端口占用情况..."

# 定义需要检查的端口
declare -A PORTS=(
    ["9200"]="Elasticsearch HTTP API"
    ["9300"]="Elasticsearch 传输层"
    ["5601"]="Kibana Web 界面"
)

# 检查操作系统类型
OS_TYPE=$(uname -s)
PORT_CHECK_CMD=""

case $OS_TYPE in
    "Linux")
        PORT_CHECK_CMD="netstat -tlnp"
        ;;
    "Darwin")  # macOS
        PORT_CHECK_CMD="netstat -an -p tcp"
        ;;
    "MINGW"*|"CYGWIN"*|"MSYS"*)  # Windows
        PORT_CHECK_CMD="netstat -an"
        ;;
    *)
        echo "⚠️  未知操作系统: $OS_TYPE"
        echo "💡 将尝试使用通用命令检查端口"
        PORT_CHECK_CMD="netstat -an"
        ;;
esac

echo "🖥️  检测到操作系统: $OS_TYPE"
echo ""

# 检查 Docker 是否运行
echo "🐳 检查 Docker 状态..."
if ! docker info > /dev/null 2>&1; then
    echo "⚠️  Docker 未运行，无法检查 Docker 容器端口占用"
    DOCKER_RUNNING=false
else
    echo "✅ Docker 正在运行"
    DOCKER_RUNNING=true
fi

echo ""
echo "📊 端口占用检查结果："
echo "=================================="

CONFLICT_FOUND=false

# 检查每个端口
for port in "${!PORTS[@]}"; do
    service_name="${PORTS[$port]}"
    echo -n "🔍 检查端口 $port ($service_name): "
    
    # 检查系统端口占用
    if $PORT_CHECK_CMD 2>/dev/null | grep -q ":$port "; then
        echo "❌ 被占用"
        CONFLICT_FOUND=true
        
        # 尝试找出占用进程
        case $OS_TYPE in
            "Linux")
                echo "   📋 占用进程信息:"
                netstat -tlnp 2>/dev/null | grep ":$port " | while read line; do
                    echo "      $line"
                done
                ;;
            "Darwin")
                echo "   📋 尝试查找占用进程:"
                lsof -i :$port 2>/dev/null | head -5 || echo "      无法获取进程信息"
                ;;
            *)
                echo "   📋 端口被占用，请手动检查占用进程"
                ;;
        esac
        echo ""
    else
        echo "✅ 可用"
    fi
done

# 检查 Docker 容器端口占用
if $DOCKER_RUNNING; then
    echo ""
    echo "🐳 检查 Docker 容器端口占用："
    echo "=================================="
    
    for port in "${!PORTS[@]}"; do
        service_name="${PORTS[$port]}"
        echo -n "🔍 检查 Docker 端口 $port ($service_name): "
        
        if docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -q ":$port->"; then
            echo "❌ 被 Docker 容器占用"
            CONFLICT_FOUND=true
            echo "   📋 占用的容器:"
            docker ps --format "table {{.Names}}\t{{.Ports}}" | grep ":$port->" | while read line; do
                echo "      $line"
            done
            echo ""
        else
            echo "✅ 可用"
        fi
    done
fi

echo ""
echo "=================================="

# 总结检查结果
if $CONFLICT_FOUND; then
    echo "❌ 发现端口冲突！"
    echo ""
    echo "🔧 解决建议："
    echo "1. 停止占用端口的服务或进程"
    echo "2. 修改 docker-compose.yaml 中的端口映射"
    echo "3. 使用以下命令停止可能的 Elasticsearch 容器："
    echo "   docker stop \$(docker ps -q --filter ancestor=docker.elastic.co/elasticsearch/elasticsearch)"
    echo ""
    echo "💡 常用端口管理命令："
    case $OS_TYPE in
        "Linux")
            echo "   - 查看端口占用: sudo netstat -tlnp | grep :端口号"
            echo "   - 杀死进程: sudo kill -9 进程ID"
            ;;
        "Darwin")
            echo "   - 查看端口占用: lsof -i :端口号"
            echo "   - 杀死进程: kill -9 进程ID"
            ;;
        *)
            echo "   - 查看端口占用: netstat -an | findstr :端口号"
            echo "   - 在任务管理器中结束相关进程"
            ;;
    esac
    echo ""
    exit 1
else
    echo "✅ 所有端口都可用！"
    echo ""
    echo "🚀 可以安全启动 Elasticsearch 集群："
    echo "   docker-compose up -d"
    echo ""
fi

# 额外的系统资源检查
echo "📊 系统资源检查："
echo "=================================="

# 检查可用内存
echo -n "💾 内存检查: "
case $OS_TYPE in
    "Linux")
        TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
        AVAIL_MEM=$(free -g | awk '/^Mem:/{print $7}')
        echo "总内存 ${TOTAL_MEM}GB, 可用内存 ${AVAIL_MEM}GB"
        if [ "$AVAIL_MEM" -lt 4 ]; then
            echo "   ⚠️  可用内存不足 4GB，建议调整 ES_JAVA_OPTS"
        else
            echo "   ✅ 内存充足"
        fi
        ;;
    "Darwin")
        TOTAL_MEM=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
        echo "总内存 ${TOTAL_MEM}GB"
        if [ "$TOTAL_MEM" -lt 8 ]; then
            echo "   ⚠️  总内存不足 8GB，建议调整 ES_JAVA_OPTS"
        else
            echo "   ✅ 内存充足"
        fi
        ;;
    *)
        echo "无法检测内存信息"
        echo "   💡 请确保系统有足够内存运行 Elasticsearch"
        ;;
esac

# 检查磁盘空间
echo -n "💿 磁盘空间检查: "
case $OS_TYPE in
    "Linux"|"Darwin")
        DISK_AVAIL=$(df -h . | awk 'NR==2{print $4}' | sed 's/G//')
        echo "当前目录可用空间: ${DISK_AVAIL}"
        if [ "${DISK_AVAIL%.*}" -lt 10 ]; then
            echo "   ⚠️  磁盘空间不足 10GB，可能影响数据存储"
        else
            echo "   ✅ 磁盘空间充足"
        fi
        ;;
    *)
        echo "无法检测磁盘空间"
        echo "   💡 请确保有足够磁盘空间存储数据"
        ;;
esac

echo ""
echo "🎯 检查完成！" 