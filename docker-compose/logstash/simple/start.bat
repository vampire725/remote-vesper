@echo off
setlocal enabledelayedexpansion

REM Logstash 简单部署启动脚本 (Windows)
REM 适用于开发和测试环境

set "SCRIPT_DIR=%~dp0"
set "PROJECT_NAME=logstash-simple"
set "COMPOSE_FILE=%SCRIPT_DIR%docker-compose.yaml"
set "NETWORK_NAME=logging-network"

REM 颜色定义 (Windows 10+)
set "RED=[91m"
set "GREEN=[92m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "NC=[0m"

goto main

:log_info
echo %BLUE%[INFO]%NC% %~1
goto :eof

:log_success
echo %GREEN%[SUCCESS]%NC% %~1
goto :eof

:log_warning
echo %YELLOW%[WARNING]%NC% %~1
goto :eof

:log_error
echo %RED%[ERROR]%NC% %~1
goto :eof

:check_dependencies
call :log_info "检查系统依赖..."

docker --version >nul 2>&1
if errorlevel 1 (
    call :log_error "Docker 未安装或不在 PATH 中"
    exit /b 1
)

docker-compose --version >nul 2>&1
if errorlevel 1 (
    docker compose version >nul 2>&1
    if errorlevel 1 (
        call :log_error "Docker Compose 未安装或不在 PATH 中"
        exit /b 1
    )
)

call :log_success "系统依赖检查完成"
goto :eof

:check_ports
call :log_info "检查端口占用情况..."

set "ports=5044 9600 5000 5001 8080"
set "occupied_ports="

for %%p in (%ports%) do (
    netstat -an | findstr ":%%p " >nul 2>&1
    if not errorlevel 1 (
        set "occupied_ports=!occupied_ports! %%p"
    )
)

if not "!occupied_ports!"=="" (
    call :log_warning "以下端口已被占用:!occupied_ports!"
    call :log_warning "请确保这些端口可用或修改 docker-compose.yaml 中的端口映射"
) else (
    call :log_success "端口检查完成，所有端口可用"
)
goto :eof

:create_network
call :log_info "创建 Docker 网络..."

docker network ls | findstr "%NETWORK_NAME%" >nul 2>&1
if errorlevel 1 (
    docker network create %NETWORK_NAME% --driver bridge
    call :log_success "网络 %NETWORK_NAME% 创建成功"
) else (
    call :log_info "网络 %NETWORK_NAME% 已存在"
)
goto :eof

:start_services
call :log_info "启动 Logstash 服务..."

cd /d "%SCRIPT_DIR%"

docker-compose --version >nul 2>&1
if not errorlevel 1 (
    docker-compose up -d
) else (
    docker compose up -d
)

call :log_success "Logstash 服务启动完成"
goto :eof

:wait_for_services
call :log_info "等待 Logstash 服务就绪..."

set /a max_attempts=30
set /a attempt=1

:wait_loop
if %attempt% gtr %max_attempts% (
    call :log_error "Logstash 服务启动超时"
    exit /b 1
)

curl -s -f http://localhost:9600/_node/stats >nul 2>&1
if not errorlevel 1 (
    call :log_success "Logstash 服务已就绪"
    goto :eof
)

call :log_info "等待 Logstash 启动... (%attempt%/%max_attempts%)"
timeout /t 10 /nobreak >nul
set /a attempt+=1
goto wait_loop

:show_status
call :log_info "服务状态:"

cd /d "%SCRIPT_DIR%"

docker-compose --version >nul 2>&1
if not errorlevel 1 (
    docker-compose ps
) else (
    docker compose ps
)

echo.
call :log_info "服务访问地址:"
echo   - Logstash API: http://localhost:9600
echo   - Beats 输入端口: 5044
echo   - TCP 输入端口: 5000
echo   - UDP 输入端口: 5001
echo   - HTTP 输入端口: 8080
goto :eof

:show_logs
call :log_info "显示 Logstash 日志..."

cd /d "%SCRIPT_DIR%"

docker-compose --version >nul 2>&1
if not errorlevel 1 (
    docker-compose logs -f logstash
) else (
    docker compose logs -f logstash
)
goto :eof

:stop_services
call :log_info "停止 Logstash 服务..."

cd /d "%SCRIPT_DIR%"

docker-compose --version >nul 2>&1
if not errorlevel 1 (
    docker-compose down
) else (
    docker compose down
)

call :log_success "Logstash 服务已停止"
goto :eof

:restart_services
call :log_info "重启 Logstash 服务..."
call :stop_services
timeout /t 5 /nobreak >nul
call :start_services
call :wait_for_services
call :show_status
goto :eof

:cleanup
call :log_warning "这将删除所有 Logstash 数据和日志！"
set /p confirm="确认继续？(y/N): "

if /i "!confirm!"=="y" (
    call :log_info "清理 Logstash 数据..."
    
    cd /d "%SCRIPT_DIR%"
    
    docker-compose --version >nul 2>&1
    if not errorlevel 1 (
        docker-compose down -v
    ) else (
        docker compose down -v
    )
    
    REM 删除命名卷
    docker volume rm logstash_simple_logs logstash_simple_data >nul 2>&1
    
    call :log_success "数据清理完成"
) else (
    call :log_info "取消清理操作"
)
goto :eof

:test_connection
call :log_info "测试 Logstash 连接..."

REM 测试 API 端点
curl -s -f http://localhost:9600/_node/stats >nul 2>&1
if not errorlevel 1 (
    call :log_success "Logstash API 连接正常"
) else (
    call :log_error "Logstash API 连接失败"
    exit /b 1
)

REM 测试 HTTP 输入
call :log_info "测试 HTTP 输入端点..."
for /f "tokens=1-3 delims=/ " %%a in ('date /t') do set "current_date=%%c-%%a-%%b"
for /f "tokens=1-2 delims=: " %%a in ('time /t') do set "current_time=%%a:%%b"
set "timestamp=%current_date%T%current_time%"

curl -s -X POST -H "Content-Type: application/json" -d "{\"message\":\"test\",\"timestamp\":\"%timestamp%\"}" http://localhost:8080 >nul 2>&1
if not errorlevel 1 (
    call :log_success "HTTP 输入端点测试成功"
) else (
    call :log_warning "HTTP 输入端点测试失败（可能端口未开放）"
)

REM 显示节点信息
call :log_info "Logstash 节点信息:"
curl -s http://localhost:9600/_node/stats
goto :eof

:show_help
echo Logstash 简单部署管理脚本 (Windows)
echo.
echo 用法: %~nx0 [选项]
echo.
echo 选项:
echo   start     启动 Logstash 服务
echo   stop      停止 Logstash 服务
echo   restart   重启 Logstash 服务
echo   status    显示服务状态
echo   logs      查看服务日志
echo   test      测试服务连接
echo   cleanup   清理所有数据（危险操作）
echo   help      显示此帮助信息
echo.
echo 示例:
echo   %~nx0 start    # 启动服务
echo   %~nx0 logs     # 查看日志
echo   %~nx0 test     # 测试连接
goto :eof

:main
set "action=%~1"
if "%action%"=="" set "action=start"

if "%action%"=="start" (
    call :check_dependencies
    call :check_ports
    call :create_network
    call :start_services
    call :wait_for_services
    call :show_status
) else if "%action%"=="stop" (
    call :stop_services
) else if "%action%"=="restart" (
    call :restart_services
) else if "%action%"=="status" (
    call :show_status
) else if "%action%"=="logs" (
    call :show_logs
) else if "%action%"=="test" (
    call :test_connection
) else if "%action%"=="cleanup" (
    call :cleanup
) else if "%action%"=="help" (
    call :show_help
) else if "%action%"=="--help" (
    call :show_help
) else if "%action%"=="-h" (
    call :show_help
) else (
    call :log_error "未知选项: %action%"
    call :show_help
    exit /b 1
)

endlocal 