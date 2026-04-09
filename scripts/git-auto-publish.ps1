#!/usr/bin/env pwsh
[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [string]$Message = '',

  [Parameter(Mandatory = $false)]
  [string[]]$Files = @(),

  [Parameter(Mandatory = $false)]
  [string]$BaseBranch = 'develop',

  [Parameter(Mandatory = $false)]
  [string]$Title = '',

  [Parameter(Mandatory = $false)]
  [string]$Body = '',

  [Parameter(Mandatory = $false)]
  [switch]$NoPush,

  [Parameter(Mandatory = $false)]
  [switch]$NoPR
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

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$gitFlowScript = Join-Path $scriptDir 'git-flow.ps1'
if (-not (Test-Path $gitFlowScript)) {
  Fail "未找到脚本: $gitFlowScript"
}

if ([string]::IsNullOrWhiteSpace($Message)) {
  $Message = "chore: auto publish $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
}

Write-Step '执行 git-flow 提交与推送'
$flowArgs = @{
  Message = $Message
}
if ($Files.Count -gt 0) { $flowArgs.Files = $Files }
if ($NoPush) { $flowArgs.NoPush = $true }

& $gitFlowScript @flowArgs
if ($LASTEXITCODE -ne 0) {
  Fail "git-flow 执行失败，退出码: $LASTEXITCODE"
}

if ($NoPush) {
  Write-Warn '已指定 -NoPush，跳过 PR 创建。'
  exit 0
}

if ($NoPR) {
  Write-Warn '已指定 -NoPR，跳过 PR 创建。'
  exit 0
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  Write-Warn '未检测到 gh，跳过自动创建 Draft PR。'
  exit 0
}

$branch = (git branch --show-current).Trim()
if (-not $branch) {
  Fail '无法获取当前分支名。'
}
if ($branch -eq $BaseBranch) {
  Write-Warn "当前分支与目标基线相同($BaseBranch)，跳过 PR 创建。"
  exit 0
}

if ([string]::IsNullOrWhiteSpace($Title)) {
  $Title = $Message
}
if ([string]::IsNullOrWhiteSpace($Body)) {
  $Body = "Auto publish from branch '$branch'."
}

Write-Step "创建 Draft PR -> base:$BaseBranch head:$branch"
$createOutput = gh pr create --base $BaseBranch --head $branch --title $Title --body $Body --draft 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Warn "自动创建 Draft PR 失败: $createOutput"
  exit 0
}

Write-Ok "Draft PR 已创建: $createOutput"
