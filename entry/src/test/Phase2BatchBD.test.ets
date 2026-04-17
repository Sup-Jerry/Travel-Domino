import { describe, expect, it } from '@ohos/hypium';
import { TimelineExecutionService } from '../main/ets/domain/timeline/services/TimelineExecutionService';
import { TimelineDistributionService } from '../main/ets/domain/timeline/services/TimelineDistributionService';
import { TimelineAiService } from '../main/ets/domain/timeline/services/TimelineAiService';
import { TimelineCompressionService } from '../main/ets/domain/timeline/services/TimelineCompressionService';
import { TimelineWeatherService } from '../main/ets/domain/timeline/services/TimelineWeatherService';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { PlanPersistenceFacade } from '../main/ets/viewmodel/internal/PlanPersistenceFacade';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { DEFAULT_WEATHER_USER_PREFERENCE } from '../main/ets/domain/services/WeatherModels';
import { WeatherFacade } from '../main/ets/domain/services/WeatherFacade';
import { WeatherRefreshScheduler } from '../main/ets/domain/services/WeatherRefreshScheduler';

class PlanStatusSnapshotBD {
  status: PlanStatus = PlanStatus.READY;
}

class ReflowHintBD {
  type: string = 'reflow';
  minutesDelta: number = 0;
  message: string = '';
  updatedAt: number = 0;
}

class ReminderFacadeStubBD {
  async updateScheduleNotification(): Promise<void> {
    return;
  }
}

class ExecutionPlanStateMachineBD {
  getPlanStatus(_planId: string): PlanStatusSnapshotBD {
    return new PlanStatusSnapshotBD();
  }

  startExecution(): void {
    return;
  }

  completeExecution(): void {
    return;
  }
}

class ExecutionHostBD {
  events: EventEntity[] = [];
  conflictList: EventEntity[] = [];
  planStartDate: number = Date.now();
  isArchived: boolean = false;
  actualTimeMutationInFlight: boolean = false;
  latestReflowHint: ReflowHintBD | null = null;
  planId: number = 1;
  currentPlanStatus: PlanStatus = PlanStatus.READY;
  planStateMachine: ExecutionPlanStateMachineBD = new ExecutionPlanStateMachineBD();
  reminderFacade: ReminderFacadeStubBD = new ReminderFacadeStubBD();

  async applyRuntimeTransition(): Promise<boolean> {
    return true;
  }

  recalculateFromEventId(): void {
    return;
  }

  getNextExecutableEvent(): EventEntity | null {
    return null;
  }

  buildReflowHint(): ReflowHintBD {
    return new ReflowHintBD();
  }

  logTimelineSnapshot(): void {
    return;
  }

  getPlaceCheckinSummary(): string {
    return '';
  }

  evaluatePlanStatusByRuntime(): void {
    return;
  }

  getRealActiveEvent(): EventEntity | null {
    return null;
  }

  markScheduleChanged(): void {
    return;
  }

  getOrderedScheduleEvents(): EventEntity[] {
    return this.events;
  }

  getOrderedScheduleIndexById(): number {
    return 0;
  }

  getCurrentPlanStatus(): PlanStatus {
    return this.currentPlanStatus;
  }
}

class DistributionHostBD {
  updateCalls: number = 0;

  events: EventEntity[] = [];
  planId: number = 1;
  idleGapDetectionEnabled: boolean = true;
  idleGapTriggerMinutes: number = 20;

  getEffectiveDayOffset(item: EventEntity): number {
    return item.day_offset;
  }

  getOrderedScheduleEvents(): EventEntity[] {
    return [];
  }

  getOrderedScheduleIndexById(): number {
    return 0;
  }

  isFirstScheduledItemOfDay(): boolean {
    return false;
  }

  _calculateNaturalArrival(): number {
    return 0;
  }

  recalculateFromIndex(): void {
    return;
  }

  async updateEventInfo(): Promise<void> {
    this.updateCalls += 1;
  }
}

class StrategyBD {
  density: number = 1;
  pace: number = 1;
  preference: number = 0;
  energy: number = 1;
}

class SoftReplanPreviewBD {
  suggestionId: string = 'preview';
  actionType: string = 'NONE';
  changedOrder: boolean = false;
  changedDurations: boolean = false;
  skippedNodeIds: string[] = [];
  affectedNodeIds: string[] = [];
  changeSummary: string[] = [];
  summary: string = 'ok';
  riskDelta: number = 0;
}

