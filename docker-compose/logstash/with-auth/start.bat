@echo off
setlocal enabledelayedexpansion

REM Logstash 企业级部署启动脚本 (Windows)
REM 包含完整的SSL证书管理和认证配置

set "SCRIPT_DIR=%~dp0"
set "PROJECT_NAME=logstash-auth"
set "COMPOSE_FILE=%SCRIPT_DIR%docker-compose.yaml"
set "ENV_FILE=%SCRIPT_DIR%.env"
set "ENV_TEMPLATE=%SCRIPT_DIR%env-template.txt"
set "CERTS_DIR=%SCRIPT_DIR%certs"

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

openssl version >nul 2>&1
if errorlevel 1 (
    call :log_error "OpenSSL 未安装或不在 PATH 中"
    call :log_info "请安装 OpenSSL 或使用 Git Bash"
    exit /b 1
)

call :log_success "系统依赖检查完成"
goto :eof

:check_env_file
call :log_info "检查环境变量配置..."

if not exist "%ENV_FILE%" (
    call :log_warning ".env 文件不存在，正在从模板创建..."
    
    if exist "%ENV_TEMPLATE%" (
        copy "%ENV_TEMPLATE%" "%ENV_FILE%" >nul
        call :log_warning "请编辑 %ENV_FILE% 文件并设置所有必需的密码"
        
        call :log_info "建议的随机密码："
        echo   ELASTIC_PASSWORD=请使用 openssl rand -base64 32 生成
        echo   KIBANA_PASSWORD=请使用 openssl rand -base64 32 生成
        echo   LOGSTASH_KEYSTORE_PASS=请使用 openssl rand -base64 32 生成
        echo   KIBANA_ENCRYPTION_KEY=请使用 openssl rand -hex 32 生成
        
        exit /b 1
    ) else (
        call :log_error "环境变量模板文件不存在: %ENV_TEMPLATE%"
        exit /b 1
    )
)

call :log_success "环境变量配置检查完成"
goto :eof

:generate_certificates
call :log_info "检查SSL证书..."

if exist "%CERTS_DIR%\ca\ca.crt" (
    call :log_info "SSL证书已存在，跳过生成"
    goto :eof
)

call :log_info "生成SSL证书..."

REM 创建证书目录
mkdir "%CERTS_DIR%\ca" 2>nul
mkdir "%CERTS_DIR%\elasticsearch" 2>nul
mkdir "%CERTS_DIR%\kibana" 2>nul
mkdir "%CERTS_DIR%\logstash" 2>nul

REM 生成CA私钥和证书
openssl genrsa -out "%CERTS_DIR%\ca\ca.key" 4096
openssl req -new -x509 -days 365 -key "%CERTS_DIR%\ca\ca.key" -out "%CERTS_DIR%\ca\ca.crt" -subj "/C=CN/ST=Beijing/L=Beijing/O=Logstash/OU=IT/CN=Logstash-CA"

REM 为每个服务生成证书
for %%s in (elasticsearch kibana logstash) do (
    call :log_info "生成 %%s 证书..."
    
    openssl genrsa -out "%CERTS_DIR%\%%s\%%s.key" 2048
    openssl req -new -key "%CERTS_DIR%\%%s\%%s.key" -out "%CERTS_DIR%\%%s\%%s.csr" -subj "/C=CN/ST=Beijing/L=Beijing/O=Logstash/OU=IT/CN=%%s"
    openssl x509 -req -days 365 -in "%CERTS_DIR%\%%s\%%s.csr" -CA "%CERTS_DIR%\ca\ca.crt" -CAkey "%CERTS_DIR%\ca\ca.key" -CAcreateserial -out "%CERTS_DIR%\%%s\%%s.crt"
    
    del "%CERTS_DIR%\%%s\%%s.csr" 2>nul
)

call :log_success "SSL证书生成完成"
goto :eof

:start_services
call :log_info "启动 Logstash 企业级服务..."

cd /d "%SCRIPT_DIR%"

docker-compose --version >nul 2>&1
if not errorlevel 1 (
    docker-compose --env-file "%ENV_FILE%" up -d
) else (
    docker compose --env-file "%ENV_FILE%" up -d
)

call :log_success "Logstash 企业级服务启动完成"
goto :eof

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
echo   - Elasticsearch: https://localhost:9200
echo   - Kibana: https://localhost:5601
echo   - Logstash API: https://localhost:9600
echo   - Logstash Beats: ssl://localhost:5044
goto :eof

:stop_services
call :log_info "停止 Logstash 企业级服务..."

cd /d "%SCRIPT_DIR%"

docker-compose --version >nul 2>&1
if not errorlevel 1 (
    docker-compose down
) else (
    docker compose down
)

call :log_success "Logstash 企业级服务已停止"
goto :eof

:show_help
echo Logstash 企业级部署管理脚本 (Windows)
echo.
echo 用法: %~nx0 [选项]
echo.
echo 选项:
echo   start     启动所有服务
echo   stop      停止所有服务
echo   status    显示服务状态
echo   help      显示此帮助信息
echo.
echo 注意:
echo   - 需要安装 OpenSSL (可通过 Git Bash 获得)
echo   - 首次运行前请编辑 .env 文件设置密码
goto :eof

:main
set "action=%~1"
if "%action%"=="" set "action=start"

if "%action%"=="start" (
    call :check_dependencies
    call :check_env_file
    call :generate_certificates
    call :start_services
    call :show_status
) else if "%action%"=="stop" (
    call :stop_services
) else if "%action%"=="status" (
    call :show_status
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