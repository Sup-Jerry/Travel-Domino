param(
  [switch]$NoWebReport,
  [switch]$NoOpenReport
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $repoRoot

$devEcoJavaHome = 'E:\DevEco Studio\jbr\bin'
$devEcoJavaExe = Join-Path $devEcoJavaHome 'java.exe'
if (Test-Path $devEcoJavaExe) {
  $env:PATH = "$devEcoJavaHome;$env:PATH"
  Write-Host "[full-gate] java pinned to $devEcoJavaExe"
}

$runStartedAt = Get-Date
$steps = New-Object System.Collections.Generic.List[object]
$overallExitCode = 0
$overallSuccess = $true

$reportDir = Join-Path $repoRoot '.tmp'
New-Item -ItemType Directory -Path $reportDir -ErrorAction SilentlyContinue | Out-Null
$reportTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$reportPath = Join-Path $reportDir "full-gate-report-$reportTimestamp.html"
$latestReportPath = Join-Path $reportDir 'full-gate-report-latest.html'

function HtmlEncode([string]$value) {
  if ($null -eq $value) {
    return ''
  }
  $encoded = $value -replace '&', '&amp;'
  $encoded = $encoded -replace '<', '&lt;'
  $encoded = $encoded -replace '>', '&gt;'
  return $encoded
}

function New-StepResult(
  [string]$Name,
  [string]$Command,
  [bool]$Success,
  [int]$ExitCode,
  [int]$DurationMs,
  [string[]]$OutputLines,
  [string[]]$Highlights
) {
  return [pscustomobject]@{
    Name = $Name
    Command = $Command
    Success = $Success
    ExitCode = $ExitCode
    DurationMs = $DurationMs
    OutputLines = $OutputLines
    Highlights = $Highlights
  }
}

function Invoke-LoggedStep(
  [string]$Name,
  [string]$CommandText,
  [scriptblock]$Invoker
) {
  $start = Get-Date
  $lines = @()
  $exitCode = 0
  $invoked = $true

  try {
    $captured = & $Invoker 2>&1
    $lines = @($captured | ForEach-Object { "$_" })
    if ($null -ne $LASTEXITCODE) {
      $exitCode = [int]$LASTEXITCODE
    }
  }
  catch {
    $invoked = $false
    $exitCode = if ($LASTEXITCODE -is [int]) { [int]$LASTEXITCODE } else { 1 }
    $lines += "[exception] $($_.Exception.Message)"
  }

  $durationMs = [int]((Get-Date) - $start).TotalMilliseconds
  if ($lines.Count -gt 0) {
    $lines | ForEach-Object { Write-Host $_ }
  }

  $success = $invoked -and ($exitCode -eq 0)
  return New-StepResult -Name $Name -Command $CommandText -Success $success -ExitCode $exitCode -DurationMs $durationMs -OutputLines $lines -Highlights @()
}

function Get-Highlights([object]$step) {
  $lines = $step.OutputLines
  $result = @()

  switch ($step.Name) {
    'Structure Gate' {
      $result += $lines | Where-Object { $_ -match '^\[validate-list-suite-registration\]' } | Select-Object -First 1
      $result += $lines | Where-Object { $_ -match '^\[validate-unit-test-cases\]' } | Select-Object -First 1
      break
    }
    'Entry Unit All' {
      $result += $lines | Where-Object { $_ -match 'BUILD SUCCESSFUL' } | Select-Object -Last 1
      $result += $lines | Where-Object { $_ -match '^\[unit-all\]' } | Select-Object -Last 1
      break
    }
    'Backend Unit All' {
      $result += $lines | Where-Object { $_ -match '^Test Suites:' } | Select-Object -Last 1
      $result += $lines | Where-Object { $_ -match '^Tests:' } | Select-Object -Last 1
      $result += $lines | Where-Object { $_ -match '^Ran all test suites\.' } | Select-Object -Last 1
      break
    }
  }

  return @($result | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
}

function New-ReportHtml(
  [object[]]$StepResults,
  [bool]$IsSuccess,
  [DateTime]$StartedAt,
  [DateTime]$FinishedAt
) {
  $statusText = if ($IsSuccess) { 'PASS' } else { 'FAIL' }
  $statusClass = if ($IsSuccess) { 'ok' } else { 'fail' }
  $totalMs = [int]($FinishedAt - $StartedAt).TotalMilliseconds
  $totalSec = [Math]::Round($totalMs / 1000, 2)
  $passCount = @($StepResults | Where-Object { $_.Success }).Count
  $failCount = @($StepResults | Where-Object { -not $_.Success }).Count

  $cards = foreach ($step in $StepResults) {
    $cardClass = if ($step.Success) { 'ok' } else { 'fail' }
    $durationSec = [Math]::Round(($step.DurationMs / 1000), 2)
    $stepBadge = if ($step.Success) { 'PASS' } else { 'FAIL' }
    $highlights = if ($step.Highlights.Count -gt 0) { $step.Highlights } else { @('No key summary. Check logs below.') }

    $maxLogLines = 220
    $logLines = $step.OutputLines
    $logNotice = ''
    if ($logLines.Count -gt $maxLogLines) {
      $skipCount = $logLines.Count - $maxLogLines
      $logLines = $logLines[$skipCount..($logLines.Count - 1)]
      $logNotice = "Log truncated. Showing last $maxLogLines lines out of $($step.OutputLines.Count)."
    }

    $encodedLog = HtmlEncode (($logLines -join "`r`n"))
    $encodedCommand = HtmlEncode $step.Command
    $highlightsHtml = ($highlights | ForEach-Object {
      '<li>' + (HtmlEncode $_) + '</li>'
    }) -join ''

@"
<section class="card $cardClass">
  <div class="card-head">
    <h2>$($step.Name)</h2>
    <span class="badge">$stepBadge / $durationSec s</span>
  </div>
  <p class="cmd"><code>$encodedCommand</code></p>
  <ul class="highlights">$highlightsHtml</ul>
  <details>
    <summary>View Raw Logs</summary>
    <p class="notice">$logNotice</p>
    <pre>$encodedLog</pre>
  </details>
</section>
"@
  }

  $cardsHtml = ($cards -join "`r`n")

return @"
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Full Gate Report</title>
  <style>
    :root {
      --bg: #0f172a;
      --bg-soft: #111827;
      --text: #e5e7eb;
      --muted: #94a3b8;
      --ok: #22c55e;
      --fail: #ef4444;
      --line: #1f2937;
      --accent: #38bdf8;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      color: var(--text);
      font-family: "IBM Plex Sans", "Segoe UI", "PingFang SC", sans-serif;
      background:
        radial-gradient(1200px circle at 0% 0%, #0f3a55 0%, transparent 42%),
        radial-gradient(900px circle at 100% 100%, #2b123d 0%, transparent 35%),
        linear-gradient(160deg, var(--bg) 0%, var(--bg-soft) 100%);
      min-height: 100vh;
    }
    .wrap {
      width: min(1120px, calc(100% - 32px));
      margin: 24px auto 36px;
    }
    .head {
      background: rgba(11, 18, 32, 0.72);
      border: 1px solid var(--line);
      backdrop-filter: blur(4px);
      border-radius: 16px;
      padding: 18px 20px;
      margin-bottom: 18px;
    }
    .title {
      margin: 0 0 8px;
      font-size: 28px;
      letter-spacing: 0.5px;
      font-family: "Avenir Next", "Trebuchet MS", "Segoe UI", sans-serif;
    }
    .meta {
      margin: 0;
      color: var(--muted);
      line-height: 1.5;
      font-size: 14px;
    }
    .status {
      display: inline-block;
      margin-top: 10px;
      padding: 6px 12px;
      border-radius: 999px;
      font-weight: 700;
      font-size: 13px;
      letter-spacing: 0.6px;
      border: 1px solid transparent;
    }
    .status.ok { background: rgba(34, 197, 94, 0.16); color: #bbf7d0; border-color: rgba(34, 197, 94, 0.4); }
    .status.fail { background: rgba(239, 68, 68, 0.16); color: #fecaca; border-color: rgba(239, 68, 68, 0.4); }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 14px;
    }
    .card {
      background: rgba(7, 13, 24, 0.86);
      border: 1px solid var(--line);
      border-left: 5px solid transparent;
      border-radius: 14px;
      padding: 14px;
      box-shadow: 0 10px 30px rgba(2, 6, 23, 0.35);
    }
    .card.ok { border-left-color: var(--ok); }
    .card.fail { border-left-color: var(--fail); }
    .card-head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 8px;
      margin-bottom: 6px;
    }
    .card h2 {
      margin: 0;
      font-size: 18px;
      font-weight: 700;
    }
    .badge {
      display: inline-block;
      border: 1px solid var(--line);
      border-radius: 999px;
      padding: 4px 10px;
      font-size: 12px;
      color: var(--muted);
      font-family: "JetBrains Mono", "Cascadia Mono", Consolas, monospace;
    }
    .cmd {
      margin: 0 0 8px;
      color: #cbd5e1;
      font-size: 12px;
      word-break: break-all;
    }
    .cmd code {
      color: var(--accent);
      font-family: "JetBrains Mono", "Cascadia Mono", Consolas, monospace;
    }
    .highlights {
      margin: 0 0 8px 16px;
      padding: 0;
      color: #dbeafe;
      font-size: 13px;
      line-height: 1.45;
    }
    details {
      border-top: 1px dashed var(--line);
      margin-top: 8px;
      padding-top: 8px;
    }
    summary {
      cursor: pointer;
      color: #93c5fd;
      user-select: none;
      font-size: 13px;
    }
    .notice {
      margin: 6px 0;
      color: #fbbf24;
      font-size: 12px;
    }
    pre {
      white-space: pre-wrap;
      word-break: break-word;
      background: #020617;
      border: 1px solid #1e293b;
      border-radius: 10px;
      padding: 10px;
      max-height: 280px;
      overflow: auto;
      font-size: 12px;
      color: #e2e8f0;
      font-family: "JetBrains Mono", "Cascadia Mono", Consolas, monospace;
    }
  </style>
</head>
<body>
  <main class="wrap">
    <header class="head">
      <h1 class="title">Travel Domino Full Gate Report</h1>
      <p class="meta">
        Started: $($StartedAt.ToString('yyyy-MM-dd HH:mm:ss'))<br/>
        Finished: $($FinishedAt.ToString('yyyy-MM-dd HH:mm:ss'))<br/>
        Duration: $totalSec s / Passed Steps: $passCount / Failed Steps: $failCount
      </p>
      <span class="status $statusClass">Overall: $statusText</span>
    </header>
    <section class="grid">
      $cardsHtml
    </section>
  </main>
</body>
</html>
"@
}

Write-Host '[full-gate] step 1/3 validate unit test case contract...'
$step1 = Invoke-LoggedStep `
  -Name 'Structure Gate' `
  -CommandText 'powershell -ExecutionPolicy Bypass -File scripts/ci/validate-unit-test-cases.ps1' `
  -Invoker { powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'validate-unit-test-cases.ps1') }
$step1.Highlights = Get-Highlights $step1
$steps.Add($step1)
if (-not $step1.Success) {
  $overallSuccess = $false
  $overallExitCode = if ($step1.ExitCode -ne 0) { $step1.ExitCode } else { 1 }
}

if ($overallSuccess) {
  Write-Host '[full-gate] step 2/3 run entry unit-all...'
  $step2 = Invoke-LoggedStep `
    -Name 'Entry Unit All' `
    -CommandText 'powershell -ExecutionPolicy Bypass -File scripts/ci/unit-all.ps1' `
    -Invoker { powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'unit-all.ps1') }
  $step2.Highlights = Get-Highlights $step2
  $steps.Add($step2)
  if (-not $step2.Success) {
    $overallSuccess = $false
    $overallExitCode = if ($step2.ExitCode -ne 0) { $step2.ExitCode } else { 1 }
  }
}

if ($overallSuccess) {
  Write-Host '[full-gate] step 3/3 run backend npm test -- --runInBand...'
  Push-Location (Join-Path $repoRoot 'backend')
  try {
    $step3 = Invoke-LoggedStep `
      -Name 'Backend Unit All' `
      -CommandText 'cd backend; npm test -- --runInBand' `
      -Invoker { & cmd /c "npm test -- --runInBand 2>&1" }
  }
  finally {
    Pop-Location
  }
  $step3.Highlights = Get-Highlights $step3
  $steps.Add($step3)
  if (-not $step3.Success) {
    $overallSuccess = $false
    $overallExitCode = if ($step3.ExitCode -ne 0) { $step3.ExitCode } else { 1 }
  }
}

$runFinishedAt = Get-Date

if (-not $NoWebReport) {
  try {
    $html = New-ReportHtml -StepResults $steps.ToArray() -IsSuccess $overallSuccess -StartedAt $runStartedAt -FinishedAt $runFinishedAt
    Set-Content -Path $reportPath -Value $html -Encoding UTF8
    Copy-Item -Path $reportPath -Destination $latestReportPath -Force
    Write-Host "[full-gate] web report: $reportPath"
    Write-Host "[full-gate] web report latest: $latestReportPath"

    if (-not $NoOpenReport -and -not $env:CI) {
      try {
        Start-Process $reportPath | Out-Null
      }
      catch {
        Write-Host "[full-gate] note: open report failed, open manually -> $reportPath"
      }
    }
  }
  catch {
    Write-Host "[full-gate] warning: web report generation failed: $($_.Exception.Message)"
  }
}

if (-not $overallSuccess) {
  Write-Host "[full-gate] failed, exit=$overallExitCode"
  exit $overallExitCode
}

Write-Host '[full-gate] success.'
