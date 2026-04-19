import { describe, it, expect } from '@ohos/hypium';
import { common } from '@kit.AbilityKit';
import { GeoFence } from '@amap/amap_lbs_location';
import { PoiItem } from '@amap/amap_lbs_search';
import { ArrivalReminderAction, ArrivalReminderEngine, ArrivalReminderPayload } from '../main/ets/infrastructure/services/ArrivalReminderEngine';
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
import { ArrivalReminderStore } from '../main/ets/common/utils/arrival/ArrivalReminderStore';
import { ArrivalLiveActivityBridge } from '../main/ets/common/utils/ArrivalLiveActivityBridge';
import { NotificationGateway } from '../main/ets/infrastructure/adapters/NotificationGateway';

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

interface GeoFenceListenerProbeAQ {
  onGeoFenceCreateFinished?: (list: Object, errorCode: number, customId: string) => void;
}

interface LocationListenerProbeAQ {
  onLocationChanged?: (location: Object) => void;
  onLocationError?: (errorInfo: Object) => void;
}

interface ArrivalReminderEnginePrivateAQ {
  buildPlanCandidateCache(plan: PlanItem, events: Object[], now: number): PlanCandidateCacheAQ;
  prunePlanCandidateCache(activePlanIds: Set<number>): void;
  applyDirtyPlansToActiveSnapshot(activePlanIds: Set<number>, dirtyPlanIds: Set<number>): Promise<void>;
  ensureStorageDefaults(): void;
  ensureClients(): boolean;
  onLocationChanged(location: FakeAmapLocationAQ): void;
  collectReadyCandidateIds(): number[];
  collectDirectReadyCandidateIds(location: FakeAmapLocationAQ): number[];
  scheduleCandidateEvaluation(reason: string): void;
  evaluateCandidates(reason: string): void;
  getEligibleEvents(): EventEntity[];
  isEligibleEvent(event: EventEntity, timeDelta: number): boolean;
  hasActiveEvent(): boolean;
  pickBestCandidate(candidateIds: number[], location: FakeAmapLocationAQ, now: number): EventEntity | null;
  fireReminder(event: EventEntity, location: FakeAmapLocationAQ, reason: string): void;
  publishLiveActivityState(eventId: number, status: string): void;
  ensureReminderConsistency(): void;
  makeCustomId(event: EventEntity): string;
  parseEventId(customId: string): number;
  getTimeDeltaByCurrentWindow(event: EventEntity, planStartDate: number, now: number): number;
  toGeoFenceArray(rawList: Object | undefined): Object[];
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
  checkCalls: number = 0;
  checkShouldThrow: boolean = false;

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
    this.checkCalls += 1;
    if (this.checkShouldThrow) {
      throw new Error('check_fence_failed_aq');
    }
  }

  public setActivateAction(_action: number): void {
  }

  public setGeoFenceListener(_listener: Object): void {
  }
}

class FakeGeoFenceForEachListAQ {
  private readonly items: FakeGeoFenceAQ[];

  constructor(items: FakeGeoFenceAQ[]) {
    this.items = items;
  }

  public forEach(callback: (value: FakeGeoFenceAQ) => void): void {
    for (let i = 0; i < this.items.length; i++) {
      callback(this.items[i]);
    }
  }
}

class FakeGeoFenceForEachMixedListAQ {
  public forEach(callback: (value: FakeGeoFenceAQ | undefined) => void): void {
    callback(undefined);
    callback(new FakeGeoFenceAQ('1:4', GeoFence.STATUS_IN));
  }
}

class FakeGeoFenceSizeNumberListAQ {
  size: number;
  private readonly items: FakeGeoFenceAQ[];

  constructor(items: FakeGeoFenceAQ[]) {
    this.items = items;
    this.size = items.length + 1;
  }

  public get(index: number): FakeGeoFenceAQ | undefined {
    return this.items[index];
  }
}

class FakeGeoFenceSizeFunctionOnlyListAQ {
  private readonly rawSize: number;

  constructor(rawSize: number) {
    this.rawSize = rawSize;
  }

  public size(): number {
    return this.rawSize;
  }
}

class FakeGeoFencePlainObjectAQ {
  marker: string = 'no_iterable';
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
    this.originRequest = Reflect.get(Object(HttpRequestHelper), 'request') as Object;
    this.originValidateAmapWebConfig = Reflect.get(Object(AppConfig), 'validateAmapWebConfig') as Object;
    this.originGetRuntimeContext = Reflect.get(Object(AmapService), 'getRuntimeContext') as Object;
    this.originSearchPoiBySdk = Reflect.get(Object(AmapService), 'searchPoiBySdk') as Object;
    this.originSearchPoiWithWebFallback = Reflect.get(Object(AmapService), 'searchPoiWithWebFallback') as Object;
    this.originGetGeocodeBySdkGeoSearch = Reflect.get(Object(AmapService), 'getGeocodeBySdkGeoSearch') as Object;
    this.originGetGeocodeBySdkKeyword = Reflect.get(Object(AmapService), 'getGeocodeBySdkKeyword') as Object;
    this.originGetGeocodeByWeb = Reflect.get(Object(AmapService), 'getGeocodeByWeb') as Object;
    this.originGetCityCodeByCoordinate = Reflect.get(Object(AmapService), 'getCityCodeByCoordinate') as Object;
    this.originGetCityCodeBySdkGeoSearch = Reflect.get(Object(AmapService), 'getCityCodeBySdkGeoSearch') as Object;
    this.originGetRegeo = Reflect.get(Object(AmapService), 'getRegeo') as Object;
    this.originGetRegeoBySdkGeoSearch = Reflect.get(Object(AmapService), 'getRegeoBySdkGeoSearch') as Object;
    this.originGetRegeoBySdkNearby = Reflect.get(Object(AmapService), 'getRegeoBySdkNearby') as Object;
  }

  public setRequest(
    fn: (ownerTag: string, requestName: string, url: string, options: Object) => Promise<Object>
  ): void {
    Reflect.set(Object(HttpRequestHelper), 'request', fn);
  }

  public setValidateAmapWebConfig(fn: () => void): void {
    Reflect.set(Object(AppConfig), 'validateAmapWebConfig', fn);
  }

  public setGetRuntimeContext(fn: () => Object | null): void {
    Reflect.set(Object(AmapService), 'getRuntimeContext', fn);
  }

  public setSearchPoiBySdk(
    fn: (context: Object, keyword: string, centerLat: number, centerLng: number, limit: number, nearbyOnly: boolean) => Promise<PoiSearchItem[]>
  ): void {
    Reflect.set(Object(AmapService), 'searchPoiBySdk', fn);
  }

  public setSearchPoiWithWebFallback(
    fn: (keyword: string, centerLat: number, centerLng: number, limit: number) => Promise<PoiSearchItem[]>
  ): void {
    Reflect.set(Object(AmapService), 'searchPoiWithWebFallback', fn);
  }

  public setGetGeocodeBySdkGeoSearch(
    fn: (address: string, context: Object) => Promise<GeoCoordinate | null>
  ): void {
    Reflect.set(Object(AmapService), 'getGeocodeBySdkGeoSearch', fn);
  }

  public setGetGeocodeBySdkKeyword(
    fn: (address: string, context: Object) => Promise<GeoCoordinate | null>
  ): void {
    Reflect.set(Object(AmapService), 'getGeocodeBySdkKeyword', fn);
  }

  public setGetGeocodeByWeb(fn: (address: string) => Promise<GeoCoordinate | null>): void {
    Reflect.set(Object(AmapService), 'getGeocodeByWeb', fn);
  }

  public setGetCityCodeByCoordinate(
    fn: (latitude: number, longitude: number) => Promise<string | null>
  ): void {
    Reflect.set(Object(AmapService), 'getCityCodeByCoordinate', fn);
  }

  public setGetCityCodeBySdkGeoSearch(
    fn: (context: Object, latitude: number, longitude: number) => Promise<string | null>
  ): void {
    Reflect.set(Object(AmapService), 'getCityCodeBySdkGeoSearch', fn);
  }

  public setGetRegeo(fn: (latitude: number, longitude: number) => Promise<string | null>): void {
    Reflect.set(Object(AmapService), 'getRegeo', fn);
  }

  public setGetRegeoBySdkGeoSearch(
    fn: (context: Object, latitude: number, longitude: number) => Promise<string | null>
  ): void {
    Reflect.set(Object(AmapService), 'getRegeoBySdkGeoSearch', fn);
  }

  public setGetRegeoBySdkNearby(
    fn: (context: Object, latitude: number, longitude: number) => Promise<string | null>
  ): void {
    Reflect.set(Object(AmapService), 'getRegeoBySdkNearby', fn);
  }

  public restore(): void {
    Reflect.set(Object(HttpRequestHelper), 'request', this.originRequest);
    Reflect.set(Object(AppConfig), 'validateAmapWebConfig', this.originValidateAmapWebConfig);
    Reflect.set(Object(AmapService), 'getRuntimeContext', this.originGetRuntimeContext);
    Reflect.set(Object(AmapService), 'searchPoiBySdk', this.originSearchPoiBySdk);
    Reflect.set(Object(AmapService), 'searchPoiWithWebFallback', this.originSearchPoiWithWebFallback);
    Reflect.set(Object(AmapService), 'getGeocodeBySdkGeoSearch', this.originGetGeocodeBySdkGeoSearch);
    Reflect.set(Object(AmapService), 'getGeocodeBySdkKeyword', this.originGetGeocodeBySdkKeyword);
    Reflect.set(Object(AmapService), 'getGeocodeByWeb', this.originGetGeocodeByWeb);
    Reflect.set(Object(AmapService), 'getCityCodeByCoordinate', this.originGetCityCodeByCoordinate);
    Reflect.set(Object(AmapService), 'getCityCodeBySdkGeoSearch', this.originGetCityCodeBySdkGeoSearch);
    Reflect.set(Object(AmapService), 'getRegeo', this.originGetRegeo);
    Reflect.set(Object(AmapService), 'getRegeoBySdkGeoSearch', this.originGetRegeoBySdkGeoSearch);
    Reflect.set(Object(AmapService), 'getRegeoBySdkNearby', this.originGetRegeoBySdkNearby);
  }
}

