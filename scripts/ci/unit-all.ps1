$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $repoRoot

Write-Host '[unit-all] running all entry unit tests...'
$logDir = Join-Path $repoRoot '.tmp'
New-Item -ItemType Directory -Path $logDir -ErrorAction SilentlyContinue | Out-Null
$logPath = Join-Path $logDir 'unit-all.log'

$rawOutput = & cmd /c "entry\hvigorw.bat --mode module -p module=entry@default -p product=default test 2>&1"
$exitCode = $LASTEXITCODE
$rawOutput | Tee-Object -FilePath $logPath | Out-Null
$lines = @($rawOutput | ForEach-Object { "$_" })
$joined = ($lines -join "`n")

$coverageNoisePatterns = @(
  'ErrorCode:\s*00507008',
  'getInitCoverageData failed',
  '@ohos\\coverage\\lib\\src\\report\.js',
  '@ohos\\coverage\\lib\\src\\generateReportForHvigorw\.js',
  '@ohos\\coverage\\lib\\src\\commandLine\\localTest\\coverageParser\.js',
  '@ohos\\coverage\\lib\\src\\commandLine\\localTest\\previewer\.js'
)
$coverageNoiseMatched = $false
$inCoverageBlock = $false
foreach ($line in $lines) {
  if ($line -match 'ErrorCode:\s*00507008' -or $line -match 'getInitCoverageData failed') {
    $coverageNoiseMatched = $true
    $inCoverageBlock = $true
    continue
  }
  if ($inCoverageBlock -and $line -match 'Finished write html report') {
    $inCoverageBlock = $false
    continue
  }
  if ($inCoverageBlock) {
    continue
  }

  $isCoverageNoise = $false
  foreach ($pattern in $coverageNoisePatterns) {
    if ($line -match $pattern) {
      $isCoverageNoise = $true
      $coverageNoiseMatched = $true
      break
    }
  }
  if (-not $isCoverageNoise) {
    Write-Host $line
  }
}

if ($coverageNoiseMatched) {
  Write-Host '[unit-all] note: ignored known coverage parser noise (00507008).'
}

$buildSuccess = $joined -match 'BUILD SUCCESSFUL'
$unknownErrorLines = @()
foreach ($line in $lines) {
  if ($line -match 'ERROR:' -and
      $line -notmatch 'ErrorCode:\s*00507008' -and
      $line -notmatch '@ohos\\coverage\\') {
    $unknownErrorLines += $line
  }
}

if ($exitCode -ne 0 -or -not $buildSuccess -or $unknownErrorLines.Count -gt 0) {
  if ($unknownErrorLines.Count -gt 0) {
    Write-Host '[unit-all] unexpected ERROR lines:'
    $unknownErrorLines | Select-Object -First 20 | ForEach-Object { Write-Host $_ }
  }
  Write-Host "[unit-all] failed, exit=$exitCode, log=$logPath"
  if ($exitCode -ne 0) {
    exit $exitCode
  }
  exit 1
}

Write-Host "[unit-all] success. log=$logPath"
