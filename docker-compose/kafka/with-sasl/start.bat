@echo off
setlocal enabledelayedexpansion

REM Kafka SASL 安全部署启动脚本 (Windows版本)
REM 适用于 Windows 系统
REM 版本: Apache Kafka 3.9.1 (SASL/SCRAM认证版本)

REM 脚本配置
set SCRIPT_DIR=%~dp0
set COMPOSE_FILE=%SCRIPT_DIR%docker-compose.yaml
set ENV_FILE=%SCRIPT_DIR%.env
set ENV_TEMPLATE=%SCRIPT_DIR%env-template.txt
set PROJECT_NAME=kafka-sasl

REM 颜色定义 (Windows CMD 不支持颜色，使用echo替代)
set "INFO_PREFIX=[INFO]"
set "SUCCESS_PREFIX=[SUCCESS]"
set "WARNING_PREFIX=[WARNING]"
set "ERROR_PREFIX=[ERROR]"
set "STEP_PREFIX=[STEP]"
set "SECURITY_PREFIX=[SECURITY]"

REM 显示帮助信息
:show_help
echo Kafka SASL 安全部署管理脚本 (Windows版本)
echo.
echo 用法: %~nx0 [选项]
echo.
echo 选项:
echo   start           启动 Kafka 安全集群
echo   stop            停止 Kafka 集群
echo   restart         重启 Kafka 集群
echo   status          查看服务状态
echo   logs [service]  查看日志 (可选指定服务名)
echo   clean           清理所有数据和容器
echo   reset           重置集群 (停止、清理、启动)
echo   test            测试 SASL 认证连接
echo   topics          管理主题
echo   users           管理 SASL 用户
echo   acl             管理访问控制列表
echo   ui              打开 Kafka UI
echo   health          健康检查
echo   security        安全配置检查
echo   setup-env       设置环境变量
echo   help            显示此帮助信息
echo.
echo 示例:
echo   %~nx0 setup-env                # 设置环境变量
echo   %~nx0 start                    # 启动安全集群
echo   %~nx0 users list               # 列出所有用户
echo   %~nx0 test                     # 测试SASL认证
echo   %~nx0 acl list                 # 列出ACL规则
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

:log_security
echo %SECURITY_PREFIX% %~1
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

REM 设置环境变量
:setup_env
call :log_step "设置环境变量..."

if not exist "%ENV_FILE%" (
    if exist "%ENV_TEMPLATE%" (
        call :log_info "创建环境变量文件..."
        copy "%ENV_TEMPLATE%" "%ENV_FILE%" >nul
        call :log_warning "请编辑 .env 文件并修改默认密码"
        call :log_warning "文件位置: %ENV_FILE%"
        
        echo.
        call :log_info "建议使用强密码，包含大小写字母、数字和特殊字符"
        echo.
        
        set /p edit_now="是否现在编辑环境变量文件? (y/N): "
        if /i "!edit_now!"=="y" (
            notepad "%ENV_FILE%"
        )
    ) else (
        call :log_error "环境变量模板文件不存在: %ENV_TEMPLATE%"
        exit /b 1
    )
) else (
    call :log_info "环境变量文件已存在: %ENV_FILE%"
)
goto :eof

REM 检查环境变量
:check_env
if not exist "%ENV_FILE%" (
    call :log_warning "环境变量文件不存在，将使用默认配置"
    call :log_warning "建议运行: %~nx0 setup-env"
    exit /b 1
)

REM 检查是否使用默认密码
findstr /C:"admin-secret" /C:"user-secret" /C:"producer-secret" /C:"consumer-secret" "%ENV_FILE%" >nul 2>&1
if not errorlevel 1 (
    call :log_warning "检测到默认密码，建议修改为强密码"
    call :log_security "在生产环境中使用默认密码存在安全风险"
)

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

netstat -an | findstr ":9093 " >nul 2>&1
if not errorlevel 1 (
    call :log_warning "端口 9093 已被占用"
)

netstat -an | findstr ":8080 " >nul 2>&1
if not errorlevel 1 (
    call :log_warning "端口 8080 已被占用"
)

netstat -an | findstr ":8081 " >nul 2>&1
if not errorlevel 1 (
    call :log_warning "端口 8081 已被占用"
)

