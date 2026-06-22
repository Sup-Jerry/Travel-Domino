import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import {
  ComposableStrategy,
  DensityLevel,
  EnergyLevel,
  PaceLevel,
  PreferenceType
} from '../main/ets/domain/strategy/TravelStrategyDimensions';
import {
  GeoPointInput,
  PlanNodeWeatherBinding,
  ReplanChangeSummaryItem,
  SoftReplanPreview,
  WeatherCollabOptions,
  WeatherSchedulePolicy,
  WeatherSnapshot,
  WeatherStageType,
  WeatherTrendTag,
  WeatherSuggestion,
  WeatherSuggestionTriggerType,
  WeatherUserPreference
} from '../main/ets/domain/services/WeatherModels';
import { ITimelineWeatherHost, TimelineWeatherService } from '../main/ets/domain/timeline/services/TimelineWeatherService';
import { WeatherFacade } from '../main/ets/domain/services/WeatherFacade';
import { WeatherRefreshScheduler } from '../main/ets/domain/services/WeatherRefreshScheduler';
import { PreferenceManager } from '../main/ets/common/utils/PreferenceManager';
import { EventRepositoryImpl } from '../main/ets/infrastructure/persistence/EventRepositoryImpl';
import { PlanRepositoryImpl } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';
import { GeoCoordinate, AmapService } from '../main/ets/infrastructure/services/AmapService';
import { WeatherCollabContext, WeatherContextBuildResult } from '../main/ets/domain/services/WeatherModels';

interface ReplanNodeSnapshotForHM {
  id: number;
  sortOrder: number;
  duration: number;
  startTs: number;
  endTs: number;
}

class StrategyDataForHM implements ComposableStrategy {
  density: DensityLevel = DensityLevel.MEDIUM;
  pace: PaceLevel = PaceLevel.BALANCED;
  preference: PreferenceType = PreferenceType.BALANCED;
  energy: EnergyLevel = EnergyLevel.MEDIUM;
}

class UserPreferenceDataForHM implements WeatherUserPreference {
  heatSensitivity: 0 | 1 | 2 = 1;
  rainSensitivity: 0 | 1 | 2 = 1;
  weatherRiskTolerance: 0 | 1 | 2 = 1;
}

class CollabOptionsDataForHM implements WeatherCollabOptions {
  enableMultiDay?: boolean = true;
  enableMultiCity?: boolean = true;
}

class SchedulePolicyDataForHM implements WeatherSchedulePolicy {
  stage: WeatherStageType = 'IN_PROGRESS';
  pollIntervalMs: number = 60_000;
  allowLocationTrigger: boolean = true;
  allowManualBypass: boolean = true;
  forceRefreshOnEnter: boolean = false;
}

class GateResultDataForHM {
  success: boolean = true;
  reasonCode?: string = 'ok';
  startFromEventId?: number = 0;
}

class PlanStateMachineMockForHM {
  requestSoftReplan(_args: Object): GateResultDataForHM {
    return new GateResultDataForHM();
  }
}

class HostMockForHM implements ITimelineWeatherHost {
  events: EventEntity[] = [];
  planId: number = 1;
  currentStrategyMode: number = 0;
  weatherFeatureEnabled: boolean = true;
  weatherLoading: boolean = false;
  weatherUserPreference: WeatherUserPreference = new UserPreferenceDataForHM();
  weatherCollabOptions: WeatherCollabOptions = new CollabOptionsDataForHM();
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
  currentWeatherSchedulePolicy: WeatherSchedulePolicy = new SchedulePolicyDataForHM();
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
  planStateMachine: PlanStateMachineMockForHM = new PlanStateMachineMockForHM();
  activeEvent: EventEntity | null = null;
  recalcIndexes: number[] = [];

  resolveCurrentWeatherStage(): WeatherStageType { return 'IN_PROGRESS'; }
  async getCurrentStrategy(): Promise<ComposableStrategy> { return new StrategyDataForHM(); }
  getCurrentPlanStatus(): PlanStatus { return this.currentPlanStatus; }
  findCurrentActiveEvent(): EventEntity | null { return this.activeEvent; }
  getOrderedScheduleEvents(): EventEntity[] { return this.events; }
  getMinEventDurationLimit(): number { return 20; }
  async skipEvent(_item: EventEntity): Promise<void> { return; }
  recalculateFromEventId(_eventId: number): void { return; }
  recalculateFromIndex(startIndex: number): void { this.recalcIndexes.push(startIndex); }
  markScheduleChanged(): void { return; }
}

interface TimelineWeatherServicePrivateHM {
  buildExecutionStrategyHint(suggestion: WeatherSuggestion): string | undefined;
  buildExecutionStrategyAdjustment(suggestion: WeatherSuggestion): Object | undefined;
  resolveReplanReasonCode(actionType: string): string;
  findNextPendingEvent(activeEventId: number): EventEntity | null;
  shouldSkipByLocationThreshold(currentLocation: GeoPointInput | null): boolean;
  measureDistanceMeters(lat1: number, lng1: number, lat2: number, lng2: number): number;
  resolveExecutionCurrentLocation(): GeoPointInput | null;
  filterActiveExecutionSuggestions(items: WeatherSuggestion[]): WeatherSuggestion[];
  backfillPlanningCoordinatesByName(scheduleEvents: EventEntity[]): Promise<void>;
}

class ServiceBundleForHM {
  host: HostMockForHM = new HostMockForHM();
  service: TimelineWeatherService = new TimelineWeatherService(this.host, new WeatherFacade(), new WeatherRefreshScheduler());
}

class WeatherCollabContextDataForHM {
  collabSummary: string = '';
  cityGroupCount: number = 0;
  dayWindowCount: number = 0;
  cityCappedCount: number = 0;
  cityMissCount: number = 0;
  trendTag: string = 'STABLE';
  fallbackPath: string = 'none';
}

