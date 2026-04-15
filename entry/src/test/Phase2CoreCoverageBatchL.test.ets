import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { EventRepositoryImpl } from '../main/ets/infrastructure/persistence/EventRepositoryImpl';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { ComposableStrategy, DensityLevel, EnergyLevel, PaceLevel, PreferenceType } from '../main/ets/domain/strategy/TravelStrategyDimensions';
import { GeoPointInput, WeatherCollabOptions, WeatherSchedulePolicy, WeatherStageType, WeatherSuggestion, WeatherUserPreference } from '../main/ets/domain/services/WeatherModels';
import { ITimelineWeatherHost, TimelineWeatherService } from '../main/ets/domain/timeline/services/TimelineWeatherService';
import { WeatherFacade } from '../main/ets/domain/services/WeatherFacade';
import { WeatherRefreshScheduler } from '../main/ets/domain/services/WeatherRefreshScheduler';

class StrategyDataForL implements ComposableStrategy {
  density: DensityLevel = DensityLevel.MEDIUM;
  pace: PaceLevel = PaceLevel.BALANCED;
  preference: PreferenceType = PreferenceType.BALANCED;
  energy: EnergyLevel = EnergyLevel.MEDIUM;
}

class UserPreferenceDataForL implements WeatherUserPreference {
  heatSensitivity: 0 | 1 | 2 = 1;
  rainSensitivity: 0 | 1 | 2 = 1;
  weatherRiskTolerance: 0 | 1 | 2 = 1;
}

class CollabOptionsDataForL implements WeatherCollabOptions {
  enableMultiDay?: boolean = true;
  enableMultiCity?: boolean = true;
}

class SchedulePolicyDataForL implements WeatherSchedulePolicy {
  stage: WeatherStageType = 'PLANNING';
  pollIntervalMs: number = 60_000;
  allowLocationTrigger: boolean = true;
  allowManualBypass: boolean = true;
  forceRefreshOnEnter: boolean = false;
}

class GateResultDataForL {
  success: boolean = true;
  reasonCode?: string = 'ok';
  startFromEventId?: number = 1;
}

class PlanStateMachineMockForL {
  requestSoftReplan(_args: Object): GateResultDataForL {
    return new GateResultDataForL();
  }
}

class HostMockForL implements ITimelineWeatherHost {
  events: EventEntity[] = [];
  planId: number = 1;
  currentStrategyMode: number = 0;
  weatherFeatureEnabled: boolean = true;
  weatherLoading: boolean = false;
  weatherUserPreference: WeatherUserPreference = new UserPreferenceDataForL();
  weatherCollabOptions: WeatherCollabOptions = new CollabOptionsDataForL();
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
  currentWeatherSchedulePolicy: WeatherSchedulePolicy = new SchedulePolicyDataForL();
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
  planStateMachine: PlanStateMachineMockForL = new PlanStateMachineMockForL();

  skipCalls: number = 0;
  recalculateFromEventIdCalls: number[] = [];
  recalculateFromIndexCalls: number[] = [];
  minEventDurationLimit: number = 20;

  resolveCurrentWeatherStage(): WeatherStageType { return 'PLANNING'; }
  async getCurrentStrategy(): Promise<ComposableStrategy> { return new StrategyDataForL(); }
  getCurrentPlanStatus(): PlanStatus { return this.currentPlanStatus; }
  findCurrentActiveEvent(): EventEntity | null { return null; }
  getOrderedScheduleEvents(): EventEntity[] { return this.events.filter((item: EventEntity) => item.status === 1); }
  getMinEventDurationLimit(): number { return this.minEventDurationLimit; }
  async skipEvent(_item: EventEntity): Promise<void> { this.skipCalls += 1; }
  recalculateFromEventId(eventId: number): void { this.recalculateFromEventIdCalls.push(eventId); }
  recalculateFromIndex(startIndex: number): void { this.recalculateFromIndexCalls.push(startIndex); }
  markScheduleChanged(): void { return; }
}

class ServiceBundleForL {
  host: HostMockForL = new HostMockForL();
  service: TimelineWeatherService = new TimelineWeatherService(this.host, new WeatherFacade(), new WeatherRefreshScheduler());
}

class StaticHooksForL {
  private readonly originUpdateTimelineConsistency: Object;
  private readonly originUpdateSingleField: Object;

  constructor() {
    this.originUpdateTimelineConsistency = Reflect.get(EventRepositoryImpl, 'updateTimelineConsistency') as Object;
    this.originUpdateSingleField = Reflect.get(EventRepositoryImpl, 'updateSingleField') as Object;
  }

  setUpdateTimelineConsistency(fn: (events: Object[], planIdHint?: number) => Promise<void>): void {
    Reflect.set(EventRepositoryImpl, 'updateTimelineConsistency', fn);
  }

