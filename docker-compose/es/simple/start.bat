@echo off
REM ===========================================
REM Elasticsearch 简化环境启动脚本 (Windows)
REM 文件名: start.bat
REM 功能: 启动简化的 Elasticsearch 服务
REM 特点: 无SSL，无认证，适合开发测试
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
if "%1"=="--stop" goto :stop_service
if "%1"=="--restart" goto :restart_service
if "%1"=="--clean" goto :clean_service

REM 默认启动服务
goto :start_service

:show_help
echo.
echo %CYAN%Elasticsearch 简化环境启动脚本%NC%
echo.
echo 用法: %0 [选项]
echo.
echo 选项:
echo     -h, --help          显示帮助信息
echo     -s, --status        显示服务状态
echo     -l, --logs          显示服务日志
echo     -t, --test          测试连接
echo     --stop              停止服务
echo     --restart           重启服务
echo     --clean             清理数据并重启
echo.
echo 特点:
echo     - 无SSL加密
echo     - 无用户认证
echo     - 单节点模式
echo     - 适合开发测试
echo.
echo 示例:
echo     %0                  # 启动服务
echo     %0 --status         # 查看状态
echo     %0 --test           # 测试连接
echo     %0 --clean          # 清理重启
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
REM 启动服务函数
REM ==========================================
:start_service
echo %CYAN%========================================%NC%
echo %CYAN%启动 Elasticsearch 简化环境%NC%
echo %CYAN%========================================%NC%

call :check_prerequisites
if errorlevel 1 exit /b 1

call :prepare_networks
if errorlevel 1 exit /b 1

echo %BLUE%[INFO]%NC% 启动 Elasticsearch 服务...
docker-compose up -d

echo %BLUE%[INFO]%NC% 等待服务启动...
timeout /t 10 /nobreak >nul

REM 健康检查
set attempt=1
set max_attempts=10

:health_check_loop
echo %BLUE%[INFO]%NC% 健康检查尝试 !attempt!/!max_attempts!...

curl -s http://localhost:9200/_cluster/health >nul 2>&1
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
    
    echo %BLUE%[INFO]%NC% 等待 10 秒后重试...
    timeout /t 10 /nobreak >nul
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
echo %GREEN%Elasticsearch 简化环境启动成功！%NC%
echo.
echo %BLUE%服务访问信息:%NC%
echo - HTTP API: %YELLOW%http://localhost:9200%NC%
echo - 集群健康: %YELLOW%http://localhost:9200/_cluster/health%NC%
echo - 节点信息: %YELLOW%http://localhost:9200/_nodes%NC%
echo.
echo %BLUE%常用命令:%NC%
echo # 查看集群状态
echo curl http://localhost:9200/_cluster/health?pretty
echo.
echo # 查看节点信息
echo curl http://localhost:9200/_nodes?pretty
echo.
echo # 创建索引
echo curl -X PUT http://localhost:9200/test-index
echo.
echo # 查看所有索引
echo curl http://localhost:9200/_cat/indices?v
echo.
echo %BLUE%管理命令:%NC%
echo start.bat --status      # 查看服务状态
echo start.bat --logs        # 查看服务日志
echo start.bat --test        # 测试连接
echo start.bat --stop        # 停止服务
echo.
echo %YELLOW%注意: 此配置禁用了SSL和认证，仅适用于开发环境%NC%
echo.
goto :eof

REM ==========================================
REM 显示服务状态
REM ==========================================
:show_status
echo %CYAN%========================================%NC%
echo %CYAN%Elasticsearch 服务状态%NC%
echo %CYAN%========================================%NC%

echo %BLUE%[INFO]%NC% Docker Compose 服务状态:
docker-compose ps
echo.

REM 容器资源使用情况
docker ps | findstr "elasticsearch" >nul
if not errorlevel 1 (
    echo %BLUE%[INFO]%NC% 容器资源使用情况:
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" | findstr elasticsearch
    echo.
    
    REM 集群健康状态
    echo %BLUE%[INFO]%NC% 集群健康状态:
    curl -s http://localhost:9200/_cluster/health?pretty 2>nul
    if not errorlevel 1 (
        echo %GREEN%[SUCCESS]%NC% 集群连接正常
    ) else (
        echo %RED%[ERROR]%NC% 集群连接失败
    )
) else (
    echo %YELLOW%[WARNING]%NC% 没有运行中的 Elasticsearch 容器
)
goto :eof

REM ==========================================
REM 测试连接函数
REM ==========================================
:test_connection
echo %CYAN%========================================%NC%
echo %CYAN%测试 Elasticsearch 连接%NC%
echo %CYAN%========================================%NC%

REM 基础连接测试
echo %BLUE%[INFO]%NC% 测试基础连接...
curl -s http://localhost:9200 >nul
if not errorlevel 1 (
    echo %GREEN%[SUCCESS]%NC% 基础连接测试通过
) else (
    echo %RED%[ERROR]%NC% 基础连接测试失败
    exit /b 1
)

REM 集群健康测试
echo %BLUE%[INFO]%NC% 测试集群健康...
for /f "tokens=2 delims=:" %%a in ('curl -s http://localhost:9200/_cluster/health ^| findstr "status"') do (
    set health=%%a
    set health=!health:"=!
    set health=!health:,=!
    set health=!health: =!
)

if "!health!"=="green" (
    echo %GREEN%[SUCCESS]%NC% 集群健康状态: !health!
) else if "!health!"=="yellow" (
    echo %GREEN%[SUCCESS]%NC% 集群健康状态: !health!
) else (
    echo %RED%[ERROR]%NC% 集群健康状态异常: !health!
    exit /b 1
)

REM 创建测试索引
echo %BLUE%[INFO]%NC% 创建测试索引...
curl -s -X PUT http://localhost:9200/connection-test >nul
if not errorlevel 1 (
    echo %GREEN%[SUCCESS]%NC% 测试索引创建成功
) else (
    echo %RED%[ERROR]%NC% 测试索引创建失败
    exit /b 1
)

REM 删除测试索引
echo %BLUE%[INFO]%NC% 清理测试索引...
curl -s -X DELETE http://localhost:9200/connection-test >nul

echo %GREEN%[SUCCESS]%NC% 连接测试完成！
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