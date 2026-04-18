param(
  [string]$Source = 'E:\Travel\skills\large-file-split-migration',
  [switch]$Commit,
  [string]$Message = 'chore: sync skill from Travel workspace',
  [switch]$Push
)

$RepoRoot = Split-Path -Parent $PSScriptRoot
if (!(Test-Path $Source)) {
  Write-Error "Source path not found: $Source"
  exit 1
}

$targets = @('SKILL.md','agents\openai.yaml','references\migration-template.md','references\equivalence-matrix.md','scripts\checklist.ps1')
foreach ($t in $targets) {
  $src = Join-Path $Source $t
  $dst = Join-Path $RepoRoot $t
  if (Test-Path $src) {
    $dstDir = Split-Path -Parent $dst
    if (!(Test-Path $dstDir)) { New-Item -ItemType Directory -Force $dstDir | Out-Null }
    Copy-Item $src $dst -Force
    Write-Host "Synced: $t"
  } else {
    Write-Warning "Skip missing source file: $src"
  }
}

if ($Commit) {
  git -C $RepoRoot add .
  $hasChanges = git -C $RepoRoot status --porcelain
  if ($hasChanges) {
    git -C $RepoRoot commit -m $Message
    Write-Host "Committed: $Message"
  } else {
    Write-Host 'No changes to commit.'
  }
}

if ($Push) {
  git -C $RepoRoot push
  Write-Host 'Pushed to origin.'
}