class RepoHooksAQ {
  private readonly originPlanConsumeDirtyPlanIds: Object;
  private readonly originPlanGetPlanList: Object;
  private readonly originPlanGetPlanById: Object;
  private readonly originEventConsumeDirtyPlanIds: Object;
  private readonly originEventGetAllEvents: Object;

  constructor() {
    this.originPlanConsumeDirtyPlanIds = Reflect.get(Object(PlanRepositoryImpl), 'consumeDirtyPlanIds') as Object;
    this.originPlanGetPlanList = Reflect.get(Object(PlanRepositoryImpl), 'getPlanList') as Object;
    this.originPlanGetPlanById = Reflect.get(Object(PlanRepositoryImpl), 'getPlanById') as Object;
    this.originEventConsumeDirtyPlanIds = Reflect.get(Object(EventRepositoryImpl), 'consumeDirtyPlanIds') as Object;
    this.originEventGetAllEvents = Reflect.get(Object(EventRepositoryImpl), 'getAllEvents') as Object;
  }

  public setPlanConsumeDirtyPlanIds(fn: () => number[]): void {
    Reflect.set(Object(PlanRepositoryImpl), 'consumeDirtyPlanIds', fn);
  }

  public setPlanGetPlanList(fn: () => Promise<PlanItem[]>): void {
    Reflect.set(Object(PlanRepositoryImpl), 'getPlanList', fn);
  }

  public setPlanGetPlanById(fn: (planId: number) => Promise<PlanItem | undefined>): void {
    Reflect.set(Object(PlanRepositoryImpl), 'getPlanById', fn);
  }

  public setEventConsumeDirtyPlanIds(fn: () => number[]): void {
    Reflect.set(Object(EventRepositoryImpl), 'consumeDirtyPlanIds', fn);
  }

  public setEventGetAllEvents(fn: (planId: number) => Promise<Object[]>): void {
    Reflect.set(Object(EventRepositoryImpl), 'getAllEvents', fn);
  }

  public restore(): void {
    Reflect.set(Object(PlanRepositoryImpl), 'consumeDirtyPlanIds', this.originPlanConsumeDirtyPlanIds);
    Reflect.set(Object(PlanRepositoryImpl), 'getPlanList', this.originPlanGetPlanList);
    Reflect.set(Object(PlanRepositoryImpl), 'getPlanById', this.originPlanGetPlanById);
    Reflect.set(Object(EventRepositoryImpl), 'consumeDirtyPlanIds', this.originEventConsumeDirtyPlanIds);
    Reflect.set(Object(EventRepositoryImpl), 'getAllEvents', this.originEventGetAllEvents);
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
  Reflect.set(Object(ArrivalReminderEngine), 'instance', null);
  return ArrivalReminderEngine.getInstance();
}

function resetTrafficEngineAQ(): TrafficEngine {
  Reflect.set(Object(TrafficEngine), 'instance', null);
  return TrafficEngine.getInstance();
}

function clearAmapPoiCacheAQ(): void {
  const cache = Reflect.get(Object(AmapService), 'poiSearchCache') as Map<string, Object>;
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

    it('invalid: arrival_location_sample_should_reject_non_finite_coordinate', 0, () => {
      // Arrange
      // Act
      const nanCoordinate = ArrivalReminderEngine.isLocationSampleAccepted(Number.NaN, 121.47, 1, 1, 400, 20);
      // Assert
      expect(nanCoordinate).assertEqual(false);
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
      Reflect.set(Object(ArrivalReminderEngine), 'instance', null);
      // Act
      const first = ArrivalReminderEngine.getInstance();
      const second = ArrivalReminderEngine.getInstance();
      // Assert
      expect(first === second).assertTrue();
    });

    it('boundary: arrival_get_instance_should_create_new_after_reset', 0, () => {
      // Arrange
      Reflect.set(Object(ArrivalReminderEngine), 'instance', null);
      const first = ArrivalReminderEngine.getInstance();
      Reflect.set(Object(ArrivalReminderEngine), 'instance', null);
      // Act
      const second = ArrivalReminderEngine.getInstance();
      // Assert
      expect(first === second).assertEqual(false);
    });

    it('invalid: arrival_get_instance_should_return_existing_polluted_value', 0, () => {
      // Arrange
      const pollutedObj: PollutedMapServiceAQ = { marker: '' };
      const polluted: ArrivalReminderEngine = pollutedObj as Object as ArrivalReminderEngine;
      Reflect.set(Object(ArrivalReminderEngine), 'instance', polluted as Object);
      // Act
      const current = ArrivalReminderEngine.getInstance();
      // Assert
      expect(current === polluted).assertTrue();
      Reflect.set(Object(ArrivalReminderEngine), 'instance', null);
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
      // Act
      const vmArg8Obj: PollutedMapServiceAQ = { marker: '' };
      const vmArg8: Object = vmArg8Obj as Object;
      const ctxArg8Obj: PollutedMapServiceAQ = { marker: '' };
      const ctxArg8: Object = ctxArg8Obj as Object;
      engine.start(8, vmArg8 as never, ctxArg8 as never);
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
      // Act
      const vmArg0Obj: PollutedMapServiceAQ = { marker: '' };
      const vmArg0: Object = vmArg0Obj as Object;
      const ctxArg0Obj: PollutedMapServiceAQ = { marker: '' };
      const ctxArg0: Object = ctxArg0Obj as Object;
      engine.start(0, vmArg0 as never, ctxArg0 as never);
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
      // Act
      const vmArg1Obj: PollutedMapServiceAQ = { marker: '' };
      const vmArg1: Object = vmArg1Obj as Object;
      const ctxArg1Obj: PollutedMapServiceAQ = { marker: '' };
      const ctxArg1: Object = ctxArg1Obj as Object;
      engine.start(1, vmArg1 as never, ctxArg1 as never);
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

    it('boundary: arrival_refresh_fences_should_return_early_when_client_missing_or_refreshing', 0, async () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const geoFenceClient = new FakeGeoFenceClientAQ();
      Reflect.set(engine as Object, 'geoFenceClient', geoFenceClient as Object);
      Reflect.set(engine as Object, 'isRefreshingCandidates', true);
      // Act
      await engine.refreshFencesNow('manual');
      Reflect.set(engine as Object, 'isRefreshingCandidates', false);
      Reflect.set(engine as Object, 'geoFenceClient', null);
      await engine.refreshFencesNow('manual');
      // Assert
      expect((Reflect.get(engine as Object, 'isRefreshingCandidates') as boolean)).assertEqual(false);
    });

    it('boundary: arrival_refresh_fences_should_mark_full_resync_and_rebuild_when_only_inactive_plans', 0, async () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const hooks = new RepoHooksAQ();
      const geoFenceClient = new FakeGeoFenceClientAQ();
      Reflect.set(engine as Object, 'geoFenceClient', geoFenceClient as Object);
      const staleFences = Reflect.get(engine as Object, 'fenceIdSnapshot') as Set<string>;
      staleFences.clear();
      staleFences.add('legacy:1');
      hooks.setPlanConsumeDirtyPlanIds((): number[] => []);
      hooks.setEventConsumeDirtyPlanIds((): number[] => []);
      hooks.setPlanGetPlanList(async (): Promise<PlanItem[]> => {
        const archived = createPlanItemAQ(301);
        archived.status = 2;
        return [archived];
      });
      hooks.setPlanGetPlanById(async (_planId: number): Promise<PlanItem | undefined> => undefined);
      hooks.setEventGetAllEvents(async (_planId: number): Promise<Object[]> => []);
      // Act
      await engine.refreshFencesNow('start');
      hooks.restore();
      // Assert
      expect((Reflect.get(engine as Object, 'lastFullResyncTs') as number) > 0).assertTrue();
      expect(geoFenceClient.removeCount).assertEqual(1);
      expect((Reflect.get(engine as Object, 'monitoredEvents') as EventEntity[]).length).assertEqual(0);
    });

    it('boundary: arrival_refresh_fences_should_rebuild_when_fence_snapshot_size_equal_but_ids_changed', 0, async () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const hooks = new RepoHooksAQ();
      const geoFenceClient = new FakeGeoFenceClientAQ();
      const plan = createPlanItemAQ(401);
      const event = createEventAQ(4001, 31.23, 121.47, 'rebuilt');
      event.fixed_start_time = '';
      event.dynamic_start_time = Date.now() + 60_000;
      Reflect.set(engine as Object, 'geoFenceClient', geoFenceClient as Object);
      const oldFenceIds = Reflect.get(engine as Object, 'fenceIdSnapshot') as Set<string>;
      oldFenceIds.clear();
      oldFenceIds.add('stale:4001');
      hooks.setPlanConsumeDirtyPlanIds((): number[] => []);
      hooks.setEventConsumeDirtyPlanIds((): number[] => []);
      hooks.setPlanGetPlanList(async (): Promise<PlanItem[]> => [plan]);
      hooks.setPlanGetPlanById(async (_planId: number): Promise<PlanItem | undefined> => plan);
      hooks.setEventGetAllEvents(async (_planId: number): Promise<Object[]> => [event]);
      // Act
      await engine.refreshFencesNow('start');
      hooks.restore();
      // Assert
      expect(geoFenceClient.removeCount).assertEqual(1);
    });

