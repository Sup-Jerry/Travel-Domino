import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { EventRepositoryImpl } from '../main/ets/infrastructure/persistence/EventRepositoryImpl';
import { PlanRepositoryImpl } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';
import { GeoCoordinate, AmapService } from '../main/ets/infrastructure/services/AmapService';
import { ArrivalReminderEngine } from '../main/ets/infrastructure/services/ArrivalReminderEngine';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { ComposableStrategy, DensityLevel, EnergyLevel, PaceLevel, PreferenceType } from '../main/ets/domain/strategy/TravelStrategyDimensions';
import {
  GeoPointInput,
  PlanNodeWeatherBinding,
  WeatherCollabContext,
  WeatherCollabOptions,
  WeatherContextBuildResult,
  WeatherSchedulePolicy,
  WeatherSnapshot,
  WeatherStageType,
  WeatherSuggestion,
  WeatherUserPreference
} from '../main/ets/domain/services/WeatherModels';
import { ITimelineWeatherHost, TimelineWeatherService } from '../main/ets/domain/timeline/services/TimelineWeatherService';
import { WeatherFacade } from '../main/ets/domain/services/WeatherFacade';
import { WeatherRefreshScheduler } from '../main/ets/domain/services/WeatherRefreshScheduler';

class StrategyDataForI implements ComposableStrategy {
  density: DensityLevel = DensityLevel.MEDIUM;
  pace: PaceLevel = PaceLevel.BALANCED;
  preference: PreferenceType = PreferenceType.BALANCED;
  energy: EnergyLevel = EnergyLevel.MEDIUM;
}

class UserPreferenceDataForI implements WeatherUserPreference {
  heatSensitivity: 0 | 1 | 2 = 1;
  rainSensitivity: 0 | 1 | 2 = 1;
  weatherRiskTolerance: 0 | 1 | 2 = 1;
}

class CollabOptionsDataForI implements WeatherCollabOptions {
  enableMultiDay?: boolean = true;
  enableMultiCity?: boolean = true;
}

class SchedulePolicyDataForI implements WeatherSchedulePolicy {
  stage: WeatherStageType = 'PLANNING';
  pollIntervalMs: number = 60_000;
  allowLocationTrigger: boolean = true;
  allowManualBypass: boolean = true;
  forceRefreshOnEnter: boolean = false;
}

class GateResultDataForI {
  success: boolean = true;
  reasonCode?: string = 'ok';
  startFromEventId?: number = 1;
}

class PlanStateMachineMockForI {
  requestSoftReplan(_args: Object): GateResultDataForI {
    return new GateResultDataForI();
  }
}

class HostMockForI implements ITimelineWeatherHost {
  events: EventEntity[] = [];
  planId: number = 1;
  currentStrategyMode: number = 0;
  weatherFeatureEnabled: boolean = true;
  weatherLoading: boolean = false;
  weatherUserPreference: WeatherUserPreference = new UserPreferenceDataForI();
  weatherCollabOptions: WeatherCollabOptions = new CollabOptionsDataForI();
  executionWeatherEnabled: boolean = true;
  executionWeatherLoading: boolean = false;
  currentPlanStatus: PlanStatus = PlanStatus.READY;
  executionWeatherLastTrigger: string = '';
  executionWeatherErrorCode: string = '';
  executionWeatherScore: number = -1;
  executionWeatherRefreshAt: number = 0;
  executionWeatherCollabSummary: string = '';
  executionWeatherCollabBadge: string = '';
  executionWeatherDisplaySource: 'CURRENT' | 'NEXT_FALLBACK' | 'UNKNOWN' = 'UNKNOWN';
  executionWeatherCurrentText: string = '';
  executionWeatherNextText: string = '';
  executionWeatherSuggestions: WeatherSuggestion[] = [];
  executionSuggestionMap: Map<string, WeatherSuggestion> = new Map<string, WeatherSuggestion>();
  executionWeatherHint: string = '';
  executionWeatherLevel: 'INFO' | 'NOTICE' | 'WARNING' = 'INFO';
  executionWeatherLastLocation: GeoPointInput | null = null;
  executionWeatherLocationTriggerCooldownMs: number = 0;
  executionWeatherLastLocationTriggerAt: number = 0;
  currentWeatherSchedulePolicy: WeatherSchedulePolicy = new SchedulePolicyDataForI();
  executionReplanBusy: boolean = false;
  executionWeatherApplying: boolean = false;
  executionWeatherAppliedSummary: string = '';
  executionWeatherLastEmitAt: number = 0;
  executionWeatherLocationDeltaMeters: number = 0;
  executionSuggestionCooldownMs: number = 0;
  executionSuggestionCooldownMap: Map<string, number> = new Map<string, number>();
  weatherPlanningHint: string = '';
  weatherRouteScore: number = -1;
  weatherCollabSummary: string = '';
  weatherCollabLabel: string = '';
  weatherStrategyHint: string = '';
  weatherLastRefreshAt: number = 0;
  planStateMachine: PlanStateMachineMockForI = new PlanStateMachineMockForI();

