$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

& git config core.hooksPath .githooks
if ($LASTEXITCODE -ne 0) {
  Write-Host '[setup-git-governance] failed to set core.hooksPath'
  exit $LASTEXITCODE
}

& git config commit.template .gitmessage.txt
if ($LASTEXITCODE -ne 0) {
  Write-Host '[setup-git-governance] failed to set commit.template'
  exit $LASTEXITCODE
}

Write-Host '[setup-git-governance] git governance enabled in this repository.'
Write-Host '[setup-git-governance] core.hooksPath=.githooks'
Write-Host '[setup-git-governance] commit.template=.gitmessage.txt'
