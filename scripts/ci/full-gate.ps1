$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $repoRoot

$devEcoJavaHome = 'E:\DevEco Studio\jbr\bin'
$devEcoJavaExe = Join-Path $devEcoJavaHome 'java.exe'
if (Test-Path $devEcoJavaExe) {
  $env:PATH = "$devEcoJavaHome;$env:PATH"
  Write-Host "[full-gate] java pinned to $devEcoJavaExe"
}

Write-Host '[full-gate] step 1/2 quality gate...'
powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'quality-gate.ps1')
if ($LASTEXITCODE -ne 0) {
  Write-Host "[full-gate] failed at quality gate, exit=$LASTEXITCODE"
  exit $LASTEXITCODE
}

Write-Host '[full-gate] step 2/2 unit test...'
& cmd /c "entry\hvigorw.bat --no-daemon --mode module -p module=entry -p product=default -p buildMode=debug test 2>&1" | Out-Host
if ($LASTEXITCODE -ne 0) {
  Write-Host "[full-gate] failed at test, exit=$LASTEXITCODE"
  exit $LASTEXITCODE
}

Write-Host '[full-gate] success.'