  activeEvent: EventEntity | null = null;
  recalculateFromEventIdCalls: number[] = [];
  recalculateFromIndexCalls: number[] = [];

  resolveCurrentWeatherStage(): WeatherStageType {
    return 'PLANNING';
  }

  async getCurrentStrategy(): Promise<ComposableStrategy> {
    return new StrategyDataForI();
  }

  getCurrentPlanStatus(): PlanStatus {
    return this.currentPlanStatus;
  }

  findCurrentActiveEvent(): EventEntity | null {
    return this.activeEvent;
  }

  getOrderedScheduleEvents(): EventEntity[] {
    return this.events.filter((item: EventEntity) => item.status === 1).sort((a: EventEntity, b: EventEntity) => a.sort_order - b.sort_order);
  }

  getMinEventDurationLimit(): number {
    return 20;
  }

  async skipEvent(_item: EventEntity): Promise<void> {
    return;
  }

  recalculateFromEventId(eventId: number): void {
    this.recalculateFromEventIdCalls.push(eventId);
  }

  recalculateFromIndex(startIndex: number): void {
    this.recalculateFromIndexCalls.push(startIndex);
  }

  markScheduleChanged(): void {
    return;
  }
}

class WeatherFacadeMockForI {
  policy: WeatherSchedulePolicy = new SchedulePolicyDataForI();
  planningResult: WeatherContextBuildResult = {} as WeatherContextBuildResult;
  executionResult: WeatherContextBuildResult = {} as WeatherContextBuildResult;
  lastExecutionLocation: GeoPointInput | undefined = undefined;

  resolveSchedulePolicy(_stage: WeatherStageType): WeatherSchedulePolicy {
    return this.policy;
  }

  async buildPlanningContext(
    _events: EventEntity[],
    _preference?: WeatherUserPreference,
    _options?: WeatherCollabOptions,
    _stage?: WeatherStageType
  ): Promise<WeatherContextBuildResult> {
    return this.planningResult;
  }

  async buildExecutionContext(
    _events: EventEntity[],
    currentLocation?: GeoPointInput,
    _forceRefresh: boolean = false,
    _preference?: WeatherUserPreference,
    _options?: WeatherCollabOptions,
    _stage?: WeatherStageType
  ): Promise<WeatherContextBuildResult> {
    this.lastExecutionLocation = currentLocation;
    return this.executionResult;
  }

  buildExecutionAdjustments(
    _planId: number,
    _context: Object,
    _futureNodes: EventEntity[],
    _preference?: WeatherUserPreference
  ): WeatherSuggestion[] {
    return [];
  }
}

class WeatherSchedulerMockForI {
  start(_intervalMs: number, _callback: () => void): void {
    return;
  }

  stop(): void {
    return;
  }
}

class ServiceBundleForI {
  host: HostMockForI = new HostMockForI();
  service: TimelineWeatherService = new TimelineWeatherService(this.host, new WeatherFacade(), new WeatherRefreshScheduler());
  facade: WeatherFacadeMockForI = new WeatherFacadeMockForI();
  scheduler: WeatherSchedulerMockForI = new WeatherSchedulerMockForI();
}

class StaticHooksForI {
  private readonly originAmapGetGeocode: Object;
  private readonly originUpdateFields: Object;
  private readonly originUpdateStrategyDimensions: Object;
  private readonly originArrivalGetInstance: Object;

