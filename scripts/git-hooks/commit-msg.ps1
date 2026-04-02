param(
  [Parameter(Mandatory = $true)]
  [string]$CommitMessageFile
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

if (-not (Test-Path -LiteralPath $CommitMessageFile)) {
  Write-Host "[commit-msg] commit message file not found: $CommitMessageFile"
  exit 1
}

$raw = Get-Content -LiteralPath $CommitMessageFile -Raw
if ([string]::IsNullOrWhiteSpace($raw)) {
  Write-Host '[commit-msg] message is empty.'
  Write-Host '[commit-msg] expected format: <type>[optional scope]: <description>'
  exit 1
}

$subject = $null
foreach ($line in ($raw -split "`r?`n")) {
  $trimmed = $line.Trim()
  if ($trimmed.Length -eq 0) {
    continue
  }
  if ($trimmed.StartsWith('#')) {
    continue
  }
  $subject = $trimmed
  break
}

if (-not $subject) {
  Write-Host '[commit-msg] no non-comment subject line found.'
  Write-Host '[commit-msg] expected format: <type>[optional scope]: <description>'
  exit 1
}

$subjectPattern = '^[A-Za-z\u4E00-\u9FFF][A-Za-z0-9\u4E00-\u9FFF-]*(\([^)]+\))?: .+'
if ($subject -notmatch $subjectPattern) {
  Write-Host '[commit-msg] invalid commit subject:'
  Write-Host "  $subject"
  Write-Host '[commit-msg] expected format: <type>[optional scope]: <description>'
  Write-Host '[commit-msg] examples: feat(auth): add login, fix: handle empty input'
  exit 1
}

exit 0