class ExecutionContextDataForHM {
  stage: WeatherStageType = 'IN_PROGRESS';
  generatedAt: number = 1700000000000;
  currentLocationWeather: WeatherSnapshot | undefined = undefined;
  nextNodeWeather: WeatherSnapshot | undefined = undefined;
  executionRiskScore: number = 82;
  collabContext: WeatherCollabContextDataForHM = new WeatherCollabContextDataForHM();
}

class ExecutionBuildResultDataForHM {
  context: ExecutionContextDataForHM = new ExecutionContextDataForHM();
  eventMap: Map<number, PlanNodeWeatherBinding> = new Map<number, PlanNodeWeatherBinding>();
  sourceEvents: EventEntity[] = [];
}

class WeatherFacadeMockForHM {
  allowLocationTrigger: boolean = true;
  forceRefreshOnEnter: boolean = false;
  buildExecutionContextCalls: number = 0;
  currentLocationWeather: WeatherSnapshot | undefined = undefined;
  nextNodeWeather: WeatherSnapshot | undefined = undefined;

  resolveSchedulePolicy(stage: WeatherStageType): WeatherSchedulePolicy {
    const policy = new SchedulePolicyDataForHM();
    policy.stage = stage;
    policy.allowLocationTrigger = this.allowLocationTrigger;
    policy.forceRefreshOnEnter = this.forceRefreshOnEnter;
    return policy;
  }

  async buildExecutionContext(
    events: EventEntity[],
    _currentLocation?: GeoPointInput,
    _forceRefresh: boolean = false,
    _preference?: WeatherUserPreference,
    _options?: WeatherCollabOptions,
    stage: WeatherStageType = 'IN_PROGRESS'
  ): Promise<Object> {
    this.buildExecutionContextCalls += 1;
    const result = new ExecutionBuildResultDataForHM();
    result.context.stage = stage;
    result.context.currentLocationWeather = this.currentLocationWeather;
    result.context.nextNodeWeather = this.nextNodeWeather;
    result.sourceEvents = events;
    return result as Object;
  }

  buildExecutionAdjustments(): WeatherSuggestion[] {
    return [];
  }
}

class PreferenceManagerMockForHM {
  featureEnabled: boolean = true;
  preference: WeatherUserPreference = new UserPreferenceDataForHM();

  async getWeatherUserPreference(): Promise<WeatherUserPreference> {
    return this.preference;
  }

  async isWeatherFeatureEnabled(): Promise<boolean> {
    return this.featureEnabled;
  }
}

class SchedulerMockForHM {
  callback: (() => void) | undefined = undefined;

  start(_intervalMs: number, callback: () => void): void {
    this.callback = callback;
  }

  stop(): void {
    this.callback = undefined;
  }
}

class StaticHooksForHM {
  private readonly originPreferenceGetInstance: Object;
  private readonly originUpdateFields: Object;
  private readonly originUpdateTimelineConsistency: Object;
  private readonly originUpdateStrategyDimensions: Object;
  private readonly originGetGeocode: Object;

  constructor() {
    this.originPreferenceGetInstance = Reflect.get(PreferenceManager as Object, 'getInstance') as Object;
    this.originUpdateFields = Reflect.get(EventRepositoryImpl as Object, 'updateFields') as Object;
    this.originUpdateTimelineConsistency = Reflect.get(EventRepositoryImpl as Object, 'updateTimelineConsistency') as Object;
    this.originUpdateStrategyDimensions = Reflect.get(PlanRepositoryImpl as Object, 'updateStrategyDimensions') as Object;
    this.originGetGeocode = Reflect.get(AmapService as Object, 'getGeocode') as Object;
  }

  setPreferenceGetInstance(fn: () => PreferenceManagerMockForHM): void {
    Reflect.set(PreferenceManager as Object, 'getInstance', fn);
  }

  setUpdateFields(fn: (id: number, updates: Object[], planIdHint?: number) => Promise<void>): void {
    Reflect.set(EventRepositoryImpl as Object, 'updateFields', fn);
  }

  setUpdateTimelineConsistency(fn: (items: Object[], planIdHint?: number) => Promise<void>): void {
    Reflect.set(EventRepositoryImpl as Object, 'updateTimelineConsistency', fn);
  }

  setUpdateStrategyDimensions(
    fn: (planId: number, density: number, pace: number, preference: number, energy: number) => Promise<void>
  ): void {
    Reflect.set(PlanRepositoryImpl as Object, 'updateStrategyDimensions', fn);
  }

  setGetGeocode(fn: (address: string) => Promise<GeoCoordinate | null>): void {
    Reflect.set(AmapService as Object, 'getGeocode', fn);
  }

  restore(): void {
    Reflect.set(PreferenceManager as Object, 'getInstance', this.originPreferenceGetInstance);
    Reflect.set(EventRepositoryImpl as Object, 'updateFields', this.originUpdateFields);
    Reflect.set(EventRepositoryImpl as Object, 'updateTimelineConsistency', this.originUpdateTimelineConsistency);
    Reflect.set(PlanRepositoryImpl as Object, 'updateStrategyDimensions', this.originUpdateStrategyDimensions);
    Reflect.set(AmapService as Object, 'getGeocode', this.originGetGeocode);
  }
}

function createBundleForHM(): ServiceBundleForHM {
  return new ServiceBundleForHM();
}

function createEventForHM(id: number, lat: number = 0, lng: number = 0): EventEntity {
  const item = new EventEntity(`hm_${id}`, 1);
  item.id = id;
  item.status = 1;
  item.sort_order = id * 100;
  item.completion_status = EventEntity.STATE_PENDING;
  item.latitude = lat;
  item.longitude = lng;
  return item;
}

function createSuggestionForHM(triggerType: WeatherSuggestionTriggerType): WeatherSuggestion {
  return {
    suggestionId: `hm_${triggerType}`,
    level: 'NOTICE',
    triggerType: triggerType,
    actionType: 'PREPARE',
    title: 'title_hm',
    message: 'message_hm',
    relatedNodeIds: [],
    createdAt: Date.now(),
    reason: 'reason_hm',
    expectedBenefit: 'benefit_hm',
    canRollback: true,
    cooldownKey: `cool_hm_${triggerType}`,
    expiresAt: Date.now() + 60_000,
    actionPayload: {}
  };
}

