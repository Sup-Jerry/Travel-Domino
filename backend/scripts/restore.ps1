param(
  [Parameter(Mandatory = $true)]
  [string]$SqlFile
)

Get-Content $SqlFile | docker compose -f ../../docker-compose.auth.yml exec -T postgres psql -U travel -d travel_auth
Write-Host "Restore completed from $SqlFile"
