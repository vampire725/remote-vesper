@echo off
setlocal enabledelayedexpansion

REM Kafka 简单部署启动脚本 (Windows版本)
REM 适用于 Windows 系统
REM 版本: Apache Kafka 3.9.1 (简单版本 - 不带SASL认证)

REM 脚本配置
set SCRIPT_DIR=%~dp0
set COMPOSE_FILE=%SCRIPT_DIR%docker-compose.yaml
set PROJECT_NAME=kafka-simple

REM 颜色定义 (Windows CMD 不支持颜色，使用echo替代)
set "INFO_PREFIX=[INFO]"
set "SUCCESS_PREFIX=[SUCCESS]"
set "WARNING_PREFIX=[WARNING]"
set "ERROR_PREFIX=[ERROR]"
set "STEP_PREFIX=[STEP]"

REM 显示帮助信息
:show_help
echo Kafka 简单部署管理脚本 (Windows版本)
echo.
echo 用法: %~nx0 [选项]
echo.
echo 选项:
echo   start           启动 Kafka 集群
echo   stop            停止 Kafka 集群
echo   restart         重启 Kafka 集群
echo   status          查看服务状态
echo   logs [service]  查看日志 (可选指定服务名)
echo   clean           清理所有数据和容器
echo   reset           重置集群 (停止、清理、启动)
echo   test            测试 Kafka 连接
echo   topics          管理主题
echo   ui              打开 Kafka UI
echo   health          健康检查
echo   help            显示此帮助信息
echo.
echo 示例:
echo   %~nx0 start                    # 启动集群
echo   %~nx0 logs kafka               # 查看 Kafka 日志
echo   %~nx0 test                     # 测试连接
echo   %~nx0 topics list              # 列出所有主题
echo.
goto :eof

REM 日志函数
:log_info
echo %INFO_PREFIX% %~1
goto :eof

:log_success
echo %SUCCESS_PREFIX% %~1
goto :eof

:log_warning
echo %WARNING_PREFIX% %~1
goto :eof

:log_error
echo %ERROR_PREFIX% %~1
goto :eof

:log_step
echo %STEP_PREFIX% %~1
goto :eof

REM 检查依赖
:check_dependencies
call :log_step "检查系统依赖..."

REM 检查 Docker
docker --version >nul 2>&1
if errorlevel 1 (
    call :log_error "Docker 未安装或不在 PATH 中"
    exit /b 1
)

REM 检查 Docker Compose
docker-compose --version >nul 2>&1
if errorlevel 1 (
    docker compose version >nul 2>&1
    if errorlevel 1 (
        call :log_error "Docker Compose 未安装或不在 PATH 中"
        exit /b 1
    )
)

REM 检查 Docker 服务状态
docker info >nul 2>&1
if errorlevel 1 (
    call :log_error "Docker 服务未运行，请启动 Docker Desktop"
    exit /b 1
)

call :log_success "依赖检查通过"
goto :eof

REM 检查端口占用
:check_ports
call :log_step "检查端口占用..."

REM Windows 端口检查
netstat -an | findstr ":2181 " >nul 2>&1
if not errorlevel 1 (
    call :log_warning "端口 2181 已被占用"
)

netstat -an | findstr ":9092 " >nul 2>&1
if not errorlevel 1 (
    call :log_warning "端口 9092 已被占用"
)

netstat -an | findstr ":8080 " >nul 2>&1
if not errorlevel 1 (
    call :log_warning "端口 8080 已被占用"
)

call :log_success "端口检查完成"
goto :eof

REM 创建网络
:create_network
call :log_step "创建 Docker 网络..."

docker network ls | findstr "kafka-simple-network" >nul 2>&1
if errorlevel 1 (
    docker network create kafka-simple-network --driver bridge --subnet=172.20.0.0/16 >nul 2>&1
    call :log_success "网络创建成功"
) else (
    call :log_info "网络已存在"
)
goto :eof

REM 启动服务
:start_services
call :log_step "启动 Kafka 集群..."

call :check_dependencies
if errorlevel 1 exit /b 1

call :check_ports
call :create_network

REM 拉取镜像
call :log_step "拉取 Docker 镜像..."
docker-compose -f "%COMPOSE_FILE%" -p "%PROJECT_NAME%" pull

REM 启动服务
call :log_step "启动服务..."
docker-compose -f "%COMPOSE_FILE%" -p "%PROJECT_NAME%" up -d

REM 等待服务启动
call :log_step "等待服务启动..."
timeout /t 10 /nobreak >nul

REM 健康检查
call :wait_for_services
if errorlevel 1 exit /b 1

call :log_success "Kafka 集群启动成功!"
call :show_access_info
goto :eof

REM 等待服务启动
:wait_for_services
call :log_step "等待服务健康检查..."

