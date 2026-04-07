param()

$ErrorActionPreference = 'Stop'

$currentBranch = (git branch --show-current).Trim()
$allowMainPush = $env:ALLOW_MAIN_PUSH -eq '1'
if ($currentBranch -eq 'main' -and -not $allowMainPush) {
  Write-Host '[pre-push] blocked: direct push to main is disabled by governance.' -ForegroundColor Red
  Write-Host '[pre-push] use develop/feature/release/hotfix branches, or set ALLOW_MAIN_PUSH=1 for an explicit override.' -ForegroundColor Yellow
  exit 1
}

function Get-UpstreamRef {
  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $upstream = & git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null
  $ErrorActionPreference = $previousPreference
  if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($upstream)) {
    return $upstream.Trim()
  }
  return 'origin/main'
}

function Get-ChangedFiles {
  $upstream = Get-UpstreamRef
  $range = "$upstream...HEAD"
  $files = git diff --name-only --diff-filter=ACMR $range 2>$null
  if ($LASTEXITCODE -ne 0) {
    $files = git diff --name-only --diff-filter=ACMR HEAD~1...HEAD
  }

  return @($files | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Is-TextFile([string]$Path) {
  $ext = [IO.Path]::GetExtension($Path).ToLowerInvariant()
  $textExts = @(
    '.js', '.jsx', '.ts', '.tsx', '.json', '.json5', '.md', '.txt', '.yml', '.yaml',
    '.xml', '.html', '.css', '.scss', '.less', '.java', '.kt', '.swift', '.py', '.ps1',
    '.sh', '.c', '.h', '.cpp', '.hpp', '.cs', '.go', '.rs', '.rb', '.php', '.sql', '.env'
  )
  return $textExts -contains $ext
}

$changedFiles = Get-ChangedFiles
if ($changedFiles.Count -eq 0) {
  Write-Host '[pre-push] no changed files detected in push range.' -ForegroundColor DarkGray
} else {
  $violations = New-Object System.Collections.Generic.List[string]
  $forbiddenPathPattern = '(?i)^DeepScientist/runtime/tools/uv/bin/(uv\.exe|uvx\.exe)?$|(?i)^DeepScientist/runtime/tools/uv/bin/'

  foreach ($file in $changedFiles) {
    if ($file -match $forbiddenPathPattern) {
      $violations.Add("Forbidden runtime binary path: $file")
      continue
    }

    $sizeOutput = git cat-file -s "HEAD:$file" 2>$null
    if ($LASTEXITCODE -eq 0 -and $sizeOutput -as [long]) {
      $size = [long]$sizeOutput
      if ($size -gt 1MB) {
        $violations.Add("Large file >1MB: $file ($size bytes)")
      }
    }

    if ((Test-Path -LiteralPath $file) -and (Is-TextFile $file)) {
      $content = Get-Content -LiteralPath $file -Raw -ErrorAction SilentlyContinue
      if ($null -ne $content) {
        if ($content -match '\bconsole\.log\s*\(') {
          $violations.Add("console.log found: $file")
        }
        $taskTag = ('TO' + 'DO')
        $taskPattern = "(?im)#?\s*$taskTag\b|//\s*$taskTag\b|/\*\s*$taskTag\b"
        if ($content -match $taskPattern) {
          $violations.Add("task-tag comment found: $file")
        }
      }
    }
  }

  if ($violations.Count -gt 0) {
    Write-Host '[pre-push] blocked by governance checks:' -ForegroundColor Red
    $violations | Sort-Object -Unique | ForEach-Object { Write-Host " - $_" -ForegroundColor Yellow }
    exit 1
  }
}

$repoRoot = (git rev-parse --show-toplevel).Trim()
$secretScanScript = Join-Path $repoRoot 'scripts/ci/secret-scan.ps1'
if (-not (Test-Path -LiteralPath $secretScanScript)) {
  Write-Host '[pre-push] missing scripts/ci/secret-scan.ps1' -ForegroundColor Red
  exit 1
}

& powershell -NoProfile -ExecutionPolicy Bypass -File $secretScanScript -Scope Repo
if ($LASTEXITCODE -ne 0) {
  Write-Host '[pre-push] secret scan failed.' -ForegroundColor Red
  exit $LASTEXITCODE
}

Write-Host '[pre-push] governance checks passed.' -ForegroundColor Green
