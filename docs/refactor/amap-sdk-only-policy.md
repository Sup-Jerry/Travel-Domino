# AMap SDK-Only Policy (Travel)

## Goal
- Weather and route-duration logic must use HarmonyOS NEXT AMap SDK APIs.
- Web REST is not allowed as the default path.

## Required APIs
- Weather: `WeatherSearch` and `WeatherSearchQuery` from `@amap/amap_lbs_search`.
- Route duration: `RouteSearchV2` and `DriveRouteQueryV2` from `@amap/amap_lbs_search`.
- Geo and reverse-geo: SDK geo search APIs.

## Code Anchors
- `entry/src/main/ets/infrastructure/services/AmapWeatherService.ets`
- `entry/src/main/ets/model/acl/MapServiceImpl.ets`
- `entry/src/main/ets/infrastructure/services/AmapService.ets`
- `entry/src/main/ets/entryability/EntryAbility.ets`

## Pre-commit Gate
1. Run `powershell -ExecutionPolicy Bypass -File scripts/guard-amap-sdk-only.ps1`.
2. Confirm route path does not call AMap Web route endpoints.
3. Confirm weather path uses SDK listener flow.
4. Confirm build has no `libAMapOpenMapJNI.so` import/type errors.

## Official References
- Drive: https://lbs.amap.com/api/harmonyosnext-map3d-sdk/guide/route-plan/drive
- Walk: https://lbs.amap.com/api/harmonyosnext-map3d-sdk/guide/route-plan/walk
- Bus: https://lbs.amap.com/api/harmonyosnext-map3d-sdk/guide/route-plan/bus
- Ride: https://lbs.amap.com/api/harmonyosnext-map3d-sdk/guide/route-plan/ride
- Geo: https://lbs.amap.com/api/harmonyosnext-map3d-sdk/guide/map-data/geo
- Weather: https://lbs.amap.com/api/harmonyosnext-map3d-sdk/guide/map-data/weather
