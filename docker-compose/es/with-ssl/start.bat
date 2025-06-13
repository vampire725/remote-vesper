@echo off
REM ===========================================
REM Elasticsearch SSL 安全环境启动脚本 (Windows)
REM 文件名: start.bat
REM 功能: 启动带SSL加密和认证的 Elasticsearch 服务
REM 特点: 完整SSL加密，用户认证，生产级安全
REM ===========================================

setlocal enabledelayedexpansion

REM ==========================================
REM 颜色定义 (Windows)
REM ==========================================
set "RED=[91m"
set "GREEN=[92m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "PURPLE=[95m"
set "CYAN=[96m"
set "NC=[0m"

REM ==========================================
REM 帮助信息
REM ==========================================
if "%1"=="--help" goto :show_help
if "%1"=="-h" goto :show_help
if "%1"=="--status" goto :show_status
if "%1"=="-s" goto :show_status
if "%1"=="--logs" goto :show_logs
if "%1"=="-l" goto :show_logs
if "%1"=="--test" goto :test_connection
if "%1"=="-t" goto :test_connection
if "%1"=="--setup" goto :setup_certificates
if "%1"=="--stop" goto :stop_service
if "%1"=="--restart" goto :restart_service
if "%1"=="--clean" goto :clean_service
if "%1"=="--reset-certs" goto :reset_certificates

REM 默认启动服务
goto :start_service

:show_help
echo.
echo %CYAN%Elasticsearch SSL 安全环境启动脚本%NC%
echo.
echo 用法: %0 [选项]
echo.
echo 选项:
echo     -h, --help          显示帮助信息
echo     -s, --status        显示服务状态
echo     -l, --logs          显示服务日志
echo     -t, --test          测试连接
echo     --setup             仅运行证书生成
echo     --stop              停止服务
echo     --restart           重启服务
echo     --clean             清理数据并重启
echo     --reset-certs       重新生成证书
echo.
echo 特点:
echo     - 完整SSL加密
echo     - 用户认证保护
echo     - 自动证书生成
echo     - 生产级安全配置
echo.
echo 示例:
echo     %0                  # 启动服务
echo     %0 --status         # 查看状态
echo     %0 --test           # 测试连接
echo     %0 --clean          # 清理重启
echo.
echo 安全提示:
echo     - 首次运行前请设置 .env 文件中的密码
echo     - 使用 HTTPS 访问: https://localhost:9200
echo     - 默认用户名: elastic
echo.
goto :eof

REM ==========================================
REM 环境检查函数
REM ==========================================
:check_prerequisites
echo %BLUE%[INFO]%NC% 检查前置条件...

REM 检查 Docker
docker --version >nul 2>&1
if errorlevel 1 (
    echo %RED%[ERROR]%NC% Docker 未安装，请先安装 Docker
    exit /b 1
)

REM 检查 Docker 是否运行
docker info >nul 2>&1
if errorlevel 1 (
    echo %RED%[ERROR]%NC% Docker 未运行，请先启动 Docker
    exit /b 1
)

REM 检查 Docker Compose
docker-compose --version >nul 2>&1
if errorlevel 1 (
    echo %RED%[ERROR]%NC% Docker Compose 未安装
    exit /b 1
)

REM 检查配置文件
if not exist "docker-compose.yaml" (
    echo %RED%[ERROR]%NC% 配置文件 docker-compose.yaml 不存在
    exit /b 1
)

REM 检查环境变量文件
if not exist ".env" (
    echo %YELLOW%[WARNING]%NC% .env 文件不存在
    echo %BLUE%[INFO]%NC% 请根据 env-template.txt 创建 .env 文件并设置密码
    
    if exist "env-template.txt" (
        echo %BLUE%[INFO]%NC% 创建默认 .env 文件...
        findstr "^ELASTIC_PASSWORD ^KIBANA_PASSWORD" env-template.txt > .env
        echo %YELLOW%[WARNING]%NC% 已创建默认 .env 文件，请修改其中的密码！
    ) else (
        echo %RED%[ERROR]%NC% 缺少环境变量配置，请手动创建 .env 文件
        exit /b 1
    )
)

echo %GREEN%[SUCCESS]%NC% 前置条件检查通过
goto :eof

REM ==========================================
REM 网络准备函数
REM ==========================================
:prepare_networks
echo %BLUE%[INFO]%NC% 准备 Docker 网络...

REM 创建 logging-network 网络
docker network ls | findstr "logging-network" >nul
if errorlevel 1 (
    docker network create logging-network
    echo %GREEN%[SUCCESS]%NC% 创建 logging-network 网络
) else (
    echo %BLUE%[INFO]%NC% logging-network 网络已存在
)

REM 创建 kafka 网络
docker network ls | findstr "kafka" >nul
if errorlevel 1 (
    docker network create kafka
    echo %GREEN%[SUCCESS]%NC% 创建 kafka 网络
) else (
    echo %BLUE%[INFO]%NC% kafka 网络已存在
)
goto :eof

REM ==========================================
REM 证书生成函数
REM ==========================================
:setup_certificates
echo %CYAN%========================================%NC%
echo %CYAN%生成 SSL 证书%NC%
echo %CYAN%========================================%NC%

call :check_prerequisites
if errorlevel 1 exit /b 1

call :prepare_networks
if errorlevel 1 exit /b 1

echo %BLUE%[INFO]%NC% 启动证书生成服务...
docker-compose up setup

if not errorlevel 1 (
    echo %GREEN%[SUCCESS]%NC% SSL 证书生成完成
) else (
    echo %RED%[ERROR]%NC% SSL 证书生成失败
    exit /b 1
)
goto :eof

REM ==========================================
REM 启动服务函数
REM ==========================================
:start_service
echo %CYAN%========================================%NC%
echo %CYAN%启动 Elasticsearch SSL 安全环境%NC%
echo %CYAN%========================================%NC%

call :check_prerequisites
if errorlevel 1 exit /b 1

call :prepare_networks
if errorlevel 1 exit /b 1

echo %BLUE%[INFO]%NC% 启动所有服务...
docker-compose up -d

echo %BLUE%[INFO]%NC% 等待服务启动...
timeout /t 15 /nobreak >nul

REM 健康检查
set attempt=1
set max_attempts=15

:health_check_loop
echo %BLUE%[INFO]%NC% 健康检查尝试 !attempt!/!max_attempts!...

REM 简化的健康检查（Windows 下 curl 命令较复杂）
docker-compose ps | findstr "Up" | findstr "es01" >nul
if not errorlevel 1 (
    echo %GREEN%[SUCCESS]%NC% Elasticsearch 服务启动成功！
    call :show_service_info
    goto :eof
) else (
    if !attempt! equ !max_attempts! (
        echo %RED%[ERROR]%NC% 服务启动失败，请检查日志
        docker-compose logs --tail=20
        exit /b 1
    )
    
    echo %BLUE%[INFO]%NC% 等待 15 秒后重试...
    timeout /t 15 /nobreak >nul
)

set /a attempt+=1
goto :health_check_loop

REM ==========================================
REM 显示服务信息
REM ==========================================
:show_service_info
echo %CYAN%========================================%NC%
echo %CYAN%服务信息%NC%
echo %CYAN%========================================%NC%
echo.
echo %GREEN%Elasticsearch SSL 安全环境启动成功！%NC%
echo.
echo %BLUE%服务访问信息:%NC%
echo - Elasticsearch HTTPS API: %YELLOW%https://localhost:9200%NC%
echo - Kibana HTTPS 界面: %YELLOW%https://localhost:5601%NC%
echo - 用户名: %YELLOW%elastic%NC%
echo - 密码: %YELLOW%请查看 .env 文件%NC%
echo.
echo %BLUE%SSL 证书信息:%NC%
echo - CA 证书: 自动生成并存储在 Docker 卷中
echo - 节点证书: 自动为 es01 和 kibana 生成
echo - 证书验证: 启用完整证书验证
echo.
echo %BLUE%安全连接示例:%NC%
echo # 获取 CA 证书（用于客户端连接）
echo docker-compose exec es01 cat /usr/share/elasticsearch/config/certs/ca/ca.crt ^> ca.crt
echo.
echo # 使用 CA 证书访问 API（需要设置密码）
echo curl --cacert ca.crt -u elastic:YOUR_PASSWORD https://localhost:9200/_cluster/health?pretty
echo.
echo %BLUE%管理命令:%NC%
echo start.bat --status      # 查看服务状态
echo start.bat --logs        # 查看服务日志
echo start.bat --test        # 测试连接
echo start.bat --stop        # 停止服务
echo.
echo %GREEN%安全提示:%NC%
echo - 所有通信均已加密
echo - 启用了用户认证
echo - 证书自动管理
echo - 适合生产环境使用
echo.
goto :eof

REM ==========================================
REM 显示服务状态
REM ==========================================
:show_status
echo %CYAN%========================================%NC%
echo %CYAN%Elasticsearch SSL 服务状态%NC%
echo %CYAN%========================================%NC%

echo %BLUE%[INFO]%NC% Docker Compose 服务状态:
docker-compose ps
echo.

REM 容器资源使用情况
docker ps | findstr "es01" >nul
if not errorlevel 1 (
    echo %BLUE%[INFO]%NC% 容器资源使用情况:
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" | findstr "es01\|kibana"
    echo.
    
    echo %BLUE%[INFO]%NC% 集群状态: 请使用 --test 选项进行详细测试
) else (
    echo %YELLOW%[WARNING]%NC% 没有运行中的 Elasticsearch 容器
)
goto :eof

REM ==========================================
REM 测试连接函数
REM ==========================================
:test_connection
echo %CYAN%========================================%NC%
echo %CYAN%测试 Elasticsearch SSL 连接%NC%
echo %CYAN%========================================%NC%

REM 检查服务是否运行
docker ps | findstr "es01" >nul
if errorlevel 1 (
    echo %RED%[ERROR]%NC% Elasticsearch 服务未运行
    exit /b 1
)

echo %BLUE%[INFO]%NC% 检查服务状态...
docker-compose ps | findstr "Up" | findstr "es01" >nul
if not errorlevel 1 (
    echo %GREEN%[SUCCESS]%NC% Elasticsearch 容器运行正常
) else (
    echo %RED%[ERROR]%NC% Elasticsearch 容器状态异常
    exit /b 1
)

echo %BLUE%[INFO]%NC% 检查端口连接...
netstat -an | findstr "9200" | findstr "LISTENING" >nul
if not errorlevel 1 (
    echo %GREEN%[SUCCESS]%NC% 端口 9200 监听正常
) else (
    echo %RED%[ERROR]%NC% 端口 9200 未监听
    exit /b 1
)

echo %GREEN%[SUCCESS]%NC% 基础连接测试完成！
echo.
echo %BLUE%[INFO]%NC% 连接信息:
echo URL: https://localhost:9200
echo 用户名: elastic
echo 密码: 请查看 .env 文件
echo Kibana: https://localhost:5601
echo.
echo %YELLOW%[提示]%NC% 请使用浏览器或支持 HTTPS 的工具访问服务
goto :eof

REM ==========================================
REM 显示日志
REM ==========================================
:show_logs
echo %BLUE%[INFO]%NC% 显示服务日志 (Ctrl+C 退出):
docker-compose logs -f
goto :eof

REM ==========================================
REM 停止服务
REM ==========================================
:stop_service
echo %BLUE%[INFO]%NC% 停止服务...
docker-compose down
echo %GREEN%[SUCCESS]%NC% 服务已停止
goto :eof

REM ==========================================
REM 重启服务
REM ==========================================
:restart_service
echo %BLUE%[INFO]%NC% 重启服务...
docker-compose restart
echo %GREEN%[SUCCESS]%NC% 服务已重启
goto :eof

REM ==========================================
REM 清理服务
REM ==========================================
:clean_service
echo %BLUE%[INFO]%NC% 清理数据并重启...
docker-compose down -v
call :start_service
goto :eof

REM ==========================================
REM 重置证书
REM ==========================================
:reset_certificates
echo %BLUE%[INFO]%NC% 重新生成证书...
docker-compose down
for /f "tokens=*" %%i in ('docker volume ls -q ^| findstr certs') do docker volume rm %%i 2>nul
call :start_service
goto :eof 