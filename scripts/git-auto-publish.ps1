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

function Invoke-WithRetry {
  param(
    [Parameter(Mandatory = $true)]
    [scriptblock]$Action,

    [Parameter(Mandatory = $true)]
    [string]$Description,

    [int]$MaxAttempts = 3,
    [int]$InitialDelaySeconds = 2
  )

  $lastError = $null
  $lastOutput = $null
  for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    try {
      $lastOutput = & $Action
      if ($LASTEXITCODE -eq 0) {
        return $lastOutput
      }
      $lastError = "退出码: $LASTEXITCODE"
    } catch {
      $lastError = $_.Exception.Message
    }

    if ($attempt -ge $MaxAttempts) {
      break
    }

    $delaySeconds = $InitialDelaySeconds * $attempt
    Write-Warn ("{0} 失败，第 {1}/{2} 次，{3} 秒后重试。原因: {4}" -f $Description, $attempt, $MaxAttempts, $delaySeconds, $lastError)
    Start-Sleep -Seconds $delaySeconds
  }

  throw ("{0} 失败，已重试 {1} 次。最后错误: {2}`n{3}" -f $Description, $MaxAttempts, $lastError, $lastOutput)
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
$prevNativePref = $false
$hasNativePref = $false
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
  $hasNativePref = $true
  $prevNativePref = $PSNativeCommandUseErrorActionPreference
  $PSNativeCommandUseErrorActionPreference = $false
}
try {
  try {
    $createOutput = Invoke-WithRetry -Description '创建 Draft PR' -Action {
      gh pr create --base $BaseBranch --head $branch --title $Title --body $Body --draft 2>&1
    }
    Write-Ok "Draft PR 已创建: $createOutput"
  } catch {
    Write-Warn "自动创建 Draft PR 失败: $($_.Exception.Message)"
    exit 0
  }
} finally {
  if ($hasNativePref) {
    $PSNativeCommandUseErrorActionPreference = $prevNativePref
  }
}
