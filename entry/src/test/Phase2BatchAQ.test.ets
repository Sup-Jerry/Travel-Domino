import { describe, it, expect } from '@ohos/hypium';
import { common } from '@kit.AbilityKit';
import { PoiItem } from '@amap/amap_lbs_search';
import { ArrivalReminderAction, ArrivalReminderEngine } from '../main/ets/infrastructure/services/ArrivalReminderEngine';
import { AmapService, GeoCoordinate, PoiSearchItem } from '../main/ets/infrastructure/services/AmapService';
import { AmapWeatherService } from '../main/ets/infrastructure/services/AmapWeatherService';
import { TrafficEngine } from '../main/ets/infrastructure/services/TrafficEngine';
import { HttpRequestHelper } from '../main/ets/infrastructure/adapters/HttpRequestHelper';
import { AppConfig } from '../main/ets/common/utils/AppConfig';
import { WeatherCache } from '../main/ets/infrastructure/services/WeatherCache';
import { WeatherGeoPointRequest, WeatherInfo } from '../main/ets/infrastructure/adapters/IWeatherAdapter';
import { IMapService, LocationInfo, DriveStrategy } from '../main/ets/model/interface/IMapService';
import { MapServiceImpl } from '../main/ets/model/acl/MapServiceImpl';
import { DomainConstants } from '../main/ets/common/constants/DomainConstants';
import { PlanItem, PlanRepositoryImpl } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';
import { EventRepositoryImpl } from '../main/ets/infrastructure/persistence/EventRepositoryImpl';
import { EventEntity } from '../main/ets/model/entity/EventEntity';

interface PlanCandidateCacheAQ {
  scheduleCount: number;
  pendingCount: number;
  activeCount: number;
  withCoordinateCount: number;
  eligibleCount: number;
  candidates: EventEntity[];
  timeDeltaByEventId: Map<number, number>;
}

interface HttpResponseAQ {
  responseCode: number;
  result: string;
}

interface PoiNodeAQ {
  name: string;
  address: string;
  location: string;
  distance?: string;
}

interface PollutedMapServiceAQ {
  marker: string;
}

class RuntimeContextMockAQ {
  marker: string;

  constructor(marker: string) {
    this.marker = marker;
  }
}

class FakeLatLonPointAQ {
  private readonly latitude: number;
  private readonly longitude: number;

  constructor(latitude: number, longitude: number) {
    this.latitude = latitude;
    this.longitude = longitude;
  }

  public getLatitude(): number {
    return this.latitude;
  }

  public getLongitude(): number {
    return this.longitude;
  }
}

class FakePoiItemAQ {
  private readonly title: string;
  private readonly snippet: string;
  private readonly point: FakeLatLonPointAQ | undefined;
  private readonly distance: number;

  constructor(title: string, snippet: string, lat: number, lng: number, distance: number = 0, withPoint: boolean = true) {
    this.title = title;
    this.snippet = snippet;
    this.point = withPoint ? new FakeLatLonPointAQ(lat, lng) : undefined;
    this.distance = distance;
  }

  public getLatLonPoint(): FakeLatLonPointAQ | undefined {
    return this.point;
  }

  public getTitle(): string {
    return this.title;
  }

  public getSnippet(): string {
    return this.snippet;
  }

  public getDistance(): number {
    return this.distance;
  }
}

class FakeAmapLocationAQ {
  latitude: number = 0;
  longitude: number = 0;
  accuracy: number = 0;
  speed: number = 0;
}

class FakeGeoFenceAQ {
  private readonly customId: string;
  private readonly status: number;

  constructor(customId: string, status: number) {
    this.customId = customId;
    this.status = status;
  }

  public getCustomId(): string {
    return this.customId;
  }

  public getStatus(): number {
    return this.status;
  }
}

class FakeGeoFenceListAQ {
  private readonly items: FakeGeoFenceAQ[];
  length: number = 0;

  constructor(items: FakeGeoFenceAQ[]) {
    this.items = items;
    this.length = items.length;
  }

  public get(index: number): FakeGeoFenceAQ | undefined {
    return this.items[index];
  }
}

class FakeGeoFenceClientAQ {
  addedIds: string[] = [];
  removeCount: number = 0;
  fenceList: FakeGeoFenceAQ[] = [];
  removeShouldThrow: boolean = false;

  public removeGeoFence(): void {
    this.removeCount += 1;
    if (this.removeShouldThrow) {
      throw new Error('remove_geofence_failed_aq');
    }
  }

  public addRoundGeoFence(_point: Object, _radius: number, customId: string): void {
    this.addedIds.push(customId);
  }

  public getAllGeoFence(): Object {
    return new FakeGeoFenceListAQ(this.fenceList) as Object;
  }

  public doCheckFence(_location: Object): void {
  }

  public setActivateAction(_action: number): void {
  }

  public setGeoFenceListener(_listener: Object): void {
  }
}

class FakeLocationManagerAQ {
  startCalls: number = 0;
  stopCalls: number = 0;
  startShouldThrow: boolean = false;
  stopShouldThrow: boolean = false;

  public startUpdatingLocation(): void {
    this.startCalls += 1;
    if (this.startShouldThrow) {
      throw new Error('start_location_failed_aq');
    }
  }

  public stopUpdatingLocation(): void {
    this.stopCalls += 1;
    if (this.stopShouldThrow) {
      throw new Error('stop_location_failed_aq');
    }
  }

  public setLocationOption(_type: number, _option: Object): void {
  }

  public setLocationListener(_type: number, _listener: Object): void {
  }
}

class FakeMapServiceAQ implements IMapService {
  public async getLocationInfo(_keyword: string): Promise<LocationInfo[]> {
    return [];
  }

  public async calculateCommute(_from: string, _to: string): Promise<number> {
    return 0;
  }

  public async getDriveDuration(
    _origin: LocationInfo,
    _destination: LocationInfo,
    _strategy: DriveStrategy
  ): Promise<number> {
    return 12;
  }

  public async getDurationByMode(
    _origin: LocationInfo,
    _destination: LocationInfo,
    _mode: number,
    _startTime?: string
  ): Promise<number> {
    return 18;
  }
}

class TestableAmapWeatherServiceAQ extends AmapWeatherService {
  weatherByCity: Map<string, WeatherInfo> = new Map<string, WeatherInfo>();
  getWeatherCallCount: number = 0;

  public async getWeather(cityName: string): Promise<WeatherInfo | null> {
    this.getWeatherCallCount += 1;
    return this.weatherByCity.get(cityName) ?? null;
  }
}

class AmapHooksAQ {
  private readonly originRequest: Object;
  private readonly originValidateAmapWebConfig: Object;
  private readonly originGetRuntimeContext: Object;
  private readonly originSearchPoiBySdk: Object;
  private readonly originSearchPoiWithWebFallback: Object;
  private readonly originGetGeocodeBySdkGeoSearch: Object;
  private readonly originGetGeocodeBySdkKeyword: Object;
  private readonly originGetGeocodeByWeb: Object;
  private readonly originGetCityCodeByCoordinate: Object;
  private readonly originGetCityCodeBySdkGeoSearch: Object;
  private readonly originGetRegeo: Object;
  private readonly originGetRegeoBySdkGeoSearch: Object;
  private readonly originGetRegeoBySdkNearby: Object;

  constructor() {
    this.originRequest = Reflect.get(HttpRequestHelper, 'request') as Object;
    this.originValidateAmapWebConfig = Reflect.get(AppConfig, 'validateAmapWebConfig') as Object;
    this.originGetRuntimeContext = Reflect.get(AmapService, 'getRuntimeContext') as Object;
    this.originSearchPoiBySdk = Reflect.get(AmapService, 'searchPoiBySdk') as Object;
    this.originSearchPoiWithWebFallback = Reflect.get(AmapService, 'searchPoiWithWebFallback') as Object;
    this.originGetGeocodeBySdkGeoSearch = Reflect.get(AmapService, 'getGeocodeBySdkGeoSearch') as Object;
    this.originGetGeocodeBySdkKeyword = Reflect.get(AmapService, 'getGeocodeBySdkKeyword') as Object;
    this.originGetGeocodeByWeb = Reflect.get(AmapService, 'getGeocodeByWeb') as Object;
    this.originGetCityCodeByCoordinate = Reflect.get(AmapService, 'getCityCodeByCoordinate') as Object;
    this.originGetCityCodeBySdkGeoSearch = Reflect.get(AmapService, 'getCityCodeBySdkGeoSearch') as Object;
    this.originGetRegeo = Reflect.get(AmapService, 'getRegeo') as Object;
    this.originGetRegeoBySdkGeoSearch = Reflect.get(AmapService, 'getRegeoBySdkGeoSearch') as Object;
    this.originGetRegeoBySdkNearby = Reflect.get(AmapService, 'getRegeoBySdkNearby') as Object;
  }

  public setRequest(
    fn: (ownerTag: string, requestName: string, url: string, options: Object) => Promise<Object>
  ): void {
    Reflect.set(HttpRequestHelper, 'request', fn);
  }

  public setValidateAmapWebConfig(fn: () => void): void {
    Reflect.set(AppConfig, 'validateAmapWebConfig', fn);
  }

  public setGetRuntimeContext(fn: () => Object | null): void {
    Reflect.set(AmapService, 'getRuntimeContext', fn);
  }

  public setSearchPoiBySdk(
    fn: (context: Object, keyword: string, centerLat: number, centerLng: number, limit: number, nearbyOnly: boolean) => Promise<PoiSearchItem[]>
  ): void {
    Reflect.set(AmapService, 'searchPoiBySdk', fn);
  }

  public setSearchPoiWithWebFallback(
    fn: (keyword: string, centerLat: number, centerLng: number, limit: number) => Promise<PoiSearchItem[]>
  ): void {
    Reflect.set(AmapService, 'searchPoiWithWebFallback', fn);
  }

  public setGetGeocodeBySdkGeoSearch(
    fn: (address: string, context: Object) => Promise<GeoCoordinate | null>
  ): void {
    Reflect.set(AmapService, 'getGeocodeBySdkGeoSearch', fn);
  }

  public setGetGeocodeBySdkKeyword(
    fn: (address: string, context: Object) => Promise<GeoCoordinate | null>
  ): void {
    Reflect.set(AmapService, 'getGeocodeBySdkKeyword', fn);
  }