  constructor() {
    this.originAmapGetGeocode = Reflect.get(AmapService, 'getGeocode') as Object;
    this.originUpdateFields = Reflect.get(EventRepositoryImpl, 'updateFields') as Object;
    this.originUpdateStrategyDimensions = Reflect.get(PlanRepositoryImpl, 'updateStrategyDimensions') as Object;
    this.originArrivalGetInstance = Reflect.get(ArrivalReminderEngine, 'getInstance') as Object;
  }

  setAmapGetGeocode(fn: (name: string) => Promise<GeoCoordinate | null>): void {
    Reflect.set(AmapService, 'getGeocode', fn);
  }

  setUpdateFields(fn: (id: number, updates: Object[], planIdHint?: number) => Promise<void>): void {
    Reflect.set(EventRepositoryImpl, 'updateFields', fn);
  }

  setUpdateStrategyDimensions(fn: (id: number, density: number, pace: number, preference: number, energy: number) => Promise<void>): void {
    Reflect.set(PlanRepositoryImpl, 'updateStrategyDimensions', fn);
  }

  setArrivalGetInstance(fn: () => Object): void {
    Reflect.set(ArrivalReminderEngine, 'getInstance', fn);
  }

  restore(): void {
    Reflect.set(AmapService, 'getGeocode', this.originAmapGetGeocode);
    Reflect.set(EventRepositoryImpl, 'updateFields', this.originUpdateFields);
    Reflect.set(PlanRepositoryImpl, 'updateStrategyDimensions', this.originUpdateStrategyDimensions);
    Reflect.set(ArrivalReminderEngine, 'getInstance', this.originArrivalGetInstance);
  }
}

class SnapshotDataForI implements WeatherSnapshot {
  locationKey: string = '';
  sourceType: 'CURRENT_LOCATION' | 'PLAN_LOCATION' = 'PLAN_LOCATION';
  weatherTime: number = 0;
  fetchTime: number = 0;
  conditionCode: string = 'UNKNOWN';
  conditionText: string = '天气未知';
  temperatureCelsius?: number = 0;
}

class ArrivalEngineMockForI {
  getLastKnownLocation(): Object | null {
    return null;
  }
}

function createBundleForI(): ServiceBundleForI {
  const bundle = new ServiceBundleForI();
  Reflect.set(bundle.service as Object, 'weatherFacade', bundle.facade);
  Reflect.set(bundle.service as Object, 'weatherScheduler', bundle.scheduler);
  return bundle;
}

function createEventForI(id: number, name: string, lat: number, lng: number): EventEntity {
  const item = new EventEntity(name, 1);
  item.id = id;
  item.status = 1;
  item.sort_order = id * 100;
  item.duration = 90;
  item.completion_status = EventEntity.STATE_PENDING;
  item.latitude = lat;
  item.longitude = lng;
  return item;
}

function createPlanningResultForI(eventId: number, generatedAt: number, routeScore: number): WeatherContextBuildResult {
  const snapshot = new SnapshotDataForI();
  snapshot.locationKey = 'loc_i_1';
  snapshot.weatherTime = generatedAt;
  snapshot.fetchTime = generatedAt;
  snapshot.conditionCode = 'RAIN';
  snapshot.conditionText = '小雨';
  snapshot.temperatureCelsius = 24;
  const eventMap = new Map<number, PlanNodeWeatherBinding>();
  eventMap.set(eventId, {
    nodeId: `${eventId}`,
    eventId: eventId,
    suitabilityScore: routeScore,
    riskTags: ['RAIN'],
    weather: snapshot
  });
  const collabContext: WeatherCollabContext = {
    dayWindows: [],
    cityBuckets: [],
    collabSummary: '跨城趋势偏弱',
    dayWindowCount: 0,
    cityGroupCount: 0,
    cityCappedCount: 0,
    cityMissCount: 0,
    trendTag: 'RAIN_PERSIST',
    fallbackPath: 'none'
  };
  return {
    context: {
      stage: 'PLANNING',
      generatedAt: generatedAt,
      bindings: [],
      routeSuitability: {
        routeScore: routeScore,
        riskTags: ['RAIN'],
        summaryText: '天气风险偏高'
      },
      collabContext: collabContext
    },
    eventMap: eventMap,
    sourceEvents: []
  };
}

