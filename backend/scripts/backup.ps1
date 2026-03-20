param(
  [string]$OutFile = "./backup_$(Get-Date -Format yyyyMMdd_HHmmss).sql"
)

docker compose -f ../../docker-compose.auth.yml exec -T postgres pg_dump -U travel -d travel_auth > $OutFile
Write-Host "Backup saved to $OutFile"
