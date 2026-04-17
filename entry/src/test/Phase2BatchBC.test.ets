import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { PreferenceManager } from '../main/ets/common/utils/PreferenceManager';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { WeatherFacade } from '../main/ets/domain/services/WeatherFacade';
import { GeoPointInput, WeatherStageType, WeatherSuggestion } from '../main/ets/domain/services/WeatherModels';
import { EventRepositoryImpl } from '../main/ets/infrastructure/persistence/EventRepositoryImpl';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import { TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';
import { ScheduleOrchestrator } from '../main/ets/viewmodel/internal/ScheduleOrchestrator';
import { ITimelineCompanionHost, TimelineCompanionManager } from '../main/ets/viewmodel/managers/TimelineCompanionManager';
import { TimelineEventMutationManager, ITimelineEventMutationHost } from '../main/ets/viewmodel/managers/TimelineEventMutationManager';
import { TimelinePlanStateManager, ITimelinePlanStateHost } from '../main/ets/viewmodel/managers/TimelinePlanStateManager';
import { UserBehaviorTracker } from '../main/ets/domain/strategy/UserBehaviorTracker';
import { TimelineStrategyManager } from '../main/ets/viewmodel/managers/TimelineStrategyManager';
import { ReflowHint } from '../main/ets/viewmodel/types/TimelineTypes';

class StaticPatchBC {
  private readonly target: Object;
  private readonly key: string;
  private readonly origin: Object;

  constructor(target: Object, key: string, replacement: Object) {
    this.target = target;
    this.key = key;
    this.origin = Reflect.get(target, key) as Object;
    Reflect.set(target, key, replacement);
  }

  restore(): void {
    Reflect.set(this.target, this.key, this.origin);
  }
}

class FakePreferenceBC {
  enabled: boolean = true;
  threshold: number = 45;
  throwEnabled: boolean = false;
  throwThreshold: boolean = false;

  async getIdleGapDetectionEnabled(): Promise<boolean> {
    if (this.throwEnabled) {
      throw new Error('enabled_fail_bc');
    }
    return this.enabled;
  }

  async getIdleGapTriggerMinutes(): Promise<number> {
    if (this.throwThreshold) {
      throw new Error('threshold_fail_bc');
    }
    return this.threshold;
  }
}

class FakeCompanionStageBC {
  canPause: boolean = false;
  canResume: boolean = false;
}

class FakeCompanionMachineBC {
  stage: FakeCompanionStageBC = new FakeCompanionStageBC();

  getPlanStageViewModel(_planId: string): FakeCompanionStageBC {
    return this.stage;
  }
}

class FakeCompanionHostBC implements ITimelineCompanionHost {
  planId: number = 7;
  latestReflowHint: ReflowHint | null = null;
  planStateMachine: FakeCompanionMachineBC = new FakeCompanionMachineBC();
  private schedule: EventEntity[] = [];
  private readonly nextMap: Map<number, EventEntity> = new Map<number, EventEntity>();

  setSchedule(schedule: EventEntity[]): void {
    this.schedule = schedule;
  }

  setNext(afterId: number, next: EventEntity): void {
    this.nextMap.set(afterId, next);
  }

  getOrderedScheduleEvents(): EventEntity[] {
    return this.schedule;
  }

  getNextExecutableEvent(afterId: number, _schedule?: EventEntity[]): EventEntity | null {
    return this.nextMap.get(afterId) ?? null;
  }
}

class FakePlanStateMachineBC {
  status: PlanStatus = PlanStatus.DRAFT;
  executionContext: Object | null = null;
  updateExecutionContextCalls: number = 0;
  evaluateCalls: number = 0;
  markRecoveryCalls: string[] = [];
  lastUpdatePayload: Object | null = null;

  updateExecutionContext(payload: Object): void {
    this.updateExecutionContextCalls += 1;
    this.lastUpdatePayload = payload;
  }

  getExecutionContext(_planId: string): Object | null {
    return this.executionContext;
  }

  markRecovery(_planId: string, ok: boolean, reason: string): void {
    this.markRecoveryCalls.push(`${ok ? 'ok' : 'fail'}:${reason}`);
  }

  buildEvaluationInput(planId: string, _events: EventEntity[], now: number): Object {
    return { planId: planId, now: now };
  }

  evaluateAndApply(_input: Object): void {
    this.evaluateCalls += 1;
  }

  getPlanStatus(_planId: string): Object {
    return { status: this.status };
  }

  subscribePlanTransition(_planId: string, _listener: (event: Object) => void): () => void {
    return (): void => {};
  }

  subscribeLocationChange(_planId: string, _listener: (event: Object) => void): () => void {
    return (): void => {};
  }

  pauseExecution(_planId: string): Object {
    return { success: false, toStatus: PlanStatus.DRAFT };
  }

  resumeExecution(_planId: string): Object {
    return { success: false, toStatus: PlanStatus.DRAFT };
  }

  confirmPlan(_planId: string): void {
    return;
  }

  completeExecution(_planId: string): void {
    return;
  }
}

class FakePlanStateHostBC implements ITimelinePlanStateHost {
  planId: number = 10;
  planName: string = 'plan_bc';
  events: EventEntity[] = [];
  globalStartTime: string = '08:00';
  planStartDate: number = new Date(2026, 3, 17).getTime();
  idleGapDetectionEnabled: boolean = true;
  idleGapTriggerMinutes: number = 45;
  currentPlanStatus: PlanStatus = PlanStatus.DRAFT;
  weatherFeatureEnabled: boolean = false;
  executionWeatherEnabled: boolean = false;
  executionWeatherHint: string = '';
  executionWeatherSuggestions: WeatherSuggestion[] = [];
  executionWeatherAppliedSummary: string = '';
  executionWeatherLevel: 'INFO' | 'NOTICE' | 'WARNING' = 'INFO';
  weatherFacade: WeatherFacade = { resolveSchedulePolicy: (_stage: WeatherStageType): Object => ({ allowLocationTrigger: true }) } as WeatherFacade;
  planStateMachine: FakePlanStateMachineBC = new FakePlanStateMachineBC();
  persistDateCalls: number = 0;
  throwPersistDate: boolean = false;

  resolveCurrentWeatherStage(): WeatherStageType {
    return 'READY';
  }

  startExecutionWeatherScheduler(_planId?: number, _stage?: WeatherStageType): void {
    return;
  }

  stopExecutionWeatherScheduler(): void {
    return;
  }

  async refreshExecutionWeather(
    _forceRefresh?: boolean,
    _trigger?: 'ENTER_EXECUTION' | 'LOCATION_CHANGE' | 'TIMER' | 'MANUAL',
    _stage?: WeatherStageType
  ): Promise<void> {
    return;
  }

  getCompanionContext(_nowTs?: number): Object {
    return { runtimeState: 'IDLE' };
  }

  recalculateFromIndex(_startIndex: number): void {
    return;
  }

  getScheduleOrchestrator(): ScheduleOrchestrator {
    return new ScheduleOrchestrator();
  }

  isAutoRouteEnabled(): boolean {
    return false;
  }

  calculateRealtimeSchedule(): void {
    return;
  }

  regenerateGroups(): void {
    return;
  }

  markScheduleChanged(): void {
    return;
  }

  refreshTimelineView(): void {
    return;
  }

  async persistPlanStartDate(_planId: number, _startDate: number): Promise<void> {
    if (this.throwPersistDate) {
      throw new Error('persist_date_failed_bc');
    }
    this.persistDateCalls += 1;
  }

  async persistPlanName(_planId: number, _name: string): Promise<void> {
    return;
  }
}

class FakePointBC implements GeoPointInput {
  latitude: number = 0;
  longitude: number = 0;
}

class FakeMutationHostBC implements ITimelineEventMutationHost {
  events: EventEntity[] = [];
  planId: number = 1;
  enableAutoAmapRoute: boolean = true;
  enableGlobalAmapRouteApi: boolean = true;
  tryBeginMutationResult: boolean = true;
  throwUpdatePlanDate: boolean = false;
  refreshCalls: number = 0;
  saveCalls: number = 0;
  recalcFromEventIdCalls: number = 0;
  recalcFromIndexCalls: number = 0;
  updatePlanDateCalls: number = 0;
  endMutationCalls: number = 0;
  resolvedPoint: FakePointBC = new FakePointBC();

  isFirstScheduledItemOfDay(_item: EventEntity): boolean {
    return false;
  }

  async resolveCoordinatesForPlaceName(
    _placeName: string,
    lat?: number,
    lng?: number,
    _source?: 'add' | 'update',
    fallbackLat?: number,
    fallbackLng?: number
  ): Promise<GeoPointInput> {
    const point = new FakePointBC();
    point.latitude = Number.isFinite(this.resolvedPoint.latitude) ? this.resolvedPoint.latitude : (lat ?? fallbackLat ?? 0);
    point.longitude = Number.isFinite(this.resolvedPoint.longitude) ? this.resolvedPoint.longitude : (lng ?? fallbackLng ?? 0);
    return point;
  }

  isCoordinateMissingForWeather(latitude: number, longitude: number): boolean {
    return latitude === 0 || longitude === 0;
  }

  recalculateFromEventId(_eventId: number): void {
    this.recalcFromEventIdCalls += 1;
  }

  recalculateFromIndex(_startIndex: number): void {
    this.recalcFromIndexCalls += 1;
  }

  async save(): Promise<void> {
    this.saveCalls += 1;
  }

  async updatePlanDate(_newDateTimestamp: number): Promise<void> {
    if (this.throwUpdatePlanDate) {
      throw new Error('update_plan_date_fail_bc');
    }
    this.updatePlanDateCalls += 1;
  }

  tryBeginMutation(_itemId: number): boolean {
    return this.tryBeginMutationResult;
  }

  endMutation(_itemId: number): void {
    this.endMutationCalls += 1;
  }

  refreshTimelineView(): void {
    this.refreshCalls += 1;
  }
}

class FakeBehaviorTrackerBC extends UserBehaviorTracker {
}

class FakeStrategyManagerBC {
  adaptationCalls: number = 0;

  async triggerStrategyAdaptation(): Promise<void> {
    this.adaptationCalls += 1;
  }
}

function createEventBC(id: number, name: string, status: number = 1): EventEntity {
  const event = new EventEntity(name, 30);
  event.id = id;
  event.status = status;
  event.sort_order = id * 100;
  event.fixed_start_time = status === 1 ? '09:00' : '';
  event.computed_time = status === 1 ? '09:00' : '';
  event.day_offset = 0;
  event.dynamic_day_offset = 0;
  event.completion_status = EventEntity.STATE_PENDING;
  return event;
}

export default function phase2BatchBCTest() {
  describe('phase2BatchBCTest_timeline_viewmodel', () => {
    it('normal: set_filter_should_update_range_and_regenerate_groups', 0, () => {
      const vm = new TimelineViewModel();
      let regenerateCalls = 0;
      Reflect.set(vm as Object, 'generateGroups', (): void => { regenerateCalls += 1; });
      vm.setFilter(111, 222);
      expect(vm.filterStart).assertEqual(111);
      expect(vm.filterEnd).assertEqual(222);
      expect(regenerateCalls).assertEqual(1);
    });

    it('boundary: clear_filter_should_reset_range_to_zero', 0, () => {
      const vm = new TimelineViewModel();
      vm.filterStart = 99;
      vm.filterEnd = 199;
      vm.clearFilter();
      expect(vm.filterStart).assertEqual(0);
      expect(vm.filterEnd).assertEqual(0);
    });

    it('invalid: get_schedule_version_should_keep_default_zero_before_mark_changed', 0, () => {
      const vm = new TimelineViewModel();
      expect(vm.getScheduleVersion()).assertEqual(0);
    });

    it('normal: reload_idle_gap_settings_should_apply_preference_values', 0, async () => {
      const vm = new TimelineViewModel();
      const pref = new FakePreferenceBC();
      pref.enabled = false;
      pref.threshold = 30;
      const patch = new StaticPatchBC(PreferenceManager, 'getInstance', (): Object => pref as Object);
      try {
        await vm.reloadIdleGapSettings();
      } finally {
        patch.restore();
      }
      expect(vm.idleGapDetectionEnabled).assertFalse();
      expect(vm.idleGapTriggerMinutes).assertEqual(30);
    });

    it('boundary: reload_idle_gap_settings_should_normalize_out_of_range_threshold', 0, async () => {
      const vm = new TimelineViewModel();
      const pref = new FakePreferenceBC();
      pref.threshold = 9999;
      const patch = new StaticPatchBC(PreferenceManager, 'getInstance', (): Object => pref as Object);
      try {
        await vm.reloadIdleGapSettings();
      } finally {
        patch.restore();
      }
      expect(vm.idleGapTriggerMinutes > 0).assertTrue();
      expect(vm.idleGapTriggerMinutes < 9999).assertTrue();
    });

    it('invalid: reload_idle_gap_settings_should_fallback_to_default_when_preference_throws', 0, async () => {
      const vm = new TimelineViewModel();
      const pref = new FakePreferenceBC();
      pref.throwEnabled = true;
      const patch = new StaticPatchBC(PreferenceManager, 'getInstance', (): Object => pref as Object);
      try {
        await vm.reloadIdleGapSettings();
      } finally {
        patch.restore();
      }
      expect(vm.idleGapDetectionEnabled).assertTrue();
      expect(vm.idleGapTriggerMinutes).assertEqual(45);
    });

    it('normal: get_companion_context_should_delegate_to_companion_manager', 0, () => {
      const vm = new TimelineViewModel();
      const expected = { runtimeState: 'READY' };
      Reflect.set(vm as Object, 'companionManager', {
        getCompanionContext: (_nowTs: number): Object => expected,
        getRealActiveEvent: (_schedule?: EventEntity[]): EventEntity | null => null
      });
      const context = vm.getCompanionContext(123);
      expect(String((context as Object as Record<string, Object>)['runtimeState'])).assertEqual('READY');
    });

    it('boundary: get_real_active_event_should_forward_explicit_schedule_argument', 0, () => {
      const vm = new TimelineViewModel();
      const active = createEventBC(88, 'active_bc');
      Reflect.set(vm as Object, 'companionManager', {
        getCompanionContext: (_nowTs: number): Object => ({ runtimeState: 'IDLE' }),
        getRealActiveEvent: (schedule?: EventEntity[]): EventEntity | null => schedule && schedule.length > 0 ? schedule[0] : null
      });
      const picked = vm.getRealActiveEvent([active]);
      expect(picked?.id ?? -1).assertEqual(88);
    });

    it('invalid: get_companion_context_should_propagate_delegate_error', 0, () => {
      const vm = new TimelineViewModel();
      Reflect.set(vm as Object, 'companionManager', {
        getCompanionContext: (_nowTs: number): Object => { throw new Error('companion_context_fail_bc'); },
        getRealActiveEvent: (_schedule?: EventEntity[]): EventEntity | null => null
      });
      let message = '';
      try {
        vm.getCompanionContext();
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message).assertEqual('companion_context_fail_bc');
    });
  });

  describe('phase2BatchBCTest_timeline_plan_state_manager', () => {
    it('normal: on_location_sample_should_update_execution_context_for_valid_coordinate', 0, () => {
      const host = new FakePlanStateHostBC();
      const manager = new TimelinePlanStateManager(host);
      manager.onLocationSampleForStateMachine(30.1, 120.2, 2, 15, 100);
      expect(host.planStateMachine.updateExecutionContextCalls).assertEqual(1);
    });

    it('boundary: on_location_sample_should_keep_only_latest_three_samples', 0, () => {
      const host = new FakePlanStateHostBC();
      const manager = new TimelinePlanStateManager(host);
      manager.onLocationSampleForStateMachine(30.1, 120.1, 1, 10, 100);
      manager.onLocationSampleForStateMachine(30.2, 120.2, 1, 10, 200);
      manager.onLocationSampleForStateMachine(30.3, 120.3, 1, 10, 300);
      manager.onLocationSampleForStateMachine(30.4, 120.4, 1, 10, 400);
      const samples = Reflect.get(manager as Object, 'runtimeMotionSamples') as Object[];
      expect(samples.length).assertEqual(3);
    });

    it('invalid: on_location_sample_should_ignore_nan_coordinate', 0, () => {
      const host = new FakePlanStateHostBC();
      const manager = new TimelinePlanStateManager(host);
      manager.onLocationSampleForStateMachine(Number.NaN, 120.2, 2, 15, 100);
      expect(host.planStateMachine.updateExecutionContextCalls).assertEqual(0);
    });

    it('normal: recover_runtime_state_should_mark_partial_context_and_restore', 0, () => {
      const host = new FakePlanStateHostBC();
      host.planStateMachine.executionContext = {
        plannedEndTime: Date.now() + 10000,
        status: PlanStatus.IN_PROGRESS,
        currentNodeId: ''
      };
      host.planStateMachine.status = PlanStatus.IN_PROGRESS;
      const manager = new TimelinePlanStateManager(host);
      manager.recoverPlanRuntimeState();
      expect(host.planStateMachine.markRecoveryCalls.indexOf('fail:context_partial') >= 0).assertTrue();
      expect(host.planStateMachine.markRecoveryCalls[host.planStateMachine.markRecoveryCalls.length - 1]).assertEqual('ok:context_restored');
    });

    it('boundary: update_plan_date_should_skip_persist_when_plan_id_is_minus_one', 0, async () => {
      const host = new FakePlanStateHostBC();
      host.planId = -1;
      const manager = new TimelinePlanStateManager(host);
      await manager.updatePlanDate(new Date(2026, 3, 18, 10, 20).getTime());
      expect(host.persistDateCalls).assertEqual(0);
    });

    it('invalid: update_plan_date_should_propagate_persist_error', 0, async () => {
      const host = new FakePlanStateHostBC();
      host.throwPersistDate = true;
      const manager = new TimelinePlanStateManager(host);
      let message = '';
      try {
        await manager.updatePlanDate(new Date(2026, 3, 19).getTime());
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message).assertEqual('persist_date_failed_bc');
    });
  });

  describe('phase2BatchBCTest_timeline_event_mutation_manager', () => {
    it('normal: move_to_backlog_should_demote_schedule_item', 0, async () => {
      const host = new FakeMutationHostBC();
      const target = createEventBC(201, 'to_backlog', 1);
      host.events = [target];
      const manager = new TimelineEventMutationManager(host, new FakeBehaviorTrackerBC(), new FakeStrategyManagerBC() as Object as TimelineStrategyManager);
      await manager.moveToBacklog(target);
      expect(target.status).assertEqual(0);
      expect(host.saveCalls).assertEqual(1);
      expect(host.endMutationCalls).assertEqual(1);
    });

    it('boundary: update_event_info_should_keep_old_coordinates_when_resolved_point_missing', 0, async () => {
      const host = new FakeMutationHostBC();
      const target = createEventBC(202, 'origin', 1);
      target.latitude = 31.2;
      target.longitude = 121.5;
      host.events = [target];
      host.resolvedPoint.latitude = 0;
      host.resolvedPoint.longitude = 0;
      const patch = new StaticPatchBC(EventRepositoryImpl, 'updateFields', async (): Promise<void> => {});
      const manager = new TimelineEventMutationManager(host, new FakeBehaviorTrackerBC(), new FakeStrategyManagerBC() as Object as TimelineStrategyManager);
      try {
        await manager.updateEventInfo(202, 'origin', 30);
      } finally {
        patch.restore();
      }
      expect(target.latitude).assertEqual(31.2);
      expect(target.longitude).assertEqual(121.5);
    });

    it('invalid: move_to_backlog_should_throw_for_invalid_item', 0, async () => {
      const host = new FakeMutationHostBC();
      const manager = new TimelineEventMutationManager(host, new FakeBehaviorTrackerBC(), new FakeStrategyManagerBC() as Object as TimelineStrategyManager);
      let message = '';
      try {
        await manager.moveToBacklog({ id: 0 } as TravelPlanItem);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message.indexOf('invalid_item') >= 0).assertTrue();
    });

    it('normal: resolve_conflict_by_moving_plan_should_update_plan_date_then_update_event', 0, async () => {
      const host = new FakeMutationHostBC();
      const target = createEventBC(203, 'target_bc', 1);
      host.events = [target];
      const patchA = new StaticPatchBC(EventRepositoryImpl, 'updateFields', async (): Promise<void> => {});
      const patchB = new StaticPatchBC(EventRepositoryImpl, 'updateTimelineConsistency', async (): Promise<void> => {});
      const manager = new TimelineEventMutationManager(host, new FakeBehaviorTrackerBC(), new FakeStrategyManagerBC() as Object as TimelineStrategyManager);
      try {
        await manager.resolveConflictByMovingPlan(203, new Date(2026, 3, 20).getTime(), 'renamed_bc', 60, true, '10:00');
      } finally {
        patchA.restore();
        patchB.restore();
      }
      expect(host.updatePlanDateCalls).assertEqual(1);
      expect(target.name).assertEqual('renamed_bc');
    });

    it('boundary: hard_delete_should_throw_when_mutation_is_locked', 0, async () => {
      const host = new FakeMutationHostBC();
      host.tryBeginMutationResult = false;
      const target = createEventBC(204, 'locked_bc', 1);
      host.events = [target];
      const manager = new TimelineEventMutationManager(host, new FakeBehaviorTrackerBC(), new FakeStrategyManagerBC() as Object as TimelineStrategyManager);
      let message = '';
      try {
        await manager.hardDelete(target);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message.indexOf('mutation_in_flight') >= 0).assertTrue();
    });

    it('invalid: resolve_conflict_by_moving_plan_should_propagate_plan_date_error', 0, async () => {
      const host = new FakeMutationHostBC();
      host.throwUpdatePlanDate = true;
      const manager = new TimelineEventMutationManager(host, new FakeBehaviorTrackerBC(), new FakeStrategyManagerBC() as Object as TimelineStrategyManager);
      let message = '';
      try {
        await manager.resolveConflictByMovingPlan(-1, new Date(2026, 3, 21).getTime(), 'new_bc', 60, true, '10:00');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message).assertEqual('update_plan_date_fail_bc');
    });
  });

  describe('phase2BatchBCTest_timeline_companion_manager', () => {
    it('normal: get_real_active_event_should_prefer_active_event', 0, () => {
      const active = createEventBC(301, 'active', 1);
      active.actual_start_time = Date.now() - 1000;
      const pending = createEventBC(302, 'pending', 1);
      pending.dynamic_end_time = Date.now() + 60000;
      const host = new FakeCompanionHostBC();
      host.setSchedule([pending, active]);
      const manager = new TimelineCompanionManager(host);
      const event = manager.getRealActiveEvent();
      expect(event?.id ?? -1).assertEqual(301);
    });

    it('boundary: get_companion_context_should_generate_overdue_ready_hint', 0, () => {
      const pending = createEventBC(303, 'overdue_ready', 1);
      const nowTs = Date.now();
      pending.dynamic_start_time = nowTs - 10 * 60 * 1000;
      const host = new FakeCompanionHostBC();
      host.setSchedule([pending]);
      const manager = new TimelineCompanionManager(host);
      const context = manager.getCompanionContext(nowTs);
      expect(context.runtimeState).assertEqual('READY');
      expect((context.hint?.message || '').length > 0).assertTrue();
    });

    it('invalid: get_real_active_event_should_return_null_when_pending_window_expired', 0, () => {
      const pending = createEventBC(304, 'expired_pending', 1);
      pending.dynamic_end_time = Date.now() - 1;
      const host = new FakeCompanionHostBC();
      host.setSchedule([pending]);
      const manager = new TimelineCompanionManager(host);
      const event = manager.getRealActiveEvent();
      expect(event === null).assertTrue();
    });
  });
}
