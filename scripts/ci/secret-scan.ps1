$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $repoRoot

$allowlistPath = Join-Path $PSScriptRoot 'secret-scan-allowlist.txt'
$allowlist = @()
if (Test-Path $allowlistPath) {
  $allowlist = Get-Content $allowlistPath |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith('#') }
}

function Is-Allowlisted([string]$path) {
  foreach ($item in $allowlist) {
    if ($path -eq $item) {
      return $true
    }
  }
  return $false
}

function Is-PlaceholderValue([string]$value) {
  if ([string]::IsNullOrWhiteSpace($value)) {
    return $true
  }
  if ($value.StartsWith('REPLACE_WITH_')) {
    return $true
  }
  if ($value.StartsWith('YOUR_')) {
    return $true
  }
  if ($value -eq '***') {
    return $true
  }
  return $false
}

$trackedFiles = @()
try {
  $trackedFiles = git ls-files
} catch {
  Write-Error 'secret-scan requires git repository context.'
}

$findings = @()
foreach ($file in $trackedFiles) {
  if (Is-Allowlisted $file) {
    continue
  }
  if (-not (Test-Path $file)) {
    continue
  }
  $content = Get-Content $file -Raw -ErrorAction SilentlyContinue
  if (-not $content) {
    continue
  }

  $typedKeyMatches = [regex]::Matches($content, "(AI_API_KEY|AMAP_WEB_API_KEY|AMAP_SDK_API_KEY)\s*:\s*string\s*=\s*'([^']*)'")
  foreach ($m in $typedKeyMatches) {
    $value = $m.Groups[2].Value
    if (-not (Is-PlaceholderValue $value)) {
      $findings += "${file}: hardcoded $($m.Groups[1].Value)"
    }
  }

  $bearerMatches = [regex]::Matches($content, "Bearer\s+[A-Za-z0-9_\-]{24,}")
  foreach ($m in $bearerMatches) {
    $findings += "${file}: possible bearer token"
  }

  $genericKeyMatches = [regex]::Matches($content, "(api[_-]?key|secret|token)\s*[:=]\s*['""][A-Za-z0-9_\-]{24,}['""]", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  foreach ($m in $genericKeyMatches) {
    $findings += "${file}: possible hardcoded credential"
  }
}

if ($findings.Count -gt 0) {
  Write-Host 'Secret scan failed. Findings:'
  $findings | Sort-Object -Unique | ForEach-Object { Write-Host " - $_" }
  exit 1
}

Write-Host 'Secret scan passed.'