set /a max_attempts=30
set /a attempt=1

:wait_loop
if !attempt! gtr !max_attempts! (
    call :log_error "服务启动超时，请检查日志"
    call :show_logs
    exit /b 1
)

call :log_info "健康检查 (!attempt!/!max_attempts!)..."

REM 检查 Zookeeper
docker exec kafka-zookeeper nc -z localhost 2181 >nul 2>&1
if errorlevel 1 (
    call :log_warning "Zookeeper 服务未就绪"
    timeout /t 5 /nobreak >nul
    set /a attempt+=1
    goto :wait_loop
) else (
    call :log_success "Zookeeper 服务正常"
)

REM 检查 Kafka
docker exec kafka-broker /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092 >nul 2>&1
if errorlevel 1 (
    call :log_warning "Kafka 服务未就绪"
    timeout /t 5 /nobreak >nul
    set /a attempt+=1
    goto :wait_loop
) else (
    call :log_success "Kafka 服务正常"
    goto :eof
)

REM 停止服务
:stop_services
call :log_step "停止 Kafka 集群..."
docker-compose -f "%COMPOSE_FILE%" -p "%PROJECT_NAME%" down
call :log_success "Kafka 集群已停止"
goto :eof

REM 重启服务
:restart_services
call :log_step "重启 Kafka 集群..."
call :stop_services
timeout /t 3 /nobreak >nul
call :start_services
goto :eof

REM 查看服务状态
:show_status
call :log_step "查看服务状态..."
docker-compose -f "%COMPOSE_FILE%" -p "%PROJECT_NAME%" ps

echo.
call :log_step "服务健康状态:"

REM 检查 Zookeeper
docker exec kafka-zookeeper nc -z localhost 2181 >nul 2>&1
if errorlevel 1 (
    call :log_error "Zookeeper: 不健康"
) else (
    call :log_success "Zookeeper: 健康"
)

REM 检查 Kafka
docker exec kafka-broker /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092 >nul 2>&1
if errorlevel 1 (
    call :log_error "Kafka: 不健康"
) else (
    call :log_success "Kafka: 健康"
)

REM 检查 Kafka UI
curl -s http://localhost:8080/actuator/health >nul 2>&1
if errorlevel 1 (
    call :log_warning "Kafka UI: 不健康或未启动"
) else (
    call :log_success "Kafka UI: 健康"
)
goto :eof

REM 查看日志
:show_logs
if "%~2"=="" (
    call :log_step "查看所有服务日志..."
    docker-compose -f "%COMPOSE_FILE%" -p "%PROJECT_NAME%" logs -f
) else (
    call :log_step "查看 %~2 服务日志..."
    docker-compose -f "%COMPOSE_FILE%" -p "%PROJECT_NAME%" logs -f "%~2"
)
goto :eof

REM 清理数据
:clean_data
call :log_step "清理 Kafka 数据..."

set /p confirm="确定要清理所有数据吗? 这将删除所有主题和消息 (y/N): "
if /i not "%confirm%"=="y" (
    call :log_info "操作已取消"
    goto :eof
)

REM 停止服务
docker-compose -f "%COMPOSE_FILE%" -p "%PROJECT_NAME%" down -v

REM 删除数据卷
docker volume rm kafka-simple-zookeeper-data kafka-simple-zookeeper-logs kafka-simple-kafka-data kafka-simple-kafka-logs >nul 2>&1

REM 删除网络
docker network rm kafka-simple-network >nul 2>&1

call :log_success "数据清理完成"
goto :eof

REM 重置集群
:reset_cluster
call :log_step "重置 Kafka 集群..."
call :clean_data
timeout /t 2 /nobreak >nul
call :start_services
goto :eof

REM 测试连接
:test_connection
call :log_step "测试 Kafka 连接..."

REM 创建测试主题
call :log_info "创建测试主题..."
docker exec kafka-broker /opt/kafka/bin/kafka-topics.sh --create --topic test-topic --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 --if-not-exists

REM 发送测试消息
call :log_info "发送测试消息..."
echo Hello Kafka %date% %time% | docker exec -i kafka-broker /opt/kafka/bin/kafka-console-producer.sh --topic test-topic --bootstrap-server localhost:9092

REM 消费测试消息
call :log_info "消费测试消息..."
docker exec kafka-broker timeout 10 /opt/kafka/bin/kafka-console-consumer.sh --topic test-topic --bootstrap-server localhost:9092 --from-beginning --max-messages 1 2>nul

call :log_success "连接测试完成"
goto :eof

REM 主题管理
:manage_topics
set action=%~2
if "%action%"=="" set action=list

