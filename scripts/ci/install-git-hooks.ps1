param(
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $repoRoot

if (-not (Test-Path '.githooks/pre-commit') -or -not (Test-Path '.githooks/pre-push')) {
  throw 'Missing hook files under .githooks. Please ensure pre-commit and pre-push exist.'
}

$current = git config --get core.hooksPath
if (-not $Force -and $current -and $current -ne '.githooks') {
  throw "core.hooksPath is already set to '$current'. Use -Force to overwrite."
}

git config core.hooksPath .githooks
Write-Host 'Git hooks installed. core.hooksPath=.githooks'