netstat -an | findstr ":8083 " >nul 2>&1
if not errorlevel 1 (
    call :log_warning "端口 8083 已被占用"
)

call :log_success "端口检查完成"
goto :eof

REM 创建网络
:create_network
call :log_step "创建 Docker 网络..."

docker network ls | findstr "kafka-sasl-network" >nul 2>&1
if errorlevel 1 (
    docker network create kafka-sasl-network --driver bridge --subnet=172.21.0.0/16 >nul 2>&1
    call :log_success "网络创建成功"
) else (
    call :log_info "网络已存在"
)
goto :eof

REM 安全配置检查
:security_check
call :log_step "执行安全配置检查..."

set security_issues=0

REM 检查默认密码
if exist "%ENV_FILE%" (
    findstr /C:"admin-secret" /C:"user-secret" "%ENV_FILE%" >nul 2>&1
    if not errorlevel 1 (
        call :log_warning "使用默认密码"
        set /a security_issues+=1
    )
)

REM 显示安全检查结果
if !security_issues! equ 0 (
    call :log_success "安全配置检查通过"
) else (
    call :log_warning "发现 !security_issues! 个安全问题"
    call :log_security "建议在生产环境部署前解决这些问题"
)
goto :eof

REM 启动服务
:start_services
call :log_step "启动 Kafka SASL 安全集群..."

call :check_dependencies
if errorlevel 1 exit /b 1

call :check_env
if errorlevel 1 (
    call :log_warning "继续使用默认配置..."
)

call :check_ports
call :create_network
call :security_check

REM 拉取镜像
call :log_step "拉取 Docker 镜像..."
if exist "%ENV_FILE%" (
    docker-compose -f "%COMPOSE_FILE%" --env-file "%ENV_FILE%" -p "%PROJECT_NAME%" pull
) else (
    docker-compose -f "%COMPOSE_FILE%" -p "%PROJECT_NAME%" pull
)

REM 启动服务
call :log_step "启动服务..."
if exist "%ENV_FILE%" (
    docker-compose -f "%COMPOSE_FILE%" --env-file "%ENV_FILE%" -p "%PROJECT_NAME%" up -d
) else (
    docker-compose -f "%COMPOSE_FILE%" -p "%PROJECT_NAME%" up -d
)

REM 等待服务启动
call :log_step "等待服务启动..."
timeout /t 15 /nobreak >nul

REM 健康检查
call :wait_for_services
if errorlevel 1 exit /b 1

call :log_success "Kafka SASL 安全集群启动成功!"
call :show_access_info
call :show_security_info
goto :eof

REM 等待服务启动
:wait_for_services
call :log_step "等待服务健康检查..."

set /a max_attempts=60
set /a attempt=1

:wait_loop
if !attempt! gtr !max_attempts! (
    call :log_error "服务启动超时，请检查日志"
    call :show_logs
    exit /b 1
)

call :log_info "健康检查 (!attempt!/!max_attempts!)..."

REM 检查 Zookeeper
docker exec kafka-zookeeper-sasl nc -z localhost 2181 >nul 2>&1
if errorlevel 1 (
    call :log_warning "Zookeeper 服务未就绪"
    timeout /t 5 /nobreak >nul
    set /a attempt+=1
    goto :wait_loop
) else (
    call :log_success "Zookeeper 服务正常"
)

REM 检查 Kafka (需要等待SASL用户创建完成)
docker exec kafka-broker-sasl /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --command-config /opt/kafka/config/sasl/client.properties --list >nul 2>&1
if errorlevel 1 (
    call :log_warning "Kafka SASL 服务未就绪"
    timeout /t 5 /nobreak >nul
    set /a attempt+=1
    goto :wait_loop
) else (
    call :log_success "Kafka SASL 服务正常"
    goto :eof
)

REM 停止服务
:stop_services
call :log_step "停止 Kafka SASL 集群..."
if exist "%ENV_FILE%" (
    docker-compose -f "%COMPOSE_FILE%" --env-file "%ENV_FILE%" -p "%PROJECT_NAME%" down
) else (
    docker-compose -f "%COMPOSE_FILE%" -p "%PROJECT_NAME%" down
)
call :log_success "Kafka SASL 集群已停止"
goto :eof

