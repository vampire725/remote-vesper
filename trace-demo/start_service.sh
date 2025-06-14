#!/bin/bash

# 启动后台服务并发送测试请求
start_services() {
    echo "🟢 启动 vector/backservice 和 vector/gateway 二进制文件"

    # 进入目录并后台启动二进制文件
    nohup ./backservice1 > backservice1.log 2>&1 &
    echo $! > backservice1.pid

    # 进入目录并后台启动二进制文件
    nohup ./backservice2 > backservice2.log 2>&1 &
    echo $! > backservice2.pid

    nohup ./vector/gateway > gateway.log 2>&1 &
    echo $! > gateway.pid

    # 等待服务启动
    sleep 5

    # 启动循环请求脚本
    echo "🟢 启动循环请求脚本"
    nohup bash -c 'while true; do for i in {1..100}; do curl -s "http://localhost:8080/api/data" >/dev/null; echo "[$(date "+%Y-%m-%d %H:%M:%S")] 发送请求 $i 到 http://localhost:8080/api/data"; done; sleep 1800; done' > request.log 2>&1 &
    echo $! > request.pid

    echo "✅ 服务已启动"
    echo "backservice1 PID: $(cat backservice1.pid)"
    echo "backservice2 PID: $(cat backservice2.pid)"

    echo "gateway PID: $(cat gateway.pid)"
    echo "请求脚本 PID: $(cat request.pid)"
    echo "🔍 查看日志: tail -f *.log"
}

start_services