  public setGetGeocodeByWeb(fn: (address: string) => Promise<GeoCoordinate | null>): void {
    Reflect.set(AmapService, 'getGeocodeByWeb', fn);
  }

  public setGetCityCodeByCoordinate(
    fn: (latitude: number, longitude: number) => Promise<string | null>
  ): void {
    Reflect.set(AmapService, 'getCityCodeByCoordinate', fn);
  }

  public setGetCityCodeBySdkGeoSearch(
    fn: (context: Object, latitude: number, longitude: number) => Promise<string | null>
  ): void {
    Reflect.set(AmapService, 'getCityCodeBySdkGeoSearch', fn);
  }

  public setGetRegeo(fn: (latitude: number, longitude: number) => Promise<string | null>): void {
    Reflect.set(AmapService, 'getRegeo', fn);
  }

  public setGetRegeoBySdkGeoSearch(
    fn: (context: Object, latitude: number, longitude: number) => Promise<string | null>
  ): void {
    Reflect.set(AmapService, 'getRegeoBySdkGeoSearch', fn);
  }

  public setGetRegeoBySdkNearby(
    fn: (context: Object, latitude: number, longitude: number) => Promise<string | null>
  ): void {
    Reflect.set(AmapService, 'getRegeoBySdkNearby', fn);
  }

  public restore(): void {
    Reflect.set(HttpRequestHelper, 'request', this.originRequest);
    Reflect.set(AppConfig, 'validateAmapWebConfig', this.originValidateAmapWebConfig);
    Reflect.set(AmapService, 'getRuntimeContext', this.originGetRuntimeContext);
    Reflect.set(AmapService, 'searchPoiBySdk', this.originSearchPoiBySdk);
    Reflect.set(AmapService, 'searchPoiWithWebFallback', this.originSearchPoiWithWebFallback);
    Reflect.set(AmapService, 'getGeocodeBySdkGeoSearch', this.originGetGeocodeBySdkGeoSearch);
    Reflect.set(AmapService, 'getGeocodeBySdkKeyword', this.originGetGeocodeBySdkKeyword);
    Reflect.set(AmapService, 'getGeocodeByWeb', this.originGetGeocodeByWeb);
    Reflect.set(AmapService, 'getCityCodeByCoordinate', this.originGetCityCodeByCoordinate);
    Reflect.set(AmapService, 'getCityCodeBySdkGeoSearch', this.originGetCityCodeBySdkGeoSearch);
    Reflect.set(AmapService, 'getRegeo', this.originGetRegeo);
    Reflect.set(AmapService, 'getRegeoBySdkGeoSearch', this.originGetRegeoBySdkGeoSearch);
    Reflect.set(AmapService, 'getRegeoBySdkNearby', this.originGetRegeoBySdkNearby);
  }
}

class RepoHooksAQ {
  private readonly originPlanConsumeDirtyPlanIds: Object;
  private readonly originPlanGetPlanList: Object;
  private readonly originPlanGetPlanById: Object;
  private readonly originEventConsumeDirtyPlanIds: Object;
  private readonly originEventGetAllEvents: Object;

  constructor() {
    this.originPlanConsumeDirtyPlanIds = Reflect.get(PlanRepositoryImpl, 'consumeDirtyPlanIds') as Object;
    this.originPlanGetPlanList = Reflect.get(PlanRepositoryImpl, 'getPlanList') as Object;
    this.originPlanGetPlanById = Reflect.get(PlanRepositoryImpl, 'getPlanById') as Object;
    this.originEventConsumeDirtyPlanIds = Reflect.get(EventRepositoryImpl, 'consumeDirtyPlanIds') as Object;
    this.originEventGetAllEvents = Reflect.get(EventRepositoryImpl, 'getAllEvents') as Object;
  }

  public setPlanConsumeDirtyPlanIds(fn: () => number[]): void {
    Reflect.set(PlanRepositoryImpl, 'consumeDirtyPlanIds', fn);
  }

  public setPlanGetPlanList(fn: () => Promise<PlanItem[]>): void {
    Reflect.set(PlanRepositoryImpl, 'getPlanList', fn);
  }

  public setPlanGetPlanById(fn: (planId: number) => Promise<PlanItem | undefined>): void {
    Reflect.set(PlanRepositoryImpl, 'getPlanById', fn);
  }

  public setEventConsumeDirtyPlanIds(fn: () => number[]): void {
    Reflect.set(EventRepositoryImpl, 'consumeDirtyPlanIds', fn);
  }

  public setEventGetAllEvents(fn: (planId: number) => Promise<Object[]>): void {
    Reflect.set(EventRepositoryImpl, 'getAllEvents', fn);
  }

  public restore(): void {
    Reflect.set(PlanRepositoryImpl, 'consumeDirtyPlanIds', this.originPlanConsumeDirtyPlanIds);
    Reflect.set(PlanRepositoryImpl, 'getPlanList', this.originPlanGetPlanList);
    Reflect.set(PlanRepositoryImpl, 'getPlanById', this.originPlanGetPlanById);
    Reflect.set(EventRepositoryImpl, 'consumeDirtyPlanIds', this.originEventConsumeDirtyPlanIds);
    Reflect.set(EventRepositoryImpl, 'getAllEvents', this.originEventGetAllEvents);
  }
}

function createEventAQ(id: number, latitude: number = 31.23, longitude: number = 121.47, name: string = `event_${id}`): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.plan_id = 11;
  event.name = name;
  event.latitude = latitude;
  event.longitude = longitude;
  event.status = 1;
  event.type = 0;
  event.duration = 60;
  event.dynamic_start_time = Date.now() + 5 * 60 * 1000;
  event.completion_status = EventEntity.STATE_PENDING;
  event.fixed_start_time = '09:00';
  return event;
}

function createPlanItemAQ(id: number, startDate: number = 1_700_000_000_000): PlanItem {
  const plan = {} as PlanItem;
  plan.id = id;
  plan.status = 0;
  plan.delFlag = 0;
  plan.startDate = startDate;
  return plan;
}

function createWeatherInfoAQ(cityCode: string, condition: string = 'SUNNY', temperature: number = 26): WeatherInfo {
  const info = {} as WeatherInfo;
  info.temperature = temperature;
  info.condition = condition;
  info.humidity = 45;
  info.windSpeed = 3;
  info.reportTime = '2026-04-16 08:00:00';
  info.cityCode = cityCode;
  return info;
}

function createWeatherPointAQ(
  latitude: number,
  longitude: number,
  sourceType: 'CURRENT_LOCATION' | 'PLAN_LOCATION' = 'PLAN_LOCATION',
  forceRefresh: boolean = false,
  targetTime: number = 1_700_000_000_000
): WeatherGeoPointRequest {
  const point = {} as WeatherGeoPointRequest;
  point.latitude = latitude;
  point.longitude = longitude;
  point.sourceType = sourceType;
  point.forceRefresh = forceRefresh;
  point.targetTime = targetTime;
  return point;
}

function createLocationAQ(name: string, latitude: number = 31.23, longitude: number = 121.47, address: string = ''): LocationInfo {
  const location = {} as LocationInfo;
  location.name = name;
  location.address = address;
  location.latitude = latitude;
  location.longitude = longitude;
  return location;
}

function resetArrivalEngineAQ(): ArrivalReminderEngine {
  Reflect.set(ArrivalReminderEngine as Object, 'instance', null);
  return ArrivalReminderEngine.getInstance();
}

function resetTrafficEngineAQ(): TrafficEngine {
  Reflect.set(TrafficEngine as Object, 'instance', null);
  return TrafficEngine.getInstance();
}

function clearAmapPoiCacheAQ(): void {
  const cache = Reflect.get(AmapService as Object, 'poiSearchCache') as Map<string, Object>;
  cache.clear();
}

function buildTrafficKeyAQ(engine: TrafficEngine, from: LocationInfo, to: LocationInfo, mode: number): string {
  const isValidCoordinate = (lat?: number, lng?: number): boolean => {
    return Number.isFinite(lat ?? NaN) &&
      Number.isFinite(lng ?? NaN) &&
      (lat ?? 0) !== 0 &&
      (lng ?? 0) !== 0;
  };
  const fromCoord = isValidCoordinate(from.latitude, from.longitude)
    ? (from.latitude as number).toFixed(5) + ',' + (from.longitude as number).toFixed(5)
    : 'NOCOORD';
  const toCoord = isValidCoordinate(to.latitude, to.longitude)
    ? (to.latitude as number).toFixed(5) + ',' + (to.longitude as number).toFixed(5)
    : 'NOCOORD';
  return from.name + '->' + to.name + '_M' + mode + '_F' + fromCoord + '_T' + toCoord;
}