REM 重启服务
:restart_services
call :log_step "重启 Kafka SASL 集群..."
call :stop_services
timeout /t 3 /nobreak >nul
call :start_services
goto :eof

REM 查看服务状态
:show_status
call :log_step "查看服务状态..."
if exist "%ENV_FILE%" (
    docker-compose -f "%COMPOSE_FILE%" --env-file "%ENV_FILE%" -p "%PROJECT_NAME%" ps
) else (
    docker-compose -f "%COMPOSE_FILE%" -p "%PROJECT_NAME%" ps
)

echo.
call :log_step "服务健康状态:"

REM 检查 Zookeeper
docker exec kafka-zookeeper-sasl nc -z localhost 2181 >nul 2>&1
if errorlevel 1 (
    call :log_error "Zookeeper: 不健康"
) else (
    call :log_success "Zookeeper: 健康"
)

REM 检查 Kafka
docker exec kafka-broker-sasl /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --command-config /opt/kafka/config/sasl/client.properties --list >nul 2>&1
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

REM 检查 Schema Registry
curl -s http://localhost:8081/subjects >nul 2>&1
if errorlevel 1 (
    call :log_warning "Schema Registry: 不健康或未启动"
) else (
    call :log_success "Schema Registry: 健康"
)

REM 检查 Kafka Connect
curl -s http://localhost:8083/connectors >nul 2>&1
if errorlevel 1 (
    call :log_warning "Kafka Connect: 不健康或未启动"
) else (
    call :log_success "Kafka Connect: 健康"
)
goto :eof

REM 查看日志
:show_logs
if "%~2"=="" (
    call :log_step "查看所有服务日志..."
    if exist "%ENV_FILE%" (
        docker-compose -f "%COMPOSE_FILE%" --env-file "%ENV_FILE%" -p "%PROJECT_NAME%" logs -f
    ) else (
        docker-compose -f "%COMPOSE_FILE%" -p "%PROJECT_NAME%" logs -f
    )
) else (
    call :log_step "查看 %~2 服务日志..."
    if exist "%ENV_FILE%" (
        docker-compose -f "%COMPOSE_FILE%" --env-file "%ENV_FILE%" -p "%PROJECT_NAME%" logs -f "%~2"
    ) else (
        docker-compose -f "%COMPOSE_FILE%" -p "%PROJECT_NAME%" logs -f "%~2"
    )
)
goto :eof

REM 清理数据
:clean_data
call :log_step "清理 Kafka SASL 数据..."

set /p confirm="确定要清理所有数据吗? 这将删除所有主题、用户和消息 (y/N): "
if /i not "%confirm%"=="y" (
    call :log_info "操作已取消"
    goto :eof
)

REM 停止服务
if exist "%ENV_FILE%" (
    docker-compose -f "%COMPOSE_FILE%" --env-file "%ENV_FILE%" -p "%PROJECT_NAME%" down -v
) else (
    docker-compose -f "%COMPOSE_FILE%" -p "%PROJECT_NAME%" down -v
)

REM 删除数据卷
docker volume rm kafka-sasl-zookeeper-data kafka-sasl-zookeeper-logs kafka-sasl-zookeeper-config kafka-sasl-kafka-data kafka-sasl-kafka-logs kafka-sasl-kafka-config >nul 2>&1

REM 删除网络
docker network rm kafka-sasl-network >nul 2>&1

call :log_success "数据清理完成"
goto :eof

REM 重置集群
:reset_cluster
call :log_step "重置 Kafka SASL 集群..."
call :clean_data
timeout /t 2 /nobreak >nul
call :start_services
goto :eof

REM 测试 SASL 连接
:test_connection
call :log_step "测试 Kafka SASL 认证连接..."

REM 检查客户端配置文件是否存在
docker exec kafka-broker-sasl test -f /opt/kafka/config/sasl/client.properties >nul 2>&1
if errorlevel 1 (
    call :log_error "SASL 客户端配置文件不存在"
    exit /b 1
)

REM 创建测试主题
call :log_info "创建测试主题..."
docker exec kafka-broker-sasl /opt/kafka/bin/kafka-topics.sh --create --topic sasl-test-topic --bootstrap-server localhost:9092 --command-config /opt/kafka/config/sasl/client.properties --partitions 3 --replication-factor 1 --if-not-exists

