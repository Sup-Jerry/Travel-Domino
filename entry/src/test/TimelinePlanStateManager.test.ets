import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { TimelinePlanStateManager, ITimelinePlanStateHost } from '../main/ets/viewmodel/managers/TimelinePlanStateManager';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { PlanStateMachine } from '../main/ets/domain/statemachine/PlanStateMachine';
import { WeatherFacade } from '../main/ets/domain/services/WeatherFacade';
import { WeatherSuggestion, WeatherStageType } from '../main/ets/domain/services/WeatherModels';
import { ScheduleOrchestrator } from '../main/ets/viewmodel/internal/ScheduleOrchestrator';

class CompanionContextSnapshot {
  runtimeState: 'IDLE' | 'READY' | 'ACTIVE' | 'PAUSED' | 'GAP' = 'IDLE';
}

class FakeTimelinePlanStateHost implements ITimelinePlanStateHost {
  planId: number = 10;
  planName: string = 'plan_origin';
  events: EventEntity[] = [];
  globalStartTime: string = '08:00';
  planStartDate: number = new Date(2026, 3, 12).getTime();
  idleGapDetectionEnabled: boolean = false;
  idleGapTriggerMinutes: number = 15;
  currentPlanStatus: PlanStatus = PlanStatus.DRAFT;
  weatherFeatureEnabled: boolean = false;
  executionWeatherEnabled: boolean = false;
  executionWeatherHint: string = '';
  executionWeatherSuggestions: WeatherSuggestion[] = [];
  executionWeatherAppliedSummary: string = '';
  executionWeatherLevel: 'INFO' | 'NOTICE' | 'WARNING' = 'INFO';

  weatherFacade: WeatherFacade = new WeatherFacade();
  planStateMachine: PlanStateMachine = PlanStateMachine.getInstance({});

  startSchedulerCount: number = 0;
  stopSchedulerCount: number = 0;
  recalculateCount: number = 0;
  realtimeCount: number = 0;
  regenerateCount: number = 0;
  markChangedCount: number = 0;
  refreshCount: number = 0;
  persistDateCalls: number = 0;
  persistNameCalls: number = 0;
  persistedDate: number = 0;
  persistedName: string = '';

  resolveCurrentWeatherStage(): WeatherStageType {
    return 'PLANNING';
  }

  startExecutionWeatherScheduler(_planId?: number, _stage?: WeatherStageType): void {
    this.startSchedulerCount += 1;
  }

  stopExecutionWeatherScheduler(): void {
    this.stopSchedulerCount += 1;
  }

  async refreshExecutionWeather(
    _forceRefresh?: boolean,
    _trigger?: 'ENTER_EXECUTION' | 'LOCATION_CHANGE' | 'TIMER' | 'MANUAL',
    _stage?: WeatherStageType
  ): Promise<void> {
    return;
  }

  getCompanionContext(_nowTs?: number): CompanionContextSnapshot {
    const snapshot = new CompanionContextSnapshot();
    return snapshot;
  }

  recalculateFromIndex(_startIndex: number): void {
    this.recalculateCount += 1;
  }

  getScheduleOrchestrator(): ScheduleOrchestrator {
    return new ScheduleOrchestrator();
  }

  isAutoRouteEnabled(): boolean {
    return false;
  }

  calculateRealtimeSchedule(): void {
    this.realtimeCount += 1;
  }

  regenerateGroups(): void {
    this.regenerateCount += 1;
  }

  markScheduleChanged(): void {
    this.markChangedCount += 1;
  }

  refreshTimelineView(): void {
    this.refreshCount += 1;
  }

  async persistPlanStartDate(_planId: number, startDate: number): Promise<void> {
    this.persistDateCalls += 1;
    this.persistedDate = startDate;
  }

  async persistPlanName(_planId: number, name: string): Promise<void> {
    this.persistNameCalls += 1;
    this.persistedName = name;
  }
}

export default function timelinePlanStateManagerTest() {
  describe('timelinePlanStateManagerTest', () => {
    it('normal: update_plan_date_should_persist_and_refresh_runtime_views', 0, async () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      const manager = new TimelinePlanStateManager(host);
      const newDateTimestamp = new Date(2026, 3, 20, 14, 30, 25).getTime();
      const expectedNormalized = new Date(2026, 3, 20, 0, 0, 0, 0).getTime();
      // Act
      await manager.updatePlanDate(newDateTimestamp);
      // Assert
      expect(host.planStartDate).assertEqual(expectedNormalized);
      expect(host.persistDateCalls).assertEqual(1);
      expect(host.persistedDate).assertEqual(expectedNormalized);
      expect(host.realtimeCount).assertEqual(1);
      expect(host.regenerateCount).assertEqual(1);
      expect(host.markChangedCount).assertEqual(1);
      expect(host.refreshCount).assertEqual(1);
    });

    it('boundary: pause_current_execution_should_return_false_when_plan_id_non_positive', 0, () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      host.planId = 0;
      const manager = new TimelinePlanStateManager(host);
      // Act
      const paused = manager.pauseCurrentExecution();
      // Assert
      expect(paused).assertFalse();
    });

    it('invalid: rename_plan_should_ignore_when_plan_id_is_minus_one', 0, async () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      host.planId = -1;
      const manager = new TimelinePlanStateManager(host);
      // Act
      await manager.renamePlan('new_name');
      // Assert
      expect(host.planName).assertEqual('plan_origin');
      expect(host.persistNameCalls).assertEqual(0);
    });

    it('conflict: is_date_conflict_should_return_true_when_target_before_plan_start', 0, () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      host.planStartDate = new Date(2026, 3, 12).getTime();
      const manager = new TimelinePlanStateManager(host);
      const targetDate = new Date(2026, 3, 11).getTime();
      // Act
      const conflict = manager.isDateConflict(targetDate);
      // Assert
      expect(conflict).assertTrue();
    });

    it('regression: td-20260412-c4-date-conflict-should-ignore-time-part-within-same-day', 0, () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      host.planStartDate = new Date(2026, 3, 12, 8, 0, 0).getTime();
      const manager = new TimelinePlanStateManager(host);
      const sameDayTarget = new Date(2026, 3, 12, 23, 59, 59).getTime();
      // Act
      const conflict = manager.isDateConflict(sameDayTarget);
      // Assert
      expect(conflict).assertFalse();
    });

    it('combined: resume_and_pause_should_both_fail_when_plan_id_invalid_without_side_effect', 0, () => {
      // Arrange
      const host = new FakeTimelinePlanStateHost();
      host.planId = 0;
      const manager = new TimelinePlanStateManager(host);
      // Act
      const paused = manager.pauseCurrentExecution();
      const resumed = manager.resumeCurrentExecution();
      // Assert
      expect(paused).assertFalse();
      expect(resumed).assertFalse();
      expect(host.recalculateCount).assertEqual(0);
      expect(host.executionWeatherAppliedSummary).assertEqual('');
    });
  });
}
