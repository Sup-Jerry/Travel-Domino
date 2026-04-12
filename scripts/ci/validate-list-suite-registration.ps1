$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $repoRoot

$entryTestRoot = Join-Path $repoRoot 'entry\src\test'
$listPath = Join-Path $entryTestRoot 'List.test.ets'
if (-not (Test-Path $listPath)) {
  Write-Host "[validate-list-suite-registration] failed: missing file -> $listPath"
  exit 1
}

function Normalize-ImportToken([string]$value) {
  if ([string]::IsNullOrWhiteSpace($value)) {
    return ''
  }

  $normalized = $value.Trim() -replace '\\', '/'
  $normalized = $normalized -replace '^\./', ''
  $normalized = $normalized -replace '^entry/src/test/', ''
  $normalized = $normalized -replace '\.ets$', ''
  return $normalized
}

function Get-NamedImportAliases([string]$segment) {
  $aliases = @()
  $inner = $segment.Trim()
  if ($inner.StartsWith('{')) {
    $inner = $inner.Substring(1)
  }
  if ($inner.EndsWith('}')) {
    $inner = $inner.Substring(0, $inner.Length - 1)
  }

  foreach ($rawPart in ($inner -split ',')) {
    $part = $rawPart.Trim()
    if ($part -eq '') {
      continue
    }
    if ($part -match '^[A-Za-z_][A-Za-z0-9_]*\s+as\s+([A-Za-z_][A-Za-z0-9_]*)$') {
      $aliases += $Matches[1]
      continue
    }
    if ($part -match '^([A-Za-z_][A-Za-z0-9_]*)$') {
      $aliases += $Matches[1]
    }
  }

  return $aliases | Sort-Object -Unique
}

function Get-ImportAliases([string]$clause) {
  $aliases = @()
  $trimmedClause = $clause.Trim()

  if ($trimmedClause -match '^\*\s+as\s+([A-Za-z_][A-Za-z0-9_]*)$') {
    return @($Matches[1])
  }

  if ($trimmedClause -match '^([A-Za-z_][A-Za-z0-9_]*)(?:\s*,\s*(\{.*\}))?$') {
    $aliases += $Matches[1]
    if ($Matches[2]) {
      $aliases += Get-NamedImportAliases $Matches[2]
    }
    return $aliases | Sort-Object -Unique
  }

  if ($trimmedClause -match '^(\{.*\})$') {
    $aliases += Get-NamedImportAliases $Matches[1]
    return $aliases | Sort-Object -Unique
  }

  return @()
}

function Get-FileCandidateTokens([System.IO.FileInfo]$file, [string]$rootPath) {
  $relativePath = $file.FullName.Substring($rootPath.Length).TrimStart('\', '/')
  $relativeToken = Normalize-ImportToken $relativePath
  $baseToken = Normalize-ImportToken $file.Name

  $tokens = @($relativeToken, $baseToken)
  foreach ($token in @($relativeToken, $baseToken)) {
    if ($token.EndsWith('.test')) {
      $tokens += $token.Substring(0, $token.Length - 5)
    }
    if ($token.EndsWith('.spec')) {
      $tokens += $token.Substring(0, $token.Length - 5)
    }
  }

  return $tokens | Where-Object { $_ -ne '' } | Sort-Object -Unique
}

$entryPatterns = @('*.test.ets', '*.spec.ets')
$allTestFiles = @(
  foreach ($pattern in $entryPatterns) {
    Get-ChildItem -Path $entryTestRoot -File -Recurse -Filter $pattern
  }
) | Sort-Object -Property FullName -Unique

$targetTestFiles = $allTestFiles | Where-Object { $_.FullName -ne $listPath }

$content = Get-Content -Raw $listPath
$contentWithoutImports = [Regex]::Replace($content, '(?ms)^\s*import\s+.+?;\s*', '')

$aliasesByToken = @{}
$importMatches = [Regex]::Matches($content, '(?ms)^\s*import\s+(.+?)\s+from\s+["''](.+?)["'']\s*;')
foreach ($importMatch in $importMatches) {
  $clause = $importMatch.Groups[1].Value
  $pathToken = Normalize-ImportToken $importMatch.Groups[2].Value
  if ($pathToken -eq '') {
    continue
  }

  $candidateTokens = @($pathToken)
  $leaf = Split-Path -Leaf $pathToken
  if ($leaf -ne '') {
    $candidateTokens += $leaf
  }
  foreach ($token in @($pathToken, $leaf)) {
    if ($token.EndsWith('.test')) {
      $candidateTokens += $token.Substring(0, $token.Length - 5)
    }
    if ($token.EndsWith('.spec')) {
      $candidateTokens += $token.Substring(0, $token.Length - 5)
    }
  }

  $aliases = Get-ImportAliases $clause
  if ($aliases.Count -eq 0) {
    continue
  }

  foreach ($token in ($candidateTokens | Sort-Object -Unique)) {
    if ($token -eq '') {
      continue
    }
    if (-not $aliasesByToken.ContainsKey($token)) {
      $aliasesByToken[$token] = @()
    }
    foreach ($alias in $aliases) {
      if ($aliasesByToken[$token] -notcontains $alias) {
        $aliasesByToken[$token] += $alias
      }
    }
  }
}

$missingImports = @()
$missingCalls = @()

foreach ($file in $targetTestFiles) {
  $candidateTokens = Get-FileCandidateTokens $file $entryTestRoot
  $aliases = @()
  foreach ($token in $candidateTokens) {
    if ($aliasesByToken.ContainsKey($token)) {
      $aliases += $aliasesByToken[$token]
    }
  }
  $aliases = $aliases | Sort-Object -Unique

  $relativePath = $file.FullName.Substring($entryTestRoot.Length).TrimStart('\', '/')
  if ($aliases.Count -eq 0) {
    $missingImports += $relativePath
    continue
  }

  $hasReference = $false
  foreach ($alias in $aliases) {
    if ($contentWithoutImports -match ("(?m)\b" + [Regex]::Escape($alias) + "\b")) {
      $hasReference = $true
      break
    }
  }

  if (-not $hasReference) {
    $missingCalls += "$relativePath => $($aliases -join '|')"
  }
}

$failures = @()
if ($missingImports.Count -gt 0) {
  $failures += "missing imports -> $($missingImports -join ', ')"
}
if ($missingCalls.Count -gt 0) {
  $failures += "missing testsuite references -> $($missingCalls -join ', ')"
}

if ($failures.Count -gt 0) {
  Write-Host '[validate-list-suite-registration] failed:'
  $failures | ForEach-Object { Write-Host " - $_" }
  exit 1
}

Write-Host "[validate-list-suite-registration] success: checked $($targetTestFiles.Count) test files."