REM 发送测试消息
call :log_info "发送测试消息..."
echo Hello Kafka SASL %date% %time% | docker exec -i kafka-broker-sasl /opt/kafka/bin/kafka-console-producer.sh --topic sasl-test-topic --bootstrap-server localhost:9092 --producer.config /opt/kafka/config/sasl/client.properties

REM 消费测试消息
call :log_info "消费测试消息..."
docker exec kafka-broker-sasl timeout 10 /opt/kafka/bin/kafka-console-consumer.sh --topic sasl-test-topic --bootstrap-server localhost:9092 --consumer.config /opt/kafka/config/sasl/client.properties --from-beginning --max-messages 1 2>nul

call :log_success "SASL 认证连接测试完成"
goto :eof

REM 用户管理
:manage_users
set action=%~2
if "%action%"=="" set action=list

if "%action%"=="list" (
    call :log_step "列出所有 SASL 用户..."
    docker exec kafka-broker-sasl /opt/kafka/bin/kafka-configs.sh --zookeeper zookeeper:2181 --describe --entity-type users
) else if "%action%"=="create" (
    set username=%~3
    set password=%~4
    if "!username!"=="" (
        call :log_error "请指定用户名和密码"
        echo 用法: %~nx0 users create ^<username^> ^<password^>
        exit /b 1
    )
    if "!password!"=="" (
        call :log_error "请指定密码"
        echo 用法: %~nx0 users create ^<username^> ^<password^>
        exit /b 1
    )
    
    call :log_step "创建 SASL 用户: !username!"
    docker exec kafka-broker-sasl /opt/kafka/bin/kafka-configs.sh --zookeeper zookeeper:2181 --alter --add-config "SCRAM-SHA-256=[password=!password!]" --entity-type users --entity-name "!username!"
) else if "%action%"=="delete" (
    set username=%~3
    if "!username!"=="" (
        call :log_error "请指定用户名"
        echo 用法: %~nx0 users delete ^<username^>
        exit /b 1
    )
    
    call :log_step "删除 SASL 用户: !username!"
    docker exec kafka-broker-sasl /opt/kafka/bin/kafka-configs.sh --zookeeper zookeeper:2181 --alter --delete-config "SCRAM-SHA-256" --entity-type users --entity-name "!username!"
) else (
    call :log_error "未知的用户操作: %action%"
    echo 可用操作: list, create, delete
    exit /b 1
)
goto :eof

REM ACL 管理
:manage_acl
set action=%~2
if "%action%"=="" set action=list

if "%action%"=="list" (
    call :log_step "列出所有 ACL 规则..."
    docker exec kafka-broker-sasl /opt/kafka/bin/kafka-acls.sh --bootstrap-server localhost:9092 --command-config /opt/kafka/config/sasl/client.properties --list
) else if "%action%"=="add" (
    set principal=%~3
    set operation=%~4
    set resource=%~5
    if "!principal!"=="" (
        call :log_error "请指定完整的 ACL 参数"
        echo 用法: %~nx0 acl add ^<principal^> ^<operation^> ^<resource^>
        echo 示例: %~nx0 acl add User:producer Write Topic:my-topic
        exit /b 1
    )
    
    call :log_step "添加 ACL 规则..."
    docker exec kafka-broker-sasl /opt/kafka/bin/kafka-acls.sh --bootstrap-server localhost:9092 --command-config /opt/kafka/config/sasl/client.properties --add --allow-principal "!principal!" --operation "!operation!" --topic "!resource!"
) else (
    call :log_error "未知的 ACL 操作: %action%"
    echo 可用操作: list, add
    exit /b 1
)
goto :eof

REM 主题管理
:manage_topics
set action=%~2
if "%action%"=="" set action=list