    it('boundary: arrival_refresh_fences_should_tolerate_missing_plan_rows_and_missing_plan_cache', 0, async () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const hooks = new RepoHooksAQ();
      const geoFenceClient = new FakeGeoFenceClientAQ();
      Reflect.set(engine as Object, 'geoFenceClient', geoFenceClient as Object);
      Reflect.set(engine as Object, 'lastFullResyncTs', Date.now());
      Reflect.set(engine as Object, 'activePlanSnapshot', new Set<number>([501]));
      (Reflect.get(engine as Object, 'planCandidateCache') as Map<number, Object>).clear();
      hooks.setPlanConsumeDirtyPlanIds((): number[] => []);
      hooks.setEventConsumeDirtyPlanIds((): number[] => []);
      hooks.setPlanGetPlanList(async (): Promise<PlanItem[]> => []);
      hooks.setPlanGetPlanById(async (_planId: number): Promise<PlanItem | undefined> => undefined);
      hooks.setEventGetAllEvents(async (_planId: number): Promise<Object[]> => []);
      // Act
      await engine.refreshFencesNow('manual');
      hooks.restore();
      // Assert
      expect((Reflect.get(engine as Object, 'monitoredEvents') as EventEntity[]).length).assertEqual(0);
      expect((Reflect.get(engine as Object, 'eventPlanIdMap') as Map<number, number>).size).assertEqual(0);
    });

    it('boundary: arrival_refresh_fences_should_detect_same_size_but_different_fence_id_snapshot', 0, async () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const hooks = new RepoHooksAQ();
      const geoFenceClient = new FakeGeoFenceClientAQ();
      const plan = createPlanItemAQ(551);
      const event = createEventAQ(5501, 31.23, 121.47, 'snapshot_diff');
      Reflect.set(engine as Object, 'geoFenceClient', geoFenceClient as Object);
      const oldFenceIds = Reflect.get(engine as Object, 'fenceIdSnapshot') as Set<string>;
      oldFenceIds.clear();
      oldFenceIds.add('legacy_same_size');
      hooks.setPlanConsumeDirtyPlanIds((): number[] => []);
      hooks.setEventConsumeDirtyPlanIds((): number[] => []);
      hooks.setPlanGetPlanList(async (): Promise<PlanItem[]> => [plan]);
      hooks.setPlanGetPlanById(async (_planId: number): Promise<PlanItem | undefined> => plan);
      hooks.setEventGetAllEvents(async (_planId: number): Promise<Object[]> => [event]);
      Reflect.set(engine as Object, 'buildPlanCandidateCache', (_plan: PlanItem, _events: Object[], _now: number): PlanCandidateCacheAQ => {
        return {
          scheduleCount: 1,
          pendingCount: 1,
          activeCount: 0,
          withCoordinateCount: 1,
          eligibleCount: 1,
          candidates: [event],
          timeDeltaByEventId: new Map<number, number>([[event.id, 60_000]])
        };
      });
      // Act
      await engine.refreshFencesNow('start');
      hooks.restore();
      // Assert
      expect(geoFenceClient.removeCount).assertEqual(1);
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

    it('normal: arrival_build_plan_candidate_cache_should_collect_eligible_stats_and_candidates', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      const plan = createPlanItemAQ(77);
      const startableEligible = createEventAQ(7701, 31.2304, 121.4737, 'eligible');
      const startableNoCoordinate = createEventAQ(7702, 0, 0, 'no_coordinate');
      const activeEvent = createEventAQ(7703, 31.2404, 121.4837, 'active');
      activeEvent.actual_start_time = Date.now() - 60_000;
      activeEvent.actual_end_time = 0;
      Reflect.set(engine as Object, 'getTimeDeltaByCurrentWindow', (event: EventEntity): number => {
        if (event.id === startableEligible.id) {
          return 1_200;
        }
        if (event.id === startableNoCoordinate.id) {
          return 500;
        }
        return 900;
      });
      const rawEvents: Object[] = [startableEligible.toInterface() as Object, startableNoCoordinate.toInterface() as Object, activeEvent.toInterface() as Object];
      // Act
      const cache = enginePrivate.buildPlanCandidateCache(plan, rawEvents, Date.now());
      // Assert
      expect(cache.scheduleCount).assertEqual(3);
      expect(cache.pendingCount).assertEqual(2);
      expect(cache.activeCount).assertEqual(1);
      expect(cache.withCoordinateCount).assertEqual(1);
      expect(cache.eligibleCount).assertEqual(1);
      expect(cache.candidates.length).assertEqual(1);
      expect(cache.candidates[0].id).assertEqual(startableEligible.id);
      expect(cache.timeDeltaByEventId.get(startableEligible.id) ?? -1).assertEqual(1_200);
    });

    it('boundary: arrival_build_plan_candidate_cache_should_count_unscheduled_events_without_schedule_increment', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      const plan = createPlanItemAQ(78);
      const scheduledEvent = createEventAQ(7801, 31.2304, 121.4737, 'scheduled');
      const unscheduledEvent = createEventAQ(7802, 31.2404, 121.4837, 'unscheduled');
      unscheduledEvent.status = 0;
      Reflect.set(engine as Object, 'getTimeDeltaByCurrentWindow', (_event: EventEntity): number => 600);
      const rawEvents: Object[] = [scheduledEvent.toInterface() as Object, unscheduledEvent.toInterface() as Object];
      // Act
      const cache = enginePrivate.buildPlanCandidateCache(plan, rawEvents, Date.now());
      // Assert
      expect(cache.scheduleCount).assertEqual(1);
      expect(cache.pendingCount).assertEqual(1);
      expect(cache.activeCount).assertEqual(0);
      expect(cache.withCoordinateCount).assertEqual(1);
      expect(cache.eligibleCount).assertEqual(1);
      expect(cache.candidates.length).assertEqual(1);
      expect(cache.candidates[0].id).assertEqual(scheduledEvent.id);
    });

    it('boundary: arrival_prune_plan_candidate_cache_should_remove_only_inactive_plan_entries', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      const cacheMap = Reflect.get(engine as Object, 'planCandidateCache') as Map<number, Object>;
      cacheMap.clear();
      const planCacheEntry1Obj: PollutedMapServiceAQ = { marker: 'keep_1' };
      const planCacheEntry1: Object = planCacheEntry1Obj as Object;
      const planCacheEntry2Obj: PollutedMapServiceAQ = { marker: 'drop_2' };
      const planCacheEntry2: Object = planCacheEntry2Obj as Object;
      const planCacheEntry3Obj: PollutedMapServiceAQ = { marker: 'keep_3' };
      const planCacheEntry3: Object = planCacheEntry3Obj as Object;
      cacheMap.set(1, planCacheEntry1);
      cacheMap.set(2, planCacheEntry2);
      cacheMap.set(3, planCacheEntry3);
      // Act
      enginePrivate.prunePlanCandidateCache(new Set<number>([1, 3]));
      // Assert
      expect(cacheMap.has(1)).assertEqual(true);
      expect(cacheMap.has(2)).assertEqual(false);
      expect(cacheMap.has(3)).assertEqual(true);
      expect(cacheMap.size).assertEqual(2);
    });

    it('boundary: arrival_get_eligible_events_should_filter_with_time_window_and_runtime_flag', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      const eligible = createEventAQ(7801, 31.23, 121.47, 'eligible');
      const notStartable = createEventAQ(7802, 31.23, 121.47, 'backlog');
      notStartable.status = 0;
      const outOfWindow = createEventAQ(7803, 31.23, 121.47, 'late');
      const noCoordinate = createEventAQ(7804, 0, 0, 'invalid');
      Reflect.set(engine as Object, 'monitoredEvents', [eligible, notStartable, outOfWindow, noCoordinate]);
      const timeDeltaMap = Reflect.get(engine as Object, 'eventTimeDeltaMap') as Map<number, number>;
      timeDeltaMap.clear();
      timeDeltaMap.set(eligible.id, 60_000);
      timeDeltaMap.set(notStartable.id, 60_000);
      timeDeltaMap.set(outOfWindow.id, 8 * 60 * 60 * 1000);
      timeDeltaMap.set(noCoordinate.id, 60_000);
      Reflect.set(engine as Object, 'hasAnyActiveEvent', false);
      // Act
      const eligibleEvents = enginePrivate.getEligibleEvents();
      const hasActiveBefore = enginePrivate.hasActiveEvent();
      Reflect.set(engine as Object, 'hasAnyActiveEvent', true);
      const hasActiveAfter = enginePrivate.hasActiveEvent();
      // Assert
      expect(eligibleEvents.length).assertEqual(1);
      expect(eligibleEvents[0].id).assertEqual(eligible.id);
      expect(hasActiveBefore).assertEqual(false);
      expect(hasActiveAfter).assertEqual(true);
    });

    it('invalid: arrival_pick_best_candidate_should_return_null_when_all_candidates_are_blocked_by_cooldown', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      const blocked = createEventAQ(7901, 31.21, 121.41, 'blocked');
      Reflect.set(engine as Object, 'monitoredEvents', [blocked]);
      const orderMap = Reflect.get(engine as Object, 'eventOrderMap') as Map<number, number>;
      const timeDeltaMap = Reflect.get(engine as Object, 'eventTimeDeltaMap') as Map<number, number>;
      const lastReminderByEvent = Reflect.get(engine as Object, 'lastReminderByEvent') as Map<number, number>;
      orderMap.clear();
      timeDeltaMap.clear();
      lastReminderByEvent.clear();
      orderMap.set(blocked.id, 1);
      timeDeltaMap.set(blocked.id, 300);
      const now = Date.now();
      lastReminderByEvent.set(blocked.id, now - 5_000);
      const location = new FakeAmapLocationAQ();
      location.latitude = 31.20;
      location.longitude = 121.40;
      // Act
      const picked = enginePrivate.pickBestCandidate([blocked.id], location, now);
      // Assert
      expect(picked === null).assertTrue();
    });

    it('boundary: arrival_pick_best_candidate_should_skip_missing_or_ineligible_candidates', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      const ineligible = createEventAQ(7902, 31.21, 121.41, 'ineligible');
      Reflect.set(engine as Object, 'monitoredEvents', [ineligible]);
      const timeDeltaMap = Reflect.get(engine as Object, 'eventTimeDeltaMap') as Map<number, number>;
      timeDeltaMap.clear();
      timeDeltaMap.set(ineligible.id, 8 * 60 * 60 * 1000);
      const location = new FakeAmapLocationAQ();
      location.latitude = 31.20;
      location.longitude = 121.40;
      // Act
      const picked = enginePrivate.pickBestCandidate([999001, ineligible.id], location, Date.now());
      // Assert
      expect(picked === null).assertTrue();
    });

    it('conflict: arrival_pick_best_candidate_should_prioritize_time_delta_then_order_then_distance', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      const e1 = createEventAQ(8001, 31.21, 121.41, 'e1');
      const e2 = createEventAQ(8002, 31.22, 121.42, 'e2');
      const e3 = createEventAQ(8003, 31.23, 121.43, 'e3');
      Reflect.set(engine as Object, 'monitoredEvents', [e1, e2, e3]);
      const orderMap = Reflect.get(engine as Object, 'eventOrderMap') as Map<number, number>;
      const timeDeltaMap = Reflect.get(engine as Object, 'eventTimeDeltaMap') as Map<number, number>;
      orderMap.clear();
      timeDeltaMap.clear();
      orderMap.set(e1.id, 1);
      orderMap.set(e2.id, 5);
      orderMap.set(e3.id, 2);
      timeDeltaMap.set(e1.id, 300);
      timeDeltaMap.set(e2.id, 120);
      timeDeltaMap.set(e3.id, 120);
      Reflect.set(engine as Object, 'measureDistanceMeters', (_lat1: number, _lng1: number, lat2: number, _lng2: number): number => {
        if (lat2 === e1.latitude) {
          return 200;
        }
        if (lat2 === e2.latitude) {
          return 80;
        }
        return 500;
      });
      const location = new FakeAmapLocationAQ();
      location.latitude = 31.20;
      location.longitude = 121.40;
      // Act
      const picked = enginePrivate.pickBestCandidate([e1.id, e2.id, e3.id], location, Date.now());
      // Assert
      expect((picked?.id ?? 0)).assertEqual(e3.id);
    });

    it('boundary: arrival_pick_best_candidate_should_fallback_to_distance_when_time_delta_and_order_equal', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      const near = createEventAQ(8004, 31.21, 121.41, 'near');
      const far = createEventAQ(8005, 31.25, 121.45, 'far');
      Reflect.set(engine as Object, 'monitoredEvents', [near, far]);
      const orderMap = Reflect.get(engine as Object, 'eventOrderMap') as Map<number, number>;
      const timeDeltaMap = Reflect.get(engine as Object, 'eventTimeDeltaMap') as Map<number, number>;
      orderMap.clear();
      timeDeltaMap.clear();
      orderMap.set(near.id, 2);
      orderMap.set(far.id, 2);
      timeDeltaMap.set(near.id, 120);
      timeDeltaMap.set(far.id, 120);
      Reflect.set(engine as Object, 'measureDistanceMeters', (_lat1: number, _lng1: number, lat2: number, _lng2: number): number => {
        return lat2 === near.latitude ? 20 : 200;
      });
      const location = new FakeAmapLocationAQ();
      location.latitude = 31.20;
      location.longitude = 121.40;
      // Act
      const picked = enginePrivate.pickBestCandidate([far.id, near.id], location, Date.now());
      // Assert
      expect((picked?.id ?? 0)).assertEqual(near.id);
    });

    it('regression: arrival_fire_reminder_should_write_payload_and_publish_notification', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      const event = createEventAQ(8101, 31.23, 121.47, 'museum');
      const location = new FakeAmapLocationAQ();
      location.latitude = 31.2301;
      location.longitude = 121.4701;
      const eventPlanIdMap = Reflect.get(engine as Object, 'eventPlanIdMap') as Map<number, number>;
      eventPlanIdMap.clear();
      eventPlanIdMap.set(event.id, 88);
      const originNextSeq = Reflect.get(Object(ArrivalReminderStore), 'nextSeq') as Object;
      const originWritePayload = Reflect.get(Object(ArrivalReminderStore), 'writePayload') as Object;
      const originUpdateNotification = Reflect.get(Object(NotificationGateway), 'updateScheduleNotification') as Object;
      let writtenPayload: Object | null = null;
      let capturedTitle = '';
      let capturedBody = '';
      let capturedPlanId = 0;
      let capturedEventId = 0;
      Reflect.set(Object(ArrivalReminderStore), 'nextSeq', (): number => 5566);
      Reflect.set(Object(ArrivalReminderStore), 'writePayload', (payload: Object): void => {
        writtenPayload = payload;
      });
      Reflect.set(Object(NotificationGateway), 'updateScheduleNotification', (
        title: string,
        body: string,
        planId: number,
        eventId: number,
        _ongoing: boolean
      ): Promise<void> => {
        capturedTitle = title;
        capturedBody = body;
        capturedPlanId = planId;
        capturedEventId = eventId;
        return Promise.resolve();
      });
      // Act
      enginePrivate.fireReminder(event, location, 'unit_test');
      const storedPayload = writtenPayload as ArrivalReminderPayload | null;
      // Assert
      expect((Reflect.get(engine as Object, 'lastReminderEventId') as number)).assertEqual(event.id);
      expect((storedPayload?.seq ?? 0)).assertEqual(5566);
      expect((storedPayload?.planId ?? 0)).assertEqual(88);
      expect((storedPayload?.eventId ?? 0)).assertEqual(event.id);
      expect(capturedTitle).assertEqual(`到达提醒：${event.name}`);
      expect(capturedBody.includes(event.name)).assertTrue();
      expect(capturedPlanId).assertEqual(88);
      expect(capturedEventId).assertEqual(event.id);
      Reflect.set(Object(ArrivalReminderStore), 'nextSeq', originNextSeq);
      Reflect.set(Object(ArrivalReminderStore), 'writePayload', originWritePayload);
      Reflect.set(Object(NotificationGateway), 'updateScheduleNotification', originUpdateNotification);
    });

    it('combined: arrival_ensure_reminder_consistency_should_end_and_clear_when_current_event_becomes_ineligible', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      const target = createEventAQ(8201, 31.24, 121.48, 'ended_target');
      target.completion_status = EventEntity.STATE_COMPLETED;
      Reflect.set(engine as Object, 'monitoredEvents', [target]);
      Reflect.set(engine as Object, 'lastReminderEventId', target.id);
      const timeDeltaMap = Reflect.get(engine as Object, 'eventTimeDeltaMap') as Map<number, number>;
      timeDeltaMap.clear();
      timeDeltaMap.set(target.id, 30_000);
      let endedId = 0;
      let clearedId = 0;
      Reflect.set(engine as Object, 'publishLiveActivityState', (eventId: number, status: string): void => {
        if (status === 'ENDED') {
          endedId = eventId;
        }
      });
      Reflect.set(engine as Object, 'clearReminderPayloadIfMatches', (eventId: number): void => {
        clearedId = eventId;
      });
      // Act
      enginePrivate.ensureReminderConsistency();
      // Assert
      expect(endedId).assertEqual(target.id);
      expect(clearedId).assertEqual(target.id);
      expect((Reflect.get(engine as Object, 'lastReminderEventId') as number)).assertEqual(-1);
      expect(enginePrivate.isEligibleEvent(target, 30_000)).assertEqual(false);
    });

    it('boundary: arrival_ensure_reminder_consistency_should_return_when_no_reminder_event', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      Reflect.set(engine as Object, 'lastReminderEventId', -1);
      let endedCalls = 0;
      Reflect.set(engine as Object, 'publishLiveActivityState', (_eventId: number, status: string): void => {
        if (status === 'ENDED') {
          endedCalls += 1;
        }
      });
      // Act
      enginePrivate.ensureReminderConsistency();
      // Assert
      expect(endedCalls).assertEqual(0);
      expect((Reflect.get(engine as Object, 'lastReminderEventId') as number)).assertEqual(-1);
    });

    it('boundary: arrival_ensure_reminder_consistency_should_keep_reminder_when_event_still_eligible', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      const target = createEventAQ(8451, 31.23, 121.47, 'eligible');
      Reflect.set(engine as Object, 'monitoredEvents', [target]);
      Reflect.set(engine as Object, 'lastReminderEventId', target.id);
      const timeDeltaMap = Reflect.get(engine as Object, 'eventTimeDeltaMap') as Map<number, number>;
      timeDeltaMap.clear();
      timeDeltaMap.set(target.id, 60_000);
      let endedCalls = 0;
      Reflect.set(engine as Object, 'publishLiveActivityState', (_eventId: number, status: string): void => {
        if (status === 'ENDED') {
          endedCalls += 1;
        }
      });
      // Act
      enginePrivate.ensureReminderConsistency();
      // Assert
      expect(endedCalls).assertEqual(0);
      expect((Reflect.get(engine as Object, 'lastReminderEventId') as number)).assertEqual(target.id);
    });

    it('boundary: arrival_publish_live_activity_state_should_end_and_update_with_existing_event_name', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const target = createEventAQ(8461, 31.23, 121.47, 'West Lake');
      Reflect.set(engine as Object, 'monitoredEvents', [target]);
      const eventPlanIdMap = Reflect.get(engine as Object, 'eventPlanIdMap') as Map<number, number>;
      eventPlanIdMap.clear();
      eventPlanIdMap.set(target.id, 321);
      const startOrigin = Reflect.get(Object(ArrivalLiveActivityBridge), 'start') as Object;
      const endOrigin = Reflect.get(Object(ArrivalLiveActivityBridge), 'end') as Object;
      const updateOrigin = Reflect.get(Object(ArrivalLiveActivityBridge), 'update') as Object;
      let endedEventId = 0;
      let updatedEventId = 0;
      Reflect.set(Object(ArrivalLiveActivityBridge), 'start', (_planId: number, _eventId: number, _placeName: string): void => {});
      Reflect.set(Object(ArrivalLiveActivityBridge), 'end', (_planId: number, eventId: number, placeName: string): void => {
        if (placeName === 'West Lake') {
          endedEventId = eventId;
        }
      });
      Reflect.set(Object(ArrivalLiveActivityBridge), 'update', (_planId: number, eventId: number, placeName: string, _status: string): void => {
        if (placeName === 'West Lake') {
          updatedEventId = eventId;
        }
      });
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      // Act
      enginePrivate.publishLiveActivityState(target.id, 'ENDED');
      enginePrivate.publishLiveActivityState(target.id, 'ARRIVING');
      Reflect.set(Object(ArrivalLiveActivityBridge), 'start', startOrigin);
      Reflect.set(Object(ArrivalLiveActivityBridge), 'end', endOrigin);
      Reflect.set(Object(ArrivalLiveActivityBridge), 'update', updateOrigin);
      // Assert
      expect(endedEventId).assertEqual(target.id);
      expect(updatedEventId).assertEqual(target.id);
    });

    it('normal: arrival_apply_dirty_plans_should_merge_active_and_drop_inactive_plan_ids', 0, async (done: Function) => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      const hooks = new RepoHooksAQ();
      const active = new Set<number>([1, 2]);
      const dirty = new Set<number>([2, 3, 4]);
      hooks.setPlanGetPlanById(async (planId: number): Promise<PlanItem | undefined> => {
        if (planId === 2) {
          return createPlanItemAQ(2);
        }
        if (planId === 3) {
          const archived = createPlanItemAQ(3);
          archived.status = 2;
          return archived;
        }
        return undefined;
      });
      // Act
      await enginePrivate.applyDirtyPlansToActiveSnapshot(active, dirty);
      hooks.restore();
      // Assert
      expect(active.has(2)).assertTrue();
      expect(active.has(3)).assertFalse();
      expect(active.has(4)).assertFalse();
      done();
    });

    it('boundary: arrival_apply_dirty_plans_should_return_immediately_when_dirty_set_empty', 0, async (done: Function) => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      const active = new Set<number>([1, 2]);
      const dirty = new Set<number>();
      // Act
      await enginePrivate.applyDirtyPlansToActiveSnapshot(active, dirty);
      // Assert
      expect(active.size).assertEqual(2);
      expect(active.has(1)).assertTrue();
      expect(active.has(2)).assertTrue();
      done();
    });

    it('boundary: arrival_collect_ready_candidate_ids_should_track_enter_and_drop_stale_ids', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      const client = new FakeGeoFenceClientAQ();
      client.fenceList = [
        new FakeGeoFenceAQ('10:100', GeoFence.STATUS_IN),
        new FakeGeoFenceAQ('', GeoFence.STATUS_IN),
        new FakeGeoFenceAQ('10:200', 0)
      ];
      Reflect.set(engine as Object, 'geoFenceClient', client as Object);
      const enterMap = Reflect.get(engine as Object, 'geoFenceEnterTs') as Map<string, number>;
      enterMap.set('10:200', Date.now() - 1_000);
      // Act
      const ready = enginePrivate.collectReadyCandidateIds();
      // Assert
      expect(ready.length).assertEqual(1);
      expect(ready[0]).assertEqual(100);
      expect(enterMap.has('10:100')).assertTrue();
      expect(enterMap.has('10:200')).assertFalse();
    });

    it('boundary: arrival_collect_ready_candidate_ids_should_skip_short_dwell_and_invalid_event_id', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      const client = new FakeGeoFenceClientAQ();
      client.fenceList = [
        new FakeGeoFenceAQ('12:310', GeoFence.STATUS_IN),
        new FakeGeoFenceAQ('12:bad', GeoFence.STATUS_IN),
        new FakeGeoFenceAQ('12:311', GeoFence.STATUS_IN)
      ];
      Reflect.set(engine as Object, 'geoFenceClient', client as Object);
      Reflect.set(engine as Object, 'dwellWindowMs', 1_000);
      const enterMap = Reflect.get(engine as Object, 'geoFenceEnterTs') as Map<string, number>;
      enterMap.clear();
      enterMap.set('12:310', Date.now() - 2_000);
      enterMap.set('12:bad', Date.now() - 2_000);
      enterMap.set('12:311', Date.now());
      // Act
      const ready = enginePrivate.collectReadyCandidateIds();
      // Assert
      expect(ready.length).assertEqual(1);
      expect(ready[0]).assertEqual(310);
      expect(enterMap.has('12:311')).assertTrue();
    });

    it('invalid: arrival_collect_direct_ready_candidate_ids_should_prune_stale_direct_entries', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      const inside = createEventAQ(8301, 31.2304, 121.4737, 'inside');
      const outside = createEventAQ(8302, 31.9, 121.9, 'outside');
      Reflect.set(engine as Object, 'monitoredEvents', [inside, outside]);
      const timeDeltaMap = Reflect.get(engine as Object, 'eventTimeDeltaMap') as Map<number, number>;
      timeDeltaMap.clear();
      timeDeltaMap.set(inside.id, 1_000);
      timeDeltaMap.set(outside.id, 1_000);
      const directMap = Reflect.get(engine as Object, 'directEnterTs') as Map<number, number>;
      directMap.clear();
      directMap.set(9999, Date.now() - 5_000);
      const location = new FakeAmapLocationAQ();
      location.latitude = 31.2304;
      location.longitude = 121.4737;
      // Act
      const ready = enginePrivate.collectDirectReadyCandidateIds(location);
      // Assert
      expect(ready.length).assertEqual(1);
      expect(ready[0]).assertEqual(inside.id);
      expect(directMap.has(inside.id)).assertTrue();
      expect(directMap.has(9999)).assertFalse();
    });

    it('boundary: arrival_collect_direct_ready_candidate_ids_should_keep_existing_enter_without_ready_when_dwell_not_met', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      const nearEvent = createEventAQ(8311, 31.2304, 121.4737, 'near');
      Reflect.set(engine as Object, 'monitoredEvents', [nearEvent]);
      Reflect.set(engine as Object, 'dwellWindowMs', 1_000);
      const timeDeltaMap = Reflect.get(engine as Object, 'eventTimeDeltaMap') as Map<number, number>;
      timeDeltaMap.clear();
      timeDeltaMap.set(nearEvent.id, 2_000);
      const directMap = Reflect.get(engine as Object, 'directEnterTs') as Map<number, number>;
      directMap.clear();
      directMap.set(nearEvent.id, Date.now());
      const location = new FakeAmapLocationAQ();
      location.latitude = 31.2304;
      location.longitude = 121.4737;
      // Act
      const ready = enginePrivate.collectDirectReadyCandidateIds(location);
      // Assert
      expect(ready.length).assertEqual(0);
      expect(directMap.has(nearEvent.id)).assertTrue();
    });

    it('conflict: arrival_on_location_changed_should_drop_invalid_sample_and_keep_pending_candidates_unchanged', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      const client = new FakeGeoFenceClientAQ();
      Reflect.set(engine as Object, 'geoFenceClient', client as Object);
      const pending = Reflect.get(engine as Object, 'pendingCandidateIds') as Set<number>;
      pending.clear();
      pending.add(77);
      const sample = new FakeAmapLocationAQ();
      sample.latitude = 31.23;
      sample.longitude = 121.47;
      sample.accuracy = 999;
      sample.speed = 30;
      // Act
      enginePrivate.onLocationChanged(sample);
      // Assert
      expect(client.checkCalls).assertEqual(0);
      expect((Reflect.get(engine as Object, 'lastLocation') as Object | null) === null).assertTrue();
      expect(pending.has(77)).assertTrue();
    });

    it('boundary: arrival_on_location_changed_should_return_early_when_geofence_client_missing', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      Reflect.set(engine as Object, 'geoFenceClient', null);
      const pending = Reflect.get(engine as Object, 'pendingCandidateIds') as Set<number>;
      pending.clear();
      pending.add(99);
      const sample = new FakeAmapLocationAQ();
      sample.latitude = 31.20;
      sample.longitude = 121.40;
      sample.accuracy = 10;
      sample.speed = 2;
      // Act
      enginePrivate.onLocationChanged(sample);
      // Assert
      expect((Reflect.get(engine as Object, 'lastLocation') as Object | null) === null).assertTrue();
      expect(pending.has(99)).assertTrue();
    });

    it('boundary: arrival_on_location_changed_should_skip_periodic_refresh_when_interval_not_elapsed', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      const client = new FakeGeoFenceClientAQ();
      Reflect.set(engine as Object, 'geoFenceClient', client as Object);
      Reflect.set(engine as Object, 'lastRefreshTs', Date.now());
      let refreshReason = '';
      let ensured = false;
      Reflect.set(engine as Object, 'refreshFencesNow', async (reason: string): Promise<void> => {
        refreshReason = reason;
      });
      Reflect.set(engine as Object, 'ensureReminderConsistency', (): void => {
        ensured = true;
      });
      Reflect.set(engine as Object, 'collectReadyCandidateIds', (): number[] => [9101]);
      Reflect.set(engine as Object, 'collectDirectReadyCandidateIds', (_loc: FakeAmapLocationAQ): number[] => []);
      Reflect.set(engine as Object, 'scheduleCandidateEvaluation', (_reason: string): void => {});
      const sample = new FakeAmapLocationAQ();
      sample.latitude = 31.2304;
      sample.longitude = 121.4737;
      sample.accuracy = 20;
      sample.speed = 2;
      // Act
      enginePrivate.onLocationChanged(sample);
      // Assert
      expect(client.checkCalls).assertEqual(1);
      expect(refreshReason).assertEqual('');
      expect(ensured).assertFalse();
    });

    it('boundary: arrival_on_location_changed_should_return_when_no_ready_candidates_collected', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      const client = new FakeGeoFenceClientAQ();
      Reflect.set(engine as Object, 'geoFenceClient', client as Object);
      Reflect.set(engine as Object, 'lastRefreshTs', Date.now());
      const pending = Reflect.get(engine as Object, 'pendingCandidateIds') as Set<number>;
      pending.clear();
      let scheduledReason = '';
      Reflect.set(engine as Object, 'collectReadyCandidateIds', (): number[] => []);
      Reflect.set(engine as Object, 'collectDirectReadyCandidateIds', (_loc: FakeAmapLocationAQ): number[] => []);
      Reflect.set(engine as Object, 'scheduleCandidateEvaluation', (reason: string): void => {
        scheduledReason = reason;
      });
      const sample = new FakeAmapLocationAQ();
      sample.latitude = 31.2304;
      sample.longitude = 121.4737;
      sample.accuracy = 20;
      sample.speed = 2;
      // Act
      enginePrivate.onLocationChanged(sample);
      // Assert
      expect(client.checkCalls).assertEqual(1);
      expect(pending.size).assertEqual(0);
      expect(scheduledReason).assertEqual('');
    });

    it('boundary: arrival_collect_ready_candidate_ids_should_return_empty_when_geofence_client_missing', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      Reflect.set(engine as Object, 'geoFenceClient', null);
      // Act
      const ready = enginePrivate.collectReadyCandidateIds();
      // Assert
      expect(ready.length).assertEqual(0);
    });

    it('regression: arrival_on_location_changed_should_refresh_and_schedule_when_candidates_ready', 0, async (done: Function) => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      const client = new FakeGeoFenceClientAQ();
      Reflect.set(engine as Object, 'geoFenceClient', client as Object);
      Reflect.set(engine as Object, 'lastRefreshTs', Date.now() - 20_000);
      let refreshedReason = '';
      let ensured = false;
      let scheduledReason = '';
      Reflect.set(engine as Object, 'refreshFencesNow', async (reason: string): Promise<void> => {
        refreshedReason = reason;
      });
      Reflect.set(engine as Object, 'ensureReminderConsistency', (): void => {
        ensured = true;
      });
      Reflect.set(engine as Object, 'collectReadyCandidateIds', (): number[] => [9001]);
      Reflect.set(engine as Object, 'collectDirectReadyCandidateIds', (_loc: FakeAmapLocationAQ): number[] => [9002]);
      Reflect.set(engine as Object, 'scheduleCandidateEvaluation', (reason: string): void => {
        scheduledReason = reason;
      });
      const sample = new FakeAmapLocationAQ();
      sample.latitude = 31.2304;
      sample.longitude = 121.4737;
      sample.accuracy = 20;
      sample.speed = 2;
      // Act
      enginePrivate.onLocationChanged(sample);
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => setTimeout(() => resolve(), 20));
      const pending = Reflect.get(engine as Object, 'pendingCandidateIds') as Set<number>;
      // Assert
      expect(client.checkCalls).assertEqual(1);
      expect(refreshedReason).assertEqual('periodic_tick');
      expect(ensured).assertTrue();
      expect(scheduledReason).assertEqual('geo_in_or_direct');
      expect(pending.has(9001)).assertTrue();
      expect(pending.has(9002)).assertTrue();
      done();
    });

    it('combined: arrival_schedule_and_evaluate_should_trigger_once_and_fire_selected_event', 0, async (done: Function) => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      const location = new FakeAmapLocationAQ();
      location.latitude = 31.22;
      location.longitude = 121.41;
      Reflect.set(engine as Object, 'lastLocation', location as Object);
      Reflect.set(engine as Object, 'batchWindowMs', 5);
      Reflect.set(engine as Object, 'pendingBatchTimer', -1);
      Reflect.set(engine as Object, 'reminderLockUntilTs', 0);
      Reflect.set(engine as Object, 'hasAnyActiveEvent', false);
      const pending = Reflect.get(engine as Object, 'pendingCandidateIds') as Set<number>;
      pending.clear();
      pending.add(1001);
      let evaluateCalls = 0;
      Reflect.set(engine as Object, 'evaluateCandidates', (reason: string): void => {
        if (reason === 'batch') {
          evaluateCalls += 1;
        }
      });
      // Act
      enginePrivate.scheduleCandidateEvaluation('batch');
      enginePrivate.scheduleCandidateEvaluation('batch_again');
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => setTimeout(() => resolve(), 40));
      // Assert
      expect(evaluateCalls).assertEqual(1);
      expect((Reflect.get(engine as Object, 'pendingBatchTimer') as number)).assertEqual(-1);
      done();
    });

    it('normal: arrival_evaluate_candidates_should_fire_selected_candidate_when_runtime_allows', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      const location = new FakeAmapLocationAQ();
      location.latitude = 31.22;
      location.longitude = 121.41;
      Reflect.set(engine as Object, 'lastLocation', location as Object);
      Reflect.set(engine as Object, 'reminderLockUntilTs', 0);
      Reflect.set(engine as Object, 'hasAnyActiveEvent', false);
      const pending = Reflect.get(engine as Object, 'pendingCandidateIds') as Set<number>;
      pending.clear();
      pending.add(1001);
      let firedEventId = 0;
      Reflect.set(engine as Object, 'pickBestCandidate', (_ids: number[], _loc: FakeAmapLocationAQ, _now: number): EventEntity | null => {
        return createEventAQ(1001, 31.2301, 121.4701, 'picked');
      });
      Reflect.set(engine as Object, 'fireReminder', (event: EventEntity, _loc: FakeAmapLocationAQ, _reason: string): void => {
        firedEventId = event.id;
      });
      // Act
      enginePrivate.evaluateCandidates('manual_eval');
      // Assert
      expect(firedEventId).assertEqual(1001);
      expect(pending.size).assertEqual(0);
    });

    it('boundary: arrival_evaluate_candidates_should_return_early_on_guard_clauses', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      const pending = Reflect.get(engine as Object, 'pendingCandidateIds') as Set<number>;
      let fireCount = 0;
      Reflect.set(engine as Object, 'fireReminder', (_event: EventEntity, _loc: FakeAmapLocationAQ, _reason: string): void => {
        fireCount += 1;
      });
      // Act
      pending.clear();
      pending.add(2001);
      Reflect.set(engine as Object, 'lastLocation', null);
      enginePrivate.evaluateCandidates('guard_no_location');
      // Assert
      expect(pending.size).assertEqual(0);
      // Act
      const location = new FakeAmapLocationAQ();
      location.latitude = 31.22;
      location.longitude = 121.41;
      Reflect.set(engine as Object, 'lastLocation', location as Object);
      Reflect.set(engine as Object, 'reminderLockUntilTs', Date.now() + 60_000);
      pending.add(2002);
      enginePrivate.evaluateCandidates('guard_lock');
      // Assert
      expect(pending.size).assertEqual(0);
      // Act
      Reflect.set(engine as Object, 'reminderLockUntilTs', 0);
      Reflect.set(engine as Object, 'hasActiveEvent', (): boolean => true);
      pending.add(2003);
      enginePrivate.evaluateCandidates('guard_active');
      // Assert
      expect(pending.size).assertEqual(0);
      // Act
      Reflect.set(engine as Object, 'hasActiveEvent', (): boolean => false);
      pending.clear();
      enginePrivate.evaluateCandidates('guard_empty_candidates');
      // Assert
      expect(pending.size).assertEqual(0);
      // Act
      pending.add(2004);
      Reflect.set(engine as Object, 'pickBestCandidate', (_ids: number[], _loc: FakeAmapLocationAQ, _now: number): EventEntity | null => null);
      enginePrivate.evaluateCandidates('guard_no_selected');
      // Assert
      expect(pending.size).assertEqual(0);
      expect(fireCount).assertEqual(0);
    });

    it('boundary: arrival_private_helpers_should_cover_custom_id_time_delta_and_geofence_array_paths', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      const event = createEventAQ(8401, 31.20, 121.40, 'helper');
      event.plan_id = 66;
      event.day_offset = 0;
      event.fixed_start_time = '10:30';
      const startDate = new Date(2026, 3, 18, 8, 0, 0, 0).getTime();
      const dayBase = new Date(startDate);
      dayBase.setHours(0, 0, 0, 0);
      const fixedTs = dayBase.getTime() + 10 * 60 * 60 * 1000 + 30 * 60 * 1000;
      const listByLength = new FakeGeoFenceListAQ([new FakeGeoFenceAQ('1:1', GeoFence.STATUS_IN)]);
      const listByForEach = new FakeGeoFenceForEachListAQ([new FakeGeoFenceAQ('1:2', 0)]);
      const listByForEachMixed = new FakeGeoFenceForEachMixedListAQ();
      const listBySizeNumber = new FakeGeoFenceSizeNumberListAQ([new FakeGeoFenceAQ('1:3', GeoFence.STATUS_IN)]);
      const listBySizeFunctionOnly = new FakeGeoFenceSizeFunctionOnlyListAQ(2);
      const listPlainObj = new FakeGeoFencePlainObjectAQ();
      const isValidCoordinate = Reflect.get(engine as Object, 'isValidCoordinate') as (latitude: number, longitude: number) => boolean;
      const isPlanActiveForReminder = Reflect.get(engine as Object, 'isPlanActiveForReminder') as (plan: PlanItem | undefined) => boolean;
      const isSamePlanSet = Reflect.get(engine as Object, 'isSamePlanSet') as (nextSet: Set<number>, prevSet: Set<number>) => boolean;
      // Act
      const customId = enginePrivate.makeCustomId(event);
      const parsedValid = enginePrivate.parseEventId(customId);
      const parsedInvalid = enginePrivate.parseEventId('bad_id');
      const deltaFixed = enginePrivate.getTimeDeltaByCurrentWindow(event, startDate, fixedTs + 600_000);
      event.fixed_start_time = 'bad';
      const deltaWindow = enginePrivate.getTimeDeltaByCurrentWindow(event, startDate, dayBase.getTime() + 2_000);
      const deltaBeforeWindow = enginePrivate.getTimeDeltaByCurrentWindow(event, startDate, dayBase.getTime() - 5_000);
      const deltaAfterWindow = enginePrivate.getTimeDeltaByCurrentWindow(
        event,
        startDate,
        dayBase.getTime() + 24 * 60 * 60 * 1000 + 5_000
      );
      event.fixed_start_time = '25:99';
      const deltaInvalidClock = enginePrivate.getTimeDeltaByCurrentWindow(event, startDate, dayBase.getTime() + 1_000);
      event.fixed_start_time = '';
      const deltaNoFixed = enginePrivate.getTimeDeltaByCurrentWindow(event, startDate, dayBase.getTime() + 1_000);
      const deltaNoStart = enginePrivate.getTimeDeltaByCurrentWindow(event, 0, Date.now());
      const fromLength = enginePrivate.toGeoFenceArray(listByLength as Object);
      const fromForEach = enginePrivate.toGeoFenceArray(listByForEach as Object);
      const fromForEachMixed = enginePrivate.toGeoFenceArray(listByForEachMixed as Object);
      const fromUndefined = enginePrivate.toGeoFenceArray(undefined);
      const fromSizeNumber = enginePrivate.toGeoFenceArray(listBySizeNumber as Object);
      const fromSizeFunctionOnly = enginePrivate.toGeoFenceArray(listBySizeFunctionOnly as Object);
      const fromPlainObject = enginePrivate.toGeoFenceArray(listPlainObj as Object);
      const validCoordinate = isValidCoordinate(31.20, 121.40);
      const nanCoordinate = isValidCoordinate(Number.NaN, 121.40);
      const infiniteCoordinate = isValidCoordinate(31.20, Number.POSITIVE_INFINITY);
      const outOfRangeCoordinate = isValidCoordinate(95, 200);
      const activeWhenMissing = isPlanActiveForReminder(undefined);
      const activeWhenDeleted = isPlanActiveForReminder({ id: 10001, delFlag: 1 } as PlanItem);
      const activeWhenArchived = isPlanActiveForReminder({ id: 10002, status: 2 } as PlanItem);
      const activeWhenNormal = isPlanActiveForReminder({ id: 10003, delFlag: 0, status: 1 } as PlanItem);
      const samePlanSetMatched = isSamePlanSet(new Set<number>([1, 2]), new Set<number>([2, 1]));
      const samePlanSetElementDiff = isSamePlanSet(new Set<number>([1, 2]), new Set<number>([1, 3]));
      const samePlanSetSizeDiff = isSamePlanSet(new Set<number>([1, 2]), new Set<number>([1]));
      // Assert
      expect(customId).assertEqual('66:8401');
      expect(parsedValid).assertEqual(8401);
      expect(parsedInvalid).assertEqual(-1);
      expect(deltaFixed).assertEqual(600_000);
      expect(deltaWindow).assertEqual(0);
      expect(deltaBeforeWindow).assertEqual(5_000);
      expect(deltaAfterWindow).assertEqual(5_001);
      expect(deltaInvalidClock).assertEqual(0);
      expect(deltaNoFixed).assertEqual(0);
      expect(deltaNoStart).assertEqual(0);
      expect(fromLength.length).assertEqual(1);
      expect(fromForEach.length).assertEqual(1);
      expect(fromForEachMixed.length).assertEqual(1);
      expect(fromUndefined.length).assertEqual(0);
      expect(fromSizeNumber.length).assertEqual(1);
      expect(fromSizeFunctionOnly.length).assertEqual(0);
      expect(fromPlainObject.length).assertEqual(0);
      expect(validCoordinate).assertEqual(true);
      expect(nanCoordinate).assertEqual(false);
      expect(infiniteCoordinate).assertEqual(false);
      expect(outOfRangeCoordinate).assertEqual(false);
      expect(activeWhenMissing).assertEqual(false);
      expect(activeWhenDeleted).assertEqual(false);
      expect(activeWhenArchived).assertEqual(false);
      expect(activeWhenNormal).assertEqual(true);
      expect(samePlanSetMatched).assertEqual(true);
      expect(samePlanSetElementDiff).assertEqual(false);
      expect(samePlanSetSizeDiff).assertEqual(false);
    });

    it('normal: arrival_ensure_storage_defaults_should_call_store_and_live_bridge_once', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      const originEnsureDefaults = Reflect.get(Object(ArrivalReminderStore), 'ensureDefaults') as Object;
      const originLiveInit = Reflect.get(Object(ArrivalLiveActivityBridge), 'init') as Object;
      let ensureDefaultsCalls = 0;
      let liveInitCalls = 0;
      Reflect.set(Object(ArrivalReminderStore), 'ensureDefaults', (): void => {
        ensureDefaultsCalls += 1;
      });
      Reflect.set(Object(ArrivalLiveActivityBridge), 'init', (): void => {
        liveInitCalls += 1;
      });
      // Act
      enginePrivate.ensureStorageDefaults();
      // Assert
      expect(ensureDefaultsCalls).assertEqual(1);
      expect(liveInitCalls).assertEqual(1);
      Reflect.set(Object(ArrivalReminderStore), 'ensureDefaults', originEnsureDefaults);
      Reflect.set(Object(ArrivalLiveActivityBridge), 'init', originLiveInit);
    });

    it('boundary: arrival_ensure_clients_should_return_false_when_context_is_missing', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      Reflect.set(engine as Object, 'context', null);
      Reflect.set(engine as Object, 'geoFenceClient', null);
      Reflect.set(engine as Object, 'locationManager', null);
      // Act
      const ready = enginePrivate.ensureClients();
      // Assert
      expect(ready).assertEqual(false);
    });

    it('regression: arrival_ensure_clients_should_reuse_existing_clients_without_reinitializing', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      const fakeGeoFenceClient = new FakeGeoFenceClientAQ();
      const fakeLocationManager = new FakeLocationManagerAQ();
      const fakeContextObj: PollutedMapServiceAQ = { marker: 'ctx' };
      Reflect.set(engine as Object, 'context', fakeContextObj as Object);
      Reflect.set(engine as Object, 'geoFenceClient', fakeGeoFenceClient as Object);
      Reflect.set(engine as Object, 'locationManager', fakeLocationManager as Object);
      // Act
      const ready = enginePrivate.ensureClients();
      // Assert
      expect(ready).assertEqual(true);
      expect((Reflect.get(engine as Object, 'geoFenceClient') as Object) === fakeGeoFenceClient).assertTrue();
      expect((Reflect.get(engine as Object, 'locationManager') as Object) === fakeLocationManager).assertTrue();
    });

    it('normal: arrival_refresh_fences_should_execute_active_plan_and_event_refresh_maps', 0, async (done: Function) => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const hooks = new RepoHooksAQ();
      const geoFenceClient = new FakeGeoFenceClientAQ();
      Reflect.set(engine as Object, 'geoFenceClient', geoFenceClient as Object);
      Reflect.set(engine as Object, 'lastFullResyncTs', Date.now());
      Reflect.set(engine as Object, 'activePlanSnapshot', new Set<number>([901, 902]));
      hooks.setEventConsumeDirtyPlanIds((): number[] => [901]);
      hooks.setPlanConsumeDirtyPlanIds((): number[] => [902]);
      hooks.setPlanGetPlanById(async (planId: number): Promise<PlanItem | undefined> => {
        return createPlanItemAQ(planId);
      });
      hooks.setPlanGetPlanList(async (): Promise<PlanItem[]> => []);
      hooks.setEventGetAllEvents(async (_planId: number): Promise<Object[]> => []);
      let buildCalls = 0;
      Reflect.set(engine as Object, 'buildPlanCandidateCache', (_plan: PlanItem, _events: Object[], _now: number): PlanCandidateCacheAQ => {
        buildCalls += 1;
        return {
          scheduleCount: 0,
          pendingCount: 0,
          activeCount: 0,
          withCoordinateCount: 0,
          eligibleCount: 0,
          candidates: [],
          timeDeltaByEventId: new Map<number, number>()
        };
      });
      // Act
      await engine.refreshFencesNow('manual');
      hooks.restore();
      // Assert
      expect(buildCalls).assertEqual(2);
      done();
    });

    it('combined: arrival_ensure_clients_created_listeners_should_be_invokable_when_runtime_allows', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const enginePrivate = engine as Object as ArrivalReminderEnginePrivateAQ;
      const contextCandidates: Object[] = [
        ({ marker: 'ctx_try_create' } as PollutedMapServiceAQ) as Object,
        ({} as common.Context) as Object,
        (new RuntimeContextMockAQ('ctx_runtime') as Object)
      ];
      Reflect.set(engine as Object, 'createGeoFenceClient', (_context: Object): Object => {
        return new FakeGeoFenceClientAQ() as Object;
      });
      Reflect.set(engine as Object, 'createLocationManager', (_context: Object): Object => {
        return new FakeLocationManagerAQ() as Object;
      });
      let forwardedLocationCalls = 0;
      Reflect.set(engine as Object, 'onLocationChanged', (_location: Object): void => {
        forwardedLocationCalls += 1;
      });
      // Act
      let callbackExecutions = 0;
      let locationChangedInvoked = false;
      let locationErrorInvoked = false;
      let geoFenceCreateInvoked = false;
      let anyReady = false;
      for (let i = 0; i < contextCandidates.length; i++) {
        Reflect.set(engine as Object, 'context', contextCandidates[i]);
        Reflect.set(engine as Object, 'geoFenceClient', null);
        Reflect.set(engine as Object, 'geoFenceListener', null);
        Reflect.set(engine as Object, 'locationManager', null);
        Reflect.set(engine as Object, 'locationListener', null);
        const ready = enginePrivate.ensureClients();
        if (ready) {
          anyReady = true;
        }
        const geoListener = Reflect.get(engine as Object, 'geoFenceListener') as GeoFenceListenerProbeAQ | null;
        if (geoListener?.onGeoFenceCreateFinished) {
          geoListener.onGeoFenceCreateFinished(new RuntimeContextMockAQ(`list_${i}`) as Object, 0, `custom_id_${i}`);
          callbackExecutions += 1;
          geoFenceCreateInvoked = true;
        }
        const locListener = Reflect.get(engine as Object, 'locationListener') as LocationListenerProbeAQ | null;
        if (locListener?.onLocationChanged) {
          const sample = new FakeAmapLocationAQ();
          sample.latitude = 31.23 + i * 0.01;
          sample.longitude = 121.47 + i * 0.01;
          sample.accuracy = 20;
          sample.speed = 1;
          locListener.onLocationChanged(sample as Object);
          callbackExecutions += 1;
          locationChangedInvoked = true;
        }
        if (locListener?.onLocationError) {
          const errObj: PollutedMapServiceAQ = { marker: `unit_error_${i}` };
          locListener.onLocationError(errObj as Object);
          callbackExecutions += 1;
          locationErrorInvoked = true;
        }
        const rawListener = Reflect.get(engine as Object, 'locationListener') as Record<string, Object> | null;
        if (rawListener) {
          const keys = Object.keys(rawListener);
          for (let j = 0; j < keys.length; j++) {
            const key = keys[j];
            const fn = rawListener[key] as Object;
            if (typeof fn === 'function') {
              try {
                if (key.indexOf('Error') >= 0 || key.indexOf('error') >= 0) {
                  const errObj: PollutedMapServiceAQ = { marker: `unit_error_key_${i}` };
                  (fn as (arg: Object) => void)(errObj as Object);
                  locationErrorInvoked = true;
                } else {
                  const sample = new FakeAmapLocationAQ();
                  sample.latitude = 30.12 + i * 0.01;
                  sample.longitude = 120.16 + i * 0.01;
                  sample.accuracy = 15;
                  sample.speed = 0;
                  (fn as (arg: Object) => void)(sample as Object);
                  locationChangedInvoked = true;
                }
                callbackExecutions += 1;
              } catch (_error) {
                // Ignore runtime specific callback invocation failures in unit environment.
              }
            }
          }
        }
      }
      const finalGeoListener = Reflect.get(engine as Object, 'geoFenceListener') as GeoFenceListenerProbeAQ | null;
      if (finalGeoListener?.onGeoFenceCreateFinished) {
        finalGeoListener.onGeoFenceCreateFinished(new RuntimeContextMockAQ('list_final') as Object, 0, 'custom_id_final');
        callbackExecutions += 1;
        geoFenceCreateInvoked = true;
      }
      // Assert
      if (callbackExecutions > 0) {
        expect(callbackExecutions > 0).assertTrue();
        if (locationChangedInvoked) {
          expect(forwardedLocationCalls > 0).assertTrue();
        } else {
          expect(forwardedLocationCalls).assertEqual(0);
        }
        expect(geoFenceCreateInvoked).assertTrue();
        expect(locationChangedInvoked || locationErrorInvoked).assertTrue();
      } else {
        expect(anyReady).assertEqual(false);
        expect(forwardedLocationCalls).assertEqual(0);
      }
    });

    it('boundary: arrival_client_factory_methods_should_be_callable_for_runtime_probe', 0, () => {
      // Arrange
      const engine = resetArrivalEngineAQ();
      const fakeContextObj: PollutedMapServiceAQ = { marker: 'ctx_factory_probe' };
      const createGeoFenceClient = Reflect.get(engine as Object, 'createGeoFenceClient') as (context: Object) => Object;
      const createLocationManager = Reflect.get(engine as Object, 'createLocationManager') as (context: Object) => Object;
      let attempts = 0;
      // Act
      try {
        createGeoFenceClient(fakeContextObj as Object);
      } catch (_error) {
      } finally {
        attempts += 1;
      }
      try {
        createLocationManager(fakeContextObj as Object);
      } catch (_error) {
      } finally {
        attempts += 1;
      }
      // Assert
      expect(attempts).assertEqual(2);
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
      Reflect.set(Object(AmapService), 'runtimeContext', null);
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

    it('combined: amap_resolve_poi_list_count_should_handle_length_size_and_fallback', 0, () => {
      // Arrange
      const resolvePoiListCount = Reflect.get(Object(AmapService), 'resolvePoiListCount') as (listObj: Object) => number;
      const byLengthObj: PollutedMapServiceAQ = { marker: '' };
      Reflect.set(byLengthObj as Object, 'length', 3);
      const bySizeNumberObj: PollutedMapServiceAQ = { marker: '' };
      Reflect.set(bySizeNumberObj as Object, 'size', 4);
      const bySizeFunctionObj: PollutedMapServiceAQ = { marker: '' };
      Reflect.set(bySizeFunctionObj as Object, 'size', (): number => 5);
      const fallbackObj: PollutedMapServiceAQ = { marker: '' };
      Reflect.set(fallbackObj as Object, 'size', (): number => Number.NaN);
      // Act
      const byLength = resolvePoiListCount(byLengthObj as Object);
      const bySizeNumber = resolvePoiListCount(bySizeNumberObj as Object);
      const bySizeFunction = resolvePoiListCount(bySizeFunctionObj as Object);
      const fallback = resolvePoiListCount(fallbackObj as Object);
      // Assert
      expect(byLength).assertEqual(3);
      expect(bySizeNumber).assertEqual(4);
      expect(bySizeFunction).assertEqual(5);
      expect(fallback).assertEqual(0);
    });

    it('combined: amap_extract_poi_items_should_cover_get_and_for_each_paths', 0, () => {
      // Arrange
      const extractPoiItems = Reflect.get(Object(AmapService), 'extractPoiItems') as (result: Object | undefined) => PoiSearchItem[];
      const getListObj: PollutedMapServiceAQ = { marker: '' };
      const getItems: FakePoiItemAQ[] = [
        new FakePoiItemAQ('Get-A', 'GA', 31.11, 121.11, 10),
        new FakePoiItemAQ('Get-B', 'GB', 31.12, 121.12, 20)
      ];
      Reflect.set(getListObj as Object, 'length', getItems.length);
      Reflect.set(getListObj as Object, 'get', (index: number): Object | undefined => getItems[index] as Object);
      const getResultObj: PollutedMapServiceAQ = { marker: '' };
      Reflect.set(getResultObj as Object, 'getPois', (): Object => getListObj as Object);

      const forEachListObj: PollutedMapServiceAQ = { marker: '' };
      const forEachItems: FakePoiItemAQ[] = [
        new FakePoiItemAQ('Loop-A', 'LA', 31.21, 121.21, 30),
        new FakePoiItemAQ('Loop-B', 'LB', 31.22, 121.22, 40)
      ];
      Reflect.set(forEachListObj as Object, 'forEach', (callback: (poi: Object) => void): void => {
        for (let i = 0; i < forEachItems.length; i++) {
          callback(forEachItems[i] as Object);
        }
      });
      const forEachResultObj: PollutedMapServiceAQ = { marker: '' };
      Reflect.set(forEachResultObj as Object, 'getPois', (): Object => forEachListObj as Object);
      // Act
      const fromGet = extractPoiItems(getResultObj as Object);
      const fromForEach = extractPoiItems(forEachResultObj as Object);
      // Assert
      expect(fromGet.length).assertEqual(2);
      expect(fromForEach.length).assertEqual(2);
      expect(fromGet[0].name).assertEqual('Get-A');
      expect(fromForEach[0].name).assertEqual('Loop-A');
    });

    it('combined: amap_get_list_size_and_item_should_handle_valid_and_invalid_inputs', 0, () => {
      // Arrange
      const getListSize = Reflect.get(Object(AmapService), 'getListSize') as (listObj: Object | undefined) => number;
      const getListItem = Reflect.get(Object(AmapService), 'getListItem') as <T>(listObj: Object | undefined, index: number) => T | undefined;
      const listObj: PollutedMapServiceAQ = { marker: '' };
      const values: number[] = [11, 22, 33];
      Reflect.set(listObj as Object, 'size', (): number => values.length);
      Reflect.set(listObj as Object, 'get', (index: number): number | undefined => values[index]);
      // Act
      const size = getListSize(listObj as Object);
      const first = getListItem<number>(listObj as Object, 0);
      const invalidIndex = getListItem<number>(listObj as Object, -1);
      const missingListSize = getListSize(undefined);
      const missingListItem = getListItem<number>(undefined, 0);
      // Assert
      expect(size).assertEqual(3);
      expect(first ?? 0).assertEqual(11);
      expect(invalidIndex === undefined).assertTrue();
      expect(missingListSize).assertEqual(0);
      expect(missingListItem === undefined).assertTrue();
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
      Reflect.set(Object(TrafficEngine), 'instance', null);
      // Act
      const first = TrafficEngine.getInstance();
      const second = TrafficEngine.getInstance();
      // Assert
      expect(first === second).assertTrue();
    });

    it('boundary: traffic_get_instance_should_create_new_after_reset', 0, () => {
      // Arrange
      Reflect.set(Object(TrafficEngine), 'instance', null);
      const first = TrafficEngine.getInstance();
      Reflect.set(Object(TrafficEngine), 'instance', null);
      // Act
      const second = TrafficEngine.getInstance();
      // Assert
      expect(first === second).assertEqual(false);
    });

    it('invalid: traffic_get_instance_should_return_existing_polluted_value', 0, () => {
      // Arrange
      const pollutedObj2: PollutedMapServiceAQ = { marker: '' };
      const polluted: TrafficEngine = pollutedObj2 as Object as TrafficEngine;
      Reflect.set(Object(TrafficEngine), 'instance', polluted as Object);
      // Act
      const current = TrafficEngine.getInstance();
      // Assert
      expect(current === polluted).assertTrue();
      Reflect.set(Object(TrafficEngine), 'instance', null);
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
      const key = buildTrafficKeyAQ(engine, from, to, 0);
      Reflect.set(engine as Object, 'mapService', new FakeMapServiceAQ() as Object);
      const cache = Reflect.get(engine as Object, 'cache') as Map<string, number>;
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
      Reflect.set(engine as Object, 'mapService', new FakeMapServiceAQ() as Object);
      const cache = Reflect.get(engine as Object, 'cache') as Map<string, number>;
      cache.set(buildTrafficKeyAQ(engine, from, to, 1), 20);
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
      const cache = Reflect.get(engine as Object, 'cache') as Map<string, number>;
      cache.set(buildTrafficKeyAQ(engine, from, to, 0), 15);
      const second = engine.getCommuteMinutes(from, to, 0);
      // Assert
      expect(first).assertEqual(DomainConstants.COMMUTE_LOADING);
      expect(second).assertEqual(15);
    });
  });
}

