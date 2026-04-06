Param(
  [string]$RepoRoot = "E:\Travel"
)

$ErrorActionPreference = "Stop"

function Assert-Contains {
  param(
    [string]$Path,
    [string]$Pattern,
    [string]$Message
  )
  $hit = Select-String -Path $Path -Pattern $Pattern -SimpleMatch
  if (-not $hit) {
    throw $Message
  }
}

function Assert-NotContains {
  param(
    [string]$Path,
    [string]$Pattern,
    [string]$Message
  )
  $hit = Select-String -Path $Path -Pattern $Pattern -SimpleMatch
  if ($hit) {
    throw $Message
  }
}

$weatherFile = Join-Path $RepoRoot "entry\src\main\ets\infrastructure\services\AmapWeatherService.ets"
$routeFile = Join-Path $RepoRoot "entry\src\main\ets\model\acl\MapServiceImpl.ets"

if (-not (Test-Path $weatherFile)) { throw "Missing file: $weatherFile" }
if (-not (Test-Path $routeFile)) { throw "Missing file: $routeFile" }

# Weather must use SDK API.
Assert-Contains -Path $weatherFile -Pattern "WeatherSearch" -Message "SDK guard failed: weather must use WeatherSearch."
Assert-Contains -Path $weatherFile -Pattern "WeatherSearchQuery" -Message "SDK guard failed: weather must use WeatherSearchQuery."
Assert-NotContains -Path $weatherFile -Pattern "restapi.amap.com/v3/weather/weatherInfo" -Message "SDK guard failed: weather Web API is forbidden."

# Route duration must use SDK RouteSearchV2 and must not call Web route API.
Assert-Contains -Path $routeFile -Pattern "RouteSearchV2" -Message "SDK guard failed: route must use RouteSearchV2."
Assert-Contains -Path $routeFile -Pattern "DriveRouteQueryV2" -Message "SDK guard failed: route must use DriveRouteQueryV2."
Assert-NotContains -Path $routeFile -Pattern "restapi.amap.com/v5/direction/driving" -Message "SDK guard failed: route Web API is forbidden."
Assert-NotContains -Path $routeFile -Pattern "restapi.amap.com/v3/direction/driving" -Message "SDK guard failed: route Web API is forbidden."

Write-Host "[AMAP_SDK_ONLY_GUARD] PASS"