class SoftReplanResultBD {
  success: boolean = true;
  rolledBack: boolean = false;
  errorCode: string = '';
  preview: SoftReplanPreviewBD = new SoftReplanPreviewBD();
}

class BehaviorTrackerBD {
  getBehaviorContext(): Object {
    return new Object();
  }

  reset(): void {
    return;
  }
}

class AiHostBD {
  events: EventEntity[] = [];
  planId: number = 1;
  currentStrategyMode: number = 0;
  isRegenerating: boolean = false;
  weatherFeatureEnabled: boolean = false;
  weatherUserPreference = DEFAULT_WEATHER_USER_PREFERENCE;
  weatherCollabOptions: string[] = [];
  weatherStrategyHint: string = '';
  strategyAdaptationPrompt: string | null = null;
  persistence: PlanPersistenceFacade = new PlanPersistenceFacade();
  weatherFacade: WeatherFacade = new WeatherFacade();
  behaviorTracker: BehaviorTrackerBD = new BehaviorTrackerBD();

  resolveCurrentWeatherStage(): string {
    return 'PLANNING';
  }

  async applyPlanningWeatherResult(): Promise<void> {
    return;
  }

  composeWeatherConstraintPrompt(a: string, b: string): string {
    return a + b;
  }

  async getCurrentStrategy(): Promise<StrategyBD> {
    return new StrategyBD();
  }

  clampStrategyLevel(value: number): number {
    return value <= 0 ? 0 : (value >= 2 ? 2 : 1);
  }

  async requestSoftReplan(): Promise<SoftReplanResultBD> {
    return new SoftReplanResultBD();
  }

  markScheduleChanged(): void {
    return;
  }

  recalculateFromIndex(): void {
    return;
  }
}

class CompressionHostBD {
  events: EventEntity[] = [];
  planId: number = 1;
  globalStartTime: string = '08:00';

  getMinEventDurationLimit(): number {
    return 20;
  }

  getEffectiveDayOffset(item: EventEntity): number {
    return item.day_offset;
  }

  resolveEffectiveGlobalStartMinutes(): number {
    return 8 * 60;
  }

  recalculateFromEventId(): void {
    return;
  }

  recalculateFromIndex(): void {
    return;
  }

  markHasUnsavedPostpone(): void {
    return;
  }
}

class WeatherHostBD {
  events: EventEntity[] = [];
  planId: number = 1;
  currentStrategyMode: number = 0;
  weatherFeatureEnabled: boolean = true;
  weatherLoading: boolean = false;
  weatherUserPreference = DEFAULT_WEATHER_USER_PREFERENCE;
  weatherCollabOptions: string[] = [];
  executionWeatherEnabled: boolean = false;
  executionWeatherLoading: boolean = false;
  currentPlanStatus: PlanStatus = PlanStatus.DRAFT;
  executionWeatherLastTrigger: string = '';
  executionWeatherErrorCode: string = '';
  executionWeatherScore: number = -1;
  executionWeatherRefreshAt: number = 0;
  executionWeatherCollabSummary: string = '';
  executionWeatherCollabBadge: string = '';
  executionWeatherDisplaySource: string = 'NEXT_FALLBACK';
  executionWeatherCurrentText: string = '';
  executionWeatherNextText: string = '';
  executionWeatherSuggestions: string[] = [];
  executionSuggestionMap: Map<string, Object> = new Map<string, Object>();
  executionWeatherHint: string = '';
  executionWeatherLevel: 'INFO' | 'NOTICE' | 'WARNING' = 'INFO';
  executionWeatherLastLocation: Object | null = null;
  executionWeatherLocationTriggerCooldownMs: number = 0;
  executionWeatherLastLocationTriggerAt: number = 0;
  currentWeatherSchedulePolicy: WeatherSchedulePolicyBD = new WeatherSchedulePolicyBD();
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
  planStateMachine: WeatherPlanStateMachineBD = new WeatherPlanStateMachineBD();

  resolveCurrentWeatherStage(): string {
    return 'PLANNING';
  }

  async getCurrentStrategy(): Promise<StrategyBD> {
    return new StrategyBD();
  }

  getCurrentPlanStatus(): PlanStatus {
    return this.currentPlanStatus;
  }

