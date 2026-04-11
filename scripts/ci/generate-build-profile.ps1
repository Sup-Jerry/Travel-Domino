param(
  [string]$TemplatePath = 'build-profile.template.json5',
  [string]$OutputPath = 'build-profile.json5',
  [string]$EnvFile = '.env'
)

$ErrorActionPreference = 'Stop'

function Escape-JsonString([string]$value) {
  return $value.Replace('\\', '\\\\').Replace('"', '\\"')
}

function Import-EnvFile([string]$path) {
  if (-not (Test-Path $path)) {
    return
  }

  $lines = Get-Content -Encoding UTF8 $path
  foreach ($line in $lines) {
    $trimmed = $line.Trim()
    if (-not $trimmed -or $trimmed.StartsWith('#')) {
      continue
    }

    $idx = $trimmed.IndexOf('=')
    if ($idx -lt 1) {
      continue
    }

    $name = $trimmed.Substring(0, $idx).Trim()
    $value = $trimmed.Substring($idx + 1).Trim()
    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
      if ($value.Length -ge 2) {
        $value = $value.Substring(1, $value.Length - 2)
      }
    }

    if ($name) {
      [Environment]::SetEnvironmentVariable($name, $value)
    }
  }
}

function Resolve-EnvFilePath([string]$candidate) {
  if ($candidate -and (Test-Path $candidate)) {
    return $candidate
  }

  $fromEnv = [Environment]::GetEnvironmentVariable('TRAVEL_ENV_FILE')
  if ($fromEnv -and (Test-Path $fromEnv)) {
    return $fromEnv
  }

  $defaultExternal = Join-Path $HOME '.travel-domino\secrets\travel.env'
  if (Test-Path $defaultExternal) {
    return $defaultExternal
  }

  return $candidate
}

$resolvedEnvFile = Resolve-EnvFilePath $EnvFile
Import-EnvFile $resolvedEnvFile

$requiredEnvVars = @(
  'SIGN_STORE_FILE',
  'SIGN_STORE_PASSWORD',
  'SIGN_KEY_ALIAS',
  'SIGN_KEY_PASSWORD',
  'SIGN_PROFILE_FILE',
  'SIGN_CERT_PATH'
)

$missing = @()
foreach ($varName in $requiredEnvVars) {
  $value = [Environment]::GetEnvironmentVariable($varName)
  if ([string]::IsNullOrWhiteSpace($value)) {
    $missing += $varName
  }
}

if ($missing.Count -gt 0) {
  throw "Missing required environment variables: $($missing -join ', ')"
}

if (-not (Test-Path $TemplatePath)) {
  throw "Template file not found: $TemplatePath"
}

$content = Get-Content -Raw -Encoding UTF8 $TemplatePath

$replacements = @{
  '__SIGN_STORE_FILE__' = [Environment]::GetEnvironmentVariable('SIGN_STORE_FILE')
  '__SIGN_STORE_PASSWORD__' = [Environment]::GetEnvironmentVariable('SIGN_STORE_PASSWORD')
  '__SIGN_KEY_ALIAS__' = [Environment]::GetEnvironmentVariable('SIGN_KEY_ALIAS')
  '__SIGN_KEY_PASSWORD__' = [Environment]::GetEnvironmentVariable('SIGN_KEY_PASSWORD')
  '__SIGN_PROFILE_FILE__' = [Environment]::GetEnvironmentVariable('SIGN_PROFILE_FILE')
  '__SIGN_CERT_PATH__' = [Environment]::GetEnvironmentVariable('SIGN_CERT_PATH')
}

foreach ($token in $replacements.Keys) {
  $escaped = Escape-JsonString $replacements[$token]
  $content = $content.Replace($token, $escaped)
}

$outputDir = Split-Path -Parent $OutputPath
if ($outputDir -and -not (Test-Path $outputDir)) {
  New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

Set-Content -Path $OutputPath -Value $content -Encoding UTF8
Write-Host "Generated $OutputPath from $TemplatePath"