export default function phase2BatchAQTest() {
  describe('phase2BatchAQTest_arrivalReminderEngine', () => {
    it('normal: arrival_location_sample_should_accept_valid_coordinate', 0, () => {
      // Arrange
      // Act
      // Assert
      const accepted = ArrivalReminderEngine.isLocationSampleAccepted(31.23, 121.47, 20, 2, 400, 20);
      expect(accepted).assertTrue();
    });

    it('boundary: arrival_location_sample_should_accept_threshold_values', 0, () => {
      // Arrange
      // Act
      // Assert
      const accepted = ArrivalReminderEngine.isLocationSampleAccepted(-90, 180, 400, 20, 400, 20);
      expect(accepted).assertTrue();
    });

    it('invalid: arrival_location_sample_should_reject_zero_or_out_of_range_coordinate', 0, () => {
      // Arrange
      // Act
      // Assert
      const zeroCoordinate = ArrivalReminderEngine.isLocationSampleAccepted(0, 0, 1, 1, 400, 20);
      const outOfRange = ArrivalReminderEngine.isLocationSampleAccepted(91, 121.47, 1, 1, 400, 20);
      expect(zeroCoordinate).assertEqual(false);
      expect(outOfRange).assertEqual(false);
    });

    it('normal: arrival_cooldown_should_allow_after_window', 0, () => {
      // Arrange
      const now = 1000;
      // Act
      const allowed = ArrivalReminderEngine.isEventOutOfCooldown(0, now + 5000, 1000);
      // Assert
      expect(allowed).assertTrue();
    });

    it('boundary: arrival_cooldown_should_allow_exact_boundary', 0, () => {
      // Arrange
      const now = 10_000;
      // Act
      const allowed = ArrivalReminderEngine.isEventOutOfCooldown(9000, now, 1000);
      // Assert
      expect(allowed).assertTrue();
    });

    it('invalid: arrival_cooldown_should_block_future_trigger_time', 0, () => {
      // Arrange
      const now = 10_000;
      // Act
      const allowed = ArrivalReminderEngine.isEventOutOfCooldown(12_000, now, 1000);
      // Assert
      expect(allowed).assertEqual(false);
    });

    it('normal: arrival_candidate_delta_should_use_cached_value_first', 0, () => {
      // Arrange
      // Act
      // Assert
      const delta = ArrivalReminderEngine.resolveCandidateTimeDelta(3000, Date.now() + 1000, Date.now());
      expect(delta).assertEqual(3000);
    });

    it('boundary: arrival_candidate_delta_should_use_dynamic_start_time_when_cache_missing', 0, () => {
      // Arrange
      const now = 20_000;
      // Act
      const delta = ArrivalReminderEngine.resolveCandidateTimeDelta(undefined, now + 2500, now);
      // Assert
      expect(delta).assertEqual(2500);
    });

    it('invalid: arrival_candidate_delta_should_fallback_to_max_safe_integer', 0, () => {
      // Arrange
      // Act
      // Assert
      const delta = ArrivalReminderEngine.resolveCandidateTimeDelta(undefined, 0, Date.now());
      expect(delta).assertEqual(Number.MAX_SAFE_INTEGER);
    });

    it('normal: arrival_get_instance_should_return_singleton', 0, () => {
      // Arrange
      Reflect.set(ArrivalReminderEngine as Object, 'instance', null);
      // Act
      const first = ArrivalReminderEngine.getInstance();
      const second = ArrivalReminderEngine.getInstance();
      // Assert
      expect(first === second).assertTrue();
    });

    it('boundary: arrival_get_instance_should_create_new_after_reset', 0, () => {
      // Arrange
      Reflect.set(ArrivalReminderEngine as Object, 'instance', null);
      const first = ArrivalReminderEngine.getInstance();
      Reflect.set(ArrivalReminderEngine as Object, 'instance', null);
      // Act
      const second = ArrivalReminderEngine.getInstance();
      // Assert
      expect(first === second).assertEqual(false);
    });

    it('invalid: arrival_get_instance_should_return_existing_polluted_value', 0, () => {
      // Arrange
      const pollutedObj: PollutedMapServiceAQ = { marker: '' };
      const polluted: ArrivalReminderEngine = pollutedObj as Object as ArrivalReminderEngine;
      Reflect.set(ArrivalReminderEngine as Object, 'instance', polluted as Object);
      // Act
      const current = ArrivalReminderEngine.getInstance();
      // Assert
      expect(current === polluted).assertTrue();
      Reflect.set(ArrivalReminderEngine as Object, 'instance', null);
    });

    it('normal: arrival_last_known_location_should_return_snapshot', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const location = new FakeAmapLocationAQ();
      location.latitude = 31.23;
      location.longitude = 121.47;
      location.accuracy = 15;
      location.speed = 3;
      Reflect.set(engine as Object, 'lastLocation', location as Object);
      // Act
      const snapshot = engine.getLastKnownLocation();
      // Assert
      expect(snapshot?.latitude ?? 0).assertEqual(31.23);
      expect(snapshot?.longitude ?? 0).assertEqual(121.47);
      expect((snapshot?.timestamp ?? 0) > 0).assertTrue();
    });

    it('boundary: arrival_last_known_location_should_keep_zero_accuracy_and_speed', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const location = new FakeAmapLocationAQ();
      location.latitude = 30.1;
      location.longitude = 120.2;
      location.accuracy = 0;
      location.speed = 0;
      Reflect.set(engine as Object, 'lastLocation', location as Object);
      // Act
      const snapshot = engine.getLastKnownLocation();
      // Assert
      expect(snapshot?.accuracy ?? -1).assertEqual(0);
      expect(snapshot?.speed ?? -1).assertEqual(0);
    });

    it('invalid: arrival_last_known_location_should_return_null_without_sample', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      Reflect.set(engine as Object, 'lastLocation', null);
      // Act
      const snapshot = engine.getLastKnownLocation();
      // Assert
      expect(snapshot === null).assertTrue();
    });

    it('normal: arrival_start_should_refresh_and_start_location_updates', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const manager = new FakeLocationManagerAQ();
      let refreshedReason = '';
      let ensuredConsistency = false;
      Reflect.set(engine as Object, 'ensureStorageDefaults', (): void => {});
      Reflect.set(engine as Object, 'ensureClients', (): boolean => true);
      Reflect.set(engine as Object, 'refreshFencesNow', async (reason: string): Promise<void> => { refreshedReason = reason; });
      Reflect.set(engine as Object, 'ensureReminderConsistency', (): void => { ensuredConsistency = true; });
      Reflect.set(engine as Object, 'locationManager', manager as Object);
      const start = Reflect.get(engine as Object, 'start') as (planId: number, vm: Object, context: Object) => void;
      // Act
      const vmArg8Obj: PollutedMapServiceAQ = { marker: '' };
      const vmArg8: Object = vmArg8Obj as Object;
      const ctxArg8Obj: PollutedMapServiceAQ = { marker: '' };
      const ctxArg8: Object = ctxArg8Obj as Object;
      start(8, vmArg8, ctxArg8);
      // Assert
      expect(Reflect.get(engine as Object, 'activePagePlanId') as number).assertEqual(8);
      expect(manager.startCalls).assertEqual(1);
      expect(refreshedReason).assertEqual('start');
      expect(ensuredConsistency).assertTrue();
    });

    it('boundary: arrival_start_should_normalize_non_positive_plan_id_to_zero', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const manager = new FakeLocationManagerAQ();
      Reflect.set(engine as Object, 'ensureStorageDefaults', (): void => {});
      Reflect.set(engine as Object, 'ensureClients', (): boolean => true);
      Reflect.set(engine as Object, 'refreshFencesNow', async (_reason: string): Promise<void> => {});
      Reflect.set(engine as Object, 'ensureReminderConsistency', (): void => {});
      Reflect.set(engine as Object, 'locationManager', manager as Object);
      const start = Reflect.get(engine as Object, 'start') as (planId: number, vm: Object, context: Object) => void;
      // Act
      const vmArg0Obj: PollutedMapServiceAQ = { marker: '' };
      const vmArg0: Object = vmArg0Obj as Object;
      const ctxArg0Obj: PollutedMapServiceAQ = { marker: '' };
      const ctxArg0: Object = ctxArg0Obj as Object;
      start(0, vmArg0, ctxArg0);
      // Assert
      expect(Reflect.get(engine as Object, 'activePagePlanId') as number).assertEqual(0);
      expect(manager.startCalls).assertEqual(1);
    });

    it('invalid: arrival_start_should_return_early_when_clients_not_ready', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const manager = new FakeLocationManagerAQ();
      let refreshed = false;
      Reflect.set(engine as Object, 'ensureStorageDefaults', (): void => {});
      Reflect.set(engine as Object, 'ensureClients', (): boolean => false);
      Reflect.set(engine as Object, 'refreshFencesNow', async (_reason: string): Promise<void> => { refreshed = true; });
      Reflect.set(engine as Object, 'locationManager', manager as Object);
      const start = Reflect.get(engine as Object, 'start') as (planId: number, vm: Object, context: Object) => void;
      // Act
      const vmArg1Obj: PollutedMapServiceAQ = { marker: '' };
      const vmArg1: Object = vmArg1Obj as Object;
      const ctxArg1Obj: PollutedMapServiceAQ = { marker: '' };
      const ctxArg1: Object = ctxArg1Obj as Object;
      start(1, vmArg1, ctxArg1);
      // Assert
      expect(manager.startCalls).assertEqual(0);
      expect(refreshed).assertEqual(false);
    });

    it('normal: arrival_stop_should_end_live_activity_and_clear_runtime_state', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const manager = new FakeLocationManagerAQ();
      const geoFenceClient = new FakeGeoFenceClientAQ();
      let endedEventId = 0;
      Reflect.set(engine as Object, 'locationManager', manager as Object);
      Reflect.set(engine as Object, 'geoFenceClient', geoFenceClient as Object);
      Reflect.set(engine as Object, 'lastReminderEventId', 99);
      Reflect.set(engine as Object, 'pendingBatchTimer', 1);
      (Reflect.get(engine as Object, 'pendingCandidateIds') as Set<number>).add(1);
      (Reflect.get(engine as Object, 'geoFenceStatus') as Map<string, number>).set('f', 1);
      (Reflect.get(engine as Object, 'geoFenceEnterTs') as Map<string, number>).set('f', 1);
      (Reflect.get(engine as Object, 'directEnterTs') as Map<number, number>).set(1, 1);
      const planCacheEntryObj: PollutedMapServiceAQ = { marker: '' };
      const planCacheEntry: Object = planCacheEntryObj as Object;
      (Reflect.get(engine as Object, 'planCandidateCache') as Map<number, Object>).set(1, planCacheEntry);
      (Reflect.get(engine as Object, 'activePlanSnapshot') as Set<number>).add(1);
      Reflect.set(engine as Object, 'publishLiveActivityState', (eventId: number, status: string): void => {
        if (status === 'ENDED') {
          endedEventId = eventId;
        }
      });
      // Act
      engine.stop();
      // Assert
      expect(endedEventId).assertEqual(99);
      expect(manager.stopCalls).assertEqual(1);
      expect(geoFenceClient.removeCount).assertEqual(1);
      expect((Reflect.get(engine as Object, 'pendingCandidateIds') as Set<number>).size).assertEqual(0);
      expect((Reflect.get(engine as Object, 'planCandidateCache') as Map<number, Object>).size).assertEqual(0);
      expect(Reflect.get(engine as Object, 'pendingBatchTimer') as number).assertEqual(-1);
    });

    it('boundary: arrival_stop_should_be_safe_without_active_reminder', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const manager = new FakeLocationManagerAQ();
      const geoFenceClient = new FakeGeoFenceClientAQ();
      let publishCalls = 0;
      Reflect.set(engine as Object, 'locationManager', manager as Object);
      Reflect.set(engine as Object, 'geoFenceClient', geoFenceClient as Object);
      Reflect.set(engine as Object, 'lastReminderEventId', -1);
      Reflect.set(engine as Object, 'publishLiveActivityState', (_eventId: number, _status: string): void => {
        publishCalls += 1;
      });
      // Act
      engine.stop();
      // Assert
      expect(publishCalls).assertEqual(0);
      expect(manager.stopCalls).assertEqual(1);
      expect(geoFenceClient.removeCount).assertEqual(1);
    });

    it('invalid: arrival_stop_should_swallow_manager_errors_and_clear_state', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const manager = new FakeLocationManagerAQ();
      manager.stopShouldThrow = true;
      const geoFenceClient = new FakeGeoFenceClientAQ();
      geoFenceClient.removeShouldThrow = true;
      (Reflect.get(engine as Object, 'pendingCandidateIds') as Set<number>).add(7);
      Reflect.set(engine as Object, 'locationManager', manager as Object);
      Reflect.set(engine as Object, 'geoFenceClient', geoFenceClient as Object);
      // Act
      engine.stop();
      // Assert
      expect((Reflect.get(engine as Object, 'pendingCandidateIds') as Set<number>).size).assertEqual(0);
      expect(Reflect.get(engine as Object, 'lastLocation') === null).assertTrue();
    });

    it('normal: arrival_refresh_fences_should_project_cached_candidates_without_rebuild', 0, async () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const hooks = new RepoHooksAQ();
      const geoFenceClient = new FakeGeoFenceClientAQ();
      const plan = createPlanItemAQ(11);
      const event = createEventAQ(101, 31.23, 121.47, 'museum');
      const cache: PlanCandidateCacheAQ = {
        scheduleCount: 1,
        pendingCount: 1,
        activeCount: 0,
        withCoordinateCount: 1,
        eligibleCount: 1,
        candidates: [event],
        timeDeltaByEventId: new Map<number, number>([[event.id, 600]])
      };
      Reflect.set(engine as Object, 'geoFenceClient', geoFenceClient as Object);
      (Reflect.get(engine as Object, 'planCandidateCache') as Map<number, Object>).set(plan.id, cache as Object);
      (Reflect.get(engine as Object, 'fenceIdSnapshot') as Set<string>).add(`${plan.id}:${event.id}:${event.latitude.toFixed(5)}:${event.longitude.toFixed(5)}`);
      Reflect.set(engine as Object, 'activePlanSnapshot', new Set<number>());
      Reflect.set(engine as Object, 'lastFullResyncTs', Date.now());
      hooks.setPlanConsumeDirtyPlanIds((): number[] => []);
      hooks.setEventConsumeDirtyPlanIds((): number[] => []);
      hooks.setPlanGetPlanList(async (): Promise<PlanItem[]> => [plan]);
      hooks.setPlanGetPlanById(async (_planId: number): Promise<PlanItem | undefined> => plan);
      hooks.setEventGetAllEvents(async (_planId: number): Promise<Object[]> => []);
      // Act
      await engine.refreshFencesNow('manual');
      hooks.restore();
      // Assert
      expect((Reflect.get(engine as Object, 'monitoredEvents') as EventEntity[]).length).assertEqual(1);
      expect((Reflect.get(engine as Object, 'eventPlanIdMap') as Map<number, number>).get(event.id) ?? 0).assertEqual(11);
      expect(geoFenceClient.addedIds.length).assertEqual(0);
    });

    it('boundary: arrival_refresh_fences_should_skip_when_snapshot_and_cache_are_fresh', 0, async () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const hooks = new RepoHooksAQ();
      const geoFenceClient = new FakeGeoFenceClientAQ();
      const plan = createPlanItemAQ(12);
      Reflect.set(engine as Object, 'geoFenceClient', geoFenceClient as Object);
      Reflect.set(engine as Object, 'lastFullResyncTs', Date.now());
      Reflect.set(engine as Object, 'activePlanSnapshot', new Set<number>([plan.id]));
      const emptyCache: PlanCandidateCacheAQ = {
        scheduleCount: 0,
        pendingCount: 0,
        activeCount: 0,
        withCoordinateCount: 0,
        eligibleCount: 0,
        candidates: [],
        timeDeltaByEventId: new Map<number, number>()
      };
      (Reflect.get(engine as Object, 'planCandidateCache') as Map<number, Object>).set(plan.id, emptyCache as Object);
      hooks.setPlanConsumeDirtyPlanIds((): number[] => []);
      hooks.setEventConsumeDirtyPlanIds((): number[] => []);
      hooks.setPlanGetPlanById(async (_planId: number): Promise<PlanItem | undefined> => plan);
      hooks.setPlanGetPlanList(async (): Promise<PlanItem[]> => []);
      hooks.setEventGetAllEvents(async (_planId: number): Promise<Object[]> => []);
      // Act
      await engine.refreshFencesNow('manual');
      hooks.restore();
      // Assert
      expect((Reflect.get(engine as Object, 'monitoredEvents') as EventEntity[]).length).assertEqual(0);
      expect((Reflect.get(engine as Object, 'lastRefreshTs') as number) > 0).assertTrue();
      expect(geoFenceClient.removeCount).assertEqual(0);
    });

    it('invalid: arrival_refresh_fences_should_clear_monitored_state_when_scan_throws', 0, async () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const hooks = new RepoHooksAQ();
      const geoFenceClient = new FakeGeoFenceClientAQ();
      const event = createEventAQ(202);
      Reflect.set(engine as Object, 'geoFenceClient', geoFenceClient as Object);
      Reflect.set(engine as Object, 'monitoredEvents', [event]);
      (Reflect.get(engine as Object, 'eventPlanIdMap') as Map<number, number>).set(event.id, 1);
      (Reflect.get(engine as Object, 'fenceIdSnapshot') as Set<string>).add('bad');
      hooks.setPlanConsumeDirtyPlanIds((): number[] => []);
      hooks.setEventConsumeDirtyPlanIds((): number[] => []);
      hooks.setPlanGetPlanList(async (): Promise<PlanItem[]> => {
        throw new Error('refresh_failed_aq');
      });
      hooks.setPlanGetPlanById(async (_planId: number): Promise<PlanItem | undefined> => undefined);
      hooks.setEventGetAllEvents(async (_planId: number): Promise<Object[]> => []);
      // Act
      await engine.refreshFencesNow('manual');
      hooks.restore();
      // Assert
      expect((Reflect.get(engine as Object, 'monitoredEvents') as EventEntity[]).length).assertEqual(0);
      expect((Reflect.get(engine as Object, 'eventPlanIdMap') as Map<number, number>).size).assertEqual(0);
      expect(geoFenceClient.removeCount).assertEqual(1);
    });

    it('normal: arrival_request_immediate_detection_should_collect_and_evaluate_ready_candidates', 0, async () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const location = new FakeAmapLocationAQ();
      location.latitude = 30.1;
      location.longitude = 120.2;
      Reflect.set(engine as Object, 'lastLocation', location as Object);
      let refreshedReason = '';
      let evaluatedReason = '';
      let pendingCount = 0;
      Reflect.set(engine as Object, 'refreshFencesNow', async (reason: string): Promise<void> => { refreshedReason = reason; });
      Reflect.set(engine as Object, 'ensureReminderConsistency', (): void => {});
      Reflect.set(engine as Object, 'collectReadyCandidateIds', (): number[] => [1]);
      Reflect.set(engine as Object, 'collectDirectReadyCandidateIds', (_loc: Object): number[] => [2]);
      Reflect.set(engine as Object, 'evaluateCandidates', (reason: string): void => {
        evaluatedReason = reason;
        pendingCount = (Reflect.get(engine as Object, 'pendingCandidateIds') as Set<number>).size;
      });
      // Act
      await engine.requestImmediateDetection('manual_refresh_aq');
      // Assert
      expect(refreshedReason).assertEqual('manual_refresh_aq');
      expect(evaluatedReason).assertEqual('manual_refresh_aq');
      expect(pendingCount).assertEqual(2);
    });

    it('boundary: arrival_request_immediate_detection_should_skip_evaluation_when_location_absent', 0, async () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      let evaluated = false;
      Reflect.set(engine as Object, 'refreshFencesNow', async (_reason: string): Promise<void> => {});
      Reflect.set(engine as Object, 'ensureReminderConsistency', (): void => {});
      Reflect.set(engine as Object, 'lastLocation', null);
      Reflect.set(engine as Object, 'evaluateCandidates', (_reason: string): void => { evaluated = true; });
      // Act
      await engine.requestImmediateDetection('manual_refresh_aq');
      // Assert
      expect(evaluated).assertEqual(false);
    });

    it('invalid: arrival_request_immediate_detection_should_propagate_refresh_error', 0, async () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      let message = '';
      Reflect.set(engine as Object, 'refreshFencesNow', async (_reason: string): Promise<void> => {
        throw new Error('refresh_throw_aq');
      });
      // Act
      try {
        await engine.requestImmediateDetection('manual_refresh_aq');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      // Assert
      expect(message).assertEqual('refresh_throw_aq');
    });

    it('normal: arrival_acknowledge_should_apply_dismiss_lock_and_ack_status', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const before = Date.now();
      let publishedStatus = '';
      let clearedEventId = 0;
      Reflect.set(engine as Object, 'publishLiveActivityState', (_eventId: number, status: string): void => {
        publishedStatus = status;
      });
      Reflect.set(engine as Object, 'clearReminderPayloadIfMatches', (eventId: number): void => {
        clearedEventId = eventId;
      });
      // Act
      engine.acknowledgeReminder(301, 'dismiss');
      // Assert
      expect(publishedStatus).assertEqual('ACKED');
      expect(clearedEventId).assertEqual(301);
      expect((Reflect.get(engine as Object, 'reminderLockUntilTs') as number) > before).assertTrue();
    });

    it('boundary: arrival_acknowledge_should_reset_last_reminder_when_open_page_matches_current', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      Reflect.set(engine as Object, 'lastReminderEventId', 302);
      Reflect.set(engine as Object, 'publishLiveActivityState', (_eventId: number, _status: string): void => {});
      Reflect.set(engine as Object, 'clearReminderPayloadIfMatches', (_eventId: number): void => {});
      // Act
      engine.acknowledgeReminder(302, 'open_page');
      // Assert
      expect(Reflect.get(engine as Object, 'lastReminderEventId') as number).assertEqual(-1);
    });

    it('invalid: arrival_acknowledge_should_route_unknown_action_to_started_branch', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      let publishedStatus = '';
      Reflect.set(engine as Object, 'publishLiveActivityState', (_eventId: number, status: string): void => {
        publishedStatus = status;
      });
      Reflect.set(engine as Object, 'clearReminderPayloadIfMatches', (_eventId: number): void => {});
      // Act
      engine.acknowledgeReminder(303, 'unknown' as ArrivalReminderAction);
      // Assert
      expect(publishedStatus).assertEqual('STARTED');
    });
  });

  describe('phase2BatchAQTest_amapService', () => {
    it('normal: amap_runtime_context_bind_and_get_should_return_same_object', 0, () => {
      // Arrange
      const context = {} as common.Context;
      // Act
      AmapService.bindRuntimeContext(context);
      const current = AmapService.getRuntimeContext();
      // Assert
      expect(current === context).assertTrue();
    });

    it('boundary: amap_runtime_context_bind_and_get_should_overwrite_previous_context', 0, () => {
      // Arrange
      const first = {} as common.Context;
      const second = new RuntimeContextMockAQ('second') as Object as common.Context;
      AmapService.bindRuntimeContext(first);
      // Act
      AmapService.bindRuntimeContext(second);
      const current = AmapService.getRuntimeContext();
      // Assert
      expect(current === second).assertTrue();
    });

    it('invalid: amap_get_runtime_context_should_allow_manual_reset_to_null', 0, () => {
      // Arrange
      AmapService.bindRuntimeContext(new RuntimeContextMockAQ('temp') as Object as common.Context);
      // Act
      Reflect.set(AmapService as Object, 'runtimeContext', null);
      const current = AmapService.getRuntimeContext();
      // Assert
      expect(current === null).assertTrue();
    });

    it('normal: amap_should_fallback_to_nationwide_when_nearby_count_below_min', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(AmapService.shouldFallbackToNationwide(2, 5)).assertTrue();
    });

    it('boundary: amap_should_not_fallback_to_nationwide_at_threshold', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(AmapService.shouldFallbackToNationwide(5, 5)).assertEqual(false);
    });

    it('invalid: amap_should_treat_negative_nearby_count_as_need_fallback', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(AmapService.shouldFallbackToNationwide(-1, 5)).assertTrue();
    });

    it('normal: amap_parse_poi_response_should_parse_valid_payload', 0, () => {
      // Arrange
      const payload = '{"status":"1","pois":[{"name":"Museum","address":"A","location":"121.4700,31.2300","distance":"320"}]}';
      // Act
      const items = AmapService.parsePoiResponse(payload);
      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('Museum');
      expect(items[0].distance ?? 0).assertEqual(320);
    });

    it('boundary: amap_parse_poi_response_should_return_empty_for_blank_payload', 0, () => {
      // Arrange
      // Act
      const items = AmapService.parsePoiResponse('   ');
      // Assert
      expect(items.length).assertEqual(0);
    });

    it('invalid: amap_parse_poi_response_should_return_empty_for_malformed_json', 0, () => {
      // Arrange
      // Act
      const items = AmapService.parsePoiResponse('{bad');
      // Assert
      expect(items.length).assertEqual(0);
    });

    it('normal: amap_normalize_poi_nodes_should_map_valid_nodes', 0, () => {
      // Arrange
      const nodes: PoiNodeAQ[] = [{ name: 'Park', address: 'B', location: '120.1000,30.2000', distance: '88' }];
      // Act
      const items = AmapService.normalizePoiNodes(nodes);
      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].lat).assertEqual(30.2);
      expect(items[0].lng).assertEqual(120.1);
    });

    it('boundary: amap_normalize_poi_nodes_should_return_empty_for_undefined_nodes', 0, () => {
      // Arrange
      // Act
      const items = AmapService.normalizePoiNodes(undefined);
      // Assert
      expect(items.length).assertEqual(0);
    });

    it('invalid: amap_normalize_poi_nodes_should_filter_invalid_name_and_location', 0, () => {
      // Arrange
      const nodes: PoiNodeAQ[] = [
        { name: '', address: 'B', location: '120.1000,30.2000' },
        { name: 'Bad', address: 'C', location: 'abc,def' },
        { name: 'Zero', address: 'D', location: '0,0' }
      ];
      // Act
      const items = AmapService.normalizePoiNodes(nodes);
      // Assert
      expect(items.length).assertEqual(0);
    });

    it('normal: amap_merge_poi_results_should_dedupe_and_keep_limit', 0, () => {
      // Arrange
      const primary = [
        new PoiSearchItem('Museum', 'A', 31.23001, 121.47001, 100),
        new PoiSearchItem('Park', 'B', 31.24001, 121.48001, 200)
      ];
      const secondary = [
        new PoiSearchItem('Museum', 'A2', 31.23001, 121.47001, 999),
        new PoiSearchItem('Tower', 'C', 31.25001, 121.49001, 300)
      ];
      // Act
      const merged = AmapService.mergePoiResults(primary, secondary, 3);
      // Assert
      expect(merged.length).assertEqual(3);
      expect(merged[2].name).assertEqual('Tower');
    });

    it('boundary: amap_merge_poi_results_should_use_default_limit_when_input_limit_not_positive', 0, () => {
      // Arrange
      const primary: PoiSearchItem[] = [];
      const secondary: PoiSearchItem[] = [];
      for (let i = 0; i < 12; i++) {
        secondary.push(new PoiSearchItem(`P${i}`, 'addr', 30 + i / 100, 120 + i / 100, i));
      }
      // Act
      const merged = AmapService.mergePoiResults(primary, secondary, 0);
      // Assert
      expect(merged.length).assertEqual(10);
    });

    it('invalid: amap_merge_poi_results_should_return_empty_for_empty_inputs', 0, () => {
      // Arrange
      // Act
      const merged = AmapService.mergePoiResults([], [], 3);
      // Assert
      expect(merged.length).assertEqual(0);
    });

    it('normal: amap_to_poi_search_item_should_map_valid_poi_item', 0, () => {
      // Arrange
      const poi = new FakePoiItemAQ('Cafe', 'Road 1', 31.21, 121.45, 66);
      // Act
      const item = AmapService.toPoiSearchItem(poi as Object as PoiItem);
      // Assert
      expect(item?.name ?? '').assertEqual('Cafe');
      expect(item?.distance ?? 0).assertEqual(66);
    });

    it('boundary: amap_to_poi_search_item_should_drop_negative_distance_only', 0, () => {
      // Arrange
      const poi = new FakePoiItemAQ('Bookstore', 'Road 2', 31.22, 121.46, -1);
      // Act
      const item = AmapService.toPoiSearchItem(poi as Object as PoiItem);
      // Assert
      expect(item !== null).assertTrue();
      expect(item?.distance === undefined).assertTrue();
    });

    it('invalid: amap_to_poi_search_item_should_return_null_without_title_or_point', 0, () => {
      // Arrange
      const poi = new FakePoiItemAQ('', 'Road 3', 31.23, 121.47, 10, false);
      // Act
      const item = AmapService.toPoiSearchItem(poi as Object as PoiItem);
      // Assert
      expect(item === null).assertTrue();
    });

    it('normal: amap_search_poi_should_cache_nearby_sdk_result', 0, async () => {
      // Arrange
      clearAmapPoiCacheAQ();
      const hooks = new AmapHooksAQ();
      let sdkCalls = 0;
      hooks.setSearchPoiBySdk(async (
        _context: Object,
        _keyword: string,
        _centerLat: number,
        _centerLng: number,
        _limit: number,
        nearbyOnly: boolean
      ): Promise<PoiSearchItem[]> => {
        sdkCalls += 1;
        if (!nearbyOnly) {
          return [];
        }
        return [
          new PoiSearchItem('A', 'a', 31.1, 121.1, 1),
          new PoiSearchItem('B', 'b', 31.2, 121.2, 2),
          new PoiSearchItem('C', 'c', 31.3, 121.3, 3),
          new PoiSearchItem('D', 'd', 31.4, 121.4, 4),
          new PoiSearchItem('E', 'e', 31.5, 121.5, 5)
        ];
      });
      hooks.setSearchPoiWithWebFallback(async (): Promise<PoiSearchItem[]> => []);
      // Act
      const first = await AmapService.searchPoi({} as common.Context, 'museum', 31.2, 121.4, 5);
      const second = await AmapService.searchPoi({} as common.Context, 'museum', 31.2, 121.4, 5);
      hooks.restore();
      // Assert
      expect(first.length).assertEqual(5);
      expect(second.length).assertEqual(5);
      expect(sdkCalls).assertEqual(1);
    });

    it('boundary: amap_search_poi_should_use_default_limit_when_limit_not_positive', 0, async () => {
      // Arrange
      clearAmapPoiCacheAQ();
      const hooks = new AmapHooksAQ();
      hooks.setSearchPoiBySdk(async (
        _context: Object,
        _keyword: string,
        _centerLat: number,
        _centerLng: number,
        _limit: number,
        _nearbyOnly: boolean
      ): Promise<PoiSearchItem[]> => {
        const items: PoiSearchItem[] = [];
        for (let i = 0; i < 12; i++) {
          items.push(new PoiSearchItem(`N${i}`, 'addr', 30 + i / 100, 120 + i / 100, i));
        }
        return items;
      });
      hooks.setSearchPoiWithWebFallback(async (): Promise<PoiSearchItem[]> => []);
      // Act
      const result = await AmapService.searchPoi({} as common.Context, 'park', 31.2, 121.4, 0);
      hooks.restore();
      // Assert
      expect(result.length).assertEqual(10);
    });

    it('invalid: amap_search_poi_should_use_web_fallback_when_sdk_throws', 0, async () => {
      // Arrange
      clearAmapPoiCacheAQ();
      const hooks = new AmapHooksAQ();
      hooks.setSearchPoiBySdk(async (): Promise<PoiSearchItem[]> => {
        throw new Error('sdk_failed_aq');
      });
      hooks.setSearchPoiWithWebFallback(async (): Promise<PoiSearchItem[]> => {
        return [new PoiSearchItem('Fallback', 'addr', 30.6, 120.6, 10)];
      });
      // Act
      const result = await AmapService.searchPoi({} as common.Context, 'fallback', 30.6, 120.6, 3);
      hooks.restore();
      // Assert
      expect(result.length).assertEqual(1);
      expect(result[0].name).assertEqual('Fallback');
    });

    it('normal: amap_get_geocode_should_prefer_sdk_geo_search', 0, async () => {
      // Arrange
      const hooks = new AmapHooksAQ();
      hooks.setGetGeocodeBySdkGeoSearch(async (_address: string, _context: Object): Promise<GeoCoordinate | null> => {
        return new GeoCoordinate(31.23, 121.47);
      });
      hooks.setGetGeocodeBySdkKeyword(async (_address: string, _context: Object): Promise<GeoCoordinate | null> => null);
      hooks.setGetGeocodeByWeb(async (_address: string): Promise<GeoCoordinate | null> => null);
      // Act
      const coordinate = await AmapService.getGeocode('museum', {} as common.Context);
      hooks.restore();
      // Assert
      expect(coordinate?.lat ?? 0).assertEqual(31.23);
      expect(coordinate?.lng ?? 0).assertEqual(121.47);
    });

    it('boundary: amap_get_geocode_should_fallback_to_sdk_keyword_search', 0, async () => {
      // Arrange
      const hooks = new AmapHooksAQ();
      hooks.setGetGeocodeBySdkGeoSearch(async (_address: string, _context: Object): Promise<GeoCoordinate | null> => null);
      hooks.setGetGeocodeBySdkKeyword(async (_address: string, _context: Object): Promise<GeoCoordinate | null> => {
        return new GeoCoordinate(30.11, 120.22);
      });
      hooks.setGetGeocodeByWeb(async (_address: string): Promise<GeoCoordinate | null> => null);
      // Act
      const coordinate = await AmapService.getGeocode('library', {} as common.Context);
      hooks.restore();
      // Assert
      expect(coordinate?.lat ?? 0).assertEqual(30.11);
      expect(coordinate?.lng ?? 0).assertEqual(120.22);
    });

    it('invalid: amap_get_geocode_should_return_null_for_empty_address', 0, async () => {
      // Arrange
      // Act
      const coordinate = await AmapService.getGeocode('');
      // Assert
      expect(coordinate === null).assertTrue();
    });

    it('normal: amap_get_driving_duration_by_web_api_should_parse_minutes', 0, async () => {
      // Arrange
      const hooks = new AmapHooksAQ();
      hooks.setValidateAmapWebConfig((): void => {});
      hooks.setRequest(async (_ownerTag: string, _requestName: string, _url: string, _options: Object): Promise<Object> => {
        const resp: HttpResponseAQ = { responseCode: 200, result: '{"status":"1","route":{"paths":[{"duration":"600"}]}}' };
        return resp as Object;
      });
      // Act
      const minutes = await AmapService.getDrivingDurationByWebApi(31.23, 121.47, 31.24, 121.48, 1);
      hooks.restore();
      // Assert
      expect(minutes ?? 0).assertEqual(10);
    });

    it('boundary: amap_get_driving_duration_by_web_api_should_clamp_strategy_and_keep_minimum_one_minute', 0, async () => {
      // Arrange
      const hooks = new AmapHooksAQ();
      let capturedUrl = '';
      hooks.setValidateAmapWebConfig((): void => {});
      hooks.setRequest(async (_ownerTag: string, _requestName: string, url: string, _options: Object): Promise<Object> => {
        capturedUrl = url;
        const resp: HttpResponseAQ = { responseCode: 200, result: '{"status":"1","route":{"paths":[{"duration":"59"}]}}' };
        return resp as Object;
      });
      // Act
      const minutes = await AmapService.getDrivingDurationByWebApi(31.23, 121.47, 31.24, 121.48, -3);
      hooks.restore();
      // Assert
      expect(minutes ?? 0).assertEqual(1);
      expect(capturedUrl.includes('strategy=0')).assertTrue();
    });

    it('invalid: amap_get_driving_duration_by_web_api_should_skip_request_for_invalid_coordinate', 0, async () => {
      // Arrange
      const hooks = new AmapHooksAQ();
      let requestCalls = 0;
      hooks.setValidateAmapWebConfig((): void => {});
      hooks.setRequest(async (_ownerTag: string, _requestName: string, _url: string, _options: Object): Promise<Object> => {
        requestCalls += 1;
        const resp: HttpResponseAQ = { responseCode: 200, result: '{}' };
        return resp as Object;
      });
      // Act
      const minutes = await AmapService.getDrivingDurationByWebApi(0, 0, 31.24, 121.48);
      hooks.restore();
      // Assert
      expect(minutes === null).assertTrue();
      expect(requestCalls).assertEqual(0);
    });

    it('normal: amap_get_city_code_by_coordinate_should_prefer_sdk_value', 0, async () => {
      // Arrange
      const hooks = new AmapHooksAQ();
      hooks.setGetRuntimeContext((): Object | null => {
        const ctxObj: PollutedMapServiceAQ = { marker: '' };
        const ctx: Object = ctxObj as Object;
        return ctx;
      });
      hooks.setGetCityCodeBySdkGeoSearch(async (_context: Object, _lat: number, _lng: number): Promise<string | null> => '310000');
      // Act
      const cityCode = await AmapService.getCityCodeByCoordinate(31.23, 121.47);
      hooks.restore();
      // Assert
      expect(cityCode ?? '').assertEqual('310000');
    });

    it('boundary: amap_get_city_code_by_coordinate_should_fallback_to_web_and_prioritize_adcode', 0, async () => {
      // Arrange
      const hooks = new AmapHooksAQ();
      hooks.setGetRuntimeContext((): Object | null => {
        const ctxObj: PollutedMapServiceAQ = { marker: '' };
        const ctx: Object = ctxObj as Object;
        return ctx;
      });
      hooks.setGetCityCodeBySdkGeoSearch(async (_context: Object, _lat: number, _lng: number): Promise<string | null> => null);
      hooks.setValidateAmapWebConfig((): void => {});
      hooks.setRequest(async (_ownerTag: string, _requestName: string, _url: string, _options: Object): Promise<Object> => {
        const resp: HttpResponseAQ = { responseCode: 200, result: '{"status":"1","regeocode":{"addressComponent":{"adcode":"320100","citycode":"025"}}}' };
        return resp as Object;
      });
      // Act
      const cityCode = await AmapService.getCityCodeByCoordinate(32.01, 118.78);
      hooks.restore();
      // Assert
      expect(cityCode ?? '').assertEqual('320100');
    });

    it('invalid: amap_get_city_code_by_coordinate_should_return_null_for_zero_coordinate', 0, async () => {
      // Arrange
      // Act
      const cityCode = await AmapService.getCityCodeByCoordinate(0, 0);
      // Assert
      expect(cityCode === null).assertTrue();
    });

    it('normal: amap_get_regeo_should_return_first_poi_name', 0, async () => {
      // Arrange
      const hooks = new AmapHooksAQ();
      hooks.setValidateAmapWebConfig((): void => {});
      hooks.setRequest(async (_ownerTag: string, _requestName: string, _url: string, _options: Object): Promise<Object> => {
        const resp: HttpResponseAQ = { responseCode: 200, result: '{"status":"1","regeocode":{"formatted_address":"Address","pois":[{"name":"Bund"}]}}' };
        return resp as Object;
      });
      // Act
      const place = await AmapService.getRegeo(31.24, 121.49);
      hooks.restore();
      // Assert
      expect(place ?? '').assertEqual('Bund');
    });

    it('boundary: amap_get_regeo_should_fallback_to_formatted_address', 0, async () => {
      // Arrange
      const hooks = new AmapHooksAQ();
      hooks.setValidateAmapWebConfig((): void => {});
      hooks.setRequest(async (_ownerTag: string, _requestName: string, _url: string, _options: Object): Promise<Object> => {
        const resp: HttpResponseAQ = { responseCode: 200, result: '{"status":"1","regeocode":{"formatted_address":"Nanjing Road","pois":[]}}' };
        return resp as Object;
      });
      // Act
      const place = await AmapService.getRegeo(31.24, 121.49);
      hooks.restore();
      // Assert
      expect(place ?? '').assertEqual('Nanjing Road');
    });

    it('invalid: amap_get_regeo_should_return_null_for_invalid_coordinate', 0, async () => {
      // Arrange
      // Act
      const place = await AmapService.getRegeo(0, 0);
      // Assert
      expect(place === null).assertTrue();
    });

    it('normal: amap_get_regeo_with_sdk_fallback_should_return_sdk_geo_result_first', 0, async () => {
      // Arrange
      const hooks = new AmapHooksAQ();
      hooks.setGetRegeoBySdkGeoSearch(async (_context: Object, _lat: number, _lng: number): Promise<string | null> => 'Temple');
      hooks.setGetRegeo(async (_lat: number, _lng: number): Promise<string | null> => 'WebResult');
      hooks.setGetRegeoBySdkNearby(async (_context: Object, _lat: number, _lng: number): Promise<string | null> => 'Nearby');
      // Act
      const place = await AmapService.getRegeoWithSdkFallback(31.2, 121.4, {} as common.Context);
      hooks.restore();
      // Assert
      expect(place ?? '').assertEqual('Temple');
    });

    it('boundary: amap_get_regeo_with_sdk_fallback_should_use_sdk_nearby_after_web_miss', 0, async () => {
      // Arrange
      const hooks = new AmapHooksAQ();
      hooks.setGetRegeoBySdkGeoSearch(async (_context: Object, _lat: number, _lng: number): Promise<string | null> => null);
      hooks.setGetRegeo(async (_lat: number, _lng: number): Promise<string | null> => null);
      hooks.setGetRegeoBySdkNearby(async (_context: Object, _lat: number, _lng: number): Promise<string | null> => 'NearbyPOI');
      // Act
      const place = await AmapService.getRegeoWithSdkFallback(31.2, 121.4, {} as common.Context);
      hooks.restore();
      // Assert
      expect(place ?? '').assertEqual('NearbyPOI');
    });

    it('invalid: amap_get_regeo_with_sdk_fallback_should_return_null_without_context_and_web_hit', 0, async () => {
      // Arrange
      const hooks = new AmapHooksAQ();
      hooks.setGetRegeo(async (_lat: number, _lng: number): Promise<string | null> => null);
      // Act
      const place = await AmapService.getRegeoWithSdkFallback(31.2, 121.4, null);
      hooks.restore();
      // Assert
      expect(place === null).assertTrue();
    });
  });

  describe('phase2BatchAQTest_amapWeatherService', () => {
    it('normal: amap_weather_to_point_key_should_match_weather_cache_key', 0, () => {
      // Arrange
      // Act
      const key = AmapWeatherService.toPointKey(31.2349, 121.4788, 1_700_000_000_000);
      // Assert
      expect(key).assertEqual(WeatherCache.buildLocationKey(31.2349, 121.4788, 1_700_000_000_000));
    });

    it('boundary: amap_weather_to_point_key_should_use_current_hour_bucket_when_target_missing', 0, () => {
      // Arrange
      // Act
      const key = AmapWeatherService.toPointKey(30.1234, 120.5678);
      // Assert
      expect(key.startsWith('30.123:120.568:')).assertTrue();
    });

    it('invalid: amap_weather_to_point_key_should_tolerate_nan_coordinate', 0, () => {
      // Arrange
      // Act
      const key = AmapWeatherService.toPointKey(Number.NaN, Number.NaN, 1_700_000_000_000);
      // Assert
      expect(key.startsWith('0.000:0.000:')).assertTrue();
    });

    it('normal: amap_weather_get_weather_should_return_sdk_result_when_runtime_context_exists', 0, async () => {
      // Arrange
      const service = new AmapWeatherService();
      const hooks = new AmapHooksAQ();
      hooks.setGetRuntimeContext((): Object | null => {
        const ctxObj: PollutedMapServiceAQ = { marker: '' };
        const ctx: Object = ctxObj as Object;
        return ctx;
      });
      Reflect.set(service as Object, 'getWeatherBySdk', async (_cityName: string, _context: Object): Promise<WeatherInfo | null> => {
        return createWeatherInfoAQ('310000', 'SUNNY', 28);
      });
      // Act
      const info = await service.getWeather('Shanghai');
      hooks.restore();
      // Assert
      expect(info?.temperature ?? 0).assertEqual(28);
      expect(info?.condition ?? '').assertEqual('SUNNY');
    });

    it('boundary: amap_weather_get_weather_should_return_null_when_sdk_miss_even_with_context', 0, async () => {
      // Arrange
      const service = new AmapWeatherService();
      const hooks = new AmapHooksAQ();
      hooks.setGetRuntimeContext((): Object | null => {
        const ctxObj: PollutedMapServiceAQ = { marker: '' };
        const ctx: Object = ctxObj as Object;
        return ctx;
      });
      Reflect.set(service as Object, 'getWeatherBySdk', async (_cityName: string, _context: Object): Promise<WeatherInfo | null> => null);
      // Act
      const info = await service.getWeather('Hangzhou');
      hooks.restore();
      // Assert
      expect(info === null).assertTrue();
    });

    it('invalid: amap_weather_get_weather_should_return_null_for_empty_city_or_missing_context', 0, async () => {
      // Arrange
      const service = new AmapWeatherService();
      const hooks = new AmapHooksAQ();
      hooks.setGetRuntimeContext((): Object | null => null);
      // Act
      const emptyCity = await service.getWeather('');
      const noContext = await service.getWeather('Nanjing');
      hooks.restore();
      // Assert
      expect(emptyCity === null).assertTrue();
      expect(noContext === null).assertTrue();
    });

    it('normal: amap_weather_get_weather_by_geo_point_should_resolve_city_and_return_info', 0, async () => {
      // Arrange
      const service = new TestableAmapWeatherServiceAQ();
      const hooks = new AmapHooksAQ();
      hooks.setGetCityCodeByCoordinate(async (_lat: number, _lng: number): Promise<string | null> => '320100');
      service.weatherByCity.set('320100', createWeatherInfoAQ('320100', 'CLOUDY', 23));
      // Act
      const info = await service.getWeatherByGeoPoint(32.01, 118.78, 1_700_000_000_100, 'PLAN_LOCATION', false);
      hooks.restore();
      // Assert
      expect(info?.cityCode ?? '').assertEqual('320100');
      expect(service.getWeatherCallCount).assertEqual(1);
    });

    it('boundary: amap_weather_get_weather_by_geo_point_should_hit_cache_without_force_refresh', 0, async () => {
      // Arrange
      const service = new TestableAmapWeatherServiceAQ();
      const hooks = new AmapHooksAQ();
      let geocodeCalls = 0;
      hooks.setGetCityCodeByCoordinate(async (_lat: number, _lng: number): Promise<string | null> => {
        geocodeCalls += 1;
        return '330100';
      });
      service.weatherByCity.set('330100', createWeatherInfoAQ('330100', 'RAIN', 20));
      // Act
      const first = await service.getWeatherByGeoPoint(30.27, 120.15, 1_700_000_000_101, 'PLAN_LOCATION', false);
      const second = await service.getWeatherByGeoPoint(30.27, 120.15, 1_700_000_000_101, 'PLAN_LOCATION', false);
      hooks.restore();
      // Assert
      expect(first !== null).assertTrue();
      expect(second !== null).assertTrue();
      expect(geocodeCalls).assertEqual(1);
      expect(service.getWeatherCallCount).assertEqual(1);
    });

    it('invalid: amap_weather_get_weather_by_geo_point_should_return_null_for_invalid_coordinate', 0, async () => {
      // Arrange
      const service = new TestableAmapWeatherServiceAQ();
      // Act
      const info = await service.getWeatherByGeoPoint(0, 0);
      // Assert
      expect(info === null).assertTrue();
    });

    it('normal: amap_weather_batch_get_weather_should_dedup_points_and_share_city_result', 0, async () => {
      // Arrange
      const service = new TestableAmapWeatherServiceAQ();
      const hooks = new AmapHooksAQ();
      hooks.setGetCityCodeByCoordinate(async (_lat: number, _lng: number): Promise<string | null> => '310100');
      service.weatherByCity.set('310100', createWeatherInfoAQ('310100', 'SUNNY', 26));
      const p1 = createWeatherPointAQ(31.20, 121.40, 'PLAN_LOCATION', false, 1_700_000_000_201);
      const p2 = createWeatherPointAQ(31.20, 121.40, 'PLAN_LOCATION', false, 1_700_000_000_201);
      const p3 = createWeatherPointAQ(31.21, 121.41, 'PLAN_LOCATION', false, 1_700_000_000_202);
      // Act
      const map = await service.batchGetWeather([p1, p2, p3]);
      hooks.restore();
      // Assert
      expect(map.size).assertEqual(2);
      expect(service.getWeatherCallCount).assertEqual(1);
    });

    it('boundary: amap_weather_batch_get_weather_should_cap_city_groups_when_current_location_exists', 0, async () => {
      // Arrange
      const service = new TestableAmapWeatherServiceAQ();
      const hooks = new AmapHooksAQ();
      hooks.setGetCityCodeByCoordinate(async (lat: number, _lng: number): Promise<string | null> => `CITY_${Math.floor(lat)}`);
      for (let i = 1; i <= 6; i++) {
        service.weatherByCity.set(`CITY_${i}`, createWeatherInfoAQ(`CITY_${i}`, 'SUNNY', 20 + i));
      }
      const points: WeatherGeoPointRequest[] = [];
      points.push(createWeatherPointAQ(1.1, 120.1, 'CURRENT_LOCATION', false, 1_700_000_000_301));
      for (let i = 2; i <= 6; i++) {
        points.push(createWeatherPointAQ(i + 0.1, 120.1, 'PLAN_LOCATION', false, 1_700_000_000_301 + i));
      }
      // Act
      const map = await service.batchGetWeather(points);
      hooks.restore();
      // Assert
      expect(map.size).assertEqual(5);
      expect(service.getWeatherCallCount).assertEqual(5);
    });

    it('invalid: amap_weather_batch_get_weather_should_filter_invalid_points_and_city_miss', 0, async () => {
      // Arrange
      const service = new TestableAmapWeatherServiceAQ();
      const hooks = new AmapHooksAQ();
      hooks.setGetCityCodeByCoordinate(async (lat: number, _lng: number): Promise<string | null> => {
        return lat > 0 ? '440100' : null;
      });
      service.weatherByCity.set('440100', createWeatherInfoAQ('440100', 'WINDY', 29));
      const invalidPoint = createWeatherPointAQ(0, 0);
      const validPoint = createWeatherPointAQ(23.12, 113.26);
      // Act
      const map = await service.batchGetWeather([invalidPoint, validPoint]);
      hooks.restore();
      // Assert
      expect(map.size).assertEqual(1);
      expect(service.getWeatherCallCount).assertEqual(1);
    });

    it('normal: amap_weather_to_snapshot_by_point_should_preserve_input_fields', 0, () => {
      // Arrange
      const service = new AmapWeatherService();
      const info = createWeatherInfoAQ('110000', 'CLEAR', 24);
      // Act
      const snapshot = service.toSnapshotByPoint('point_a', info);
      // Assert
      expect(snapshot.locationKey).assertEqual('point_a');
      expect(snapshot.conditionCode).assertEqual('CLEAR');
      expect(snapshot.temperatureCelsius ?? 0).assertEqual(24);
    });

    it('boundary: amap_weather_to_snapshot_by_point_should_use_unknown_condition_for_empty_text', 0, () => {
      // Arrange
      const service = new AmapWeatherService();
      const info = createWeatherInfoAQ('120000', '', 19);
      // Act
      const snapshot = service.toSnapshotByPoint('point_b', info);
      // Assert
      expect(snapshot.conditionCode).assertEqual('UNKNOWN');
      expect(snapshot.temperatureCelsius ?? 0).assertEqual(19);
    });

    it('invalid: amap_weather_to_snapshot_by_point_should_allow_empty_location_key', 0, () => {
      // Arrange
      const service = new AmapWeatherService();
      const info = createWeatherInfoAQ('130000', 'FOG', 17);
      // Act
      const snapshot = service.toSnapshotByPoint('', info);
      // Assert
      expect(snapshot.locationKey).assertEqual('');
      expect(snapshot.cityCode ?? '').assertEqual('130000');
    });
  });

  describe('phase2BatchAQTest_trafficEngine', () => {
    it('normal: traffic_get_instance_should_return_singleton', 0, () => {
      // Arrange
      Reflect.set(TrafficEngine as Object, 'instance', null);
      // Act
      const first = TrafficEngine.getInstance();
      const second = TrafficEngine.getInstance();
      // Assert
      expect(first === second).assertTrue();
    });

    it('boundary: traffic_get_instance_should_create_new_after_reset', 0, () => {
      // Arrange
      Reflect.set(TrafficEngine as Object, 'instance', null);
      const first = TrafficEngine.getInstance();
      Reflect.set(TrafficEngine as Object, 'instance', null);
      // Act
      const second = TrafficEngine.getInstance();
      // Assert
      expect(first === second).assertEqual(false);
    });

    it('invalid: traffic_get_instance_should_return_existing_polluted_value', 0, () => {
      // Arrange
      const pollutedObj2: PollutedMapServiceAQ = { marker: '' };
      const polluted: TrafficEngine = pollutedObj2 as Object as TrafficEngine;
      Reflect.set(TrafficEngine as Object, 'instance', polluted as Object);
      // Act
      const current = TrafficEngine.getInstance();
      // Assert
      expect(current === polluted).assertTrue();
      Reflect.set(TrafficEngine as Object, 'instance', null);
    });

    it('normal: traffic_initialize_should_create_long_lived_map_service', 0, () => {
      // Arrange
      const engine = resetTrafficEngineAQ();
      // Act
      engine.initialize({} as common.Context);
      const mapService: Object = Reflect.get(engine as Object, 'mapService') as Object;
      // Assert
      expect(mapService instanceof MapServiceImpl).assertTrue();
    });

    it('boundary: traffic_initialize_should_skip_when_map_service_already_exists', 0, () => {
      // Arrange
      const engine = resetTrafficEngineAQ();
      const fakeService = new FakeMapServiceAQ();
      Reflect.set(engine as Object, 'mapService', fakeService as Object);
      // Act
      engine.initialize({} as common.Context);
      // Assert
      expect((Reflect.get(engine as Object, 'mapService') as Object) === fakeService).assertTrue();
    });

    it('invalid: traffic_initialize_should_preserve_polluted_truthy_map_service', 0, () => {
      // Arrange
      const engine = resetTrafficEngineAQ();
      const polluted: PollutedMapServiceAQ = { marker: 'polluted' };
      Reflect.set(engine as Object, 'mapService', polluted as Object);
      // Act
      engine.initialize({} as common.Context);
      // Assert
      expect((Reflect.get(engine as Object, 'mapService') as Object) === polluted).assertTrue();
    });

    it('normal: traffic_get_commute_minutes_should_return_cached_value', 0, () => {
      // Arrange
      const engine = resetTrafficEngineAQ();
      const from = createLocationAQ('A', 31.20, 121.40);
      const to = createLocationAQ('B', 31.30, 121.50);
      const key = buildTrafficKeyAQ(engine, from, to, 2);
      Reflect.set(engine as Object, 'mapService', new FakeMapServiceAQ() as Object);
      (Reflect.get(engine as Object, 'cache') as Map<string, number>).set(key, 28);
      // Act
      const minutes = engine.getCommuteMinutes(from, to, 2, '09:00');
      // Assert
      expect(minutes).assertEqual(28);
    });

    it('boundary: traffic_get_commute_minutes_should_return_loading_flag_for_inflight_cache', 0, () => {
      // Arrange
      const engine = resetTrafficEngineAQ();
      const from = createLocationAQ('A', 31.20, 121.40);
      const to = createLocationAQ('B', 31.30, 121.50);
      const key = buildTrafficKeyAQ(engine, from, to, 2);
      Reflect.set(engine as Object, 'mapService', new FakeMapServiceAQ() as Object);
      (Reflect.get(engine as Object, 'cache') as Map<string, number>).set(key, -1);
      // Act
      const minutes = engine.getCommuteMinutes(from, to, 2, '09:00');
      // Assert
      expect(minutes).assertEqual(DomainConstants.COMMUTE_LOADING);
    });

    it('boundary: traffic_get_commute_minutes_should_evict_legacy_dirty_cache_and_trigger_async_fetch', 0, () => {
      // Arrange
      const engine = resetTrafficEngineAQ();
      const from = createLocationAQ('A', 31.20, 121.40);
      const to = createLocationAQ('B', 31.30, 121.50);
      const key = buildTrafficKeyAQ(engine, from, to, 2);
      let capturedKey = '';
      Reflect.set(engine as Object, 'mapService', new FakeMapServiceAQ() as Object);
      Reflect.set(engine as Object, 'fetchMultiModalTrafficAsync', (
        _from: LocationInfo,
        _to: LocationInfo,
        _mode: number,
        asyncKey: string,
        _startTime?: string
      ): void => {
        capturedKey = asyncKey;
      });
      (Reflect.get(engine as Object, 'cache') as Map<string, number>).set(key, DomainConstants.COMMUTE_FALLBACK_UNKNOWN);
      // Act
      const minutes = engine.getCommuteMinutes(from, to, 2, '09:00');
      // Assert
      expect(minutes).assertEqual(DomainConstants.COMMUTE_LOADING);
      expect(capturedKey).assertEqual(key);
      expect((Reflect.get(engine as Object, 'cache') as Map<string, number>).has(key)).assertEqual(false);
    });

    it('invalid: traffic_get_commute_minutes_should_return_zero_for_empty_name', 0, () => {
      // Arrange
      const engine = resetTrafficEngineAQ();
      const from = createLocationAQ('', 31.20, 121.40);
      const to = createLocationAQ('B', 31.30, 121.50);
      // Act
      const minutes = engine.getCommuteMinutes(from, to, 2, '09:00');
      // Assert
      expect(minutes).assertEqual(0);
    });

    it('invalid: traffic_get_commute_minutes_should_return_fallback_when_service_missing', 0, () => {
      // Arrange
      const engine = resetTrafficEngineAQ();
      const from = createLocationAQ('A', 31.20, 121.40);
      const to = createLocationAQ('B', 31.30, 121.50);
      Reflect.set(engine as Object, 'mapService', null);
      // Act
      const minutes = engine.getCommuteMinutes(from, to, 2, '09:00');
      // Assert
      expect(minutes).assertEqual(60);
    });

    it('boundary: traffic_get_commute_minutes_should_honor_transient_failure_window', 0, () => {
      // Arrange
      const engine = resetTrafficEngineAQ();
      const from = createLocationAQ('A', 31.20, 121.40);
      const to = createLocationAQ('B', 31.30, 121.50);
      const key = buildTrafficKeyAQ(engine, from, to, 2);
      Reflect.set(engine as Object, 'mapService', new FakeMapServiceAQ() as Object);
      (Reflect.get(engine as Object, 'transientFailureUntil') as Map<string, number>).set(key, Date.now() + 10_000);
      // Act
      const minutes = engine.getCommuteMinutes(from, to, 2, '09:00');
      // Assert
      expect(minutes).assertEqual(60);
    });

    it('normal: traffic_get_commute_minutes_should_trigger_async_fetch_on_cache_miss', 0, () => {
      // Arrange
      const engine = resetTrafficEngineAQ();
      const from = createLocationAQ('A', 31.20, 121.40);
      const to = createLocationAQ('B', 31.30, 121.50);
      let capturedMode = -1;
      let capturedKey = '';
      let capturedStartTime = '';
      Reflect.set(engine as Object, 'mapService', new FakeMapServiceAQ() as Object);
      Reflect.set(engine as Object, 'fetchMultiModalTrafficAsync', (
        _from: LocationInfo,
        _to: LocationInfo,
        mode: number,
        key: string,
        startTime?: string
      ): void => {
        capturedMode = mode;
        capturedKey = key;
        capturedStartTime = startTime ?? '';
      });
      // Act
      const minutes = engine.getCommuteMinutes(from, to, 3, '08:30');
      // Assert
      expect(minutes).assertEqual(DomainConstants.COMMUTE_LOADING);
      expect(capturedMode).assertEqual(3);
      expect(capturedKey.length > 0).assertTrue();
      expect(capturedStartTime).assertEqual('08:30');
    });

    it('conflict: traffic_get_commute_minutes_should_prefer_fresh_cache_over_concurrent_fetch', 0, () => {
      // Arrange
      const engine = resetTrafficEngineAQ();
      const from = createLocationAQ('X', 31.20, 121.40);
      const to = createLocationAQ('Y', 31.30, 121.50);
      const key = `${from.name}-${to.name}-0`;
      const cache = Reflect.get(engine as Object, 'commuteCache') as Map<string, number>;
      cache.set(key, 12);
      // Act
      const minutes = engine.getCommuteMinutes(from, to, 0);
      // Assert
      expect(minutes).assertEqual(12);
    });

    it('regression: td-20260416-traffic-cache-key-should-include-mode', 0, () => {
      // Arrange
      const engine = resetTrafficEngineAQ();
      const from = createLocationAQ('P', 31.20, 121.40);
      const to = createLocationAQ('Q', 31.30, 121.50);
      const cache = Reflect.get(engine as Object, 'commuteCache') as Map<string, number>;
      cache.set(`${from.name}-${to.name}-1`, 20);
      // Act
      const minutesMode0 = engine.getCommuteMinutes(from, to, 0);
      const minutesMode1 = engine.getCommuteMinutes(from, to, 1);
      // Assert
      expect(minutesMode0).assertEqual(DomainConstants.COMMUTE_LOADING);
      expect(minutesMode1).assertEqual(20);
    });

    it('combined: traffic_get_commute_minutes_should_return_loading_then_cached_on_second_call', 0, () => {
      // Arrange
      const engine = resetTrafficEngineAQ();
      const from = createLocationAQ('M', 31.20, 121.40);
      const to = createLocationAQ('N', 31.30, 121.50);
      Reflect.set(engine as Object, 'mapService', new FakeMapServiceAQ() as Object);
      Reflect.set(engine as Object, 'fetchMultiModalTrafficAsync', (): void => {});
      // Act - first call triggers fetch
      const first = engine.getCommuteMinutes(from, to, 0);
      // Simulate cache populated
      const cache = Reflect.get(engine as Object, 'commuteCache') as Map<string, number>;
      cache.set(`${from.name}-${to.name}-0`, 15);
      const second = engine.getCommuteMinutes(from, to, 0);
      // Assert
      expect(first).assertEqual(DomainConstants.COMMUTE_LOADING);
      expect(second).assertEqual(15);
    });
  });
}

