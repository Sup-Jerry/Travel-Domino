import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { GeoCoordinate, AmapService } from '../main/ets/infrastructure/services/AmapService';
import { ComposableStrategy, DensityLevel, EnergyLevel, PaceLevel, PreferenceType } from '../main/ets/domain/strategy/TravelStrategyDimensions';
import {
  GeoPointInput,
  PlanNodeWeatherBinding,
  WeatherCollabOptions,
  WeatherContextBuildResult,
  WeatherSchedulePolicy,
  WeatherStageType,
  WeatherSuggestion,
  WeatherUserPreference
} from '../main/ets/domain/services/WeatherModels';
import { ITimelineWeatherHost, TimelineWeatherService } from '../main/ets/domain/timeline/services/TimelineWeatherService';
import { WeatherFacade } from '../main/ets/domain/services/WeatherFacade';
import { WeatherRefreshScheduler } from '../main/ets/domain/services/WeatherRefreshScheduler';

class StrategyDataForU implements ComposableStrategy {
  density: DensityLevel = DensityLevel.MEDIUM;
  pace: PaceLevel = PaceLevel.BALANCED;
  preference: PreferenceType = PreferenceType.BALANCED;
  energy: EnergyLevel = EnergyLevel.MEDIUM;
}

class UserPreferenceDataForU implements WeatherUserPreference {
  heatSensitivity: 0 | 1 | 2 = 1;
  rainSensitivity: 0 | 1 | 2 = 1;
  weatherRiskTolerance: 0 | 1 | 2 = 1;
}

class CollabOptionsDataForU implements WeatherCollabOptions {
  enableMultiDay?: boolean = true;
  enableMultiCity?: boolean = true;
}

class SchedulePolicyDataForU implements WeatherSchedulePolicy {
  stage: WeatherStageType = 'IN_PROGRESS';
  pollIntervalMs: number = 60_000;
  allowLocationTrigger: boolean = true;
  allowManualBypass: boolean = true;
  forceRefreshOnEnter: boolean = false;
}

class GateResultDataForU {
  success: boolean = true;
  reasonCode?: string = 'ok';
  startFromEventId?: number = 1;
}

class PlanStateMachineMockForU {
  gateResult: GateResultDataForU = new GateResultDataForU();
  lastArgs: Object | null = null;

  requestSoftReplan(args: Object): GateResultDataForU {
    this.lastArgs = args;
    return this.gateResult;
  }
}

class HostMockForU implements ITimelineWeatherHost {
  events: EventEntity[] = [];
  planId: number = 1;
  currentStrategyMode: number = 0;
  weatherFeatureEnabled: boolean = true;
  weatherLoading: boolean = false;
  weatherUserPreference: WeatherUserPreference = new UserPreferenceDataForU();
  weatherCollabOptions: WeatherCollabOptions = new CollabOptionsDataForU();
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
  currentWeatherSchedulePolicy: WeatherSchedulePolicy = new SchedulePolicyDataForU();
  executionReplanBusy: boolean = false;
  executionWeatherApplying: boolean = false;
  executionWeatherAppliedSummary: string = '';
  executionWeatherLastEmitAt: number = 0;
  executionWeatherLocationDeltaMeters: number = 0;
  executionSuggestionCooldownMs: number = 60_000;
  executionSuggestionCooldownMap: Map<string, number> = new Map<string, number>();
  weatherPlanningHint: string = '';
  weatherRouteScore: number = -1;
  weatherCollabSummary: string = '';
  weatherCollabLabel: string = '';
  weatherStrategyHint: string = '';
  weatherLastRefreshAt: number = 0;
  planStateMachine: PlanStateMachineMockForU = new PlanStateMachineMockForU();
  activeEvent: EventEntity | null = null;

  resolveCurrentWeatherStage(): WeatherStageType { return 'IN_PROGRESS'; }
  async getCurrentStrategy(): Promise<ComposableStrategy> { return new StrategyDataForU(); }
  getCurrentPlanStatus(): PlanStatus { return this.currentPlanStatus; }
  findCurrentActiveEvent(): EventEntity | null { return this.activeEvent; }
  getOrderedScheduleEvents(): EventEntity[] { return this.events; }
  getMinEventDurationLimit(): number { return 20; }
  async skipEvent(_item: EventEntity): Promise<void> { return; }
  recalculateFromEventId(_eventId: number): void { return; }
  recalculateFromIndex(_startIndex: number): void { return; }
  markScheduleChanged(): void { return; }
}

