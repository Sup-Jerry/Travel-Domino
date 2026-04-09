#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Git 提交推送流程脚本
.DESCRIPTION
    自动执行: 暂存 → 查看状态 → 提交 → 推送
.PARAMETER Message
    提交信息（必需）
.PARAMETER Files
    要暂存的文件，默认为所有修改文件
.PARAMETER NoPush
    只提交不推送
.EXAMPLE
    .\git-flow.ps1 -Message "feat: 添加新功能"
    .\git-flow.ps1 -Message "fix: 修复bug" -Files "src/main.ts"
    .\git-flow.ps1 -Message "chore: 更新配置" -NoPush
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Message,

    [Parameter(Mandatory=$false)]
    [string[]]$Files = @(),

    [Parameter(Mandatory=$false)]
    [switch]$NoPush
)

$ErrorActionPreference = "Stop"

# 颜色输出函数
function Write-Step {
    param([string]$Text)
    Write-Host "`n==> $Text" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Text)
    Write-Host "✓ $Text" -ForegroundColor Green
}

function Write-Error {
    param([string]$Text)
    Write-Host "✗ $Text" -ForegroundColor Red
}

try {
    # 步骤 1: 暂存文件
    Write-Step "暂存文件"
    if ($Files.Count -eq 0) {
        git add -A
        Write-Success "已暂存所有修改"
    } else {
        foreach ($file in $Files) {
            git add $file
        }
        Write-Success "已暂存指定文件: $($Files -join ', ')"
    }

    # 步骤 2: 查看状态
    Write-Step "查看暂存状态"
    git status --short
    git diff --staged --stat

    # 步骤 3: 提交
    Write-Step "创建提交"
    $commitMessage = @"
$Message

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
"@
    git commit -m $commitMessage
    Write-Success "提交成功"

    # 步骤 4: 推送（可选）
    if (-not $NoPush) {
        Write-Step "推送到远程"
        $branch = git branch --show-current
        git push origin $branch
        Write-Success "推送成功到 origin/$branch"
    } else {
        Write-Host "`n⚠ 跳过推送（使用了 -NoPush 参数）" -ForegroundColor Yellow
    }

    # 步骤 5: 最终状态
    Write-Step "最终状态"
    git status

    Write-Host "`n✓ 流程完成" -ForegroundColor Green

} catch {
    Write-Error "流程失败: $_"
    exit 1
}
