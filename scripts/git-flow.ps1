#!/usr/bin/env pwsh
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$Message,

  [Parameter(Mandatory = $false)]
  [string[]]$Files = @(),

  [Parameter(Mandatory = $false)]
  [switch]$NoPush
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step {
  param([string]$Text)
  Write-Host "`n==> $Text" -ForegroundColor Cyan
}

function Write-Ok {
  param([string]$Text)
  Write-Host "[OK] $Text" -ForegroundColor Green
}

function Write-Warn {
  param([string]$Text)
  Write-Host "[WARN] $Text" -ForegroundColor Yellow
}

function Fail {
  param([string]$Text)
  Write-Host "[ERROR] $Text" -ForegroundColor Red
  exit 1
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Fail 'git 未安装或不在 PATH 中。'
}

$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
  Fail '当前目录不是 Git 仓库。'
}

try {
  Write-Step '暂存文件'
  if ($Files.Count -eq 0) {
    git add -A
    Write-Ok '已暂存所有变更。'
  } else {
    foreach ($file in $Files) {
      git add -- $file
    }
    Write-Ok ("已暂存指定文件: {0}" -f ($Files -join ', '))
  }

  Write-Step '查看暂存状态'
  git status --short
  git diff --staged --stat

  $staged = git diff --cached --name-only
  if (-not $staged) {
    Write-Warn '没有可提交的暂存变更，流程结束。'
    exit 0
  }

  Write-Step '创建提交'
  git commit -m $Message
  Write-Ok '提交成功。'

  if (-not $NoPush) {
    Write-Step '推送到远程'
    $branch = (git branch --show-current).Trim()
    if (-not $branch) {
      Fail '无法获取当前分支名。'
    }
    git push -u origin $branch
    Write-Ok "已推送到 origin/$branch"
  } else {
    Write-Warn '已跳过推送（-NoPush）。'
  }

  Write-Step '最终状态'
  git status --short
  Write-Ok '流程完成。'
} catch {
  Fail ("流程失败: {0}" -f $_)
}
