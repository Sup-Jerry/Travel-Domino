import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
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

class StrategyDataForP implements ComposableStrategy {
  density: DensityLevel = DensityLevel.MEDIUM;
  pace: PaceLevel = PaceLevel.BALANCED;
  preference: PreferenceType = PreferenceType.BALANCED;
  energy: EnergyLevel = EnergyLevel.MEDIUM;
}

class UserPreferenceDataForP implements WeatherUserPreference {
  heatSensitivity: 0 | 1 | 2 = 1;
  rainSensitivity: 0 | 1 | 2 = 1;
  weatherRiskTolerance: 0 | 1 | 2 = 1;
}

class CollabOptionsDataForP implements WeatherCollabOptions {
  enableMultiDay?: boolean = true;
  enableMultiCity?: boolean = true;
}

class SchedulePolicyDataForP implements WeatherSchedulePolicy {
  stage: WeatherStageType = 'IN_PROGRESS';
  pollIntervalMs: number = 60_000;
  allowLocationTrigger: boolean = true;
  allowManualBypass: boolean = true;
  forceRefreshOnEnter: boolean = false;
}

class GateResultDataForP {
  success: boolean = true;
  reasonCode?: string = 'ok';
  startFromEventId?: number = 1;
}

class PlanStateMachineMockForP {
  requestSoftReplan(_args: Object): GateResultDataForP {
    return new GateResultDataForP();
  }
}

class HostMockForP implements ITimelineWeatherHost {
  events: EventEntity[] = [];
  planId: number = 1;
  currentStrategyMode: number = 0;
  weatherFeatureEnabled: boolean = true;
  weatherLoading: boolean = false;
  weatherUserPreference: WeatherUserPreference = new UserPreferenceDataForP();
  weatherCollabOptions: WeatherCollabOptions = new CollabOptionsDataForP();
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
  currentWeatherSchedulePolicy: WeatherSchedulePolicy = new SchedulePolicyDataForP();
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
  planStateMachine: PlanStateMachineMockForP = new PlanStateMachineMockForP();

  activeEvent: EventEntity | null = null;

  resolveCurrentWeatherStage(): WeatherStageType { return 'IN_PROGRESS'; }
  async getCurrentStrategy(): Promise<ComposableStrategy> { return new StrategyDataForP(); }
  getCurrentPlanStatus(): PlanStatus { return this.currentPlanStatus; }
  findCurrentActiveEvent(): EventEntity | null { return this.activeEvent; }
  getOrderedScheduleEvents(): EventEntity[] {
    return this.events
      .filter((item: EventEntity) => item.status === 1)
      .sort((a: EventEntity, b: EventEntity) => a.sort_order - b.sort_order);
  }
  getMinEventDurationLimit(): number { return 20; }
  async skipEvent(_item: EventEntity): Promise<void> { return; }
  recalculateFromEventId(_eventId: number): void { return; }
  recalculateFromIndex(_startIndex: number): void { return; }
  markScheduleChanged(): void { return; }
}

class WeatherFacadeMockForP {
  policy: WeatherSchedulePolicy = new SchedulePolicyDataForP();
  executionResult: WeatherContextBuildResult = {} as WeatherContextBuildResult;
  suggestions: WeatherSuggestion[] = [];
  buildExecutionContextCalls: number = 0;
  lastExecutionLocation: GeoPointInput | undefined = undefined;

  resolveSchedulePolicy(_stage: WeatherStageType): WeatherSchedulePolicy {
    return this.policy;
  }

  async buildExecutionContext(
    _events: EventEntity[],
    currentLocation?: GeoPointInput,
    _forceRefresh: boolean = false,
    _preference?: WeatherUserPreference,
    _options?: WeatherCollabOptions,
    _stage?: WeatherStageType
  ): Promise<WeatherContextBuildResult> {
    this.buildExecutionContextCalls += 1;
    this.lastExecutionLocation = currentLocation;
    return this.executionResult;
  }

  buildExecutionAdjustments(
    _planId: number,
    _context: Object,
    _futureNodes: EventEntity[],
    _preference?: WeatherUserPreference
  ): WeatherSuggestion[] {
    return this.suggestions;
  }
}

class ArrivalEngineMockForP {
  private readonly location: GeoPointInput | null;

  constructor(location: GeoPointInput | null) {
    this.location = location;
  }

  getLastKnownLocation(): GeoPointInput | null {
    return this.location;
  }
}

class StaticHooksForP {
  private readonly originArrivalGetInstance: Object;

  constructor() {
    this.originArrivalGetInstance = Reflect.get(ArrivalReminderEngine, 'getInstance') as Object;
  }

