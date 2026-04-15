import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { ComposableStrategy, DensityLevel, EnergyLevel, PaceLevel, PreferenceType } from '../main/ets/domain/strategy/TravelStrategyDimensions';
import {
  GeoPointInput,
  PlanNodeWeatherBinding,
  WeatherCollabOptions,
  WeatherSchedulePolicy,
  WeatherStageType,
  WeatherSuggestion,
  WeatherUserPreference
} from '../main/ets/domain/services/WeatherModels';
import { EventRepositoryImpl } from '../main/ets/infrastructure/persistence/EventRepositoryImpl';
import { ITimelineWeatherHost, TimelineWeatherService } from '../main/ets/domain/timeline/services/TimelineWeatherService';
import { WeatherFacade } from '../main/ets/domain/services/WeatherFacade';
import { WeatherRefreshScheduler } from '../main/ets/domain/services/WeatherRefreshScheduler';

class StrategyDataForH implements ComposableStrategy {
  density: DensityLevel = DensityLevel.MEDIUM;
  pace: PaceLevel = PaceLevel.BALANCED;
  preference: PreferenceType = PreferenceType.BALANCED;
  energy: EnergyLevel = EnergyLevel.MEDIUM;
}

class UserPreferenceDataForH implements WeatherUserPreference {
  heatSensitivity: 0 | 1 | 2 = 1;
  rainSensitivity: 0 | 1 | 2 = 1;
  weatherRiskTolerance: 0 | 1 | 2 = 1;
}

class CollabOptionsDataForH implements WeatherCollabOptions {
  enableMultiDay?: boolean = true;
  enableMultiCity?: boolean = true;
}

class SchedulePolicyDataForH implements WeatherSchedulePolicy {
  stage: WeatherStageType = 'IN_PROGRESS';
  pollIntervalMs: number = 30_000;
  allowLocationTrigger: boolean = true;
  allowManualBypass: boolean = true;
  forceRefreshOnEnter: boolean = false;
}

class GateResultDataForH {
  success: boolean = true;
  reasonCode?: string = 'ok';
  startFromEventId?: number = 1;
}

class PlanStateMachineMockForH {
  requestSoftReplan(_args: Object): GateResultDataForH {
    return new GateResultDataForH();
  }
}

class SchedulerMockForH {
  startCalls: number = 0;
  stopCalls: number = 0;
  lastInterval: number = 0;

  start(intervalMs: number, _callback: () => void): void {
    this.startCalls += 1;
    this.lastInterval = intervalMs;
  }

  stop(): void {
    this.stopCalls += 1;
  }
}

class WeatherFacadeMockForH {
  policy: WeatherSchedulePolicy = new SchedulePolicyDataForH();
  resolveSchedulePolicyCalls: number = 0;

  resolveSchedulePolicy(_stage: WeatherStageType): WeatherSchedulePolicy {
    this.resolveSchedulePolicyCalls += 1;
    return this.policy;
  }
}

class HostMockForH implements ITimelineWeatherHost {
  events: EventEntity[] = [];
  planId: number = 1;
  currentStrategyMode: number = 0;
  weatherFeatureEnabled: boolean = true;
  weatherLoading: boolean = false;
  weatherUserPreference: WeatherUserPreference = new UserPreferenceDataForH();
  weatherCollabOptions: WeatherCollabOptions = new CollabOptionsDataForH();
  executionWeatherEnabled: boolean = false;
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
  currentWeatherSchedulePolicy: WeatherSchedulePolicy = new SchedulePolicyDataForH();
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
  planStateMachine: PlanStateMachineMockForH = new PlanStateMachineMockForH();

  activeEvent: EventEntity | null = null;
  skippedEventIds: number[] = [];
  recalculateFromEventIdCalls: number[] = [];
  recalculateFromIndexCalls: number[] = [];

  resolveCurrentWeatherStage(): WeatherStageType {
    return 'IN_PROGRESS';
  }

