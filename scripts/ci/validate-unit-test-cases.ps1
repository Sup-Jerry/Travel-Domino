$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $repoRoot

$listSuiteValidator = Join-Path $PSScriptRoot 'validate-list-suite-registration.ps1'
if (-not (Test-Path $listSuiteValidator)) {
  Write-Host "[validate-unit-test-cases] failed: missing script -> $listSuiteValidator"
  exit 1
}
& $listSuiteValidator
if (-not $?) {
  if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
  exit 1
}

$categories = @('normal', 'boundary', 'invalid', 'conflict', 'regression', 'combined')

$entryRoot = Join-Path $repoRoot 'entry\src\test'
$backendRoot = Join-Path $repoRoot 'backend\test'
$entryPatterns = @('*.test.ets', '*.spec.ets')
$backendPatterns = @('*.spec.ts', '*.test.ts')

$testFiles = @(
  foreach ($pattern in $entryPatterns) {
    if (Test-Path $entryRoot) {
      Get-ChildItem -Path $entryRoot -File -Recurse -Filter $pattern
    }
  }
  foreach ($pattern in $backendPatterns) {
    if (Test-Path $backendRoot) {
      Get-ChildItem -Path $backendRoot -File -Recurse -Filter $pattern
    }
  }
) | Sort-Object -Property FullName -Unique

if ($testFiles.Count -eq 0) {
  Write-Host '[validate-unit-test-cases] no test files found.'
  exit 1
}

function Get-TestCaseNames([string]$content) {
  $names = @()
  $matches = [Regex]::Matches($content, '(?ms)\b(?:it|test)\s*\(\s*(?:''([^'']+)''|"([^"]+)"|`([^`]+)`)')
  foreach ($match in $matches) {
    foreach ($groupIndex in 1..3) {
      $value = $match.Groups[$groupIndex].Value
      if (-not [string]::IsNullOrEmpty($value)) {
        $names += $value
        break
      }
    }
  }
  return $names
}

$fileFailures = @()

foreach ($file in $testFiles) {
  $content = Get-Content -Raw $file.FullName
  $lines = $content -split "`r?`n"

  $names = Get-TestCaseNames $content
  if ($names.Count -eq 0) {
    $fileFailures += "$($file.FullName): no test case found."
    continue
  }

  $present = @{}
  foreach ($name in $names) {
    if ($name -match '^(?i)(normal|boundary|invalid|conflict|regression|combined):') {
      $present[$Matches[1].ToLowerInvariant()] = $true
    }
  }

  $missingCats = @()
  foreach ($cat in $categories) {
    if (-not $present.ContainsKey($cat)) {
      $missingCats += $cat
    }
  }
  if ($missingCats.Count -gt 0) {
    $fileFailures += "$($file.FullName): missing categories -> $($missingCats -join ', ')"
  }

  if (-not $present.ContainsKey('regression')) {
    $fileFailures += "$($file.FullName): regression case missing."
  }

  $testStartIndexes = @()
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*(?:it|test)\s*\(') {
      $testStartIndexes += $i
    }
  }

  for ($j = 0; $j -lt $testStartIndexes.Count; $j++) {
    $start = $testStartIndexes[$j]
    $nextStart = if ($j -lt $testStartIndexes.Count - 1) { $testStartIndexes[$j + 1] } else { $lines.Count }
    $windowEnd = [Math]::Min($nextStart - 1, $start + 250)
    if ($windowEnd -lt $start) {
      continue
    }

    $window = $lines[$start..$windowEnd]
    $hasArrange = ($window | Where-Object { $_ -match '(?i)//\s*Arrange' }).Count -gt 0
    $hasAct = ($window | Where-Object { $_ -match '(?i)//\s*Act' }).Count -gt 0
    $hasAssert = ($window | Where-Object { $_ -match '(?i)//\s*Assert' }).Count -gt 0
    if (-not ($hasArrange -and $hasAct -and $hasAssert)) {
      $fileFailures += "$($file.FullName): AAA missing near line $($start + 1)."
    }
  }
}

if ($fileFailures.Count -gt 0) {
  Write-Host '[validate-unit-test-cases] failed:'
  $fileFailures | Sort-Object -Unique | ForEach-Object { Write-Host " - $_" }
  exit 1
}

Write-Host "[validate-unit-test-cases] success: checked $($testFiles.Count) files."
