param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("list", "check", "delete", "update", "evolve", "align-all", "clean-garbled")]
  [string]$Action,

  [string]$Target = "",
  [string]$Payload = "",
  [string]$SkillsRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$defaultSkillsRoot = [System.IO.Path]::GetFullPath((Join-Path $scriptDir "..\.."))
if ([string]::IsNullOrWhiteSpace($SkillsRoot)) {
  $SkillsRoot = $defaultSkillsRoot
} else {
  $SkillsRoot = [System.IO.Path]::GetFullPath($SkillsRoot)
}

$managerDir = Join-Path $scriptDir "manager"
$evolutionDir = Join-Path $scriptDir "evolution"

function Resolve-TargetSkillDir([string]$rawTarget) {
  if ([string]::IsNullOrWhiteSpace($rawTarget)) {
    throw "Target is required for this action."
  }

  if (Test-Path -LiteralPath $rawTarget) {
    return [System.IO.Path]::GetFullPath($rawTarget)
  }

  return [System.IO.Path]::GetFullPath((Join-Path $SkillsRoot $rawTarget))
}

switch ($Action) {
  "list" {
    & python (Join-Path $managerDir "list_skills.py") $SkillsRoot
  }
  "check" {
    & python (Join-Path $managerDir "scan_and_check.py") $SkillsRoot
  }
  "delete" {
    if ([string]::IsNullOrWhiteSpace($Target)) {
      throw "delete action requires -Target <skill_name>."
    }
    & python (Join-Path $managerDir "delete_skill.py") $Target $SkillsRoot
  }
  "update" {
    $targetSkillDir = Resolve-TargetSkillDir $Target
    & python (Join-Path $managerDir "update_helper.py") $targetSkillDir
  }
  "evolve" {
    if ([string]::IsNullOrWhiteSpace($Payload)) {
      throw "evolve action requires -Payload '<json>'."
    }
    $targetSkillDir = Resolve-TargetSkillDir $Target
    & python (Join-Path $evolutionDir "merge_evolution.py") $targetSkillDir $Payload
    if ($LASTEXITCODE -ne 0) {
      exit $LASTEXITCODE
    }
    & python (Join-Path $evolutionDir "smart_stitch.py") $targetSkillDir
  }
  "align-all" {
    & python (Join-Path $evolutionDir "align_all.py") $SkillsRoot
  }
  "clean-garbled" {
    if ([string]::IsNullOrWhiteSpace($Target)) {
      & python (Join-Path $evolutionDir "clean_garbled_evolution.py")
    } else {
      $targetSkillDir = Resolve-TargetSkillDir $Target
      & python (Join-Path $evolutionDir "clean_garbled_evolution.py") $targetSkillDir
    }
  }
}

if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