function createExecutionResultForI(): WeatherContextBuildResult {
  const eventMap = new Map<number, PlanNodeWeatherBinding>();
  return {
    context: {
      stage: 'IN_PROGRESS',
      generatedAt: Date.now(),
      bindings: [],
      routeSuitability: {
        routeScore: 90,
        riskTags: [],
        summaryText: '稳定'
      }
    },
    eventMap: eventMap,
    sourceEvents: []
  };
}

function createExecutionSuggestionForI(id: string, triggerType: 'RAIN' | 'HEAT'): WeatherSuggestion {
  return {
    suggestionId: id,
    level: 'NOTICE',
    triggerType: triggerType,
    actionType: 'PREPARE',
    title: `title_${id}`,
    message: `msg_${id}`,
    relatedNodeIds: [],
    createdAt: Date.now(),
    reason: 'r',
    expectedBenefit: 'b',
    canRollback: true,
    cooldownKey: `cool_${id}`,
    expiresAt: Date.now() + 60_000
  };
}

export default function phase2CoreCoverageBatchITest() {
  describe('phase2CoreCoverageBatchITest', () => {
    it('normal: timeline_weather_service_refresh_planning_should_backfill_persist_and_apply_strategy_once', 0, async () => {
      // Arrange
      const bundle = createBundleForI();
      const hooks = new StaticHooksForI();
      let updateFieldsCalls = 0;
      let updateStrategyCalls = 0;
      hooks.setAmapGetGeocode(async (_name: string): Promise<GeoCoordinate | null> => new GeoCoordinate(31.23, 121.47));
      hooks.setUpdateFields(async (_id: number, _updates: Object[], _planIdHint?: number): Promise<void> => {
        updateFieldsCalls += 1;
        return;
      });
      hooks.setUpdateStrategyDimensions(async (_id: number, _density: number, _pace: number, _preference: number, _energy: number): Promise<void> => {
        updateStrategyCalls += 1;
        return;
      });
      const event = createEventForI(1, 'museum_i', 0, 0);
      bundle.host.events = [event];
      bundle.host.planId = 77;
      bundle.host.currentStrategyMode = 0;
      bundle.facade.planningResult = createPlanningResultForI(1, 1700000000000, 55);

      // Act
      await bundle.service.refreshPlanningWeather(true);
      await bundle.service.refreshPlanningWeather(true);
      const snapRaw = AppStorage.get<string>('PlanningWeatherSnapshot_77') ?? '';

      // Assert
      expect(bundle.host.weatherRouteScore).assertEqual(55);
      expect(bundle.host.weatherPlanningHint).assertEqual('天气风险偏高');
      expect(bundle.host.weatherCollabLabel).assertEqual('多日/多城');
      expect(bundle.host.currentStrategyMode).assertEqual(-1);
      expect(bundle.host.events[0].latitude).assertEqual(31.23);
      expect(bundle.host.events[0].longitude).assertEqual(121.47);
      expect(updateFieldsCalls > 0).assertTrue();
      expect(updateStrategyCalls).assertEqual(1);
      expect(snapRaw.indexOf('天气风险偏高') >= 0).assertTrue();
      hooks.restore();
    });

    it('boundary: timeline_weather_service_apply_execution_suggestion_should_write_strategy_hint_and_cooldown', 0, () => {
      // Arrange
      const bundle = createBundleForI();
      const rainSuggestion = createExecutionSuggestionForI('rain_i', 'RAIN');
      const heatSuggestion = createExecutionSuggestionForI('heat_i', 'HEAT');
      // Act
      bundle.service.applyExecutionSuggestion(rainSuggestion, 'MANUAL');
      bundle.service.applyExecutionSuggestion(heatSuggestion, 'MANUAL');
      // Assert
      expect(bundle.host.executionSuggestionMap.has('rain_i')).assertTrue();
      expect(bundle.host.executionSuggestionMap.has('heat_i')).assertTrue();
      expect(bundle.host.executionSuggestionCooldownMap.has('cool_rain_i')).assertTrue();
      expect(bundle.host.executionSuggestionCooldownMap.has('cool_heat_i')).assertTrue();
      expect(bundle.host.executionWeatherHint).assertEqual('msg_heat_i');
      expect(bundle.host.executionWeatherLevel).assertEqual('NOTICE');
    });

    it('combined: timeline_weather_service_refresh_execution_should_resolve_next_pending_location_when_active_invalid', 0, async () => {
      // Arrange
      const bundle = createBundleForI();
      const hooks = new StaticHooksForI();
      hooks.setArrivalGetInstance((): Object => {
        return new ArrivalEngineMockForI();
      });
      const active = createEventForI(1, 'active', 0, 0);
      const nextPending = createEventForI(2, 'next', 31.245, 121.49);
      active.sort_order = 100;
      nextPending.sort_order = 200;
      bundle.host.activeEvent = active;
      bundle.host.events = [active, nextPending];
      bundle.host.currentPlanStatus = PlanStatus.READY;
      bundle.host.weatherFeatureEnabled = true;
      bundle.host.executionWeatherEnabled = true;
      bundle.host.executionWeatherLoading = false;
      bundle.facade.policy.stage = 'IN_PROGRESS';
      bundle.facade.executionResult = createExecutionResultForI();

      // Act
      await bundle.service.refreshExecutionWeather(false, 'MANUAL', 'IN_PROGRESS');

      // Assert
      expect(bundle.host.executionWeatherLastTrigger).assertEqual('MANUAL');
      expect(bundle.host.executionWeatherLoading).assertFalse();
      expect(bundle.facade.lastExecutionLocation !== undefined).assertTrue();
      expect(bundle.facade.lastExecutionLocation!.latitude).assertEqual(31.245);
      expect(bundle.facade.lastExecutionLocation!.longitude).assertEqual(121.49);
      hooks.restore();
    });

    it('invalid: timeline_weather_service_refresh_execution_should_skip_when_feature_disabled', 0, async () => {
      // Arrange
      const bundle = createBundleForI();
      bundle.host.weatherFeatureEnabled = false;
      bundle.host.executionWeatherEnabled = true;
      bundle.host.executionWeatherLastTrigger = '';

      // Act
      await bundle.service.refreshExecutionWeather(false, 'LOCATION_CHANGE', 'IN_PROGRESS');

      // Assert
      expect(bundle.host.executionWeatherLastTrigger).assertEqual('');
      expect(bundle.host.executionWeatherLoading).assertFalse();
    });

    it('conflict: timeline_weather_service_filter_active_should_drop_expired_and_cooldown_items', 0, () => {
      // Arrange
      const bundle = createBundleForI();
      bundle.host.executionSuggestionCooldownMs = 60_000;
      const cooled = createExecutionSuggestionForI('cool_i', 'RAIN');
      const valid = createExecutionSuggestionForI('valid_i', 'HEAT');
      const expired = createExecutionSuggestionForI('expired_i', 'RAIN');
      expired.expiresAt = Date.now() - 1_000;
      bundle.host.executionSuggestionCooldownMap.set(cooled.cooldownKey || cooled.suggestionId, Date.now());

      // Act
      const filtered = bundle.service.filterActiveExecutionSuggestions([cooled, valid, expired]);

      // Assert
      expect(filtered.length).assertEqual(1);
      expect(filtered[0].suggestionId).assertEqual('valid_i');
    });

    it('regression: td-20260415-refresh-execution-fail-should-set-weather-002', 0, async () => {
      // Arrange
      const bundle = createBundleForI();
      Reflect.set(bundle.facade as Object, 'buildExecutionContext', async (): Promise<WeatherContextBuildResult> => {
        throw new Error('mock_fail_i');
      });

      // Act
      await bundle.service.refreshExecutionWeather(false, 'MANUAL', 'IN_PROGRESS');

      // Assert
      expect(bundle.host.executionWeatherErrorCode).assertEqual('WEATHER_002');
      expect(bundle.host.executionWeatherHint).assertEqual('执行天气刷新失败，已降级使用节点天气/缓存。');
      expect(bundle.host.executionWeatherLoading).assertFalse();
    });
  });
}


