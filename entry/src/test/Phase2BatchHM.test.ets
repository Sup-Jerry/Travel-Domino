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
  WeatherSuggestion,
  WeatherSuggestionTriggerType,
  WeatherUserPreference
} from '../main/ets/domain/services/WeatherModels';
import { ITimelineWeatherHost, TimelineWeatherService } from '../main/ets/domain/timeline/services/TimelineWeatherService';
import { WeatherFacade } from '../main/ets/domain/services/WeatherFacade';
import { WeatherRefreshScheduler } from '../main/ets/domain/services/WeatherRefreshScheduler';

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
}

class ServiceBundleForHM {
  host: HostMockForHM = new HostMockForHM();
  service: TimelineWeatherService = new TimelineWeatherService(this.host, new WeatherFacade(), new WeatherRefreshScheduler());
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
  });
}
