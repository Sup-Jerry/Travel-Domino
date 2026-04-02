param(
  [string]$RemoteName = 'origin',
  [string]$RemoteUrl = ''
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$zeroSha = '0000000000000000000000000000000000000000'
$maxBytes = 1MB

function Resolve-MainRef {
  param(
    [string]$RemoteName
  )

  $candidates = @(
    "$RemoteName/main",
    'origin/main',
    'main'
  )

  foreach ($candidate in $candidates) {
    & git rev-parse --verify --quiet $candidate 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
      return $candidate
    }
  }

  return $null
}

$updates = @()
while (($line = [Console]::In.ReadLine()) -ne $null) {
  if ([string]::IsNullOrWhiteSpace($line)) {
    continue
  }
  $parts = $line.Trim() -split '\s+'
  if ($parts.Count -lt 4) {
    continue
  }
  $updates += [PSCustomObject]@{
    LocalRef  = $parts[0]
    LocalSha  = $parts[1]
    RemoteRef = $parts[2]
    RemoteSha = $parts[3]
  }
}

if ($updates.Count -eq 0) {
  exit 0
}

$mainRef = Resolve-MainRef -RemoteName $RemoteName
$rangeInfos = @()

foreach ($update in $updates) {
  if ($update.LocalSha -eq $zeroSha) {
    continue
  }

  if ($update.RemoteSha -ne $zeroSha) {
    $rangeInfos += [PSCustomObject]@{
      Range    = "$($update.RemoteSha)..$($update.LocalSha)"
      LocalSha = $update.LocalSha
    }
    continue
  }

  $base = $null
  if ($mainRef) {
    $base = (& git merge-base $update.LocalSha $mainRef 2>$null | Select-Object -First 1)
  }
  if (-not $base) {
    $base = (& git rev-list --max-parents=0 $update.LocalSha 2>$null | Select-Object -First 1)
  }

  if ($base -and $base -ne $update.LocalSha) {
    $rangeInfos += [PSCustomObject]@{
      Range    = "$base..$($update.LocalSha)"
      LocalSha = $update.LocalSha
    }
  } else {
    $rangeInfos += [PSCustomObject]@{
      Range    = $update.LocalSha
      LocalSha = $update.LocalSha
    }
  }
}

if ($rangeInfos.Count -eq 0) {
  exit 0
}

$addedLines = New-Object System.Collections.Generic.List[string]
$largeFileHits = New-Object System.Collections.Generic.List[string]
$seenBlobChecks = New-Object 'System.Collections.Generic.HashSet[string]'

foreach ($info in $rangeInfos) {
  $diffLines = & git diff --unified=0 --no-color $info.Range
  if ($LASTEXITCODE -ne 0) {
    Write-Host "[pre-push] failed to inspect diff range: $($info.Range)"
    exit 1
  }

  foreach ($diffLine in $diffLines) {
    if ($diffLine -match '^\+[^+]') {
      [void]$addedLines.Add($diffLine)
    }
  }

  $changedFiles = & git diff --name-only --diff-filter=AM $info.Range
  foreach ($filePath in $changedFiles) {
    if ([string]::IsNullOrWhiteSpace($filePath)) {
      continue
    }

    $normalizedPath = $filePath.Trim()
    $checkKey = "$($info.LocalSha)|$normalizedPath"
    if (-not $seenBlobChecks.Add($checkKey)) {
      continue
    }

    & git cat-file -e "$($info.LocalSha):$normalizedPath" 2>$null
    if ($LASTEXITCODE -ne 0) {
      continue
    }

    $sizeRaw = & git cat-file -s "$($info.LocalSha):$normalizedPath"
    if ($LASTEXITCODE -ne 0) {
      continue
    }

    $size = [int64]$sizeRaw
    if ($size -gt $maxBytes) {
      [void]$largeFileHits.Add(("{0} ({1} bytes)" -f $normalizedPath, $size))
    }
  }
}

$consolePattern = 'console\.lo' + 'g\s*\('
$consoleHits = @($addedLines | Where-Object { $_ -match $consolePattern })
$todoWord = 'TO' + 'DO'
$todoCommentPattern = "^\+[^+].*((//|#|/\*|\*|<!--)\s*$todoWord\b)"
$todoHits = @($addedLines | Where-Object { $_ -match $todoCommentPattern })

$failed = $false

if ($consoleHits.Count -gt 0) {
  $failed = $true
  Write-Host '[pre-push] blocked: found added console.log statements.'
  $consoleHits | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" }
}

if ($todoHits.Count -gt 0) {
  $failed = $true
  Write-Host '[pre-push] blocked: found added TODO markers.'
  $todoHits | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" }
}

if ($largeFileHits.Count -gt 0) {
  $failed = $true
  Write-Host "[pre-push] blocked: found files larger than $maxBytes bytes."
  $largeFileHits | Select-Object -Unique | ForEach-Object { Write-Host "  $_" }
}

if ($failed) {
  Write-Host '[pre-push] fix issues and push again.'
  exit 1
}

Write-Host '[pre-push] checks passed.'
exit 0