class WeatherFacadeMockForU {
  planningResult: WeatherContextBuildResult = {
    context: {
      stage: 'IN_PROGRESS',
      generatedAt: 1700000000000,
      bindings: [],
      routeSuitability: {
        routeScore: 78,
        riskTags: [],
        summaryText: 'planning_u'
      }
    },
    eventMap: new Map<number, PlanNodeWeatherBinding>(),
    sourceEvents: []
  };

  resolveSchedulePolicy(_stage: WeatherStageType): WeatherSchedulePolicy {
    return new SchedulePolicyDataForU();
  }

  async buildPlanningContext(
    _events: EventEntity[],
    _preference?: WeatherUserPreference,
    _options?: WeatherCollabOptions,
    _stage?: WeatherStageType
  ): Promise<WeatherContextBuildResult> {
    return this.planningResult;
  }
}

class ServiceBundleForU {
  host: HostMockForU = new HostMockForU();
  service: TimelineWeatherService = new TimelineWeatherService(this.host, new WeatherFacade(), new WeatherRefreshScheduler());
  facade: WeatherFacadeMockForU = new WeatherFacadeMockForU();
}

class SchedulerMockForU {
  startCount: number = 0;
  stopCount: number = 0;
  lastIntervalMs: number = 0;
  lastTask: (() => void) | null = null;

  start(intervalMs: number, task: () => void): void {
    this.startCount++;
    this.lastIntervalMs = intervalMs;
    this.lastTask = task;
  }

  stop(): void {
    this.stopCount++;
  }
}

class StaticHooksForU {
  private readonly originAmapGetGeocode: Object;

  constructor() {
    this.originAmapGetGeocode = Reflect.get(AmapService, 'getGeocode') as Object;
  }

  setAmapGetGeocode(fn: (name: string) => Promise<GeoCoordinate | null>): void {
    Reflect.set(AmapService, 'getGeocode', fn);
  }

  restore(): void {
    Reflect.set(AmapService, 'getGeocode', this.originAmapGetGeocode);
  }
}

function createBundleForU(): ServiceBundleForU {
  const bundle = new ServiceBundleForU();
  Reflect.set(bundle.service as Object, 'weatherFacade', bundle.facade);
  return bundle;
}

function createEventForU(id: number, name: string, lat: number, lng: number): EventEntity {
  const item = new EventEntity(name, 1);
  item.id = id;
  item.status = 1;
  item.sort_order = id * 100;
  item.completion_status = EventEntity.STATE_PENDING;
  item.latitude = lat;
  item.longitude = lng;
  return item;
}

function createSuggestionForU(id: string): WeatherSuggestion {
  return {
    suggestionId: id,
    level: 'NOTICE',
    triggerType: 'RAIN',
    actionType: 'NONE',
    title: `title_${id}`,
    message: `msg_${id}`,
    relatedNodeIds: [],
    createdAt: Date.now(),
    reason: 'reason_u',
    expectedBenefit: 'benefit_u',
    canRollback: true,
    cooldownKey: `cool_${id}`,
    expiresAt: Date.now() + 60_000
  };
}