  findCurrentActiveEvent(): EventEntity | null {
    return null;
  }

  getOrderedScheduleEvents(): EventEntity[] {
    return this.events;
  }

  getMinEventDurationLimit(): number {
    return 20;
  }

  async skipEvent(): Promise<void> {
    return;
  }

  recalculateFromEventId(): void {
    return;
  }

  recalculateFromIndex(): void {
    return;
  }

  markScheduleChanged(): void {
    return;
  }
}

class WeatherSchedulePolicyBD {
  stage: string = 'PLANNING';
  pollIntervalMs: number = 0;
  allowLocationTrigger: boolean = false;
  allowManualBypass: boolean = true;
  forceRefreshOnEnter: boolean = false;
}

class WeatherPlanStateMachineBD {
  requestSoftReplan(): WeatherSoftReplanStateBD {
    return new WeatherSoftReplanStateBD();
  }
}

class WeatherSoftReplanStateBD {
  success: boolean = true;
  reasonCode: string = 'ok';
  startFromEventId: number = 1;
}

function createEventBD(id: number, name: string): EventEntity {
  const event = new EventEntity(name, 30);
  event.id = id;
  event.status = 1;
  event.sort_order = id * 100;
  event.day_offset = 0;
  event.dynamic_day_offset = 0;
  event.computed_time = '09:00';
  event.completion_status = EventEntity.STATE_PENDING;
  return event;
}

export default function phase2BatchBDTest() {
  describe('phase2BatchBD_safe_suite', () => {
    it('normal: execution_service_should_find_active_event_in_dynamic_window', 0, () => {
      // Arrange
      const host = new ExecutionHostBD();
      const event = createEventBD(1, 'active_bd');
      const now = Date.now();
      event.dynamic_start_time = now - 1000;
      event.dynamic_end_time = now + 60_000;
      host.events = [event];
      // Act
      const picked = new TimelineExecutionService(host as never).findCurrentActiveEvent();
      // Assert
      expect(picked?.id ?? 0).assertEqual(1);
    });

    it('boundary: distribution_service_should_clamp_extra_minutes_at_limit', 0, () => {
      // Arrange
      // Act
      const keepOneMinute = TimelineDistributionService.clampDistributionAdd(239, 10);
      const clampToZero = TimelineDistributionService.clampDistributionAdd(300, 1);
      // Assert
      expect(keepOneMinute).assertEqual(1);
      expect(clampToZero).assertEqual(0);
    });

    it('invalid: ai_service_should_return_false_when_weather_adjustment_missing', 0, async () => {
      // Arrange
      const host = new AiHostBD();
      const service = new TimelineAiService(host as never);
      // Act
      const result = await service.applyWeatherStrategyAdjustment(undefined, 'missing_adjustment_bd');
      // Assert
      expect(result).assertFalse();
    });

    it('conflict: compression_service_should_require_confirm_for_delay_plan', 0, () => {
      // Arrange
      const host = new CompressionHostBD();
      const first = createEventBD(21, 'first_bd');
      const second = createEventBD(22, 'second_bd');
      second.pre_travel_min = 15;
      host.events = [first, second];
      // Act
      const plan = new TimelineCompressionService(host as never).calculateDelayPlan(1);
      // Assert
      expect(plan.status).assertEqual('COMPRESS_CONFIRM');
    });

    it('regression: weather_service_should_expose_display_source_from_host_state', 0, () => {
      // Arrange
      const host = new WeatherHostBD();
      const service = new TimelineWeatherService(host as never, new WeatherFacade(), new WeatherRefreshScheduler());
      // Act
      const source = service.getExecutionWeatherDisplaySource();
      // Assert
      expect(source).assertEqual('NEXT_FALLBACK');
    });

    it('combined: execution_service_should_fill_placeholder_forecast_for_pending_schedule', 0, () => {
      // Arrange
      const host = new ExecutionHostBD();
      const first = createEventBD(2, 'first_pending_bd');
      const second = createEventBD(3, 'second_pending_bd');
      host.events = [first, second];
      // Act
      new TimelineExecutionService(host as never).calculateRealtimeSchedule();
      // Assert
      expect(first.forecast_start_time).assertEqual('xxxx');
      expect(second.forecast_end_time).assertEqual('xxxx');
    });
  });
}
