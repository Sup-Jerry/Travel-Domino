$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $repoRoot

$failed = $false

function Assert-NoMatch([string]$pattern, [string]$path, [string]$name) {
  $hits = & rg -n $pattern $path
  if ($LASTEXITCODE -eq 0 -and $hits) {
    Write-Host "[weather-structure-check][FAIL] $name"
    Write-Host $hits
    $script:failed = $true
  } else {
    Write-Host "[weather-structure-check][PASS] $name"
  }
}

function Assert-Match([string]$pattern, [string]$path, [string]$name) {
  $hits = & rg -n $pattern $path
  if ($LASTEXITCODE -ne 0 -or -not $hits) {
    Write-Host "[weather-structure-check][FAIL] $name"
    $script:failed = $true
  } else {
    Write-Host "[weather-structure-check][PASS] $name"
  }
}

$vmPath = Join-Path $repoRoot 'entry\src\main\ets\viewmodel\TimelineViewModel.ets'
Assert-NoMatch 'new\\s+WeatherContextBuilder|weatherContextBuilder\\.' $vmPath 'TimelineViewModel should not use WeatherContextBuilder directly'
Assert-Match 'WeatherFacade|weatherFacade\.' $vmPath 'TimelineViewModel should use WeatherFacade'

$serviceImports = & rg -n "domain/statemachine/WeatherRefreshScheduler" (Join-Path $repoRoot 'entry\src\main\ets')
if ($LASTEXITCODE -eq 0 -and $serviceImports) {
  $violations = @()
  foreach ($line in $serviceImports) {
    if ($line -notmatch 'domain\\statemachine\\PlanStateMachine\\.ets') {
      $violations += $line
    }
  }
  if ($violations.Count -gt 0) {
    Write-Host "[weather-structure-check][FAIL] statemachine scheduler import leaked outside PlanStateMachine"
    $violations | ForEach-Object { Write-Host $_ }
    $failed = $true
  } else {
    Write-Host "[weather-structure-check][PASS] statemachine scheduler import is isolated"
  }
} else {
  Write-Host "[weather-structure-check][PASS] no statemachine scheduler import in main ets"
}

if ($failed) {
  exit 1
}

Write-Host '[weather-structure-check][PASS] all structure checks passed'
