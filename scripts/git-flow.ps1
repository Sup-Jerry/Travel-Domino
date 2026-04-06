param(
  [Parameter(Mandatory = $true)]
  [string]$Message,

  [Parameter(Mandatory = $false)]
  [string[]]$Files = @(),

  [Parameter(Mandatory = $false)]
  [switch]$NoPush,

  [Parameter(Mandatory = $false)]
  [switch]$AllowMainPush
)

$ErrorActionPreference = "Stop"

function Write-Step([string]$Text) {
  Write-Host "`n==> $Text" -ForegroundColor Cyan
}

Write-Step "Staging files"
if ($Files.Count -eq 0) {
  git add -A
} else {
  foreach ($file in $Files) {
    git add $file
  }
}

Write-Step "Staged status"
git status --short
git diff --staged --stat

Write-Step "Commit"
$commitMessage = @"
$Message

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
"@
git commit -m $commitMessage

if (-not $NoPush) {
  Write-Step "Push"
  $branch = (git branch --show-current).Trim()
  if ($branch -eq 'main' -and -not $AllowMainPush) {
    throw "Direct push to main is blocked. Switch to develop/feature/release/hotfix, or pass -AllowMainPush explicitly."
  }
  git push origin $branch
}

Write-Step "Done"
git status --short