if "%action%"=="list" (
    call :log_step "列出所有主题..."
    docker exec kafka-broker /opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092
) else if "%action%"=="create" (
    set topic_name=%~3
    if "!topic_name!"=="" (
        call :log_error "请指定主题名称"
        echo 用法: %~nx0 topics create ^<topic-name^> [partitions] [replication-factor]
        exit /b 1
    )
    set partitions=%~4
    if "!partitions!"=="" set partitions=3
    set replication=%~5
    if "!replication!"=="" set replication=1
    
    call :log_step "创建主题: !topic_name!"
    docker exec kafka-broker /opt/kafka/bin/kafka-topics.sh --create --topic "!topic_name!" --bootstrap-server localhost:9092 --partitions !partitions! --replication-factor !replication!
) else if "%action%"=="delete" (
    set topic_name=%~3
    if "!topic_name!"=="" (
        call :log_error "请指定主题名称"
        echo 用法: %~nx0 topics delete ^<topic-name^>
        exit /b 1
    )
    
    call :log_step "删除主题: !topic_name!"
    docker exec kafka-broker /opt/kafka/bin/kafka-topics.sh --delete --topic "!topic_name!" --bootstrap-server localhost:9092
) else if "%action%"=="describe" (
    set topic_name=%~3
    if "!topic_name!"=="" (
        call :log_step "描述所有主题..."
        docker exec kafka-broker /opt/kafka/bin/kafka-topics.sh --describe --bootstrap-server localhost:9092
    ) else (
        call :log_step "描述主题: !topic_name!"
        docker exec kafka-broker /opt/kafka/bin/kafka-topics.sh --describe --topic "!topic_name!" --bootstrap-server localhost:9092
    )
) else (
    call :log_error "未知的主题操作: %action%"
    echo 可用操作: list, create, delete, describe
    exit /b 1
)
goto :eof

REM 打开 Kafka UI
:open_ui
call :log_step "打开 Kafka UI..."
start http://localhost:8080
goto :eof

REM 健康检查
:health_check
call :log_step "执行健康检查..."

set all_healthy=true

REM 检查容器状态
call :log_info "检查容器状态..."
docker-compose -f "%COMPOSE_FILE%" -p "%PROJECT_NAME%" ps | findstr "Up" >nul 2>&1
if errorlevel 1 (
    call :log_error "部分或全部容器未运行"
    set all_healthy=false
) else (
    call :log_success "所有容器正在运行"
)

REM 检查 Zookeeper
call :log_info "检查 Zookeeper 连接..."
docker exec kafka-zookeeper nc -z localhost 2181 >nul 2>&1
if errorlevel 1 (
    call :log_error "Zookeeper 连接失败"
    set all_healthy=false
) else (
    call :log_success "Zookeeper 连接正常"
)

REM 检查 Kafka
call :log_info "检查 Kafka 连接..."
docker exec kafka-broker /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092 >nul 2>&1
if errorlevel 1 (
    call :log_error "Kafka 连接失败"
    set all_healthy=false
) else (
    call :log_success "Kafka 连接正常"
)

REM 检查主题操作
call :log_info "检查主题操作..."
docker exec kafka-broker /opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092 >nul 2>&1
if errorlevel 1 (
    call :log_error "主题操作失败"
    set all_healthy=false
) else (
    call :log_success "主题操作正常"
)

if "%all_healthy%"=="true" (
    call :log_success "所有健康检查通过"
) else (
    call :log_error "部分健康检查失败"
    exit /b 1
)
goto :eof

REM 显示访问信息
:show_access_info
echo.
call :log_success "=== Kafka 集群访问信息 ==="
echo Kafka Broker:     localhost:9092
echo Zookeeper:       localhost:2181
echo Kafka UI:        http://localhost:8080
echo.
echo 常用命令:
echo   查看状态:     %~nx0 status
echo   查看日志:     %~nx0 logs
echo   测试连接:     %~nx0 test
echo   管理主题:     %~nx0 topics list
echo   打开UI:       %~nx0 ui
echo.
goto :eof

REM 主函数
:main
set command=%~1
if "%command%"=="" set command=start

if "%command%"=="start" (
    call :start_services
) else if "%command%"=="stop" (
    call :stop_services
) else if "%command%"=="restart" (
    call :restart_services
) else if "%command%"=="status" (
    call :show_status
) else if "%command%"=="logs" (
    call :show_logs %*
) else if "%command%"=="clean" (
    call :clean_data
) else if "%command%"=="reset" (
    call :reset_cluster
) else if "%command%"=="test" (
    call :test_connection
) else if "%command%"=="topics" (
    call :manage_topics %*
) else if "%command%"=="ui" (
    call :open_ui
) else if "%command%"=="health" (
    call :health_check
) else if "%command%"=="help" (
    call :show_help
) else (
    call :log_error "未知命令: %command%"
    call :show_help
    exit /b 1
)

goto :eof

REM 执行主函数
call :main %* 