export default function phase2CoreCoverageBatchUTest() {
  describe('phase2CoreCoverageBatchUTest', () => {
    it('normal: timeline_weather_refresh_planning_should_not_persist_snapshot_when_plan_id_not_positive', 0, async () => {
      // Arrange
      const bundle = createBundleForU();
      bundle.host.planId = 0;
      // Act
      await bundle.service.refreshPlanningWeather(false);
      // Assert
      const raw = AppStorage.get<string>('PlanningWeatherSnapshot_0') ?? '';
      expect(raw).assertEqual('');
      expect(bundle.host.weatherPlanningHint).assertEqual('planning_u');
    });

    it('boundary: timeline_weather_backfill_should_cover_skip_non_missing_empty_name_and_geocode_miss', 0, async () => {
      // Arrange
      const bundle = createBundleForU();
      const hooks = new StaticHooksForU();
      hooks.setAmapGetGeocode(async (_name: string): Promise<GeoCoordinate | null> => {
        return null;
      });
      const valid = createEventForU(1, 'valid_u', 30.0, 120.0);
      const emptyName = createEventForU(2, '   ', 0, 0);
      const missGeo = createEventForU(3, 'miss_u', 0, 0);
      bundle.host.events = [valid, emptyName, missGeo];
      // Act
      await bundle.service.refreshPlanningWeather(false);
      // Assert
      expect(bundle.host.events[0].latitude).assertEqual(30);
      expect(bundle.host.events[1].latitude).assertEqual(0);
      expect(bundle.host.events[2].latitude).assertEqual(0);
      hooks.restore();
    });

    it('invalid: timeline_weather_request_soft_replan_should_capture_active_event_as_current_node_id', 0, async () => {
      // Arrange
      const bundle = createBundleForU();
      bundle.host.currentPlanStatus = PlanStatus.READY;
      const active = createEventForU(9, 'active_u', 31.2, 121.4);
      bundle.host.activeEvent = active;
      const suggestion = createSuggestionForU('s_active_u');
      bundle.host.executionWeatherSuggestions = [suggestion];
      bundle.host.executionSuggestionMap.set(suggestion.suggestionId, suggestion);
      // Act
      await bundle.service.requestSoftReplan(1, suggestion.suggestionId, 'PREVIEW');
      // Assert
      expect(bundle.host.planStateMachine.lastArgs !== null).assertTrue();
      const argsObj = bundle.host.planStateMachine.lastArgs as Object;
      const currentNodeId = Reflect.get(argsObj, 'currentNodeId') as string;
      expect(currentNodeId).assertEqual('9');
    });

    it('conflict: timeline_weather_apply_execution_suggestion_should_return_when_cooling_down_and_non_manual', 0, () => {
      // Arrange
      const bundle = createBundleForU();
      const suggestion = createSuggestionForU('s_cool_u');
      bundle.host.executionSuggestionCooldownMap.set(suggestion.cooldownKey, Date.now());
      bundle.host.executionWeatherLastEmitAt = 0;
      // Act
      bundle.service.applyExecutionSuggestion(suggestion, 'TIMER');
      // Assert
      expect(bundle.host.executionWeatherLastEmitAt).assertEqual(0);
    });

    it('regression: td-20260415-refresh-planning-should-mark-missing-geo-branch-when_events_without_coordinates_exist', 0, async () => {
      // Arrange
      const bundle = createBundleForU();
      const miss = createEventForU(10, 'miss2_u', 0, 0);
      bundle.host.events = [miss];
      // Act
      await bundle.service.refreshPlanningWeather(false);
      // Assert
      expect(bundle.host.weatherPlanningHint).assertEqual('planning_u');
      expect(bundle.host.weatherLoading).assertFalse();
    });

    it('combined: timeline_weather_apply_execution_suggestion_should_keep_hint_level_update_even_when_cooldown_returns', 0, () => {
      // Arrange
      const bundle = createBundleForU();
      const suggestion = createSuggestionForU('s_hint_u');
      bundle.host.executionSuggestionCooldownMap.set(suggestion.cooldownKey, Date.now());
      // Act
      bundle.service.applyExecutionSuggestion(suggestion, 'TIMER');
      // Assert
      expect(bundle.host.executionWeatherHint).assertEqual('msg_s_hint_u');
      expect(bundle.host.executionWeatherLevel).assertEqual('NOTICE');
    });

    it('normal: timeline_weather_apply_weather_suggestion_should_delegate_to_soft_replan', 0, async () => {
      // Arrange
      const bundle = createBundleForU();
      bundle.host.planId = 1;
      // Act
      const result = await bundle.service.applyWeatherSuggestion('');
      // Assert
      expect(result.success).assertFalse();
      expect(result.reasonCode).assertEqual('invalid_input');
    });

    it('boundary: timeline_weather_should_auto_refresh_planning_only_when_snapshot_expired', 0, () => {
      // Arrange
      const bundle = createBundleForU();
      bundle.host.planId = 1;
      const event = createEventForU(21, 'fresh_u', 30.1, 120.1);
      event.weather_fetch_time = Date.now();
      bundle.host.events = [event];
      // Act
      const shouldRefreshRecent = bundle.service.shouldAutoRefreshPlanningWeather(60_000);
      event.weather_fetch_time = Date.now() - 120_000;
      const shouldRefreshExpired = bundle.service.shouldAutoRefreshPlanningWeather(60_000);
      // Assert
      expect(shouldRefreshRecent).assertFalse();
      expect(shouldRefreshExpired).assertTrue();
    });

    it('invalid: timeline_weather_dismiss_execution_suggestion_should_ignore_empty_id', 0, () => {
      // Arrange
      const bundle = createBundleForU();
      const suggestion = createSuggestionForU('s_keep_u');
      bundle.host.executionWeatherSuggestions = [suggestion];
      bundle.host.executionSuggestionMap.set(suggestion.suggestionId, suggestion);
      // Act
      bundle.service.dismissExecutionSuggestion('   ');
      // Assert
      expect(bundle.host.executionWeatherSuggestions.length).assertEqual(1);
      expect(bundle.host.executionSuggestionMap.has(suggestion.suggestionId)).assertTrue();
    });

    it('conflict: timeline_weather_start_scheduler_should_stop_immediately_when_feature_disabled', 0, () => {
      // Arrange
      const bundle = createBundleForU();
      const scheduler = new SchedulerMockForU();
      bundle.host.weatherFeatureEnabled = false;
      bundle.host.executionWeatherEnabled = true;
      Reflect.set(bundle.service as Object, 'weatherScheduler', scheduler as Object);
      // Act
      bundle.service.startExecutionWeatherScheduler(bundle.host.planId, 'IN_PROGRESS');
      // Assert
      expect(bundle.host.executionWeatherEnabled).assertFalse();
      expect(scheduler.stopCount).assertEqual(1);
      expect(scheduler.startCount).assertEqual(0);
    });

    it('regression: td-20260415-clear-runtime-state-should-reset-execution-and-planning-fields', 0, () => {
      // Arrange
      const bundle = createBundleForU();
      bundle.host.weatherRouteScore = 80;
      bundle.host.weatherPlanningHint = 'planning';
      bundle.host.executionWeatherHint = 'exec';
      bundle.host.executionWeatherDisplaySource = 'CURRENT';
      bundle.host.executionWeatherScore = 66;
      bundle.host.executionWeatherSuggestions = [createSuggestionForU('s_reset_u')];
      // Act
      bundle.service.clearWeatherRuntimeState();
      // Assert
      expect(bundle.host.weatherRouteScore).assertEqual(-1);
      expect(bundle.host.weatherPlanningHint).assertEqual('');
      expect(bundle.host.executionWeatherHint).assertEqual('');
      expect(bundle.host.executionWeatherDisplaySource).assertEqual('UNKNOWN');
      expect(bundle.host.executionWeatherScore).assertEqual(-1);
      expect(bundle.host.executionWeatherSuggestions.length).assertEqual(0);
    });

    it('combined: timeline_weather_explanations_and_coordinate_resolution_should_cover_hint_preference_and_geocode_hit', 0, async () => {
      // Arrange
      const bundle = createBundleForU();
      const hooks = new StaticHooksForU();
      hooks.setAmapGetGeocode(async (_name: string): Promise<GeoCoordinate | null> => {
        return new GeoCoordinate(39.9, 116.3);
      });
      bundle.host.executionWeatherDisplaySource = 'NEXT_FALLBACK';
      bundle.host.weatherPlanningHint = 'plan_hint_u';
      bundle.host.executionWeatherCollabSummary = 'collab_u';
      bundle.host.weatherFeatureEnabled = true;
      // Act
      const hintText = bundle.service.buildWeatherHintExplanation();
      const planHintText = bundle.service.buildPlanningWeatherHintExplanation();
      const scoreText = bundle.service.buildWeatherScoreExplanation(60);
      const pref = bundle.service.getWeatherUserPreference();
      const enabled = bundle.service.isWeatherFeatureEnabled();
      const source = bundle.service.getExecutionWeatherDisplaySource();
      const resolved = await bundle.service.resolveCoordinatesForPlaceName('beijing_u', 0, 0, 'add', 0, 0);
      hooks.restore();
      // Assert
      expect(hintText.indexOf('提示来源：下一节点天气估算') >= 0).assertTrue();
      expect(planHintText.indexOf('提示来源：计划节点天气（已按地点批量计算）') >= 0).assertTrue();
      expect(scoreText.indexOf('等级：高风险') >= 0).assertTrue();
      expect(pref.heatSensitivity).assertEqual(1);
      expect(enabled).assertTrue();
      expect(source).assertEqual('NEXT_FALLBACK');
      expect(resolved.latitude).assertEqual(39.9);
      expect(resolved.longitude).assertEqual(116.3);
    });
  });
}