  setArrivalGetInstance(fn: () => Object): void {
    Reflect.set(ArrivalReminderEngine, 'getInstance', fn);
  }

  restore(): void {
    Reflect.set(ArrivalReminderEngine, 'getInstance', this.originArrivalGetInstance);
  }
}

class ServiceBundleForP {
  host: HostMockForP = new HostMockForP();
  service: TimelineWeatherService = new TimelineWeatherService(this.host, new WeatherFacade(), new WeatherRefreshScheduler());
  facade: WeatherFacadeMockForP = new WeatherFacadeMockForP();
}

function createBundleForP(): ServiceBundleForP {
  const bundle = new ServiceBundleForP();
  Reflect.set(bundle.service as Object, 'weatherFacade', bundle.facade);
  return bundle;
}

class SnapshotDataForP implements WeatherSnapshot {
  locationKey: string = '';
  sourceType: 'CURRENT_LOCATION' | 'PLAN_LOCATION' = 'PLAN_LOCATION';
  weatherTime: number = 0;
  fetchTime: number = 0;
  conditionCode: string = 'UNKNOWN';
  conditionText: string = '天气未知';
  temperatureCelsius?: number = 0;
}

function createSnapshotForP(text: string, temperature: number): WeatherSnapshot {
  const snapshot = new SnapshotDataForP();
  snapshot.locationKey = 'loc_p';
  snapshot.weatherTime = Date.now();
  snapshot.fetchTime = Date.now();
  snapshot.conditionCode = 'RAIN';
  snapshot.conditionText = text;
  snapshot.temperatureCelsius = temperature;
  return snapshot;
}

function createExecutionResultForP(
  currentWeather?: WeatherSnapshot,
  nextWeather?: WeatherSnapshot,
  collabSummary: string = '',
  cityGroupCount: number = 0
): WeatherContextBuildResult {
  const eventMap = new Map<number, PlanNodeWeatherBinding>();
  const collabContext: WeatherCollabContext = {
    dayWindows: [],
    cityBuckets: [],
    collabSummary: collabSummary,
    dayWindowCount: 0,
    cityGroupCount: cityGroupCount,
    cityCappedCount: 0,
    cityMissCount: 0,
    trendTag: 'RAIN_PERSIST',
    fallbackPath: ''
  };
  return {
    context: {
      stage: 'IN_PROGRESS',
      generatedAt: Date.now(),
      bindings: [],
      routeSuitability: {
        routeScore: 85,
        riskTags: [],
        summaryText: 'stable_p'
      },
      collabContext: collabContext,
      executionRiskScore: 63,
      currentLocationWeather: currentWeather,
      nextNodeWeather: nextWeather
    },
    eventMap: eventMap,
    sourceEvents: []
  };
}

function createSuggestionForP(id: string): WeatherSuggestion {
  return {
    suggestionId: id,
    level: 'WARNING',
    triggerType: 'HEAT',
    actionType: 'PREPARE',
    title: `title_${id}`,
    message: `msg_${id}`,
    relatedNodeIds: [],
    createdAt: Date.now(),
    reason: 'reason_p',
    expectedBenefit: 'benefit_p',
    canRollback: true,
    cooldownKey: `cool_${id}`,
    expiresAt: Date.now() + 60_000
  };
}

function createEventForP(id: number, lat: number, lng: number): EventEntity {
  const item = new EventEntity(`evt_p_${id}`, 1);
  item.id = id;
  item.status = 1;
  item.sort_order = id * 100;
  item.completion_status = EventEntity.STATE_PENDING;
  item.latitude = lat;
  item.longitude = lng;
  return item;
}

