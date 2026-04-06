param(
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repoRoot

if (-not (Test-Path -LiteralPath '.githooks/commit-msg')) {
  throw 'Missing .githooks/commit-msg'
}
if (-not (Test-Path -LiteralPath '.githooks/pre-push')) {
  throw 'Missing .githooks/pre-push'
}
if (-not (Test-Path -LiteralPath '.gitmessage.txt')) {
  throw 'Missing .gitmessage.txt'
}

$currentHooksPath = git config --get core.hooksPath
if (-not $Force -and $currentHooksPath) {
  $targetHooksPath = (Resolve-Path '.githooks').Path
  $currentResolved = $null
  try {
    if (Test-Path -LiteralPath $currentHooksPath) {
      $currentResolved = (Resolve-Path $currentHooksPath).Path
    }
  } catch {
    $currentResolved = $null
  }

  $alreadyCorrect = $currentHooksPath -eq '.githooks' -or ($currentResolved -and $currentResolved -eq $targetHooksPath)
  if (-not $alreadyCorrect) {
    throw "core.hooksPath already set to '$currentHooksPath'. Use -Force to overwrite."
  }
}

git config core.hooksPath .githooks
git config commit.template .gitmessage.txt

Write-Host 'Git governance installed.' -ForegroundColor Green
Write-Host ' - core.hooksPath=.githooks'
Write-Host ' - commit.template=.gitmessage.txt'
Write-Host 'Recommended publish entry: ./scripts/git-auto-publish.ps1'
