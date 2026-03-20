$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $repoRoot

$logPath = Join-Path $repoRoot '.tmp\weather-p0-min.log'
$suitePassed = $false
if (Test-Path $logPath) {
  $content = Get-Content -Raw -Path $logPath -Encoding UTF8
  if ($content -match 'BUILD SUCCESSFUL') {
    $suitePassed = $true
  }
}

$cases = @(
  @{ tc='TC-001'; mode='AUTO'; ref='WeatherCityCap.test.ets / WeatherExecution.test.ets' },
  @{ tc='TC-002'; mode='MANUAL'; ref='cross-city planning manual check' },
  @{ tc='TC-003'; mode='AUTO'; ref='WeatherRiskEvaluator.test.ets' },
  @{ tc='TC-004'; mode='MANUAL'; ref='weather sorting manual check' },
  @{ tc='TC-005'; mode='AUTO'; ref='WeatherExecution.test.ets' },
  @{ tc='TC-006'; mode='AUTO'; ref='WeatherExecution.test.ets' },
  @{ tc='TC-007'; mode='AUTO'; ref='WeatherExecution.test.ets' },
  @{ tc='TC-008'; mode='AUTO'; ref='WeatherExecution.test.ets' },
  @{ tc='TC-009'; mode='MANUAL'; ref='execution UI manual check' },
  @{ tc='TC-010'; mode='MANUAL'; ref='planning UI manual check' },
  @{ tc='TC-011'; mode='MANUAL'; ref='weak network degrade manual check' },
  @{ tc='TC-012'; mode='MANUAL'; ref='cache-hit manual check' },
  @{ tc='TC-013'; mode='AUTO'; ref='WeatherCache.test.ets' },
  @{ tc='TC-014'; mode='MANUAL'; ref='manual refresh manual check' },
  @{ tc='TC-015'; mode='MANUAL'; ref='failure fallback manual check' },
  @{ tc='TC-016'; mode='MANUAL'; ref='partial failure manual check' },
  @{ tc='TC-017'; mode='MANUAL'; ref='stage-switch manual check' },
  @{ tc='TC-018'; mode='AUTO'; ref='WeatherStageCoordinator.test.ets' },
  @{ tc='TC-019'; mode='AUTO'; ref='WeatherExecution.test.ets' },
  @{ tc='TC-020'; mode='AUTO'; ref='WeatherCityCap.test.ets' }
)

$now = Get-Date
$reportDir = Join-Path $repoRoot 'docs\weather'
if (-not (Test-Path $reportDir)) {
  New-Item -ItemType Directory -Path $reportDir | Out-Null
}
$reportPath = Join-Path $reportDir ("TC_STATUS_REPORT_{0}.md" -f $now.ToString('yyyyMMdd_HHmmss'))

$lines = @()
$lines += '# Weather TC Status Report'
$lines += ''
$lines += "- GeneratedAt: $($now.ToString('yyyy-MM-dd HH:mm:ss'))"
$lines += "- AutoSuite: $(if($suitePassed){'PASS'}else{'FAIL'})"
$lines += ''
$lines += '| TC | Status | Mode | Evidence |'
$lines += '| --- | --- | --- | --- |'

foreach ($c in $cases) {
  $status = if ($c.mode -eq 'AUTO') { if ($suitePassed) { 'PASS' } else { 'FAIL' } } else { 'MANUAL' }
  $lines += "| $($c.tc) | $status | $($c.mode) | $($c.ref) |"
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($reportPath, $lines, $utf8NoBom)
Write-Host "[weather-tc-report] report=$reportPath"

