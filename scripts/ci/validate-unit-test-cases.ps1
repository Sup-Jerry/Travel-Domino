$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $repoRoot

$listSuiteValidator = Join-Path $PSScriptRoot 'validate-list-suite-registration.ps1'
if (-not (Test-Path $listSuiteValidator)) {
  Write-Host "[validate-unit-test-cases] failed: missing script -> $listSuiteValidator"
  exit 1
}
& $listSuiteValidator
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$categories = @('normal', 'boundary', 'invalid', 'conflict', 'regression', 'combined')

$testFiles = @(
  Get-ChildItem -File (Join-Path $repoRoot 'entry\src\test\*.test.ets')
  Get-ChildItem -File (Join-Path $repoRoot 'backend\test\*.spec.ts')
)

if ($testFiles.Count -eq 0) {
  Write-Host '[validate-unit-test-cases] no test files found.'
  exit 1
}

$fileFailures = @()

foreach ($file in $testFiles) {
  $content = Get-Content -Raw $file.FullName
  $lines = $content -split "`r?`n"

  $names = @()
  foreach ($line in $lines) {
    if ($line -match "^\s*(?:it|test)\s*\(\s*'([^']+)'" -or $line -match '^\s*(?:it|test)\s*\(\s*"([^"]+)"') {
      $names += $Matches[1]
    }
  }

  if ($names.Count -eq 0) {
    $fileFailures += "$($file.FullName): no test case found."
    continue
  }

  $present = @{}
  foreach ($name in $names) {
    if ($name -match '^(normal|boundary|invalid|conflict|regression|combined):') {
      $present[$Matches[1]] = $true
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

  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*(?:it|test)\s*\(.*=>\s*\{\s*$') {
      $windowEnd = [Math]::Min($i + 200, $lines.Count - 1)
      $window = $lines[($i + 1)..$windowEnd]
      $hasArrange = ($window | Where-Object { $_ -match '//\s*Arrange' }).Count -gt 0
      $hasAct = ($window | Where-Object { $_ -match '//\s*Act' }).Count -gt 0
      $hasAssert = ($window | Where-Object { $_ -match '//\s*Assert' }).Count -gt 0
      if (-not ($hasArrange -and $hasAct -and $hasAssert)) {
        $fileFailures += "$($file.FullName): AAA missing near line $($i + 1)."
      }
    }
  }
}

if ($fileFailures.Count -gt 0) {
  Write-Host '[validate-unit-test-cases] failed:'
  $fileFailures | Sort-Object -Unique | ForEach-Object { Write-Host " - $_" }
  exit 1
}

Write-Host "[validate-unit-test-cases] success: checked $($testFiles.Count) files."
