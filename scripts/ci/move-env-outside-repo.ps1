param(
  [string]$SourceEnvFile = '.env',
  [string]$DestinationEnvFile = ''
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $SourceEnvFile)) {
  throw "Source env file not found: $SourceEnvFile"
}

if ([string]::IsNullOrWhiteSpace($DestinationEnvFile)) {
  $DestinationEnvFile = Join-Path $HOME '.travel-domino\secrets\travel.env'
}

$destinationDir = Split-Path -Parent $DestinationEnvFile
if (-not (Test-Path $destinationDir)) {
  New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
}

if (Test-Path $DestinationEnvFile) {
  throw "Target already exists: $DestinationEnvFile"
}

Move-Item -LiteralPath $SourceEnvFile -Destination $DestinationEnvFile
[Environment]::SetEnvironmentVariable('TRAVEL_ENV_FILE', $DestinationEnvFile, 'User')

Write-Host "Moved env file to: $DestinationEnvFile"
Write-Host "Set user env var: TRAVEL_ENV_FILE=$DestinationEnvFile"
Write-Host "For current shell, run:"
Write-Host "`$env:TRAVEL_ENV_FILE = '$DestinationEnvFile'"
