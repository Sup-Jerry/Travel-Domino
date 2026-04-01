$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $repoRoot

$devEcoJavaHome = 'E:\DevEco Studio\jbr\bin'
$devEcoJavaExe = Join-Path $devEcoJavaHome 'java.exe'
if (Test-Path $devEcoJavaExe) {
  $env:PATH = "$devEcoJavaHome;$env:PATH"
  Write-Host "[quality-gate] java pinned to $devEcoJavaExe"
}

Write-Host '[quality-gate] running secret scan...'
powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'secret-scan.ps1')
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

Write-Host '[quality-gate] building entry module...'
New-Item -ItemType Directory -Path '.tmp' -ErrorAction SilentlyContinue | Out-Null
$buildLog = Join-Path $repoRoot '.tmp\quality-gate-build.log'
& cmd /c "entry\hvigorw.bat --no-daemon --mode module -p module=entry clean 2>&1" | Out-Host
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
$previousErrorAction = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
& cmd /c "entry\hvigorw.bat --no-daemon --mode module -p module=entry -p product=default -p buildMode=debug assembleHap 2>&1" | Tee-Object -FilePath $buildLog | Out-Host
$ErrorActionPreference = $previousErrorAction
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$allWarnMatches = Select-String -Path $buildLog -Pattern 'ArkTS:WARN'
$ignoreFile = Join-Path $PSScriptRoot 'warn-ignore-patterns.txt'
$ignorePatterns = @()
if (Test-Path $ignoreFile) {
  $ignorePatterns = Get-Content $ignoreFile | Where-Object {
    $_ -and (-not $_.TrimStart().StartsWith('#'))
  }
}

$effectiveWarnMatches = @()
foreach ($match in $allWarnMatches) {
  $line = $match.Line
  $isIgnored = $false
  foreach ($pattern in $ignorePatterns) {
    if ($line -like "*$pattern*") {
      $isIgnored = $true
      break
    }
  }
  if (-not $isIgnored) {
    $effectiveWarnMatches += $match
  }
}

$warnCount = $effectiveWarnMatches.Count
$ignoredWarnCount = $allWarnMatches.Count - $warnCount
$baselineFile = Join-Path $PSScriptRoot 'warn-budget.baseline'
$warnBaseline = [int](Get-Content $baselineFile -Raw).Trim()
Write-Host "[quality-gate] ArkTS warn count=$warnCount, ignored=$ignoredWarnCount, baseline=$warnBaseline"
if ($warnCount -gt $warnBaseline) {
  Write-Host "[quality-gate] failed: warning budget exceeded."
  $effectiveWarnMatches | ForEach-Object { Write-Host $_.Line }
  exit 1
}

Write-Host '[quality-gate] success.'