export default function phase2CoreCoverageBatchPTest() {
  describe('phase2CoreCoverageBatchPTest', () => {
    it('normal: timeline_weather_refresh_execution_should_set_current_source_and_cross_city_badge', 0, async () => {
      // Arrange
      const bundle = createBundleForP();
      bundle.facade.executionResult = createExecutionResultForP(createSnapshotForP('晴', 30), createSnapshotForP('多云', 27), '跨城联动', 2);
      bundle.facade.suggestions = [createSuggestionForP('s_normal_p')];
      // Act
      await bundle.service.refreshExecutionWeather(false, 'MANUAL', 'IN_PROGRESS');
      // Assert
      expect(bundle.host.executionWeatherDisplaySource).assertEqual('CURRENT');
      expect(bundle.host.executionWeatherCurrentText.indexOf('晴') >= 0).assertTrue();
      expect(bundle.host.executionWeatherCurrentText.indexOf('30') >= 0).assertTrue();
      expect(bundle.host.executionWeatherCollabBadge).assertEqual('跨城协同中');
      expect(bundle.host.executionWeatherSuggestions.length).assertEqual(1);
    });

    it('boundary: timeline_weather_refresh_execution_should_return_early_when_location_trigger_is_disabled', 0, async () => {
      // Arrange
      const bundle = createBundleForP();
      bundle.facade.policy.allowLocationTrigger = false;
      // Act
      await bundle.service.refreshExecutionWeather(false, 'LOCATION_CHANGE', 'IN_PROGRESS');
      // Assert
      expect(bundle.facade.buildExecutionContextCalls).assertEqual(0);
      expect(bundle.host.executionWeatherLastTrigger).assertEqual('');
      expect(bundle.host.executionWeatherLoading).assertFalse();
    });

    it('invalid: timeline_weather_refresh_execution_should_skip_when_location_trigger_is_in_cooldown', 0, async () => {
      // Arrange
      const bundle = createBundleForP();
      bundle.facade.policy.allowLocationTrigger = true;
      bundle.facade.executionResult = createExecutionResultForP();
      bundle.host.executionWeatherLocationTriggerCooldownMs = 60_000;
      bundle.host.executionWeatherLastLocationTriggerAt = Date.now();
      // Act
      await bundle.service.refreshExecutionWeather(false, 'LOCATION_CHANGE', 'IN_PROGRESS');
      // Assert
      expect(bundle.host.executionWeatherLastTrigger).assertEqual('LOCATION_CHANGE');
      expect(bundle.facade.buildExecutionContextCalls).assertEqual(0);
      expect(bundle.host.executionWeatherLoading).assertFalse();
    });

    it('conflict: timeline_weather_apply_execution_suggestion_should_respect_emit_throttle_for_non_manual_trigger', 0, () => {
      // Arrange
      const bundle = createBundleForP();
      const suggestion = createSuggestionForP('s_conflict_p');
      const lastEmitAt = Date.now();
      bundle.host.executionWeatherLastEmitAt = lastEmitAt;
      bundle.host.executionSuggestionCooldownMap.clear();
      // Act
      bundle.service.applyExecutionSuggestion(suggestion, 'TIMER');
      // Assert
      expect(bundle.host.executionWeatherLastEmitAt).assertEqual(lastEmitAt);
      expect(bundle.host.executionSuggestionCooldownMap.has('cool_s_conflict_p')).assertFalse();
      expect(bundle.host.executionWeatherHint).assertEqual('msg_s_conflict_p');
    });

    it('regression: td-20260415-timeline-weather-next-fallback-should-set_display_source_and_hint', 0, async () => {
      // Arrange
      const bundle = createBundleForP();
      bundle.facade.executionResult = createExecutionResultForP(undefined, createSnapshotForP('小雨', 18), '多日协同', 1);
      bundle.facade.suggestions = [];
      // Act
      await bundle.service.refreshExecutionWeather(false, 'MANUAL', 'IN_PROGRESS');
      // Assert
      expect(bundle.host.executionWeatherDisplaySource).assertEqual('NEXT_FALLBACK');
      expect(bundle.host.executionWeatherCurrentText.indexOf('按下一节点天气估算') >= 0).assertTrue();
      expect(bundle.host.executionWeatherCollabBadge).assertEqual('多日趋势已纳入');
      expect(bundle.host.executionWeatherHint).assertEqual('执行天气稳定，按当前节奏继续即可。');
    });

    it('combined: timeline_weather_refresh_execution_should_prefer_arrival_snapshot_location_over_active_and_next_event', 0, async () => {
      // Arrange
      const bundle = createBundleForP();
      const hooks = new StaticHooksForP();
      hooks.setArrivalGetInstance((): Object => new ArrivalEngineMockForP({ latitude: 40.0, longitude: 116.0 }));
      const active = createEventForP(1, 31.2, 121.4);
      const next = createEventForP(2, 31.3, 121.5);
      bundle.host.activeEvent = active;
      bundle.host.events = [active, next];
      bundle.facade.executionResult = createExecutionResultForP(createSnapshotForP('阴', 22));
      // Act
      await bundle.service.refreshExecutionWeather(false, 'MANUAL', 'IN_PROGRESS');
      // Assert
      expect(bundle.facade.lastExecutionLocation !== undefined).assertTrue();
      expect(bundle.facade.lastExecutionLocation!.latitude).assertEqual(40);
      expect(bundle.facade.lastExecutionLocation!.longitude).assertEqual(116);
      expect(bundle.host.executionWeatherLastLocation !== null).assertTrue();
      hooks.restore();
    });
  });
}
