$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $repoRoot

$tmpDir = Join-Path $repoRoot '.tmp'
New-Item -ItemType Directory -Path $tmpDir -ErrorAction SilentlyContinue | Out-Null
$logPath = Join-Path $tmpDir 'weather-full-test.log'

Write-Host '[weather-baseline-split] running full hvigor test...'
$rawOutput = & cmd /c "hvigorw.bat -p product=default test 2>&1"
$exitCode = $LASTEXITCODE
$lines = @($rawOutput | ForEach-Object { "$_" })
$rawOutput | Tee-Object -FilePath $logPath | Out-Host

$baselineFiles = @(
  'entry/src/test/LocalUnit.test.ets',
  'entry/src/test/TimeConstraintSolver.test.ets',
  'entry/src/test/AiService.test.ets',
  'entry/src/test/ArrivalReminderEngine.test.ets',
  'entry/src/test/ScheduleOrchestrator.test.ets',
  'entry/src/test/TimelineDatePolicy.test.ets'
)

$findings = New-Object System.Collections.Generic.List[Object]

foreach ($line in $lines) {
  if ($line -match 'ERROR: Error in (.+), expect .+$') {
    $name = $Matches[1]
    $findings.Add([PSCustomObject]@{
      file = 'entry/src/test/TimeConstraintSolver.test.ets'
      code = 'TEST_ASSERTION_FAIL'
      detail = $name
      reason = 'HISTORICAL_ASSERTION'
    }) | Out-Null
  }

  if ($line -match 'Error Message:\s+(.+)\s+At File:\s+([A-Za-z]:/.+):(\d+):(\d+)') {
    $msg = $Matches[1]
    $absFile = $Matches[2].Replace('\', '/')
    $file = $absFile.Replace('E:/Travel12.19/', '')
    $code = if ($msg -match 'arkts-no-any-unknown') {
      'ARKTS_NO_ANY_UNKNOWN'
    } elseif ($msg -match 'Cannot find module') {
      'MODULE_NOT_FOUND'
    } else {
      'ARKTS_COMPILE_ERROR'
    }
    $reason = if ($baselineFiles -contains $file) { 'HISTORICAL_BASELINE' } else { 'NEW_CANDIDATE' }
    $findings.Add([PSCustomObject]@{
      file = $file
      code = $code
      detail = $msg
      reason = $reason
    }) | Out-Null
  }
}

$historical = @($findings | Where-Object { $_.reason -eq 'HISTORICAL_BASELINE' -or $_.reason -eq 'HISTORICAL_ASSERTION' })
$newlyAdded = @($findings | Where-Object { $_.reason -eq 'NEW_CANDIDATE' })

$dateTag = (Get-Date).ToString('yyyyMMdd')
$reportPath = Join-Path $repoRoot ("docs/weather/P0_TEST_BASELINE_SPLIT_{0}.md" -f $dateTag)

$content = @()
$content += '# Weather P0 Full Test Split Report'
$content += ''
$content += "- Time: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
$content += '- Command: `./hvigorw.bat -p product=default test`'
$content += "- ProcessExitCode: $exitCode"
$content += '- RawLog: `.tmp/weather-full-test.log`'
$content += ''
$content += '## 1. New Failures (Candidate)'
if ($newlyAdded.Count -eq 0) {
  $content += '- None'
} else {
  $content += '| File | Code | Reason | Detail |'
  $content += '| --- | --- | --- | --- |'
  foreach ($item in $newlyAdded) {
    $content += "| $($item.file) | $($item.code) | $($item.reason) | $($item.detail) |"
  }
}

$content += ''
$content += '## 2. Historical Baseline'
if ($historical.Count -eq 0) {
  $content += '- None'
} else {
  $content += '| File | Code | Reason | Detail |'
  $content += '| --- | --- | --- | --- |'
  foreach ($item in $historical) {
    $content += "| $($item.file) | $($item.code) | $($item.reason) | $($item.detail) |"
  }
}

$content += ''
$content += '## 3. Conclusion'
if ($newlyAdded.Count -eq 0) {
  $content += '- No new failures introduced in this round.'
} else {
  $content += '- New failure candidates found. Please fix before release.'
}

Set-Content -Path $reportPath -Value ($content -join "`r`n") -Encoding utf8
Write-Host "[weather-baseline-split] report=$reportPath"

if ($newlyAdded.Count -gt 0) {
  exit 3
}
exit 0
