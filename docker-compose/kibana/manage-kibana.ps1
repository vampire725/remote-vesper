# ===========================================
# Kibana 管理脚本 (PowerShell)
# 功能: 管理 Kibana 认证版本和无认证版本
# 版本: 1.0.0
# ===========================================

param(
    [Parameter(Position=0)]
    [ValidateSet("start", "stop", "restart", "status", "logs", "clean", "info", "help")]
    [string]$Command = "help",
    
    [Parameter(Position=1)]
    [ValidateSet("auth", "no-auth", "both")]
    [string]$Version = ""
)

# 颜色定义
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Title {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Cyan
}

# 显示帮助信息
function Show-Help {
    Write-Title "=== Kibana 管理脚本 (PowerShell) ==="
    Write-Host ""
    Write-Host "用法: .\manage-kibana.ps1 [命令] [版本]"
    Write-Host ""
    Write-Host "命令:"
    Write-Host "  start    - 启动 Kibana 服务"
    Write-Host "  stop     - 停止 Kibana 服务"
    Write-Host "  restart  - 重启 Kibana 服务"
    Write-Host "  status   - 查看服务状态"
    Write-Host "  logs     - 查看服务日志"
    Write-Host "  clean    - 清理服务和数据"
    Write-Host "  info     - 显示服务信息"
    Write-Host "  help     - 显示帮助信息"
    Write-Host ""
    Write-Host "版本:"
    Write-Host "  auth     - 认证版本 (生产环境)"
    Write-Host "  no-auth  - 无认证版本 (开发环境)"
    Write-Host "  both     - 两个版本 (仅适用于某些命令)"
    Write-Host ""
    Write-Host "示例:"
    Write-Host "  .\manage-kibana.ps1 start auth      # 启动认证版本"
    Write-Host "  .\manage-kibana.ps1 start no-auth   # 启动无认证版本"
    Write-Host "  .\manage-kibana.ps1 stop both       # 停止所有版本"
    Write-Host "  .\manage-kibana.ps1 status both     # 查看所有版本状态"
    Write-Host ""
}

# 执行Docker Compose命令
function Invoke-DockerCompose {
    param(
        [string]$Command,
        [string]$Version
    )
    
    $dir = switch ($Version) {
        "auth" { "kibana-auth" }
        "no-auth" { "kibana-no-auth" }
    }
    
    Write-Info "执行 $Command 命令于 $Version 版本..."
    
    Push-Location $dir
    try {
        switch ($Command) {
            "start" {
                docker-compose up -d
            }
            "stop" {
                docker-compose down
            }
            "restart" {
                docker-compose restart
            }
            "status" {
                docker-compose ps
            }
            "logs" {
                docker-compose logs -f kibana
            }
            "clean" {
                $confirm = Read-Host "这将删除所有数据，是否继续？(y/N)"
                if ($confirm -eq "y" -or $confirm -eq "Y") {
                    docker-compose down -v
                    Write-Success "清理完成"
                } else {
                    Write-Info "取消清理"
                }
            }
        }
    }
    finally {
        Pop-Location
    }
}

# 显示服务信息
function Show-Info {
    param([string]$Version)
    
    switch ($Version) {
        "auth" {
            Write-Title "=== Kibana 认证版本信息 ==="
            Write-Host "📁 目录: kibana-auth\"
            Write-Host "🌐 端口: 5601"
            Write-Host "🔒 安全: 启用认证"
            Write-Host "📋 用户: elastic"
            Write-Host "🔑 密码: your_elastic_password"
            Write-Host "🌍 访问: http://localhost:5601"
            Write-Host "🎯 用途: 生产环境"
        }
        "no-auth" {
            Write-Title "=== Kibana 无认证版本信息 ==="
            Write-Host "📁 目录: kibana-no-auth\"
            Write-Host "🌐 端口: 5602"
            Write-Host "🔓 安全: 禁用认证"
            Write-Host "👤 登录: 无需登录"
            Write-Host "🌍 访问: http://localhost:5602"
            Write-Host "🎯 用途: 开发/测试环境"
            Write-Warning "⚠️  请勿在生产环境使用"
        }
        "both" {
            Show-Info "auth"
            Write-Host ""
            Show-Info "no-auth"
        }
    }
    Write-Host ""
}

# 检查服务状态
function Test-ServiceStatus {
    param([string]$Version)
    
    switch ($Version) {
        "auth" {
            Write-Info "检查认证版本状态..."
            try {
                $response = Invoke-RestMethod -Uri "http://localhost:5601/api/status" -TimeoutSec 5 -ErrorAction Stop
                Write-Success "认证版本运行正常 (端口 5601)"
            }
            catch {
                Write-Warning "认证版本未运行或无法访问"
            }
        }
        "no-auth" {
            Write-Info "检查无认证版本状态..."
            try {
                $response = Invoke-RestMethod -Uri "http://localhost:5602/api/status" -TimeoutSec 5 -ErrorAction Stop
                Write-Success "无认证版本运行正常 (端口 5602)"
            }
            catch {
                Write-Warning "无认证版本未运行或无法访问"
            }
        }
        "both" {
            Test-ServiceStatus "auth"
            Test-ServiceStatus "no-auth"
        }
    }
}

# 主逻辑
switch ($Command) {
    "help" {
        Show-Help
    }
    "info" {
        if ([string]::IsNullOrEmpty($Version)) {
            Show-Info "both"
        } else {
            Show-Info $Version
        }
    }
    "status" {
        if ([string]::IsNullOrEmpty($Version)) {
            Test-ServiceStatus "both"
        } else {
            Test-ServiceStatus $Version
        }
    }
    { $_ -in @("start", "stop", "restart", "logs", "clean") } {
        if ([string]::IsNullOrEmpty($Version)) {
            Write-Error "请指定版本: auth, no-auth"
            exit 1
        }
        
        if ($Version -eq "both") {
            if ($Command -eq "start") {
                Write-Error "不能同时启动两个版本（端口冲突）"
                Write-Info "请分别启动不同的版本"
                exit 1
            }
            
            foreach ($v in @("auth", "no-auth")) {
                Invoke-DockerCompose $Command $v
            }
        } else {
            Invoke-DockerCompose $Command $Version
        }
    }
    default {
        Write-Error "未知命令: $Command"
        Show-Help
        exit 1
    }
} 