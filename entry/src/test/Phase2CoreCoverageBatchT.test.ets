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

class StrategyDataForT implements ComposableStrategy {
  density: DensityLevel = DensityLevel.MEDIUM;
  pace: PaceLevel = PaceLevel.BALANCED;
  preference: PreferenceType = PreferenceType.BALANCED;
  energy: EnergyLevel = EnergyLevel.MEDIUM;
}

class UserPreferenceDataForT implements WeatherUserPreference {
  heatSensitivity: 0 | 1 | 2 = 1;
  rainSensitivity: 0 | 1 | 2 = 1;
  weatherRiskTolerance: 0 | 1 | 2 = 1;
}

class CollabOptionsDataForT implements WeatherCollabOptions {
  enableMultiDay?: boolean = true;
  enableMultiCity?: boolean = true;
}

class SchedulePolicyDataForT implements WeatherSchedulePolicy {
  stage: WeatherStageType = 'IN_PROGRESS';
  pollIntervalMs: number = 60_000;
  allowLocationTrigger: boolean = true;
  allowManualBypass: boolean = true;
  forceRefreshOnEnter: boolean = false;
}

class GateResultDataForT {
  success: boolean = true;
  reasonCode?: string = 'ok';
  startFromEventId?: number = 1;
}

class PlanStateMachineMockForT {
  gateResult: GateResultDataForT = new GateResultDataForT();

  requestSoftReplan(_args: Object): GateResultDataForT {
    return this.gateResult;
  }
}

class HostMockForT implements ITimelineWeatherHost {
  events: EventEntity[] = [];
  planId: number = 1;
  currentStrategyMode: number = 0;
  weatherFeatureEnabled: boolean = true;
  weatherLoading: boolean = false;
  weatherUserPreference: WeatherUserPreference = new UserPreferenceDataForT();
  weatherCollabOptions: WeatherCollabOptions = new CollabOptionsDataForT();
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
  currentWeatherSchedulePolicy: WeatherSchedulePolicy = new SchedulePolicyDataForT();
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
  planStateMachine: PlanStateMachineMockForT = new PlanStateMachineMockForT();

  resolveCurrentWeatherStage(): WeatherStageType { return 'IN_PROGRESS'; }
  async getCurrentStrategy(): Promise<ComposableStrategy> { return new StrategyDataForT(); }
  getCurrentPlanStatus(): PlanStatus { return this.currentPlanStatus; }
  findCurrentActiveEvent(): EventEntity | null { return null; }
  getOrderedScheduleEvents(): EventEntity[] { return this.events; }
  getMinEventDurationLimit(): number { return 20; }
  async skipEvent(_item: EventEntity): Promise<void> { return; }
  recalculateFromEventId(_eventId: number): void { return; }
  recalculateFromIndex(_startIndex: number): void { return; }
  markScheduleChanged(): void { return; }
}

class WeatherFacadeMockForT {
  policy: WeatherSchedulePolicy = new SchedulePolicyDataForT();
  planningResult: WeatherContextBuildResult = {
    context: {
      stage: 'IN_PROGRESS',
      generatedAt: 1700000000000,
      bindings: [],
      routeSuitability: {
        routeScore: 88,
        riskTags: [],
        summaryText: 'planning_t'
      }
    },
    eventMap: new Map<number, PlanNodeWeatherBinding>(),
    sourceEvents: []
  };

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
}

class WeatherSchedulerMockForT {
  startCalls: number = 0;
  stopCalls: number = 0;
  lastIntervalMs: number = 0;

  start(intervalMs: number, _callback: () => void): void {
    this.startCalls += 1;
    this.lastIntervalMs = intervalMs;
  }

  stop(): void {
    this.stopCalls += 1;
  }
}

class ServiceBundleForT {
  host: HostMockForT = new HostMockForT();
  service: TimelineWeatherService = new TimelineWeatherService(this.host, new WeatherFacade(), new WeatherRefreshScheduler());
  facade: WeatherFacadeMockForT = new WeatherFacadeMockForT();
  scheduler: WeatherSchedulerMockForT = new WeatherSchedulerMockForT();
}

