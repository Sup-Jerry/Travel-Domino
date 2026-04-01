param(
    [Parameter(Mandatory = $false)]
    [string]$Root = ".",

    [Parameter(Mandatory = $false)]
    [int]$MinSizeMB = 20,

    [Parameter(Mandatory = $false)]
    [int]$Top = 200,

    [Parameter(Mandatory = $false)]
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Convert-ToMB {
    param([long]$Bytes)
    return [Math]::Round($Bytes / 1MB, 2)
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$safeDirNames = @(
    "node_modules", "dist", "build", "out", "target", "coverage",
    ".next", ".nuxt", ".cache", ".turbo", ".parcel-cache", ".gradle",
    "tmp", "temp", "logs"
)
$safeExtensions = @(".log", ".tmp", ".temp", ".cache", ".bak", ".old", ".dmp")
$protectedDirNames = @(".git", ".svn", ".hg")

$trackedPathSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
$gitAvailable = $false

try {
    $null = git --version 2>$null
    $insideRepo = (git -C $resolvedRoot rev-parse --is-inside-work-tree 2>$null).Trim()
    if ($insideRepo -eq "true") {
        $gitAvailable = $true
        $tracked = git -C $resolvedRoot ls-files
        foreach ($line in $tracked) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $fullPath = Join-Path $resolvedRoot $line
            $normalized = [System.IO.Path]::GetFullPath($fullPath)
            $null = $trackedPathSet.Add($normalized)
        }
    }
}
catch {
    $gitAvailable = $false
}

$files = Get-ChildItem -LiteralPath $resolvedRoot -File -Recurse -Force | Where-Object {
    $full = [System.IO.Path]::GetFullPath($_.FullName)
    $parts = $full.Split([System.IO.Path]::DirectorySeparatorChar)
    foreach ($dirName in $protectedDirNames) {
        if ($parts -contains $dirName) { return $false }
    }
    return $true
}

$candidates = New-Object System.Collections.Generic.List[object]

foreach ($file in $files) {
    if ($file.Length -lt ($MinSizeMB * 1MB)) { continue }

    $fullPath = [System.IO.Path]::GetFullPath($file.FullName)
    if ($gitAvailable -and $trackedPathSet.Contains($fullPath)) { continue }

    $segments = $fullPath.Split([System.IO.Path]::DirectorySeparatorChar)
    $inSafeDir = $false
    foreach ($safeDir in $safeDirNames) {
        if ($segments -contains $safeDir) {
            $inSafeDir = $true
            break
        }
    }
    $safeByExt = $safeExtensions -contains $file.Extension.ToLowerInvariant()

    if (-not $inSafeDir -and -not $safeByExt) { continue }

    $reason = if ($inSafeDir) { "safe-dir" } else { "safe-extension" }
    $candidates.Add([PSCustomObject]@{
        Path     = $fullPath
        SizeMB   = Convert-ToMB -Bytes $file.Length
        Bytes    = $file.Length
        Reason   = $reason
        Tracked  = $false
    }) | Out-Null
}

$selected = @($candidates | Sort-Object Bytes -Descending | Select-Object -First $Top)
$totalBytes = 0L
foreach ($item in $selected) {
    $totalBytes += [long]$item.Bytes
}

Write-Host "Root: $resolvedRoot"
Write-Host "Git tracked protection: $gitAvailable"
Write-Host "Candidates: $($selected.Count)"
Write-Host ("Total candidate size: {0} MB" -f (Convert-ToMB -Bytes $totalBytes))

if ($selected.Count -eq 0) {
    Write-Host "No removable candidates found with current rules."
    exit 0
}

$selected | Select-Object Path, SizeMB, Reason | Format-Table -AutoSize

if (-not $Apply) {
    Write-Host ""
    Write-Host "Preview only. Re-run with -Apply to delete these files."
    exit 0
}

$deleted = New-Object System.Collections.Generic.List[object]
$failed = New-Object System.Collections.Generic.List[object]

foreach ($item in $selected) {
    try {
        Remove-Item -LiteralPath $item.Path -Force
        $deleted.Add($item) | Out-Null
    }
    catch {
        $failed.Add([PSCustomObject]@{
            Path   = $item.Path
            Error  = $_.Exception.Message
            SizeMB = $item.SizeMB
        }) | Out-Null
    }
}

$deletedBytes = 0L
foreach ($item in $deleted) {
    $deletedBytes += [long]$item.Bytes
}

$report = [PSCustomObject]@{
    root               = $resolvedRoot
    min_size_mb        = $MinSizeMB
    top                = $Top
    git_protection     = $gitAvailable
    deleted_count      = $deleted.Count
    deleted_size_mb    = Convert-ToMB -Bytes $deletedBytes
    failed_count       = $failed.Count
    deleted            = $deleted
    failed             = $failed
    generated_at       = (Get-Date).ToString("s")
}

$reportPath = Join-Path $resolvedRoot (".app-size-prune-report-{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $reportPath -Encoding utf8

Write-Host ""
Write-Host "Deleted files: $($deleted.Count)"
Write-Host ("Freed space: {0} MB" -f (Convert-ToMB -Bytes $deletedBytes))
Write-Host "Failures: $($failed.Count)"
Write-Host "Report: $reportPath"
