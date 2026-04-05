param()

$ErrorActionPreference = 'Stop'

function Get-UpstreamRef {
  $upstream = git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null
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
  exit 0
}

$violations = New-Object System.Collections.Generic.List[string]

foreach ($file in $changedFiles) {
  # 1) 1MB limit on tracked files
  $sizeOutput = git cat-file -s "HEAD:$file" 2>$null
  if ($LASTEXITCODE -eq 0 -and $sizeOutput -as [long]) {
    $size = [long]$sizeOutput
    if ($size -gt 1MB) {
      $violations.Add("Large file >1MB: $file ($size bytes)")
    }
  }

  # 2/3) console.log + task-tag checks on text files
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

Write-Host '[pre-push] governance checks passed.' -ForegroundColor Green
