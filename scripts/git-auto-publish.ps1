param(
  [string]$Slug,

  [ValidateSet('feat', 'fix', 'chore', 'refactor', 'docs', 'test')]
  [string]$Type = 'feat',

  [string]$Scope,

  [switch]$NoPR,

  [switch]$AllowMainPush
)

$ErrorActionPreference = 'Stop'

function Invoke-Git([string]$Args) {
  & git $Args
  if ($LASTEXITCODE -ne 0) {
    throw "git command failed: git $Args"
  }
}

function Get-CurrentBranch {
  $branch = (& git branch --show-current).Trim()
  if ([string]::IsNullOrWhiteSpace($branch)) {
    throw 'Cannot detect current branch.'
  }
  return $branch
}

function Normalize-Slug([string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value)) {
    return 'auto'
  }

  $normalized = $Value.ToLowerInvariant() -replace '[^a-z0-9-]+', '-'
  $normalized = $normalized.Trim('-')
  if ([string]::IsNullOrWhiteSpace($normalized)) {
    return 'auto'
  }
  return $normalized
}

function Ensure-FeatureBranch([string]$BaseBranch, [string]$SlugValue) {
  Invoke-Git 'fetch origin'
  Invoke-Git "checkout $BaseBranch"
  try {
    Invoke-Git "pull --ff-only origin $BaseBranch"
  } catch {
    Write-Host "[git-auto-publish] warning: cannot fast-forward $BaseBranch from origin; continue with local branch." -ForegroundColor Yellow
  }

  $date = Get-Date -Format 'yyyyMMdd'
  $candidate = "feature/$date-$SlugValue"
  $index = 1
  while ($true) {
    & git show-ref --verify --quiet "refs/heads/$candidate"
    if ($LASTEXITCODE -ne 0) {
      break
    }
    $candidate = "feature/$date-$SlugValue-$index"
    $index++
  }

  Invoke-Git "checkout -b $candidate"
  return $candidate
}

function Get-CommitDescription {
  $files = @(& git diff --staged --name-only | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  if ($files.Count -eq 0) {
    return 'automated update'
  }

  $tokens = New-Object System.Collections.Generic.List[string]
  foreach ($f in ($files | Select-Object -First 3)) {
    $name = [IO.Path]::GetFileNameWithoutExtension($f).ToLowerInvariant()
    if (-not [string]::IsNullOrWhiteSpace($name)) {
      $clean = ($name -replace '[^a-z0-9-]+', '-')
      if (-not [string]::IsNullOrWhiteSpace($clean)) {
        $tokens.Add($clean)
      }
    }
  }

  if ($tokens.Count -eq 0) {
    return 'automated update'
  }

  return "update $($tokens -join ', ')"
}

function Ensure-GhReady {
  $gh = Get-Command gh -ErrorAction SilentlyContinue
  if (-not $gh) {
    throw 'gh CLI not found. Install GitHub CLI or run with -NoPR.'
  }

  & gh auth status 1>$null 2>$null
  if ($LASTEXITCODE -ne 0) {
    throw 'gh is not authenticated. Run "gh auth login" first, or run with -NoPR.'
  }
}

$currentBranch = Get-CurrentBranch
if ($currentBranch -eq 'main' -and -not $AllowMainPush) {
  throw 'Direct publish from main is blocked. Switch to develop/feature/release/hotfix or use -AllowMainPush explicitly.'
}

$workBranch = $currentBranch
if ($currentBranch -eq 'develop') {
  $workBranch = Ensure-FeatureBranch -BaseBranch 'develop' -SlugValue (Normalize-Slug $Slug)
  Write-Host "[git-auto-publish] created branch: $workBranch" -ForegroundColor Cyan
}

Invoke-Git 'add -A'

$staged = @(& git diff --staged --name-only | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
if ($staged.Count -eq 0) {
  Write-Host '[git-auto-publish] no staged changes to commit.' -ForegroundColor Yellow
  exit 0
}

$description = Get-CommitDescription
if ([string]::IsNullOrWhiteSpace($description)) {
  $description = 'automated update'
}

if ([string]::IsNullOrWhiteSpace($Scope)) {
  $commitMsg = "${Type}: $description"
} else {
  $safeScope = ($Scope.ToLowerInvariant() -replace '[^a-z0-9-]+', '-')
  $safeScope = $safeScope.Trim('-')
  if ([string]::IsNullOrWhiteSpace($safeScope)) {
    $commitMsg = "${Type}: $description"
  } else {
    $commitMsg = "$Type($safeScope): $description"
  }
}

Invoke-Git "commit -m \"$commitMsg\""

if ($AllowMainPush) {
  $env:ALLOW_MAIN_PUSH = '1'
}
Invoke-Git "push -u origin $workBranch"

if (-not $NoPR) {
  Ensure-GhReady

  $prTitle = $commitMsg
  $prBody = @"
Automated by scripts/git-auto-publish.ps1.

- Branch: $workBranch
- Base: develop
- Commit: $commitMsg
"@

  & gh pr create --draft --base develop --head $workBranch --title $prTitle --body $prBody
  if ($LASTEXITCODE -ne 0) {
    throw 'Failed to create draft PR to develop.'
  }
}

Write-Host '[git-auto-publish] done.' -ForegroundColor Green