function createWeatherSnapshotForHM(text: string): WeatherSnapshot {
  return {
    locationKey: 'hm_location',
    sourceType: 'PLAN_LOCATION',
    weatherTime: 1700000000000,
    fetchTime: 1700000000000,
    conditionText: text,
    conditionCode: text === 'rain' ? 'RAIN' : 'CLEAR',
    temperatureCelsius: 26
  };
}

function createBindingForHM(event: EventEntity, text: string): PlanNodeWeatherBinding {
  return {
    nodeId: `${event.id}`,
    eventId: event.id,
    nodeName: event.name,
    weather: createWeatherSnapshotForHM(text),
    suitabilityScore: 88,
    riskTags: []
  };
}

function createPreviewForHM(reasonCode: string): SoftReplanPreview {
  return {
    suggestionId: 'preview_hm',
    actionType: 'REORDER',
    changedOrder: false,
    changedDurations: false,
    skippedNodeIds: [],
    affectedNodeIds: [],
    reasonCode: reasonCode,
    startFromEventId: 0,
    changeSummary: [],
    summary: '',
    riskDelta: 0
  };
}

function createWeatherCollabContextForHM(trendTag: WeatherTrendTag = 'RAIN_PERSIST'): WeatherCollabContext {
  return {
    dayWindows: [],
    cityBuckets: [],
    collabSummary: 'hm_collab_summary',
    dayWindowCount: 0,
    cityGroupCount: 0,
    cityCappedCount: 0,
    cityMissCount: 0,
    trendTag: trendTag,
    fallbackPath: 'none'
  };
}

function createPlanningResultForHM(
  event: EventEntity,
  generatedAt: number,
  routeScore: number,
  trendTag: WeatherTrendTag = 'RAIN_PERSIST'
): WeatherContextBuildResult {
  const eventMap = new Map<number, PlanNodeWeatherBinding>();
  eventMap.set(event.id, createBindingForHM(event, 'rain'));
  return {
    context: {
      stage: 'PLANNING',
      generatedAt: generatedAt,
      bindings: [],
      routeSuitability: {
        routeScore: routeScore,
        riskTags: ['RAIN'],
        summaryText: 'hm_planning_summary'
      },
      collabContext: createWeatherCollabContextForHM(trendTag)
    },
    eventMap: eventMap,
    sourceEvents: [event]
  };
}

