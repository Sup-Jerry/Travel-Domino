param(
  [ValidateSet('Repo', 'Staged')]
  [string]$Scope = 'Repo'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $repoRoot

function Normalize-PathForScan([string]$path) {
  return $path.Replace('\\', '/').Trim()
}

function Normalize-Value([string]$value) {
  $v = $value.Trim()
  if ($v.EndsWith(',')) {
    $v = $v.Substring(0, $v.Length - 1).Trim()
  }
  if (($v.StartsWith('"') -and $v.EndsWith('"')) -or ($v.StartsWith("'") -and $v.EndsWith("'"))) {
    if ($v.Length -ge 2) {
      $v = $v.Substring(1, $v.Length - 2)
    }
  }
  return $v.Trim()
}

$allowlistPath = Join-Path $PSScriptRoot 'secret-scan-allowlist.txt'
$allowlist = @()
if (Test-Path $allowlistPath) {
  $allowlist = Get-Content $allowlistPath |
    ForEach-Object { Normalize-PathForScan $_ } |
    Where-Object { $_ -and -not $_.StartsWith('#') }
}

function Is-Allowlisted([string]$path) {
  $normalized = Normalize-PathForScan $path
  foreach ($entry in $allowlist) {
    if ($entry.Contains('*') -or $entry.Contains('?')) {
      if ($normalized -like $entry) {
        return $true
      }
    }
    elseif ($normalized -eq $entry) {
      return $true
    }
  }
  return $false
}

function Is-TemplateFile([string]$path) {
  $normalized = Normalize-PathForScan $path
  if ($normalized -eq '.env.example' -or $normalized -like '*/.env.example') {
    return $true
  }
  if ($normalized -like '*.template.*' -or $normalized -like '*.example.*') {
    return $true
  }
  return $false
}

function Is-EnvReference([string]$value) {
  if ($value -match '^\$\{[A-Za-z_][A-Za-z0-9_]*(?::[^}]*)?\}$') {
    return $true
  }
  if ($value -match '^\$[A-Za-z_][A-Za-z0-9_]*$') {
    return $true
  }
  if ($value -match '^%[A-Za-z_][A-Za-z0-9_]*%$') {
    return $true
  }
  return $false
}

function Is-ExplicitPlaceholder([string]$value) {
  $v = $value.Trim()
  if ([string]::IsNullOrWhiteSpace($v)) {
    return $false
  }
  if ($v.StartsWith('REPLACE_WITH_')) { return $true }
  if ($v.StartsWith('YOUR_')) { return $true }
  if ($v -eq '***') { return $true }
  if ($v -eq '<REPLACE_ME>') { return $true }
  return $false
}

$weakValueSet = @(
  'change_me', 'changeme', '123456', 'password', 'test', 'travel_pass',
  'admin', 'root', 'qwerty', 'letmein'
)

function Is-WeakValue([string]$value) {
  $v = $value.Trim().ToLowerInvariant()
  foreach ($candidate in $weakValueSet) {
    if ($v -eq $candidate) {
      return $true
    }
  }
  return $false
}

function Is-BlockedPath([string]$path) {
  $normalized = Normalize-PathForScan $path
  if ($normalized -eq '.env.example' -or $normalized -like '*/.env.example') {
    return $false
  }

  $blockedPatterns = @(
    '(^|/)\.env(\..+)?$',
    '^build-profile\\.json5$',
    '(^|/)agconnect-services\.json$',
    '\.(p12|p7b|jks|keystore|cer)$'
  )

  foreach ($pattern in $blockedPatterns) {
    if ($normalized -match $pattern) {
      return $true
    }
  }

  return $false
}

function Get-ScanFiles([string]$scope) {
  $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

  if ($scope -eq 'Repo') {
    $trackedFiles = git ls-files
    foreach ($file in $trackedFiles) {
      if (-not [string]::IsNullOrWhiteSpace($file)) {
        [void]$set.Add((Normalize-PathForScan $file))
      }
    }
  }

  $stagedFiles = git diff --cached --name-only --diff-filter=ACMR
  foreach ($file in $stagedFiles) {
    if (-not [string]::IsNullOrWhiteSpace($file)) {
      [void]$set.Add((Normalize-PathForScan $file))
    }
  }

  return @($set)
}

$filesToScan = Get-ScanFiles $Scope
if ($Scope -eq 'Staged' -and $filesToScan.Count -eq 0) {
  Write-Host 'Secret scan skipped: no staged files.'
  exit 0
}

$privateKeyRegex = [regex]'-----BEGIN\s+[A-Z0-9 ]*PRIVATE KEY-----'
$bearerRegex = [regex]'Bearer\s+[A-Za-z0-9_\-]{24,}'
$quotedSensitiveRegex = [regex]'(?m)(?<key>storePassword|keyPassword|password|passwd|pwd|api[_-]?key|jwt_secret|client[_-]?secret|db[_-]?password|database[_-]?password)\s*[:=]\s*["''](?<value>[^"'']+)["'']'
$envSensitiveRegex = [regex]'(?m)^(?<key>[A-Z0-9_]*(PASSWORD|SECRET|TOKEN|API_KEY|JWT_SECRET)[A-Z0-9_]*)\s*=\s*(?<value>[^\r\n#]+)$'
$yamlSensitiveRegex = [regex]'(?m)^\s*(?<key>[A-Z0-9_]*(PASSWORD|SECRET|TOKEN|API_KEY|JWT_SECRET)[A-Z0-9_]*|storePassword|keyPassword)\s*:\s*(?<value>[^\r\n#]+)$'
$databaseUrlRegex = [regex]'(?m)^\s*DATABASE_URL\s*[:=]\s*(?<value>[^\r\n#]+)$'

$findings = New-Object System.Collections.Generic.List[object]

function Add-Finding([string]$file, [string]$issue, [string]$detail) {
  $null = $findings.Add([pscustomobject]@{
      file = $file
      issue = $issue
      detail = $detail
    })
}

function Evaluate-SensitiveValue([string]$file, [string]$key, [string]$rawValue, [bool]$isTemplate) {
  $value = Normalize-Value $rawValue
  if ([string]::IsNullOrWhiteSpace($value)) {
    return
  }

  if (Is-EnvReference $value) {
    return
  }

  if (Is-WeakValue $value) {
    Add-Finding $file 'weak_secret_value' "Weak value '$value' for key '$key'."
    return
  }

  if (Is-ExplicitPlaceholder $value) {
    if (-not $isTemplate) {
      Add-Finding $file 'placeholder_outside_template' "Placeholder '$value' used outside template/example file."
    }
    return
  }

  Add-Finding $file 'hardcoded_secret' "Literal value found for key '$key'."
}

foreach ($file in $filesToScan) {
  if (Is-Allowlisted $file) {
    continue
  }

  if (Is-BlockedPath $file) {
    Add-Finding $file 'blocked_file' 'High-risk file is tracked/staged in repository.'
    continue
  }

  if (-not (Test-Path $file)) {
    continue
  }

  $content = Get-Content -Raw -Encoding UTF8 -ErrorAction SilentlyContinue $file
  if ([string]::IsNullOrEmpty($content)) {
    continue
  }

  if ($content.Contains([char]0)) {
    continue
  }

  if ($privateKeyRegex.IsMatch($content)) {
    Add-Finding $file 'private_key' 'Detected private key block.'
  }

  if ($bearerRegex.IsMatch($content)) {
    Add-Finding $file 'bearer_token' 'Detected bearer-token-like literal.'
  }

  $isTemplate = Is-TemplateFile $file

  foreach ($match in $quotedSensitiveRegex.Matches($content)) {
    Evaluate-SensitiveValue $file $match.Groups['key'].Value $match.Groups['value'].Value $isTemplate
  }

  foreach ($match in $envSensitiveRegex.Matches($content)) {
    Evaluate-SensitiveValue $file $match.Groups['key'].Value $match.Groups['value'].Value $isTemplate
  }

  foreach ($match in $yamlSensitiveRegex.Matches($content)) {
    Evaluate-SensitiveValue $file $match.Groups['key'].Value $match.Groups['value'].Value $isTemplate
  }

  foreach ($match in $databaseUrlRegex.Matches($content)) {
    $databaseValue = Normalize-Value $match.Groups['value'].Value
    if ([string]::IsNullOrWhiteSpace($databaseValue)) {
      continue
    }

    if (Is-EnvReference $databaseValue) {
      continue
    }

    if ($databaseValue -match '^[a-z]+://[^:/\s]+:(?<pwd>[^@/\s]+)@') {
      $passwordValue = Normalize-Value $Matches['pwd']

      if (Is-EnvReference $passwordValue) {
        continue
      }
      if (Is-WeakValue $passwordValue) {
        Add-Finding $file 'weak_database_password' "Weak password literal in DATABASE_URL: '$passwordValue'."
        continue
      }
      if (Is-ExplicitPlaceholder $passwordValue) {
        if (-not $isTemplate) {
          Add-Finding $file 'placeholder_outside_template' "Placeholder password '$passwordValue' in DATABASE_URL outside template/example file."
        }
        continue
      }

      Add-Finding $file 'database_url_with_password' 'DATABASE_URL contains embedded literal password.'
    }
  }
}

if ($findings.Count -gt 0) {
  Write-Host 'Secret scan failed. Findings:'
  $findings |
    Sort-Object file, issue, detail -Unique |
    ForEach-Object { Write-Host " - $($_.file): [$($_.issue)] $($_.detail)" }
  exit 1
}

Write-Host "Secret scan passed. Scope=$Scope"





