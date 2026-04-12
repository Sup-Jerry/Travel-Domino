$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $repoRoot

$listPath = Join-Path $repoRoot 'entry\src\test\List.test.ets'
if (-not (Test-Path $listPath)) {
  Write-Host "[validate-list-suite-registration] failed: missing file -> $listPath"
  exit 1
}

$allTestFiles = Get-ChildItem -File (Join-Path $repoRoot 'entry\src\test\*.test.ets')
$targetTestFiles = $allTestFiles | Where-Object { $_.Name -ne 'List.test.ets' }

$content = Get-Content -Raw $listPath
$lines = $content -split "`r?`n"

$importAliasByStem = @{}
foreach ($line in $lines) {
  if ($line -match "^\s*import\s+([A-Za-z0-9_]+)\s+from\s+'\.\/([^']+)';\s*$") {
    $alias = $Matches[1]
    $pathToken = $Matches[2]
    $stem = $pathToken
    $importAliasByStem[$stem] = $alias
  }
}

$missingImports = @()
$missingCalls = @()

foreach ($file in $targetTestFiles) {
  $stem = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
  if (-not $importAliasByStem.ContainsKey($stem)) {
    $missingImports += $file.Name
    continue
  }

  $alias = $importAliasByStem[$stem]
  if ($content -notmatch ("(?m)\b" + [Regex]::Escape($alias) + "\s*\(\s*\)\s*;")) {
    $missingCalls += "$($file.Name) => $alias()"
  }
}

$failures = @()
if ($missingImports.Count -gt 0) {
  $failures += "missing imports -> $($missingImports -join ', ')"
}
if ($missingCalls.Count -gt 0) {
  $failures += "missing testsuite calls -> $($missingCalls -join ', ')"
}

if ($failures.Count -gt 0) {
  Write-Host '[validate-list-suite-registration] failed:'
  $failures | ForEach-Object { Write-Host " - $_" }
  exit 1
}

Write-Host "[validate-list-suite-registration] success: checked $($targetTestFiles.Count) test files."