if "%action%"=="list" (
    call :log_step "列出所有主题..."
    docker exec kafka-broker-sasl /opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092 --command-config /opt/kafka/config/sasl/client.properties
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
    docker exec kafka-broker-sasl /opt/kafka/bin/kafka-topics.sh --create --topic "!topic_name!" --bootstrap-server localhost:9092 --command-config /opt/kafka/config/sasl/client.properties --partitions !partitions! --replication-factor !replication!
) else if "%action%"=="delete" (
    set topic_name=%~3
    if "!topic_name!"=="" (
        call :log_error "请指定主题名称"
        echo 用法: %~nx0 topics delete ^<topic-name^>
        exit /b 1
    )
    
    call :log_step "删除主题: !topic_name!"
    docker exec kafka-broker-sasl /opt/kafka/bin/kafka-topics.sh --delete --topic "!topic_name!" --bootstrap-server localhost:9092 --command-config /opt/kafka/config/sasl/client.properties
) else if "%action%"=="describe" (
    set topic_name=%~3
    if "!topic_name!"=="" (
        call :log_step "描述所有主题..."
        docker exec kafka-broker-sasl /opt/kafka/bin/kafka-topics.sh --describe --bootstrap-server localhost:9092 --command-config /opt/kafka/config/sasl/client.properties
    ) else (
        call :log_step "描述主题: !topic_name!"
        docker exec kafka-broker-sasl /opt/kafka/bin/kafka-topics.sh --describe --topic "!topic_name!" --bootstrap-server localhost:9092 --command-config /opt/kafka/config/sasl/client.properties
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
if exist "%ENV_FILE%" (
    docker-compose -f "%COMPOSE_FILE%" --env-file "%ENV_FILE%" -p "%PROJECT_NAME%" ps | findstr "Up" >nul 2>&1
) else (
    docker-compose -f "%COMPOSE_FILE%" -p "%PROJECT_NAME%" ps | findstr "Up" >nul 2>&1
)
if errorlevel 1 (
    call :log_error "部分或全部容器未运行"
    set all_healthy=false
) else (
    call :log_success "所有容器正在运行"
)

REM 检查 Zookeeper
call :log_info "检查 Zookeeper 连接..."
docker exec kafka-zookeeper-sasl nc -z localhost 2181 >nul 2>&1
if errorlevel 1 (
    call :log_error "Zookeeper 连接失败"
    set all_healthy=false
) else (
    call :log_success "Zookeeper 连接正常"
)

REM 检查 Kafka SASL
call :log_info "检查 Kafka SASL 连接..."
docker exec kafka-broker-sasl /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --command-config /opt/kafka/config/sasl/client.properties --list >nul 2>&1
if errorlevel 1 (
    call :log_error "Kafka SASL 连接失败"
    set all_healthy=false
) else (
    call :log_success "Kafka SASL 连接正常"
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
call :log_success "=== Kafka SASL 安全集群访问信息 ==="
echo Kafka Broker (内部):  kafka:9092
echo Kafka Broker (外部):  localhost:9093
echo Zookeeper:           zookeeper:2181
echo Kafka UI:            http://localhost:8080
echo Schema Registry:     http://localhost:8081
echo Kafka Connect:       http://localhost:8083
echo.
echo 认证信息:
echo   协议: SASL_PLAINTEXT
echo   机制: SCRAM-SHA-256
echo   管理员: admin / admin-secret
echo.
echo 常用命令:
echo   查看状态:     %~nx0 status
echo   查看日志:     %~nx0 logs
echo   测试连接:     %~nx0 test
echo   管理用户:     %~nx0 users list
echo   管理ACL:      %~nx0 acl list
echo   管理主题:     %~nx0 topics list
echo.
goto :eof

REM 显示安全信息
:show_security_info
echo.
call :log_security "=== 安全配置信息 ==="
echo 认证机制: SASL/SCRAM-SHA-256
echo 访问控制: ACL (默认拒绝)
echo 超级用户: admin
echo 加密传输: 明文 (SASL_PLAINTEXT)
echo.
echo 安全建议:
echo   1. 修改默认密码
echo   2. 定期轮换密码
echo   3. 配置适当的 ACL 规则
echo   4. 监控访问日志
echo   5. 限制网络访问
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
) else if "%command%"=="users" (
    call :manage_users %*
) else if "%command%"=="acl" (
    call :manage_acl %*
) else if "%command%"=="ui" (
    call :open_ui
) else if "%command%"=="health" (
    call :health_check
) else if "%command%"=="security" (
    call :security_check
) else if "%command%"=="setup-env" (
    call :setup_env
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