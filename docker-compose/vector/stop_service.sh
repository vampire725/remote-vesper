#!/bin/bash

# 停止服务并清理
stop_services() {
    echo "🟠 停止 vector 服务"

#    # 停止二进制进程
#    if [ -f backservice.pid ]; then
#        echo "🟠 停止 backservice (PID: $(cat backservice.pid))"
#        kill -9 $(cat backservice.pid) && rm backservice.pid
#    fi
#
#    if [ -f gateway.pid ]; then
#        echo "🟠 停止 gateway (PID: $(cat gateway.pid))"
#        kill -9 $(cat gateway.pid) && rm gateway.pid
#    fi

#    pkill -f "gateway" && pkill -f "backservice" || { pgrep -f "gateway" | xargs kill -9 && pgrep -f "backservice" | xargs kill -9; }
    pkill -f "api/data" || { pgrep -f "api/data" | xargs kill -9; }

    # 停止请求脚本
    if [ -f request.pid ]; then
        echo "🟠 停止请求脚本 (PID: $(cat request.pid))"
        kill -9 $(cat request.pid) && rm request.pid
    fi

    echo "✅ 所有服务已停止"
    echo "🔄 清理日志文件..."
    rm -f *.log
}

stop_services