param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('init', 'feature', 'release', 'hotfix')]
  [string]$Mode,
  [string]$Name
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

function Run-Git {
  param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
  )

  & git @Args
  if ($LASTEXITCODE -ne 0) {
    throw "git $($Args -join ' ') failed with exit code $LASTEXITCODE"
  }
}

function Ensure-Name {
  param(
    [string]$Value,
    [string]$Hint
  )

  if ([string]::IsNullOrWhiteSpace($Value)) {
    throw "missing name. usage hint: $Hint"
  }
}

function Sync-BaseBranch {
  param(
    [string]$Branch
  )

  Run-Git fetch origin --prune
  Run-Git checkout $Branch
  Run-Git pull --ff-only origin $Branch
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

switch ($Mode) {
  'init' {
    Run-Git fetch origin --prune
    Run-Git checkout main
    Run-Git pull --ff-only origin main

    & git show-ref --verify --quiet refs/heads/develop
    $localDevelopExists = ($LASTEXITCODE -eq 0)

    if (-not $localDevelopExists) {
      Run-Git checkout -b develop
    } else {
      Run-Git checkout develop
    }

    & git ls-remote --exit-code --heads origin develop *> $null
    $remoteDevelopExists = ($LASTEXITCODE -eq 0)

    if ($remoteDevelopExists) {
      Run-Git pull --ff-only origin develop
    } else {
      Run-Git push -u origin develop
    }

    Write-Host '[git-flow] develop branch is ready.'
    break
  }
  'feature' {
    Ensure-Name -Value $Name -Hint 'scripts/git-flow.ps1 feature <feature-name>'
    $branchName = "feature/$Name"
    Sync-BaseBranch -Branch 'develop'
    Run-Git checkout -b $branchName
    Run-Git push -u origin $branchName
    Write-Host "[git-flow] created $branchName from develop."
    break
  }
  'release' {
    Ensure-Name -Value $Name -Hint 'scripts/git-flow.ps1 release vX.Y.Z'
    $branchName = "release/$Name"
    Sync-BaseBranch -Branch 'develop'
    Run-Git checkout -b $branchName
    Run-Git push -u origin $branchName
    Write-Host "[git-flow] created $branchName from develop."
    break
  }
  'hotfix' {
    Ensure-Name -Value $Name -Hint 'scripts/git-flow.ps1 hotfix vX.Y.Z'
    $branchName = "hotfix/$Name"
    Sync-BaseBranch -Branch 'main'
    Run-Git checkout -b $branchName
    Run-Git push -u origin $branchName
    Write-Host "[git-flow] created $branchName from main."
    break
  }
}