  async getCurrentStrategy(): Promise<ComposableStrategy> {
    return new StrategyDataForH();
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

  async skipEvent(item: EventEntity): Promise<void> {
    this.skippedEventIds.push(item.id);
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

class SuggestionDataForH implements WeatherSuggestion {
  suggestionId: string = '';
  level: 'INFO' | 'NOTICE' | 'WARNING' = 'NOTICE';
  triggerType: 'RAIN' | 'HEAT' | 'COLD' | 'WIND' | 'SEVERE_ALERT' | 'UNKNOWN' = 'UNKNOWN';
  actionType: 'NONE' | 'PREPARE' | 'REORDER' | 'SHORTEN_STAY' | 'REPLACE_NODE' | 'SKIP_NODE' = 'NONE';
  title: string = '';
  message: string = '';
  relatedNodeIds: string[] = [];
  createdAt: number = Date.now();
  reason: string = '';
  expectedBenefit: string = '';
  canRollback: boolean = true;
  cooldownKey: string = '';
  expiresAt: number = Date.now() + 60_000;
}

class ServiceBundleForH {
  host: HostMockForH = new HostMockForH();
  service: TimelineWeatherService = new TimelineWeatherService(this.host, new WeatherFacade(), new WeatherRefreshScheduler());
  facade: WeatherFacadeMockForH = new WeatherFacadeMockForH();
  scheduler: SchedulerMockForH = new SchedulerMockForH();
}

class EventRepoHooksForH {
  private readonly originUpdateSingleField: Object;

  constructor() {
    this.originUpdateSingleField = Reflect.get(EventRepositoryImpl, 'updateSingleField') as Object;
  }

  setUpdateSingleField(fn: (id: number, column: string, value: Object, planIdHint?: number) => Promise<void>): void {
    Reflect.set(EventRepositoryImpl, 'updateSingleField', fn);
  }

  restore(): void {
    Reflect.set(EventRepositoryImpl, 'updateSingleField', this.originUpdateSingleField);
  }
}

function createBundleForH(): ServiceBundleForH {
  const bundle = new ServiceBundleForH();
  Reflect.set(bundle.service as Object, 'weatherFacade', bundle.facade);
  Reflect.set(bundle.service as Object, 'weatherScheduler', bundle.scheduler);
  return bundle;
}

function createEventForH(id: number, duration: number = 90): EventEntity {
  const item = new EventEntity(`e_h_${id}`, 1);
  item.id = id;
  item.status = 1;
  item.sort_order = id * 100;
  item.duration = duration;
  item.completion_status = EventEntity.STATE_PENDING;
  item.latitude = 31.2000 + id * 0.0001;
  item.longitude = 121.4000 + id * 0.0001;
  return item;
}

function createSuggestionForH(id: string): SuggestionDataForH {
  const item = new SuggestionDataForH();
  item.suggestionId = id;
  item.title = `title_${id}`;
  item.message = `msg_${id}`;
  item.cooldownKey = `cool_${id}`;
  return item;
}

export default function phase2CoreCoverageBatchHTest() {
  describe('phase2CoreCoverageBatchHTest', () => {
    it('normal: timeline_weather_service_request_soft_replan_apply_should_succeed_for_none_action_and_remove_suggestion', 0, async () => {
      // Arrange
      const bundle = createBundleForH();
      bundle.host.planId = 9;
      bundle.host.currentPlanStatus = PlanStatus.READY;
      const suggestion = createSuggestionForH('s_apply_h');
      bundle.host.executionWeatherSuggestions = [suggestion];
      bundle.host.executionSuggestionMap.set(suggestion.suggestionId, suggestion);
      // Act
      const result = await bundle.service.requestSoftReplan(9, 's_apply_h', 'APPLY');
      // Assert
      expect(result.success).assertTrue();
      expect(bundle.host.recalculateFromEventIdCalls.length).assertEqual(1);
      expect(bundle.host.recalculateFromEventIdCalls[0]).assertEqual(1);
      expect(bundle.host.executionSuggestionMap.has('s_apply_h')).assertFalse();
      expect(bundle.host.executionWeatherSuggestions.length).assertEqual(0);
    });

    it('boundary: timeline_weather_service_apply_soft_shorten_should_respect_min_limit_and_recalculate', 0, async () => {
      // Arrange
      const bundle = createBundleForH();
      const hooks = new EventRepoHooksForH();
      hooks.setUpdateSingleField(async (_id: number, _column: string, _value: Object, _planIdHint?: number): Promise<void> => {
        return;
      });
      const event = createEventForH(1, 120);
      bundle.host.events = [event];
      // Act
      const changed = await bundle.service.applySoftShorten([1], 15);
      // Assert
      expect(changed).assertTrue();
      expect(bundle.host.events[0].duration).assertEqual(20);
      expect(bundle.host.recalculateFromIndexCalls.length).assertEqual(1);
      hooks.restore();
    });

    it('invalid: timeline_weather_service_apply_weather_suggestion_should_fail_when_suggestion_missing', 0, async () => {
      // Arrange
      const bundle = createBundleForH();
      bundle.host.planId = 3;
      bundle.host.currentPlanStatus = PlanStatus.READY;
      // Act
      const result = await bundle.service.applyWeatherSuggestion('missing_id');
      // Assert
      expect(result.success).assertFalse();
      expect(result.errorCode).assertEqual('REPLAN_INVALID');
      expect(result.reasonCode).assertEqual('suggestion_missing');
    });

    it('conflict: timeline_weather_service_start_stop_scheduler_should_follow_feature_toggle', 0, () => {
      // Arrange
      const bundle = createBundleForH();
      bundle.host.weatherFeatureEnabled = false;
      // Act
      bundle.service.startExecutionWeatherScheduler(bundle.host.planId, 'IN_PROGRESS');
      bundle.host.weatherFeatureEnabled = true;
      bundle.service.startExecutionWeatherScheduler(bundle.host.planId, 'IN_PROGRESS');
      bundle.service.stopExecutionWeatherScheduler();
      // Assert
      expect(bundle.scheduler.stopCalls >= 2).assertTrue();
      expect(bundle.scheduler.startCalls).assertEqual(1);
      expect(bundle.scheduler.lastInterval).assertEqual(30_000);
      expect(bundle.host.executionWeatherEnabled).assertFalse();
      expect(bundle.facade.resolveSchedulePolicyCalls > 0).assertTrue();
    });

    it('regression: td-20260415-timeline-weather-refresh_execution_should_skip_when_location_delta_below_threshold', 0, async () => {
      // Arrange
      const bundle = createBundleForH();
      const active = createEventForH(10, 60);
      bundle.host.activeEvent = active;
      bundle.host.events = [active];
      bundle.host.weatherFeatureEnabled = true;
      bundle.host.executionWeatherEnabled = true;
      bundle.host.currentPlanStatus = PlanStatus.READY;
      bundle.host.executionWeatherLastLocation = { latitude: active.latitude, longitude: active.longitude };
      bundle.host.executionWeatherLocationDeltaMeters = 500;
      // Act
      await bundle.service.refreshExecutionWeather(false, 'TIMER', 'IN_PROGRESS');
      // Assert
      expect(bundle.host.executionWeatherLoading).assertFalse();
      expect(bundle.host.executionWeatherLastTrigger).assertEqual('TIMER');
      expect(bundle.host.executionWeatherErrorCode).assertEqual('');
    });

    it('combined: timeline_weather_service_apply_soft_skip_and_patch_runtime_should_cover_pending_only_update', 0, async () => {
      // Arrange
      const bundle = createBundleForH();
      const pending = createEventForH(1, 80);
      const done = createEventForH(2, 80);
      done.completion_status = EventEntity.STATE_COMPLETED;
      bundle.host.events = [pending, done];
      const eventMap = new Map<number, PlanNodeWeatherBinding>();
      eventMap.set(1, {
        nodeId: '1',
        eventId: 1,
        suitabilityScore: 80,
        riskTags: [],
        weather: {
          locationKey: 'k1',
          sourceType: 'PLAN_LOCATION',
          weatherTime: Date.now(),
          fetchTime: 123456,
          conditionCode: 'RAIN',
          conditionText: '小雨',
          temperatureCelsius: 22
        }
      });
      // Act
      const skipped = await bundle.service.applySoftSkip([1]);
      bundle.service.patchExecutionWeatherToEvents(eventMap, false);
      // Assert
      expect(skipped).assertTrue();
      expect(bundle.host.skippedEventIds.length).assertEqual(1);
      expect(bundle.host.skippedEventIds[0]).assertEqual(1);
      expect(bundle.host.events[0].weather_condition).assertEqual('RAIN');
      expect(bundle.host.events[1].weather_condition).assertEqual('');
    });
  });
}