class StaticHooksForT {
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

function createBundleForT(): ServiceBundleForT {
  const bundle = new ServiceBundleForT();
  Reflect.set(bundle.service as Object, 'weatherFacade', bundle.facade);
  Reflect.set(bundle.service as Object, 'weatherScheduler', bundle.scheduler);
  return bundle;
}

function createEventForT(id: number, name: string, lat: number, lng: number): EventEntity {
  const item = new EventEntity(name, 1);
  item.id = id;
  item.status = 1;
  item.sort_order = id * 100;
  item.completion_status = EventEntity.STATE_PENDING;
  item.latitude = lat;
  item.longitude = lng;
  return item;
}

function createSuggestionForT(id: string, level: 'INFO' | 'NOTICE' | 'WARNING', trigger: 'RAIN' | 'HEAT' | 'UNKNOWN'): WeatherSuggestion {
  return {
    suggestionId: id,
    level: level,
    triggerType: trigger,
    actionType: 'NONE',
    title: `title_${id}`,
    message: `msg_${id}`,
    relatedNodeIds: [],
    createdAt: Date.now(),
    reason: 'reason_t',
    expectedBenefit: 'benefit_t',
    canRollback: true,
    cooldownKey: `cool_${id}`,
    expiresAt: Date.now() + 60_000
  };
}

export default function phase2CoreCoverageBatchTTest() {
  describe('phase2CoreCoverageBatchTTest', () => {
    it('normal: timeline_weather_refresh_planning_should_return_early_when_loading_true', 0, async () => {
      // Arrange
      const bundle = createBundleForT();
      bundle.host.weatherLoading = true;
      bundle.host.weatherPlanningHint = 'keep_hint_t';
      // Act
      await bundle.service.refreshPlanningWeather(false);
      // Assert
      expect(bundle.host.weatherPlanningHint).assertEqual('keep_hint_t');
      expect(bundle.host.weatherLoading).assertTrue();
    });

    it('boundary: timeline_weather_refresh_planning_should_hit_missing_geo_branch_and_reuse_geocode_cache', 0, async () => {
      // Arrange
      const bundle = createBundleForT();
      const hooks = new StaticHooksForT();
      let geocodeCalls = 0;
      hooks.setAmapGetGeocode(async (_name: string): Promise<GeoCoordinate | null> => {
        geocodeCalls += 1;
        return new GeoCoordinate(31.23, 121.47);
      });
      const valid = createEventForT(1, 'valid_t', 30.0, 120.0);
      const miss1 = createEventForT(2, 'bund_t', 0, 0);
      const miss2 = createEventForT(3, 'bund_t', 0, 0);
      bundle.host.events = [valid, miss1, miss2];
      // Act
      await bundle.service.refreshPlanningWeather(false);
      // Assert
      expect(bundle.host.weatherLoading).assertFalse();
      expect(bundle.host.events[1].latitude).assertEqual(31.23);
      expect(bundle.host.events[1].longitude).assertEqual(121.47);
      expect(bundle.host.events[2].latitude).assertEqual(31.23);
      expect(bundle.host.events[2].longitude).assertEqual(121.47);
      expect(geocodeCalls).assertEqual(1);
      hooks.restore();
    });

    it('invalid: timeline_weather_request_soft_replan_should_return_invalid_when_soft_gate_rejects', 0, async () => {
      // Arrange
      const bundle = createBundleForT();
      bundle.host.currentPlanStatus = PlanStatus.READY;
      bundle.host.planStateMachine.gateResult = {
        success: false,
        reasonCode: 'status_blocked_t',
        startFromEventId: 0
      };
      const suggestion = createSuggestionForT('s_gate_t', 'NOTICE', 'RAIN');
      bundle.host.executionWeatherSuggestions = [suggestion];
      bundle.host.executionSuggestionMap.set('s_gate_t', suggestion);
      // Act
      const result = await bundle.service.requestSoftReplan(1, 's_gate_t', 'APPLY');
      // Assert
      expect(result.success).assertFalse();
      expect(result.errorCode).assertEqual('REPLAN_INVALID');
      expect(result.reasonCode).assertEqual('status_blocked_t');
    });

    it('conflict: timeline_weather_scheduler_should_force_refresh_execution_when_policy_requires_enter_refresh', 0, async () => {
      // Arrange
      const bundle = createBundleForT();
      bundle.facade.policy.forceRefreshOnEnter = true;
      bundle.facade.policy.stage = 'IN_PROGRESS';
      let refreshExecutionCalls = 0;
      Reflect.set(bundle.service as Object, 'refreshExecutionWeather',
        async (_force: boolean, _trigger: string, _stage?: WeatherStageType): Promise<void> => {
          refreshExecutionCalls += 1;
          return;
        });
      // Act
      bundle.service.startExecutionWeatherScheduler(1, 'IN_PROGRESS');
      // Assert
      expect(bundle.scheduler.startCalls).assertEqual(1);
      expect(refreshExecutionCalls).assertEqual(1);
    });

    it('regression: td-20260415-apply-execution-suggestion-should-throttle-non-manual-trigger', 0, () => {
      // Arrange
      const bundle = createBundleForT();
      const suggestion = createSuggestionForT('s_throttle_t', 'NOTICE', 'RAIN');
      const lastEmit = Date.now();
      bundle.host.executionWeatherLastEmitAt = lastEmit;
      // Act
      bundle.service.applyExecutionSuggestion(suggestion, 'TIMER');
      // Assert
      expect(bundle.host.executionWeatherLastEmitAt).assertEqual(lastEmit);
      expect(bundle.host.executionSuggestionCooldownMap.has('cool_s_throttle_t')).assertFalse();
    });

    it('combined: timeline_weather_apply_execution_suggestion_should_allow_manual_trigger_to_bypass_cooldown', 0, () => {
      // Arrange
      const bundle = createBundleForT();
      const suggestion = createSuggestionForT('s_manual_t', 'INFO', 'UNKNOWN');
      bundle.host.executionSuggestionCooldownMap.set('cool_s_manual_t', Date.now());
      // Act
      bundle.service.applyExecutionSuggestion(suggestion, 'MANUAL');
      // Assert
      expect(bundle.host.executionSuggestionCooldownMap.has('cool_s_manual_t')).assertTrue();
      expect(bundle.host.executionWeatherLastEmitAt > 0).assertTrue();
      expect(bundle.host.executionWeatherHint).assertEqual('msg_s_manual_t');
    });
  });
}
