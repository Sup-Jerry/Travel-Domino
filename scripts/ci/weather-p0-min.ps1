$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $repoRoot

$listPath = Join-Path $repoRoot 'entry\src\test\List.test.ets'
if (-not (Test-Path $listPath)) {
  Write-Host "[weather-p0-min][FAIL] missing test list: $listPath"
  exit 1
}

$tmpDir = Join-Path $repoRoot '.tmp'
New-Item -ItemType Directory -Path $tmpDir -ErrorAction SilentlyContinue | Out-Null
$logPath = Join-Path $tmpDir 'weather-p0-min.log'
$testCacheDir = Join-Path $repoRoot 'entry\.test'

$originalContent = [System.IO.File]::ReadAllText($listPath)
$minimalContent = @"
import weatherP0SuiteTest from './WeatherP0Suite.test';

export default function testsuite() {
  weatherP0SuiteTest();
}
"@

try {
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($listPath, $minimalContent, $utf8NoBom)
  if (Test-Path $testCacheDir) {
    Remove-Item -Recurse -Force $testCacheDir
  }
  & cmd /c "hvigorw.bat --stop-daemon" | Out-Null
  Write-Host '[weather-p0-min] running weather minimal suite (with fresh .test cache)...'
  $rawOutput = & cmd /c "hvigorw.bat -p product=default test 2>&1"
  $exitCode = $LASTEXITCODE
  $rawOutput | Tee-Object -FilePath $logPath | Out-Host

  $joined = (($rawOutput | ForEach-Object { "$_" }) -join "`n")
  if ($exitCode -ne 0 -or
      $joined -match 'COMPILE RESULT:FAIL' -or
      $joined -match 'ERROR: Error in ' -or
      $joined -match 'ERROR: hvigor daemon' -or
      $joined -match 'Current process status is busy') {
    Write-Host "[weather-p0-min][FAIL] suite failed, log=$logPath"
    if ($exitCode -ne 0) {
      exit $exitCode
    }
    exit 2
  }

  Write-Host "[weather-p0-min][PASS] suite passed, log=$logPath"
  exit 0
}
finally {
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($listPath, $originalContent, $utf8NoBom)
}