export default function phase2BatchHMTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchHM_timeline_weather_private_helpers', () => {
    it('normal: execution_strategy_hint_should_match_rain_and_heat_triggers', 0, () => {
      // Arrange
      const bundle = createBundleForHM();
      const service = bundle.service as Object as TimelineWeatherServicePrivateHM;
      // Act
      const rainHint = service.buildExecutionStrategyHint(createSuggestionForHM('RAIN'));
      const heatHint = service.buildExecutionStrategyHint(createSuggestionForHM('HEAT'));
      // Assert
      expect((rainHint ?? '').length > 0).assertTrue();
      expect((heatHint ?? '').length > 0).assertTrue();
      expect(rainHint === heatHint).assertFalse();
    });

    it('boundary: execution_strategy_adjustment_should_return_density_or_pace_energy', 0, () => {
      // Arrange
      const bundle = createBundleForHM();
      const service = bundle.service as Object as TimelineWeatherServicePrivateHM;
      // Act
      const rainAdjustment = service.buildExecutionStrategyAdjustment(createSuggestionForHM('RAIN')) as Object;
      const heatAdjustment = service.buildExecutionStrategyAdjustment(createSuggestionForHM('HEAT')) as Object;
      // Assert
      expect(Reflect.get(rainAdjustment, 'density') as number).assertEqual(-1);
      expect(Reflect.get(heatAdjustment, 'pace') as number).assertEqual(-1);
      expect(Reflect.get(heatAdjustment, 'energy') as number).assertEqual(-1);
    });

    it('invalid: execution_strategy_helpers_should_ignore_unknown_trigger', 0, () => {
      // Arrange
      const bundle = createBundleForHM();
      const service = bundle.service as Object as TimelineWeatherServicePrivateHM;
      // Act
      const hint = service.buildExecutionStrategyHint(createSuggestionForHM('UNKNOWN'));
      const adjustment = service.buildExecutionStrategyAdjustment(createSuggestionForHM('UNKNOWN'));
      // Assert
      expect(hint === undefined).assertTrue();
      expect(adjustment === undefined).assertTrue();
    });

    it('conflict: next_pending_event_should_start_after_active_event_and_skip_done_items', 0, () => {
      // Arrange
      const bundle = createBundleForHM();
      const service = bundle.service as Object as TimelineWeatherServicePrivateHM;
      const active = createEventForHM(1);
      const done = createEventForHM(2);
      const next = createEventForHM(3);
      done.completion_status = EventEntity.STATE_COMPLETED;
      bundle.host.events = [active, done, next];
      // Act
      const found = service.findNextPendingEvent(active.id);
      const missing = service.findNextPendingEvent(999);
      // Assert
      expect(found?.id ?? 0).assertEqual(3);
      expect(missing?.id ?? 0).assertEqual(1);
    });

    it('boundary: next_pending_event_should_return_first_pending_when_active_event_id_is_not_positive', 0, () => {
      // Arrange
      const bundle = createBundleForHM();
      const service = bundle.service as Object as TimelineWeatherServicePrivateHM;
      const done = createEventForHM(4);
      const firstPending = createEventForHM(5);
      const secondPending = createEventForHM(6);
      done.completion_status = EventEntity.STATE_COMPLETED;
      bundle.host.events = [done, firstPending, secondPending];

      // Act
      const found = service.findNextPendingEvent(0);

      // Assert
      expect(found?.id ?? 0).assertEqual(5);
    });

    it('regression: location_threshold_should_only_skip_when_delta_is_below_configured_meters', 0, () => {
      // Arrange
      const bundle = createBundleForHM();
      const service = bundle.service as Object as TimelineWeatherServicePrivateHM;
      bundle.host.executionWeatherLastLocation = { latitude: 31.2304, longitude: 121.4737 };
      bundle.host.executionWeatherLocationDeltaMeters = 1000;
      // Act
      const smallMoveSkipped = service.shouldSkipByLocationThreshold({ latitude: 31.23041, longitude: 121.47371 });
      const largeMoveSkipped = service.shouldSkipByLocationThreshold({ latitude: 32.0, longitude: 122.0 });
      const noCurrentSkipped = service.shouldSkipByLocationThreshold(null);
      // Assert
      expect(smallMoveSkipped).assertTrue();
      expect(largeMoveSkipped).assertFalse();
      expect(noCurrentSkipped).assertFalse();
    });

    it('combined: execution_current_location_should_fallback_from_active_to_next_pending_event', 0, () => {
      // Arrange
      const bundle = createBundleForHM();
      const service = bundle.service as Object as TimelineWeatherServicePrivateHM;
      const active = createEventForHM(10, 0, 0);
      const next = createEventForHM(11, 30.12, 120.56);
      bundle.host.activeEvent = active;
      bundle.host.events = [active, next];
      // Act
      const location = service.resolveExecutionCurrentLocation();
      const distance = service.measureDistanceMeters(31.2304, 121.4737, 31.2305, 121.4738);
      // Assert
      expect((location?.latitude ?? 0) !== 0).assertTrue();
      expect((location?.longitude ?? 0) !== 0).assertTrue();
      expect(distance > 0).assertTrue();
    });

    it('boundary: scheduler_should_trigger_execution_refresh_when_force_enter_in_execution_stage', 0, () => {
      // Arrange
      const bundle = createBundleForHM();
      let executionRefreshCalls = 0;
      bundle.host.currentWeatherSchedulePolicy.forceRefreshOnEnter = true;
      Reflect.set(bundle.service as Object, 'refreshExecutionWeather', async (_force: boolean, trigger: string): Promise<void> => {
        if (trigger === 'ENTER_EXECUTION') {
          executionRefreshCalls += 1;
        }
        return;
      });

      // Act
      bundle.service.startExecutionWeatherScheduler(bundle.host.planId, 'IN_PROGRESS');

      // Assert
      expect(executionRefreshCalls).assertEqual(1);
    });

    it('boundary: scheduler_should_skip_planning_refresh_when_snapshot_is_still_fresh', 0, () => {
      // Arrange
      const bundle = createBundleForHM();
      const facade = new WeatherFacadeMockForHM();
      const scheduler = new SchedulerMockForHM();
      let planningRefreshCalls = 0;
      facade.forceRefreshOnEnter = true;
      bundle.host.currentPlanStatus = PlanStatus.CONFIRMED;
      Reflect.set(bundle.service as Object, 'weatherFacade', facade as Object);
      Reflect.set(bundle.service as Object, 'weatherScheduler', scheduler as Object);
      Reflect.set(bundle.service as Object, 'shouldAutoRefreshPlanningWeather', (): boolean => false);
      Reflect.set(bundle.service as Object, 'refreshPlanningWeather', async (): Promise<void> => {
        planningRefreshCalls += 1;
      });

      // Act
      bundle.service.startExecutionWeatherScheduler(bundle.host.planId, 'CONFIRMED');
      scheduler.callback?.();

      // Assert
      expect(planningRefreshCalls).assertEqual(0);
      expect(bundle.host.executionWeatherEnabled).assertTrue();
    });

    it('normal: replan_summary_should_report_order_duration_and_time_changes', 0, () => {
      // Arrange
      const bundle = createBundleForHM();
      const before = new Map<number, ReplanNodeSnapshotForHM>();
      const after = new Map<number, ReplanNodeSnapshotForHM>();
      const beforeNode: ReplanNodeSnapshotForHM = { id: 21, sortOrder: 100, duration: 60, startTs: 1000, endTs: 4600 };
      const afterNode: ReplanNodeSnapshotForHM = { id: 21, sortOrder: 200, duration: 45, startTs: 7000, endTs: 9700 };
      before.set(21, beforeNode);
      after.set(21, afterNode);

      // Act
      const summary = bundle.service.buildStructuredReplanSummary(
        before as Object as Map<number, never>,
        after as Object as Map<number, never>,
        ['bad', '21']
      );
      const text = bundle.service.composeReplanSummaryText(createPreviewForHM('ok'), summary);

      // Assert
      expect(summary.length).assertEqual(3);
      expect(text.indexOf('顺序变更 1 项') >= 0).assertTrue();
      expect(text.indexOf('时长变更 1 项') >= 0).assertTrue();
      expect(text.indexOf('时间偏移 1 项') >= 0).assertTrue();
    });

    it('boundary: replan_summary_should_fallback_to_no_op_for_empty_changes', 0, () => {
      // Arrange
      const bundle = createBundleForHM();

      // Act
      const summary = bundle.service.buildStructuredReplanSummary(
        new Map<number, never>(),
        new Map<number, never>(),
        ['0', 'nan']
      );
      const stableText = bundle.service.composeReplanSummaryText(createPreviewForHM('ok'), summary);
      const blockedText = bundle.service.composeReplanSummaryText(createPreviewForHM('immutable_blocked'), summary);

      // Assert
      expect(summary.length).assertEqual(1);
      expect(summary[0].type).assertEqual('NO_OP');
      expect(stableText.indexOf('计划保持稳定') >= 0).assertTrue();
      expect(blockedText.indexOf('节点保护') >= 0).assertTrue();
    });

    it('boundary: replan_summary_should_skip_ids_missing_before_or_after_snapshot', 0, () => {
      // Arrange
      const bundle = createBundleForHM();
      const before = new Map<number, ReplanNodeSnapshotForHM>();
      const after = new Map<number, ReplanNodeSnapshotForHM>();
      before.set(91, { id: 91, sortOrder: 100, duration: 60, startTs: 1000, endTs: 4600 });

      // Act
      const summary = bundle.service.buildStructuredReplanSummary(
        before as Object as Map<number, never>,
        after as Object as Map<number, never>,
        ['91']
      );

      // Assert
      expect(summary.length).assertEqual(1);
      expect(summary[0].type).assertEqual('NO_OP');
    });

    it('invalid: soft_replan_public_helpers_should_reject_empty_or_missing_targets', 0, async () => {
      // Arrange
      const bundle = createBundleForHM();
      const service = bundle.service as Object as TimelineWeatherServicePrivateHM;

      // Act
      const reorderEmpty = await bundle.service.applySoftReorder([]);
      const shortenEmpty = await bundle.service.applySoftShorten([]);
      const skipEmpty = await bundle.service.applySoftSkip([]);
      const skipMissing = await bundle.service.applySoftSkip([404]);
      const startId = bundle.service.resolveSoftReplanStartEventId(createPreviewForHM('ok'));
      const reason = service.resolveReplanReasonCode('REPLACE_NODE');

      // Assert
      expect(reorderEmpty).assertFalse();
      expect(shortenEmpty).assertFalse();
      expect(skipEmpty).assertFalse();
      expect(skipMissing).assertFalse();
      expect(startId).assertEqual(0);
      expect(reason).assertEqual('node_replaced');
    });

    it('boundary: soft_shorten_should_use_default_duration_when_suggestion_is_invalid', 0, async () => {
      // Arrange
      const bundle = createBundleForHM();
      const target = createEventForHM(34);
      target.duration = 30;
      bundle.host.events = [target];

      // Act
      const changed = await bundle.service.applySoftShorten([34], 0);

      // Assert
      expect(changed).assertFalse();
      expect(target.duration).assertEqual(30);
    });

    it('normal: soft_reorder_should_rebuild_schedule_when_targets_are_resolved', 0, async () => {
      // Arrange
      const bundle = createBundleForHM();
      const hooks = new StaticHooksForHM();
      let updateCalls = 0;
      const first = createEventForHM(71);
      const second = createEventForHM(72);
      const third = createEventForHM(73);
      first.actual_start_time = 1;
      first.actual_end_time = 0;
      bundle.host.events = [first, second, third];
      hooks.setUpdateTimelineConsistency(async (_items: Object[], _planIdHint?: number): Promise<void> => {
        updateCalls += 1;
      });

      // Act
      const changed = await bundle.service.applySoftReorder(['73', '72']);

      // Assert
      expect(changed).assertTrue();
      expect(updateCalls).assertEqual(1);
      expect(bundle.host.events[1].id).assertEqual(73);
      expect(bundle.host.events[2].id).assertEqual(72);
      hooks.restore();
    });

    it('invalid: soft_reorder_should_return_false_when_part_of_targets_are_missing', 0, async () => {
      // Arrange
      const bundle = createBundleForHM();
      const hooks = new StaticHooksForHM();
      let updateCalls = 0;
      const first = createEventForHM(74);
      const second = createEventForHM(75);
      bundle.host.events = [first, second];
      hooks.setUpdateTimelineConsistency(async (_items: Object[], _planIdHint?: number): Promise<void> => {
        updateCalls += 1;
      });

      // Act
      const changed = await bundle.service.applySoftReorder(['74', '999']);

      // Assert
      expect(changed).assertFalse();
      expect(updateCalls).assertEqual(0);
      hooks.restore();
    });

    it('boundary: soft_reorder_should_keep_scheduled_items_ahead_of_non_schedule_items_after_sort', 0, async () => {
      // Arrange
      const bundle = createBundleForHM();
      const hooks = new StaticHooksForHM();
      const first = createEventForHM(76);
      const second = createEventForHM(77);
      const unscheduled = createEventForHM(78);
      unscheduled.status = 0;
      bundle.host.events = [first, second, unscheduled];
      hooks.setUpdateTimelineConsistency(async (_items: Object[], _planIdHint?: number): Promise<void> => {
        return;
      });

      // Act
      const changed = await bundle.service.applySoftReorder(['77', '76']);

      // Assert
      expect(changed).assertTrue();
      expect(bundle.host.events[0].status).assertEqual(1);
      expect(bundle.host.events[1].status).assertEqual(1);
      expect(bundle.host.events[2].status).assertEqual(0);
      hooks.restore();
    });

    it('conflict: immutable_node_detection_should_block_missing_done_and_locked_nodes', 0, () => {
      // Arrange
      const bundle = createBundleForHM();
      const pending = createEventForHM(31);
      const done = createEventForHM(32);
      const locked = createEventForHM(33);
      done.completion_status = EventEntity.STATE_COMPLETED;
      locked.lock_status = 1;
      locked.fixed_start_time = '09:30';
      bundle.host.events = [pending, done, locked];

      // Act
      const pendingBlocked = bundle.service.containsImmutableNode([31]);
      const missingBlocked = bundle.service.containsImmutableNode([999]);
      const doneBlocked = bundle.service.containsImmutableNode([32]);
      const lockedBlocked = bundle.service.containsImmutableNode([33]);

      // Assert
      expect(pendingBlocked).assertFalse();
      expect(missingBlocked).assertTrue();
      expect(doneBlocked).assertTrue();
      expect(lockedBlocked).assertTrue();
    });

    it('regression: execution_weather_patch_should_update_only_pending_bound_events', 0, () => {
      // Arrange
      const bundle = createBundleForHM();
      const pending = createEventForHM(41);
      const done = createEventForHM(42);
      done.completion_status = EventEntity.STATE_COMPLETED;
      bundle.host.events = [pending, done];
      const eventMap = new Map<number, PlanNodeWeatherBinding>();
      eventMap.set(pending.id, createBindingForHM(pending, 'rain'));
      eventMap.set(done.id, createBindingForHM(done, 'clear'));

      // Act
      bundle.service.patchExecutionWeatherToEvents(eventMap, false);

      // Assert
      expect(pending.weather_condition).assertEqual('RAIN');
      expect(done.weather_condition).assertEqual('');
    });

    it('combined: weather_explanations_should_cover_score_hint_and_auto_refresh_edges', 0, () => {
      // Arrange
      const bundle = createBundleForHM();
      const stale = createEventForHM(51);
      stale.weather_fetch_time = 1;
      const ignored = createEventForHM(52);
      ignored.status = 0;
      ignored.weather_fetch_time = Date.now();
      bundle.host.events = [stale, ignored];
      bundle.host.executionWeatherDisplaySource = 'CURRENT';
      bundle.host.executionWeatherHint = '当前位置有雨';
      bundle.host.weatherCollabSummary = '跨城稳定';
      bundle.host.weatherPlanningHint = '计划天气良好';

      // Act
      const invalidScore = bundle.service.buildWeatherScoreExplanation(-1);
      const highRisk = bundle.service.buildWeatherScoreExplanation(60);
      const hint = bundle.service.buildWeatherHintExplanation();
      const planningHint = bundle.service.buildPlanningWeatherHintExplanation();
      const shouldRefresh = bundle.service.shouldAutoRefreshPlanningWeather(1);

      // Assert
      expect(invalidScore.indexOf('暂无可用') >= 0).assertTrue();
      expect(highRisk.indexOf('高风险') >= 0).assertTrue();
      expect(hint.indexOf(bundle.host.executionWeatherHint) >= 0).assertTrue();
      expect(planningHint.indexOf(bundle.host.weatherPlanningHint) >= 0).assertTrue();
      expect(shouldRefresh).assertTrue();
    });

    it('combined: suggestion_filter_and_reason_code_should_cover_expired_active_sort_and_default_reason', 0, () => {
      // Arrange
      const bundle = createBundleForHM();
      const service = bundle.service as Object as TimelineWeatherServicePrivateHM;
      const warning = createSuggestionForHM('RAIN');
      const info = createSuggestionForHM('HEAT');
      const expired = createSuggestionForHM('UNKNOWN');
      warning.level = 'WARNING';
      warning.createdAt = 2;
      info.level = 'INFO';
      info.createdAt = 1;
      expired.expiresAt = Date.now() - 1;

      // Act
      const filtered = service.filterActiveExecutionSuggestions([info, expired, warning]);
      const reason = service.resolveReplanReasonCode('NONE');

      // Assert
      expect(filtered.length).assertEqual(2);
      expect(filtered[0].level).assertEqual('WARNING');
      expect(reason).assertEqual('soft_replan');
    });

    it('boundary: weather_hint_explanation_should_fallback_to_next_node_and_empty_collab_copy', 0, () => {
      // Arrange
      const bundle = createBundleForHM();
      bundle.host.executionWeatherDisplaySource = 'NEXT_FALLBACK';
      bundle.host.executionWeatherHint = '';
      bundle.host.weatherPlanningHint = '';
      bundle.host.weatherCollabSummary = '';
      bundle.host.executionWeatherCollabSummary = '';

      // Act
      const hint = bundle.service.buildWeatherHintExplanation();

      // Assert
      expect(hint.indexOf('下一节点天气估算') >= 0).assertTrue();
      expect(hint.indexOf('当前暂无额外天气提示') >= 0).assertTrue();
      expect(hint.indexOf('当前无跨日跨城协同摘要') >= 0).assertTrue();
    });

    it('regression: reload_weather_preference_should_clear_runtime_when_feature_disabled', 0, async () => {
      // Arrange
      const bundle = createBundleForHM();
      const hooks = new StaticHooksForHM();
      const prefMock = new PreferenceManagerMockForHM();
      prefMock.featureEnabled = false;
      prefMock.preference = {
        heatSensitivity: 2,
        rainSensitivity: 0,
        weatherRiskTolerance: 2
      };
      bundle.host.weatherPlanningHint = 'planning_hm';
      bundle.host.weatherCollabSummary = 'collab_hm';
      bundle.host.executionWeatherHint = 'execution_hm';
      bundle.host.executionWeatherCurrentText = 'current_hm';
      bundle.host.executionWeatherDisplaySource = 'CURRENT';
      hooks.setPreferenceGetInstance((): PreferenceManagerMockForHM => prefMock);

      // Act
      await bundle.service.reloadWeatherUserPreference();

      // Assert
      expect(bundle.host.weatherFeatureEnabled).assertFalse();
      expect(bundle.host.weatherUserPreference.heatSensitivity).assertEqual(2);
      expect(bundle.host.weatherPlanningHint).assertEqual('');
      expect(bundle.host.executionWeatherHint).assertEqual('');
      expect(bundle.host.executionWeatherCurrentText).assertEqual('');
      expect(bundle.host.executionWeatherDisplaySource).assertEqual('UNKNOWN');
      hooks.restore();
    });

    it('boundary: reload_weather_preference_should_keep_runtime_when_feature_remains_enabled', 0, async () => {
      // Arrange
      const bundle = createBundleForHM();
      const hooks = new StaticHooksForHM();
      const prefMock = new PreferenceManagerMockForHM();
      prefMock.featureEnabled = true;
      prefMock.preference = {
        heatSensitivity: 0,
        rainSensitivity: 2,
        weatherRiskTolerance: 1
      };
      bundle.host.weatherPlanningHint = 'planning_keep_hm';
      bundle.host.executionWeatherHint = 'execution_keep_hm';
      hooks.setPreferenceGetInstance((): PreferenceManagerMockForHM => prefMock);

      // Act
      await bundle.service.reloadWeatherUserPreference();

      // Assert
      expect(bundle.host.weatherFeatureEnabled).assertTrue();
      expect(bundle.host.weatherUserPreference.rainSensitivity).assertEqual(2);
      expect(bundle.host.weatherPlanningHint).assertEqual('planning_keep_hm');
      expect(bundle.host.executionWeatherHint).assertEqual('execution_keep_hm');
      hooks.restore();
    });

    it('combined: refresh_execution_weather_should_cover_current_next_fallback_and_location_cooldown', 0, async () => {
      // Arrange
      const bundle = createBundleForHM();
      const facade = new WeatherFacadeMockForHM();
      const active = createEventForHM(61, 31.2304, 121.4737);
      const next = createEventForHM(62, 31.2404, 121.4837);
      bundle.host.activeEvent = active;
      bundle.host.events = [active, next];
      bundle.host.currentPlanStatus = PlanStatus.IN_PROGRESS;
      bundle.host.executionWeatherEnabled = true;
      bundle.host.executionWeatherLocationTriggerCooldownMs = 60_000;
      Reflect.set(bundle.service as Object, 'weatherFacade', facade as Object);

      facade.currentLocationWeather = createWeatherSnapshotForHM('sunny');
      facade.nextNodeWeather = createWeatherSnapshotForHM('rain');

      // Act
      await bundle.service.refreshExecutionWeather(false, 'MANUAL', 'IN_PROGRESS');
      const currentText = bundle.host.executionWeatherCurrentText;
      const nextText = bundle.host.executionWeatherNextText;

      facade.currentLocationWeather = undefined;
      await bundle.service.refreshExecutionWeather(false, 'MANUAL', 'IN_PROGRESS');
      const fallbackText = bundle.host.executionWeatherCurrentText;

      bundle.host.executionWeatherLastLocationTriggerAt = Date.now();
      await bundle.service.refreshExecutionWeather(false, 'LOCATION_CHANGE', 'IN_PROGRESS');

      // Assert
      expect(bundle.host.executionWeatherDisplaySource).assertEqual('NEXT_FALLBACK');
      expect(currentText.indexOf('sunny') >= 0).assertTrue();
      expect(nextText.indexOf('rain') >= 0).assertTrue();
      expect(fallbackText.indexOf('按下一节点天气估算') >= 0).assertTrue();
      expect(facade.buildExecutionContextCalls).assertEqual(2);
    });

    it('boundary: refresh_execution_weather_should_allow_location_trigger_after_cooldown_and_hide_nan_temperature', 0, async () => {
      // Arrange
      const bundle = createBundleForHM();
      const facade = new WeatherFacadeMockForHM();
      const active = createEventForHM(63, 31.2304, 121.4737);
      const next = createEventForHM(64, 31.2404, 121.4837);
      bundle.host.activeEvent = active;
      bundle.host.events = [active, next];
      bundle.host.currentPlanStatus = PlanStatus.IN_PROGRESS;
      bundle.host.executionWeatherEnabled = true;
      bundle.host.executionWeatherLocationTriggerCooldownMs = 60_000;
      bundle.host.executionWeatherLastLocationTriggerAt = Date.now() - 120_000;
      Reflect.set(bundle.service as Object, 'weatherFacade', facade as Object);
      facade.currentLocationWeather = createWeatherSnapshotForHM('cloudy');
      facade.currentLocationWeather.temperatureCelsius = Number.NaN;
      facade.nextNodeWeather = createWeatherSnapshotForHM('windy');
      facade.nextNodeWeather.temperatureCelsius = Number.NaN;

      // Act
      await bundle.service.refreshExecutionWeather(false, 'LOCATION_CHANGE', 'IN_PROGRESS');
      const currentText = bundle.host.executionWeatherCurrentText;
      const nextText = bundle.host.executionWeatherNextText;
      facade.currentLocationWeather = undefined;
      await bundle.service.refreshExecutionWeather(false, 'MANUAL', 'IN_PROGRESS');
      const fallbackText = bundle.host.executionWeatherCurrentText;

      // Assert
      expect(facade.buildExecutionContextCalls).assertEqual(2);
      expect(currentText.indexOf('cloudy') >= 0).assertTrue();
      expect(currentText.indexOf('°C') >= 0).assertFalse();
      expect(nextText.indexOf('windy') >= 0).assertTrue();
      expect(nextText.indexOf('°C') >= 0).assertFalse();
      expect(fallbackText.indexOf('windy') >= 0).assertTrue();
      expect(fallbackText.indexOf('°C') >= 0).assertFalse();
      expect(bundle.host.executionWeatherLastLocationTriggerAt > 0).assertTrue();
    });

    it('regression: patch_execution_weather_should_persist_when_force_refresh_and_event_id_positive', 0, async () => {
      // Arrange
      const bundle = createBundleForHM();
      const hooks = new StaticHooksForHM();
      const pending = createEventForHM(81);
      const eventMap = new Map<number, PlanNodeWeatherBinding>();
      let updateCalls = 0;
      eventMap.set(pending.id, createBindingForHM(pending, 'rain'));
      bundle.host.events = [pending];
      hooks.setUpdateFields(async (_id: number, _updates: Object[], _planIdHint?: number): Promise<void> => {
        updateCalls += 1;
      });

      // Act
      bundle.service.patchExecutionWeatherToEvents(eventMap, true);
      await Promise.resolve();

      // Assert
      expect(updateCalls).assertEqual(1);
      expect(pending.weather_condition).assertEqual('RAIN');
      hooks.restore();
    });

    it('boundary: planning_apply_should_skip_event_persist_and_strategy_write_when_key_already_applied', 0, async () => {
      // Arrange
      const bundle = createBundleForHM();
      const hooks = new StaticHooksForHM();
      const pending = createEventForHM(0);
      let eventUpdateCalls = 0;
      let strategyUpdateCalls = 0;
      const generatedAt = 1700001234567;
      const routeScore = 50;
      bundle.host.events = [pending];
      Reflect.set(bundle.service as Object, 'weatherStrategyAppliedKey', `${generatedAt}_${routeScore}`);
      hooks.setUpdateFields(async (): Promise<void> => {
        eventUpdateCalls += 1;
      });
      hooks.setUpdateStrategyDimensions(async (): Promise<void> => {
        strategyUpdateCalls += 1;
      });

      // Act
      await bundle.service.applyPlanningWeatherResult(createPlanningResultForHM(pending, generatedAt, routeScore), true);

      // Assert
      expect(eventUpdateCalls).assertEqual(0);
      expect(strategyUpdateCalls).assertEqual(0);
      expect(bundle.host.weatherStrategyHint.length > 0).assertTrue();
      hooks.restore();
    });

    it('boundary: planning_apply_should_clear_strategy_hint_when_weather_decision_causes_no_effective_change', 0, async () => {
      // Arrange
      const bundle = createBundleForHM();
      const hooks = new StaticHooksForHM();
      const pending = createEventForHM(0);
      let strategyUpdateCalls = 0;
      bundle.host.events = [pending];
      bundle.host.weatherStrategyHint = 'stale_hint_hm';
      Reflect.set(bundle.host as Object, 'getCurrentStrategy', async (): Promise<ComposableStrategy> => {
        const strategy = new StrategyDataForHM();
        strategy.density = DensityLevel.LOW;
        return strategy;
      });
      hooks.setUpdateStrategyDimensions(async (): Promise<void> => {
        strategyUpdateCalls += 1;
      });

      // Act
      await bundle.service.applyPlanningWeatherResult(createPlanningResultForHM(pending, 1700001234999, 50), true);

      // Assert
      expect(strategyUpdateCalls).assertEqual(0);
      expect(bundle.host.currentStrategyMode).assertEqual(0);
      expect(bundle.host.weatherStrategyHint).assertEqual('');
      hooks.restore();
    });

    it('boundary: planning_backfill_should_update_memory_without_persist_when_event_id_is_not_positive', 0, async () => {
      // Arrange
      const bundle = createBundleForHM();
      const hooks = new StaticHooksForHM();
      const pending = createEventForHM(0, 0, 0);
      pending.name = '西湖';
      let updateCalls = 0;
      hooks.setGetGeocode(async (_address: string): Promise<GeoCoordinate | null> => new GeoCoordinate(30.25, 120.16));
      hooks.setUpdateFields(async (): Promise<void> => {
        updateCalls += 1;
      });

      // Act
      await (bundle.service as Object as TimelineWeatherServicePrivateHM).backfillPlanningCoordinatesByName([pending]);

      // Assert
      expect(pending.latitude).assertEqual(30.25);
      expect(pending.longitude).assertEqual(120.16);
      expect(updateCalls).assertEqual(0);
      hooks.restore();
    });

    it('boundary: suggestion_filter_should_drop_null_items_before_sorting', 0, () => {
      // Arrange
      const bundle = createBundleForHM();
      const service = bundle.service as Object as TimelineWeatherServicePrivateHM;
      const warning = createSuggestionForHM('RAIN');
      warning.level = 'WARNING';
      const info = createSuggestionForHM('HEAT');
      info.level = 'INFO';
      const input: WeatherSuggestion[] = [warning, info];
      Reflect.set(input as Object, '0', null);

      // Act
      const filtered = service.filterActiveExecutionSuggestions(input);

      // Assert
      expect(filtered.length).assertEqual(1);
      expect(filtered[0].level).assertEqual('INFO');
    });

    it('boundary: soft_replan_future_candidates_should_fallback_to_head_when_active_id_is_nan', 0, () => {
      // Arrange
      const bundle = createBundleForHM();
      const active = createEventForHM(Number.NaN);
      const second = createEventForHM(92);
      const third = createEventForHM(93);
      const fourth = createEventForHM(94);
      active.actual_start_time = 1;
      bundle.host.events = [active, second, third, fourth];

      // Act
      const candidates = bundle.service.getSoftReplanFutureCandidates();

      // Assert
      expect(candidates.length).assertEqual(3);
      expect(Number.isNaN(candidates[0].id)).assertTrue();
      expect(candidates[1].id).assertEqual(92);
      expect(candidates[2].id).assertEqual(93);
    });

    it('invalid: soft_reorder_should_fail_when_resolved_targets_cannot_all_map_back_to_schedule', 0, async () => {
      // Arrange
      const bundle = createBundleForHM();
      const hooks = new StaticHooksForHM();
      let updateCalls = 0;
      const scheduled = createEventForHM(74);
      bundle.host.events = [scheduled];
      Reflect.set(bundle.host as Object, 'getOrderedScheduleEvents', (): EventEntity[] => {
        const first = createEventForHM(74);
        const second = createEventForHM(999);
        return [first, second];
      });
      hooks.setUpdateTimelineConsistency(async (): Promise<void> => {
        updateCalls += 1;
      });

      // Act
      const changed = await bundle.service.applySoftReorder(['74', '999']);

      // Assert
      expect(changed).assertFalse();
      expect(updateCalls).assertEqual(0);
      hooks.restore();
    });

    it('boundary: soft_reorder_should_keep_original_item_when_duplicate_target_consumes_reordered_pool', 0, async () => {
      // Arrange
      const bundle = createBundleForHM();
      const hooks = new StaticHooksForHM();
      let updateCalls = 0;
      const first = createEventForHM(80);
      const duplicate = createEventForHM(80);
      duplicate.sort_order = 100;
      const last = createEventForHM(81);
      last.sort_order = 200;
      bundle.host.events = [first, duplicate, last];
      hooks.setUpdateTimelineConsistency(async (): Promise<void> => {
        updateCalls += 1;
      });

      // Act
      const changed = await bundle.service.applySoftReorder(['80', '81']);

      // Assert
      expect(changed).assertTrue();
      expect(updateCalls).assertEqual(1);
      expect(bundle.host.events.length).assertEqual(3);
      hooks.restore();
    });
  });
}