  setUpdateSingleField(fn: (id: number, column: string, value: Object, planIdHint?: number) => Promise<void>): void {
    Reflect.set(EventRepositoryImpl, 'updateSingleField', fn);
  }

  restore(): void {
    Reflect.set(EventRepositoryImpl, 'updateTimelineConsistency', this.originUpdateTimelineConsistency);
    Reflect.set(EventRepositoryImpl, 'updateSingleField', this.originUpdateSingleField);
  }
}

function createBundleForL(): ServiceBundleForL {
  return new ServiceBundleForL();
}

function createEventForL(id: number, status: number = 1, duration: number = 90): EventEntity {
  const item = new EventEntity(`evt_l_${id}`, status);
  item.id = id;
  item.status = status;
  item.sort_order = id * 100;
  item.duration = duration;
  item.completion_status = EventEntity.STATE_PENDING;
  item.lock_status = 0;
  item.fixed_start_time = '';
  return item;
}

export default function phase2CoreCoverageBatchLTest() {
  describe('phase2CoreCoverageBatchLTest', () => {
    it('normal: timeline_weather_service_apply_soft_reorder_should_reorder_and_recalculate', 0, async () => {
      // Arrange
      const bundle = createBundleForL();
      const hooks = new StaticHooksForL();
      let updateTimelineCalls = 0;
      hooks.setUpdateTimelineConsistency(async (_events: Object[], _planIdHint?: number): Promise<void> => {
        updateTimelineCalls += 1;
        return;
      });
      bundle.host.planId = 66;
      bundle.host.events = [createEventForL(1), createEventForL(2), createEventForL(3)];
      // Act
      const ok = await bundle.service.applySoftReorder(['3', '1']);
      // Assert
      expect(ok).assertTrue();
      expect(updateTimelineCalls).assertEqual(1);
      expect(bundle.host.recalculateFromIndexCalls.length).assertEqual(1);
      expect(bundle.host.events[0].id).assertEqual(3);
      hooks.restore();
    });

    it('boundary: timeline_weather_service_apply_soft_shorten_should_clamp_to_min_duration_limit', 0, async () => {
      // Arrange
      const bundle = createBundleForL();
      const hooks = new StaticHooksForL();
      let updateSingleCalls = 0;
      hooks.setUpdateSingleField(async (_id: number, _column: string, _value: Object, _planIdHint?: number): Promise<void> => {
        updateSingleCalls += 1;
        return;
      });
      const target = createEventForL(10, 1, 120);
      bundle.host.minEventDurationLimit = 30;
      bundle.host.planId = 99;
      bundle.host.events = [target];
      // Act
      const ok = await bundle.service.applySoftShorten([10], 5);
      // Assert
      expect(ok).assertTrue();
      expect(target.duration).assertEqual(30);
      expect(updateSingleCalls).assertEqual(1);
      hooks.restore();
    });

    it('invalid: timeline_weather_service_apply_soft_reorder_should_return_false_when_target_count_lt_two', 0, async () => {
      // Arrange
      const bundle = createBundleForL();
      bundle.host.events = [createEventForL(1), createEventForL(2)];
      // Act
      const ok = await bundle.service.applySoftReorder(['1']);
      // Assert
      expect(ok).assertFalse();
      expect(bundle.host.recalculateFromIndexCalls.length).assertEqual(0);
    });

    it('conflict: timeline_weather_service_contains_immutable_node_should_be_true_for_missing_target', 0, () => {
      // Arrange
      const bundle = createBundleForL();
      bundle.host.events = [createEventForL(1)];
      // Act
      const blocked = bundle.service.containsImmutableNode([999]);
      // Assert
      expect(blocked).assertTrue();
    });

    it('regression: td-20260415-request_soft_replan_should_reject_invalid_input_early', 0, async () => {
      // Arrange
      const bundle = createBundleForL();
      bundle.host.planId = 123;
      // Act
      const result = await bundle.service.requestSoftReplan(0, '', 'APPLY');
      // Assert
      expect(result.success).assertFalse();
      expect(result.errorCode).assertEqual('REPLAN_INVALID');
      expect(result.reasonCode).assertEqual('invalid_input');
    });

    it('combined: timeline_weather_service_apply_soft_skip_should_handle_hit_and_miss_targets', 0, async () => {
      // Arrange
      const bundle = createBundleForL();
      bundle.host.events = [createEventForL(7)];
      // Act
      const hit = await bundle.service.applySoftSkip([7]);
      const miss = await bundle.service.applySoftSkip([8]);
      // Assert
      expect(hit).assertTrue();
      expect(miss).assertFalse();
      expect(bundle.host.skipCalls).assertEqual(1);
    });
  });
}

