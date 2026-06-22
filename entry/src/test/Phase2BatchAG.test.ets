import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import {
  TimelineCalculationService
} from '../main/ets/domain/timeline/services/TimelineCalculationService';
import { TimelineConflictResolver } from '../main/ets/domain/timeline/services/TimelineConflictResolver';
import {
  ITimelineCompressionHost,
  CompressionPlan,
  TimelineCompressionService
} from '../main/ets/domain/timeline/services/TimelineCompressionService';
import {
  ITimelineDistributionHost,
  TimelineDistributionService
} from '../main/ets/domain/timeline/services/TimelineDistributionService';
import { EventRepositoryImpl } from '../main/ets/infrastructure/persistence/EventRepositoryImpl';
import { ScheduleOrchestrator } from '../main/ets/viewmodel/internal/ScheduleOrchestrator';
import { TimelineCalculateOptions } from '../main/ets/domain/solver/TimeConstraintSolver';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';

interface OrchestratorCalculatedItemForAG {
  preTravelMinutes?: number;
  computedStartTime?: string;
  dynamicDayOffset?: number;
  dayOffset?: number;
}

interface OrchestratorCallForAG {
  globalStart: string;
  planStartDate: number;
  options: TimelineCalculateOptions;
}

interface RepoUpdateRecordForAG {
  id: number;
  column: string;
  value: Object;
  planIdHint?: number;
}

interface ConflictFixCallForAG {
  itemId: number;
  shiftMinutes: number;
  planId: number;
}

interface CompressionServiceBundleForAG {
  host: CompressionHostMockForAG;
  service: TimelineCompressionService;
}

interface DistributionServiceBundleForAG {
  host: DistributionHostMockForAG;
  service: TimelineDistributionService;
}

class TimelineOptionsForAG implements TimelineCalculateOptions {
  autoRouteEnabled?: boolean = true;
  idleGapDetectionEnabled?: boolean = true;
  idleGapTriggerMinutes?: number = 30;
  startFromEventId?: number = -1;
  slackRatio?: number = 0.25;
}

class OrchestratorMockForAG {
  calculated: OrchestratorCalculatedItemForAG[] = [];
  calls: OrchestratorCallForAG[] = [];

  calculate(_events: TravelPlanItem[], globalStart: string, planStartDate: number, options: TimelineCalculateOptions): OrchestratorCalculatedItemForAG[] {
    this.calls.push({ globalStart, planStartDate, options });
    return this.calculated;
  }
}

class RepoHooksForAG {
  private readonly originUpdateSingleField: Object;
  updates: RepoUpdateRecordForAG[] = [];

  constructor() {
    this.originUpdateSingleField = Reflect.get(EventRepositoryImpl, 'updateSingleField') as Object;
  }

  attachSuccess(): void {
    Reflect.set(
      EventRepositoryImpl,
      'updateSingleField',
      async (id: number, column: string, value: Object, planIdHint?: number): Promise<void> => {
        this.updates.push({ id, column, value, planIdHint });
      }
    );
  }

  restore(): void {
    Reflect.set(EventRepositoryImpl, 'updateSingleField', this.originUpdateSingleField);
  }
}

class ConflictResolverHooksForAG {
  private readonly originFixConflict: Object;
  calls: ConflictFixCallForAG[] = [];
  result: boolean = true;

  constructor() {
    this.originFixConflict = Reflect.get(TimelineConflictResolver, 'fixConflict') as Object;
  }

  attach(): void {
    Reflect.set(
      TimelineConflictResolver,
      'fixConflict',
      async (_events: EventEntity[], itemId: number, shiftMinutes: number, planId: number): Promise<boolean> => {
        this.calls.push({ itemId, shiftMinutes, planId });
        return this.result;
      }
    );
  }

  restore(): void {
    Reflect.set(TimelineConflictResolver, 'fixConflict', this.originFixConflict);
  }
}

class CompressionHostMockForAG implements ITimelineCompressionHost {
  events: EventEntity[] = [];
  planId: number = 100;
  globalStartTime: string = '08:00';
  minDurationLimit: number = 20;
  recalculateFromEventIdCalls: number[] = [];
  recalculateFromIndexCalls: number[] = [];
  markHasUnsavedPostponeCalls: number = 0;

  getMinEventDurationLimit(): number {
    return this.minDurationLimit;
  }

  getEffectiveDayOffset(item: EventEntity): number {
    return item.dynamic_day_offset || item.day_offset;
  }

  resolveEffectiveGlobalStartMinutes(): number {
    return 8 * 60;
  }

  recalculateFromEventId(eventId: number): void {
    this.recalculateFromEventIdCalls.push(eventId);
  }

  recalculateFromIndex(startIndex: number): void {
    this.recalculateFromIndexCalls.push(startIndex);
  }

  markHasUnsavedPostpone(): void {
    this.markHasUnsavedPostponeCalls += 1;
  }
}

class DistributionHostMockForAG implements ITimelineDistributionHost {
  events: EventEntity[] = [];
  planId: number = 200;
  idleGapDetectionEnabled: boolean = true;
  idleGapTriggerMinutes: number = 20;
  recalculateFromIndexCalls: number[] = [];
  updateEventInfoCalls: number = 0;
  naturalArrivalMap: Map<number, number> = new Map<number, number>();

  getEffectiveDayOffset(item: EventEntity): number {
    return item.dynamic_day_offset || item.day_offset;
  }

  getOrderedScheduleEvents(): EventEntity[] {
    return this.events
      .filter((item: EventEntity) => item.status === 1)
      .sort((a: EventEntity, b: EventEntity) => a.sort_order - b.sort_order);
  }

  getOrderedScheduleIndexById(eventId: number, schedule?: EventEntity[]): number {
    const src = schedule ?? this.getOrderedScheduleEvents();
    return src.findIndex((item: EventEntity) => item.id === eventId);
  }

  isFirstScheduledItemOfDay(item: EventEntity): boolean {
    const schedule = this.getOrderedScheduleEvents().filter((e: EventEntity) => this.getEffectiveDayOffset(e) === this.getEffectiveDayOffset(item));
    return schedule.length > 0 && schedule[0].id === item.id;
  }

  _calculateNaturalArrival(targetIndex: number): number {
    return this.naturalArrivalMap.get(targetIndex) ?? 0;
  }

  recalculateFromIndex(startIndex: number): void {
    this.recalculateFromIndexCalls.push(startIndex);
  }

  async updateEventInfo(
    _id: number,
    _name: string,
    _duration: number,
    _fixedTime?: string,
    _dayOffset?: number
  ): Promise<void> {
    this.updateEventInfoCalls += 1;
  }
}

function createEventForAG(id: number, name: string, dayOffset: number = 0): EventEntity {
  const e = new EventEntity(name, 1);
  e.id = id;
  e.name = name;
  e.status = 1;
  e.day_offset = dayOffset;
  e.dynamic_day_offset = dayOffset;
  e.duration = 60;
  e.sort_order = id * 100;
  e.lock_status = 0;
  e.priority = 0;
  e.pre_travel_min = 0;
  e.computed_time = '';
  e.fixed_start_time = '';
  e.gap_minutes = 0;
  e.has_gap = false;
  return e;
}

function createCalculatedItemForAG(): OrchestratorCalculatedItemForAG {
  const item: OrchestratorCalculatedItemForAG = { dayOffset: 0 };
  return item;
}

function createCompressionServiceForAG(events: EventEntity[]): CompressionServiceBundleForAG {
  const host = new CompressionHostMockForAG();
  host.events = events;
  return { host, service: new TimelineCompressionService(host) };
}

function createDistributionServiceForAG(events: EventEntity[]): DistributionServiceBundleForAG {
  const host = new DistributionHostMockForAG();
  host.events = events;
  return { host, service: new TimelineDistributionService(host) };
}

export default function phase2BatchAGTest() {
  describe('phase2BatchAGTest', () => {
    it('normal: calculation_recalculate_should_apply_all_items_and_collect_change_flags', 0, () => {
      // Arrange
      const events = [createEventForAG(1, 'a'), createEventForAG(2, 'b')];
      const orchestrator = new OrchestratorMockForAG();
      orchestrator.calculated = [createCalculatedItemForAG(), createCalculatedItemForAG()];
      const options = new TimelineOptionsForAG();
      let applyCount = 0;
      // Act
      const result = TimelineCalculationService.recalculate(
        events,
        '2026-04-15 09:30',
        100,
        orchestrator as Object as ScheduleOrchestrator,
        options,
        (_entity: EventEntity, _item: Object | undefined) => {
          applyCount += 1;
          return { changed: applyCount === 1, dayOffsetChanged: applyCount === 2 };
        }
      );
      // Assert
      expect(orchestrator.calls.length).assertEqual(1);
      expect(orchestrator.calls[0].globalStart).assertEqual('09:30');
      expect(applyCount).assertEqual(2);
      expect(result.hasFieldChanged).assertTrue();
      expect(result.hasDayOffsetChanged).assertTrue();
    });

    it('boundary: calculation_recalculate_should_fallback_to_default_start_when_time_invalid', 0, () => {
      // Arrange
      const events = [createEventForAG(1, 'a')];
      const orchestrator = new OrchestratorMockForAG();
      const options = new TimelineOptionsForAG();
      // Act
      const result = TimelineCalculationService.recalculate(
        events,
        'invalid-time',
        200,
        orchestrator as Object as ScheduleOrchestrator,
        options,
        () => ({ changed: false, dayOffsetChanged: false })
      );
      // Assert
      expect(orchestrator.calls[0].globalStart).assertEqual('08:00');
      expect(result.hasFieldChanged).assertFalse();
      expect(result.hasDayOffsetChanged).assertFalse();
    });

    it('invalid: calculation_recalculate_should_tolerate_empty_event_list', 0, () => {
      // Arrange
      const events: EventEntity[] = [];
      const orchestrator = new OrchestratorMockForAG();
      const options = new TimelineOptionsForAG();
      // Act
      const result = TimelineCalculationService.recalculate(
        events,
        '08:30',
        300,
        orchestrator as Object as ScheduleOrchestrator,
        options,
        () => ({ changed: true, dayOffsetChanged: true })
      );
      // Assert
      expect(orchestrator.calls.length).assertEqual(1);
      expect(result.hasFieldChanged).assertFalse();
      expect(result.hasDayOffsetChanged).assertFalse();
    });

    it('normal: calculation_recalculate_from_index_should_only_apply_from_start_index', 0, () => {
      // Arrange
      const events = [createEventForAG(1, 'a'), createEventForAG(2, 'b'), createEventForAG(3, 'c')];
      const orchestrator = new OrchestratorMockForAG();
      orchestrator.calculated = [createCalculatedItemForAG(), createCalculatedItemForAG(), createCalculatedItemForAG()];
      const calledIds: number[] = [];
      // Act
      const result = TimelineCalculationService.recalculateFromIndex(
        events,
        1,
        '09:00',
        400,
        orchestrator as Object as ScheduleOrchestrator,
        new TimelineOptionsForAG(),
        (entity: EventEntity) => {
          calledIds.push(entity.id);
          return { changed: entity.id === 2, dayOffsetChanged: false };
        }
      );
      // Assert
      expect(calledIds.length).assertEqual(2);
      expect(calledIds[0]).assertEqual(2);
      expect(calledIds[1]).assertEqual(3);
      expect(result.hasFieldChanged).assertTrue();
      expect(result.hasDayOffsetChanged).assertFalse();
    });

    it('boundary: calculation_recalculate_from_index_should_clamp_negative_start_to_zero', 0, () => {
      // Arrange
      const events = [createEventForAG(1, 'a'), createEventForAG(2, 'b')];
      const calledIds: number[] = [];
      // Act
      TimelineCalculationService.recalculateFromIndex(
        events,
        -5,
        '08:00',
        500,
        new OrchestratorMockForAG() as Object as ScheduleOrchestrator,
        new TimelineOptionsForAG(),
        (entity: EventEntity) => {
          calledIds.push(entity.id);
          return { changed: false, dayOffsetChanged: false };
        }
      );
      // Assert
      expect(calledIds.length).assertEqual(2);
    });

    it('invalid: calculation_recalculate_from_index_should_ignore_out_of_range_start', 0, () => {
      // Arrange
      const events = [createEventForAG(1, 'a')];
      let called = 0;
      // Act
      const result = TimelineCalculationService.recalculateFromIndex(
        events,
        10,
        '08:00',
        600,
        new OrchestratorMockForAG() as Object as ScheduleOrchestrator,
        new TimelineOptionsForAG(),
        () => {
          called += 1;
          return { changed: true, dayOffsetChanged: true };
        }
      );
      // Assert
      expect(called).assertEqual(0);
      expect(result.hasFieldChanged).assertFalse();
      expect(result.hasDayOffsetChanged).assertFalse();
    });

    it('boundary: calculation_recalculate_from_index_should_fallback_to_default_start_when_time_invalid', 0, () => {
      // Arrange
      const events = [createEventForAG(1, 'a')];
      const orchestrator = new OrchestratorMockForAG();
      // Act
      TimelineCalculationService.recalculateFromIndex(
        events,
        0,
        'bad-time',
        601,
        orchestrator as Object as ScheduleOrchestrator,
        new TimelineOptionsForAG(),
        () => ({ changed: false, dayOffsetChanged: false })
      );
      // Assert
      expect(orchestrator.calls.length).assertEqual(1);
      expect(orchestrator.calls[0].globalStart).assertEqual('08:00');
    });

    it('boundary: calculation_recalculate_from_index_should_collect_day_offset_change_flag', 0, () => {
      // Arrange
      const events = [createEventForAG(1, 'a'), createEventForAG(2, 'b')];
      const orchestrator = new OrchestratorMockForAG();
      orchestrator.calculated = [createCalculatedItemForAG(), createCalculatedItemForAG()];
      // Act
      const result = TimelineCalculationService.recalculateFromIndex(
        events,
        1,
        '08:30',
        602,
        orchestrator as Object as ScheduleOrchestrator,
        new TimelineOptionsForAG(),
        (entity: EventEntity) => ({ changed: false, dayOffsetChanged: entity.id === 2 })
      );
      // Assert
      expect(result.hasFieldChanged).assertFalse();
      expect(result.hasDayOffsetChanged).assertTrue();
    });

    it('normal: calculation_recalculate_traffic_only_should_update_fields_and_persist_pretravel', 0, () => {
      // Arrange
      const event = createEventForAG(1, 'a');
      event.pre_travel_min = 10;
      event.computed_time = '08:00';
      const orchestrator = new OrchestratorMockForAG();
      orchestrator.calculated = [{ preTravelMinutes: 25, computedStartTime: '09:00', dynamicDayOffset: 1 }];
      const persisted: number[] = [];
      // Act
      const result = TimelineCalculationService.recalculateTrafficOnly(
        [event],
        '08:00',
        700,
        orchestrator as Object as ScheduleOrchestrator,
        new TimelineOptionsForAG(),
        (_entity: EventEntity, minutes: number) => {
          persisted.push(minutes);
        }
      );
      // Assert
      expect(event.pre_travel_min).assertEqual(25);
      expect(event.computed_time).assertEqual('09:00');
      expect(event.dynamic_day_offset).assertEqual(1);
      expect(persisted.length).assertEqual(1);
      expect(result.hasFieldChanged).assertTrue();
      expect(result.hasDayOffsetChanged).assertTrue();
    });

    it('boundary: calculation_recalculate_traffic_only_should_skip_when_result_missing', 0, () => {
      // Arrange
      const event = createEventForAG(1, 'a');
      const orchestrator = new OrchestratorMockForAG();
      orchestrator.calculated = [];
      let persisted = 0;
      // Act
      const result = TimelineCalculationService.recalculateTrafficOnly(
        [event],
        '08:00',
        701,
        orchestrator as Object as ScheduleOrchestrator,
        new TimelineOptionsForAG(),
        () => {
          persisted += 1;
        }
      );
      // Assert
      expect(persisted).assertEqual(0);
      expect(result.hasFieldChanged).assertFalse();
      expect(result.hasDayOffsetChanged).assertFalse();
    });

    it('invalid: calculation_recalculate_traffic_only_should_keep_values_when_result_has_no_effective_changes', 0, () => {
      // Arrange
      const event = createEventForAG(1, 'a');
      event.pre_travel_min = 20;
      event.computed_time = '10:00';
      event.dynamic_day_offset = 2;
      const orchestrator = new OrchestratorMockForAG();
      orchestrator.calculated = [{ dayOffset: 2 }];
      // Act
      const result = TimelineCalculationService.recalculateTrafficOnly(
        [event],
        '08:00',
        702,
        orchestrator as Object as ScheduleOrchestrator,
        new TimelineOptionsForAG(),
        (_entity: EventEntity, _minutes: number) => { return; }
      );
      // Assert
      expect(event.pre_travel_min).assertEqual(20);
      expect(event.computed_time).assertEqual('10:00');
      expect(event.dynamic_day_offset).assertEqual(2);
      expect(result.hasFieldChanged).assertFalse();
      expect(result.hasDayOffsetChanged).assertFalse();
    });

    it('boundary: calculation_recalculate_traffic_only_should_fallback_to_day_offset_when_dynamic_day_offset_missing', 0, () => {
      // Arrange
      const event = createEventForAG(1, 'a');
      event.dynamic_day_offset = 0;
      const orchestrator = new OrchestratorMockForAG();
      orchestrator.calculated = [{ dayOffset: 3 }];
      // Act
      const result = TimelineCalculationService.recalculateTrafficOnly(
        [event],
        '08:00',
        703,
        orchestrator as Object as ScheduleOrchestrator,
        new TimelineOptionsForAG(),
        (_entity: EventEntity, _minutes: number) => { return; }
      );
      // Assert
      expect(event.dynamic_day_offset).assertEqual(3);
      expect(result.hasFieldChanged).assertTrue();
      expect(result.hasDayOffsetChanged).assertTrue();
    });

    it('boundary: calculation_recalculate_traffic_only_should_fallback_to_default_start_when_time_invalid', 0, () => {
      // Arrange
      const event = createEventForAG(1, 'a');
      const orchestrator = new OrchestratorMockForAG();
      orchestrator.calculated = [{ dayOffset: event.day_offset }];
      // Act
      TimelineCalculationService.recalculateTrafficOnly(
        [event],
        'bad-time',
        704,
        orchestrator as Object as ScheduleOrchestrator,
        new TimelineOptionsForAG(),
        (_entity: EventEntity, _minutes: number) => { return; }
      );
      // Assert
      expect(orchestrator.calls.length).assertEqual(1);
      expect(orchestrator.calls[0].globalStart).assertEqual('08:00');
    });

    it('normal: conflict_resolver_is_date_conflict_should_return_true_for_earlier_day', 0, () => {
      // Arrange
      const planStartDate = new Date('2026-04-15T10:00:00').getTime();
      const targetDateMs = new Date('2026-04-14T23:00:00').getTime();
      // Act
      const conflict = TimelineConflictResolver.isDateConflict(targetDateMs, planStartDate);
      // Assert
      expect(conflict).assertTrue();
    });

    it('boundary: conflict_resolver_is_date_conflict_should_return_false_when_plan_start_invalid', 0, () => {
      // Arrange
      const targetDateMs = Date.now();
      // Act
      const conflict = TimelineConflictResolver.isDateConflict(targetDateMs, 0);
      // Assert
      expect(conflict).assertFalse();
    });

    it('invalid: conflict_resolver_is_date_conflict_should_return_false_for_nan_target', 0, () => {
      // Arrange
      // Act
      const conflict = TimelineConflictResolver.isDateConflict(Number.NaN, Date.now());
      // Assert
      expect(conflict).assertFalse();
    });

    it('normal: conflict_resolver_fix_conflict_should_update_time_and_persist', 0, async () => {
      // Arrange
      const hooks = new RepoHooksForAG();
      hooks.attachSuccess();
      const event = createEventForAG(10, 'target');
      event.fixed_start_time = '10:00';
      // Act
      const success = await TimelineConflictResolver.fixConflict([event], 10, 15, 9);
      hooks.restore();
      // Assert
      expect(success).assertTrue();
      expect(event.fixed_start_time).assertEqual('10:15');
      expect(hooks.updates.length).assertEqual(1);
      expect(hooks.updates[0].column).assertEqual('fixed_start_time');
    });

    it('boundary: conflict_resolver_fix_conflict_should_skip_persist_when_target_id_is_zero', 0, async () => {
      // Arrange
      const hooks = new RepoHooksForAG();
      hooks.attachSuccess();
      const event = createEventForAG(0, 'target');
      event.fixed_start_time = '11:00';
      // Act
      const success = await TimelineConflictResolver.fixConflict([event], 0, 30, 9);
      hooks.restore();
      // Assert
      expect(success).assertTrue();
      expect(event.fixed_start_time).assertEqual('11:30');
      expect(hooks.updates.length).assertEqual(0);
    });

    it('invalid: conflict_resolver_fix_conflict_should_return_false_when_target_not_found_or_missing_fixed_time', 0, async () => {
      // Arrange
      const event = createEventForAG(1, 'a');
      event.fixed_start_time = '';
      // Act
      const a = await TimelineConflictResolver.fixConflict([event], 1, 10, 1);
      const b = await TimelineConflictResolver.fixConflict([event], 999, 10, 1);
      // Assert
      expect(a).assertFalse();
      expect(b).assertFalse();
    });

    it('normal: compression_fix_conflict_should_recalculate_when_resolver_updates', 0, async () => {
      // Arrange
      const hooks = new ConflictResolverHooksForAG();
      hooks.result = true;
      hooks.attach();
      const event = createEventForAG(1, 'a');
      const bundle = createCompressionServiceForAG([event]);
      // Act
      await bundle.service.fixConflict(event, 20);
      hooks.restore();
      // Assert
      expect(hooks.calls.length).assertEqual(1);
      expect(bundle.host.recalculateFromEventIdCalls.length).assertEqual(1);
      expect(bundle.host.recalculateFromEventIdCalls[0]).assertEqual(1);
    });

    it('boundary: compression_fix_conflict_should_pass_zero_id_when_item_id_missing', 0, async () => {
      // Arrange
      const hooks = new ConflictResolverHooksForAG();
      hooks.result = true;
      hooks.attach();
      const event = createEventForAG(0, 'a');
      const bundle = createCompressionServiceForAG([event]);
      // Act
      await bundle.service.fixConflict(event, 5);
      hooks.restore();
      // Assert
      expect(hooks.calls[0].itemId).assertEqual(0);
      expect(bundle.host.recalculateFromEventIdCalls[0]).assertEqual(0);
    });

    it('invalid: compression_fix_conflict_should_not_recalculate_when_resolver_returns_false', 0, async () => {
      // Arrange
      const hooks = new ConflictResolverHooksForAG();
      hooks.result = false;
      hooks.attach();
      const event = createEventForAG(2, 'b');
      const bundle = createCompressionServiceForAG([event]);
      // Act
      await bundle.service.fixConflict(event, 10);
      hooks.restore();
      // Assert
      expect(bundle.host.recalculateFromEventIdCalls.length).assertEqual(0);
    });

    it('normal: compression_smart_fix_conflict_should_apply_plan_and_mark_unsaved_when_confirm', 0, async () => {
      // Arrange
      const a = createEventForAG(1, 'a');
      a.duration = 120;
      const target = createEventForAG(2, 'target');
      target.is_conflict = true;
      target.lock_status = 1;
      target.fixed_start_time = '10:00';
      target.pre_travel_min = 60;
      const bundle = createCompressionServiceForAG([a, target]);
      // Act
      await bundle.service.smartFixConflict(target);
      // Assert
      expect(bundle.host.markHasUnsavedPostponeCalls).assertEqual(1);
      expect(a.duration < 120).assertTrue();
    });

    it('boundary: compression_smart_fix_conflict_should_mark_unsaved_on_no_action', 0, async () => {
      // Arrange
      const a = createEventForAG(1, 'a');
      const target = createEventForAG(2, 'target');
      target.is_conflict = true;
      target.lock_status = 1;
      target.fixed_start_time = '10:00';
      target.pre_travel_min = 0;
      target.gap_minutes = 0;
      const bundle = createCompressionServiceForAG([a, target]);
      // Act
      await bundle.service.smartFixConflict(target);
      // Assert
      expect(bundle.host.markHasUnsavedPostponeCalls).assertEqual(1);
    });

    it('invalid: compression_smart_fix_conflict_should_ignore_non_conflict_or_missing_item', 0, async () => {
      // Arrange
      const target = createEventForAG(2, 'target');
      target.is_conflict = false;
      const bundle = createCompressionServiceForAG([]);
      // Act
      await bundle.service.smartFixConflict(target);
      // Assert
      expect(bundle.host.markHasUnsavedPostponeCalls).assertEqual(0);
      expect(bundle.host.recalculateFromIndexCalls.length).assertEqual(0);
    });

    it('normal: compression_calculate_compression_plan_should_return_confirm_when_gap_can_be_reduced', 0, () => {
      // Arrange
      const a = createEventForAG(1, 'a');
      a.duration = 120;
      const target = createEventForAG(2, 'target');
      target.pre_travel_min = 80;
      const bundle = createCompressionServiceForAG([a, target]);
      // Act
      const plan = bundle.service.calculateCompressionPlan(1, '08:00');
      // Assert
      expect(plan.status === 'COMPRESS_CONFIRM' || plan.status === 'OVERLOAD').assertTrue();
    });

    it('boundary: compression_calculate_compression_plan_should_return_no_action_when_needed_gap_not_positive', 0, () => {
      // Arrange
      const a = createEventForAG(1, 'a');
      const target = createEventForAG(2, 'target');
      target.pre_travel_min = 0;
      const bundle = createCompressionServiceForAG([a, target]);
      // Act
      const plan = bundle.service.calculateCompressionPlan(1, '09:00');
      // Assert
      expect(plan.status).assertEqual('NO_ACTION');
    });

    it('invalid: compression_calculate_compression_plan_should_return_no_action_for_invalid_target_index', 0, () => {
      // Arrange
      const bundle = createCompressionServiceForAG([createEventForAG(1, 'a')]);
      // Act
      const plan = bundle.service.calculateCompressionPlan(0, '09:00');
      // Assert
      expect(plan.status).assertEqual('NO_ACTION');
    });

    it('normal: compression_build_selection_context_should_include_candidates_and_needed_gap', 0, () => {
      // Arrange
      const a = createEventForAG(1, 'a');
      a.duration = 100;
      const b = createEventForAG(2, 'b');
      b.duration = 90;
      const target = createEventForAG(3, 'target');
      target.pre_travel_min = 50;
      const bundle = createCompressionServiceForAG([a, b, target]);
      // Act
      const ctx = bundle.service.buildCompressionSelectionContext(2, '08:00');
      // Assert
      expect(ctx !== null).assertTrue();
      expect((ctx?.candidates.length ?? 0) > 0).assertTrue();
    });

    it('boundary: compression_build_selection_context_should_allow_forced_gap_override', 0, () => {
      // Arrange
      const a = createEventForAG(1, 'a');
      const target = createEventForAG(2, 'target');
      target.pre_travel_min = 0;
      const bundle = createCompressionServiceForAG([a, target]);
      // Act
      const ctx = bundle.service.buildCompressionSelectionContext(1, '09:00', 45);
      // Assert
      expect(ctx?.neededGapMinutes).assertEqual(45);
    });

    it('invalid: compression_build_selection_context_should_return_null_when_time_invalid', 0, () => {
      // Arrange
      const bundle = createCompressionServiceForAG([createEventForAG(1, 'a'), createEventForAG(2, 'b')]);
      // Act
      const ctx = bundle.service.buildCompressionSelectionContext(1, 'xx');
      // Assert
      expect(ctx === null).assertTrue();
    });

    it('normal: compression_build_advance_adjust_context_should_collect_non_rigid_candidates', 0, () => {
      // Arrange
      const a = createEventForAG(1, 'a');
      a.fixed_start_time = '08:00';
      const b = createEventForAG(2, 'b');
      const target = createEventForAG(3, 'target');
      const bundle = createCompressionServiceForAG([a, b, target]);
      // Act
      const ctx = bundle.service.buildAdvanceAdjustContext(2);
      // Assert
      expect(ctx !== null).assertTrue();
      expect((ctx?.candidates.length ?? 0) >= 1).assertTrue();
    });

    it('boundary: compression_build_advance_adjust_context_should_return_null_when_target_index_is_zero', 0, () => {
      // Arrange
      const bundle = createCompressionServiceForAG([createEventForAG(1, 'a')]);
      // Act
      const ctx = bundle.service.buildAdvanceAdjustContext(0);
      // Assert
      expect(ctx === null).assertTrue();
    });

    it('invalid: compression_build_advance_adjust_context_should_return_null_when_target_not_scheduled', 0, () => {
      // Arrange
      const target = createEventForAG(2, 'target');
      target.status = 0;
      const bundle = createCompressionServiceForAG([createEventForAG(1, 'a'), target]);
      // Act
      const ctx = bundle.service.buildAdvanceAdjustContext(1);
      // Assert
      expect(ctx === null).assertTrue();
    });

    it('normal: compression_preview_advance_adjust_should_return_valid_preview_for_continuous_selection', 0, () => {
      // Arrange
      const a = createEventForAG(1, 'a');
      a.fixed_start_time = '08:00';
      const b = createEventForAG(2, 'b');
      b.fixed_start_time = '09:00';
      const target = createEventForAG(3, 'target');
      target.pre_travel_min = 60;
      const bundle = createCompressionServiceForAG([a, b, target]);
      // Act
      const preview = bundle.service.previewAdvanceAdjust(2, new Set<number>([1]), '07:30', 30);
      // Assert
      expect(preview.valid).assertTrue();
      expect(preview.items.length).assertEqual(1);
    });

    it('boundary: compression_preview_advance_adjust_should_fail_when_selection_not_continuous', 0, () => {
      // Arrange
      const a = createEventForAG(1, 'a');
      const b = createEventForAG(2, 'b');
      const c = createEventForAG(3, 'c');
      const target = createEventForAG(4, 'target');
      const bundle = createCompressionServiceForAG([a, b, c, target]);
      // Act
      const preview = bundle.service.previewAdvanceAdjust(3, new Set<number>([1, 3]), '07:00');
      // Assert
      expect(preview.valid).assertFalse();
      expect(preview.message.indexOf('连续') >= 0).assertTrue();
    });

    it('invalid: compression_preview_advance_adjust_should_fail_when_target_time_invalid', 0, () => {
      // Arrange
      const a = createEventForAG(1, 'a');
      const target = createEventForAG(2, 'target');
      const bundle = createCompressionServiceForAG([a, target]);
      // Act
      const preview = bundle.service.previewAdvanceAdjust(1, new Set<number>([1]), 'bad-time');
      // Assert
      expect(preview.valid).assertFalse();
      expect(preview.message.indexOf('格式无效') >= 0).assertTrue();
    });

    it('normal: compression_apply_advance_adjust_should_apply_updates_and_recalculate', 0, async () => {
      // Arrange
      const hooks = new RepoHooksForAG();
      hooks.attachSuccess();
      const a = createEventForAG(1, 'a');
      const b = createEventForAG(2, 'b');
      b.fixed_start_time = '09:00';
      const target = createEventForAG(3, 'target');
      target.pre_travel_min = 60;
      target.gap_minutes = 20;
      const bundle = createCompressionServiceForAG([a, b, target]);
      // Act
      const result = await bundle.service.applyAdvanceAdjust(2, new Set<number>([1]), '07:30', 20);
      hooks.restore();
      // Assert
      expect(result.success).assertTrue();
      expect(bundle.host.recalculateFromIndexCalls.length).assertEqual(1);
      expect(hooks.updates.length >= 1).assertTrue();
    });

    it('boundary: compression_apply_advance_adjust_should_return_fail_result_when_preview_invalid', 0, async () => {
      // Arrange
      const target = createEventForAG(2, 'target');
      target.gap_minutes = 33;
      const bundle = createCompressionServiceForAG([createEventForAG(1, 'a'), target]);
      // Act
      const result = await bundle.service.applyAdvanceAdjust(1, new Set<number>(), '08:00');
      // Assert
      expect(result.success).assertFalse();
      expect(result.remainingGapMinutes).assertEqual(60);
    });

    it('invalid: compression_apply_advance_adjust_should_fail_for_non_continuous_selection', 0, async () => {
      // Arrange
      const events = [createEventForAG(1, 'a'), createEventForAG(2, 'b'), createEventForAG(3, 'c'), createEventForAG(4, 't')];
      events[3].gap_minutes = 20;
      const bundle = createCompressionServiceForAG(events);
      // Act
      const result = await bundle.service.applyAdvanceAdjust(3, new Set<number>([1, 3]), '07:00');
      // Assert
      expect(result.success).assertFalse();
    });

    it('normal: compression_calculate_by_selection_should_return_confirm_when_capacity_enough', 0, () => {
      // Arrange
      const a = createEventForAG(1, 'a');
      a.duration = 120;
      const b = createEventForAG(2, 'b');
      b.duration = 120;
      const target = createEventForAG(3, 'target');
      target.pre_travel_min = 80;
      const bundle = createCompressionServiceForAG([a, b, target]);
      // Act
      const plan = bundle.service.calculateCompressionPlanBySelection(2, '10:30', new Set<number>([1, 2]), 'EQUAL');
      // Assert
      expect(plan.status).assertEqual('COMPRESS_CONFIRM');
      expect((plan.affectedItems.length > 0)).assertTrue();
    });

    it('boundary: compression_calculate_by_selection_should_return_overload_when_no_selectable_items_selected', 0, () => {
      // Arrange
      const a = createEventForAG(1, 'a');
      a.lock_status = 1;
      a.fixed_start_time = '08:00';
      const target = createEventForAG(2, 'target');
      target.pre_travel_min = 50;
      const bundle = createCompressionServiceForAG([a, target]);
      // Act
      const plan = bundle.service.calculateCompressionPlanBySelection(1, '08:00', new Set<number>([1]), 'RATIO');
      // Assert
      expect(plan.status).assertEqual('OVERLOAD');
    });

    it('invalid: compression_calculate_by_selection_should_return_no_action_when_context_invalid', 0, () => {
      // Arrange
      const bundle = createCompressionServiceForAG([createEventForAG(1, 'a')]);
      // Act
      const plan = bundle.service.calculateCompressionPlanBySelection(0, '08:00', new Set<number>([1]), 'RATIO');
      // Assert
      expect(plan.status).assertEqual('NO_ACTION');
    });

    it('normal: compression_apply_plan_should_update_duration_and_recalculate', 0, () => {
      // Arrange
      const hooks = new RepoHooksForAG();
      hooks.attachSuccess();
      const a = createEventForAG(1, 'a');
      const b = createEventForAG(2, 'b');
      const bundle = createCompressionServiceForAG([a, b]);
      const plan: CompressionPlan = {
        status: 'COMPRESS_CONFIRM',
        msg: 'ok',
        affectedItems: [{ index: 1, name: 'b', oldVal: 60, newVal: 40 }]
      };
      // Act
      bundle.service.applyCompressionPlan(plan);
      hooks.restore();
      // Assert
      expect(b.duration).assertEqual(40);
      expect(bundle.host.recalculateFromIndexCalls.length).assertEqual(1);
      expect(hooks.updates.length).assertEqual(1);
    });

    it('boundary: compression_apply_plan_should_ignore_empty_affected_items', 0, () => {
      // Arrange
      const bundle = createCompressionServiceForAG([createEventForAG(1, 'a')]);
      // Act
      bundle.service.applyCompressionPlan({ status: 'NO_ACTION', msg: 'x', affectedItems: [] });
      // Assert
      expect(bundle.host.recalculateFromIndexCalls.length).assertEqual(0);
    });

    it('invalid: compression_apply_plan_should_skip_persist_for_zero_id_item', 0, () => {
      // Arrange
      const hooks = new RepoHooksForAG();
      hooks.attachSuccess();
      const item = createEventForAG(0, 'x');
      const bundle = createCompressionServiceForAG([item]);
      // Act
      bundle.service.applyCompressionPlan({
        status: 'COMPRESS_CONFIRM',
        msg: 'x',
        affectedItems: [{ index: 0, name: 'x', oldVal: 60, newVal: 30 }]
      });
      hooks.restore();
      // Assert
      expect(item.duration).assertEqual(30);
      expect(hooks.updates.length).assertEqual(0);
    });

    it('normal: compression_calculate_delay_plan_should_return_suggested_time', 0, () => {
      // Arrange
      const a = createEventForAG(1, 'a');
      a.duration = 60;
      const target = createEventForAG(2, 'target');
      target.pre_travel_min = 30;
      const bundle = createCompressionServiceForAG([a, target]);
      // Act
      const plan = bundle.service.calculateDelayPlan(1);
      // Assert
      expect(plan.status).assertEqual('COMPRESS_CONFIRM');
      expect((plan.suggestedTime ?? '').length).assertEqual(5);
    });

    it('boundary: compression_calculate_delay_plan_should_handle_first_item', 0, () => {
      // Arrange
      const target = createEventForAG(1, 'target');
      const bundle = createCompressionServiceForAG([target]);
      // Act
      const plan = bundle.service.calculateDelayPlan(0);
      // Assert
      expect(plan.status).assertEqual('COMPRESS_CONFIRM');
      expect(plan.suggestedTime).assertEqual('08:00');
    });

    it('invalid: compression_calculate_delay_plan_should_fallback_to_zero_when_target_invalid', 0, () => {
      // Arrange
      const bundle = createCompressionServiceForAG([createEventForAG(1, 'a')]);
      // Act
      const plan = bundle.service.calculateDelayPlan(9);
      // Assert
      expect(plan.suggestedTime).assertEqual('00:00');
    });

    it('normal: compression_force_compress_should_return_confirm_when_single_prev_can_absorb_gap', 0, () => {
      // Arrange
      const prev = createEventForAG(1, 'prev');
      prev.duration = 120;
      const target = createEventForAG(2, 'target');
      target.pre_travel_min = 60;
      const bundle = createCompressionServiceForAG([prev, target]);
      // Act
      const plan = bundle.service.calculateForceCompressPlan(1, '10:00');
      // Assert
      expect(plan.status).assertEqual('COMPRESS_CONFIRM');
      expect(plan.affectedItems.length).assertEqual(1);
    });

    it('boundary: compression_force_compress_should_return_no_action_when_needed_gap_not_positive', 0, () => {
      // Arrange
      const prev = createEventForAG(1, 'prev');
      const target = createEventForAG(2, 'target');
      const bundle = createCompressionServiceForAG([prev, target]);
      // Act
      const plan = bundle.service.calculateForceCompressPlan(1, '10:00');
      // Assert
      expect(plan.status).assertEqual('NO_ACTION');
    });

    it('invalid: compression_force_compress_should_fail_when_new_duration_below_min_limit', 0, () => {
      // Arrange
      const prev = createEventForAG(1, 'prev');
      prev.duration = 30;
      const target = createEventForAG(2, 'target');
      target.pre_travel_min = 80;
      const bundle = createCompressionServiceForAG([prev, target]);
      bundle.host.minDurationLimit = 25;
      // Act
      const plan = bundle.service.calculateForceCompressPlan(1, '08:00');
      // Assert
      expect(plan.status === 'FAIL_TOO_SHORT' || plan.status === 'OVERLOAD').assertTrue();
    });

    it('normal: compression_calculate_natural_arrival_should_include_duration_and_travel', 0, () => {
      // Arrange
      const a = createEventForAG(1, 'a');
      a.duration = 60;
      const target = createEventForAG(2, 'target');
      target.pre_travel_min = 30;
      const bundle = createCompressionServiceForAG([a, target]);
      // Act
      const natural = bundle.service.calculateNaturalArrival(1);
      // Assert
      expect(natural).assertEqual(570);
    });

    it('boundary: compression_calculate_natural_arrival_should_handle_first_scheduled_item', 0, () => {
      // Arrange
      const first = createEventForAG(1, 'first');
      first.pre_travel_min = 15;
      const bundle = createCompressionServiceForAG([first]);
      // Act
      const natural = bundle.service.calculateNaturalArrival(0);
      // Assert
      expect(natural).assertEqual(495);
    });

    it('invalid: compression_calculate_natural_arrival_should_return_zero_when_target_invalid', 0, () => {
      // Arrange
      const bundle = createCompressionServiceForAG([createEventForAG(1, 'a')]);
      // Act
      const natural = bundle.service.calculateNaturalArrival(99);
      // Assert
      expect(natural).assertEqual(0);
    });

    it('normal: distribution_clamp_should_return_requested_add_when_under_cap', 0, () => {
      // Arrange
      // Act
      const add = TimelineDistributionService.clampDistributionAdd(100, 20);
      // Assert
      expect(add).assertEqual(20);
    });

    it('boundary: distribution_clamp_should_limit_add_to_remaining_cap', 0, () => {
      // Arrange
      // Act
      const add = TimelineDistributionService.clampDistributionAdd(235, 20);
      // Assert
      expect(add).assertEqual(5);
    });

    it('invalid: distribution_clamp_should_sanitize_non_finite_inputs', 0, () => {
      // Arrange
      // Act
      const add = TimelineDistributionService.clampDistributionAdd(Number.NaN, Number.POSITIVE_INFINITY);
      // Assert
      expect(add).assertEqual(0);
    });

    it('normal: distribution_resolve_gap_by_sync_should_forward_update_when_natural_time_exists', 0, () => {
      // Arrange
      const item = createEventForAG(1, 'x');
      item.natural_start_time = '09:30';
      const bundle = createDistributionServiceForAG([item]);
      // Act
      bundle.service.resolveGapBySync(item);
      // Assert
      expect(bundle.host.updateEventInfoCalls).assertEqual(1);
    });

    it('boundary: distribution_resolve_gap_by_sync_should_ignore_empty_natural_time', 0, () => {
      // Arrange
      const item = createEventForAG(1, 'x');
      item.natural_start_time = '';
      const bundle = createDistributionServiceForAG([item]);
      // Act
      bundle.service.resolveGapBySync(item);
      // Assert
      expect(bundle.host.updateEventInfoCalls).assertEqual(0);
    });

    it('invalid: distribution_resolve_gap_by_sync_should_ignore_blank_natural_time', 0, () => {
      // Arrange
      const item = createEventForAG(1, 'x');
      item.natural_start_time = '   ';
      const bundle = createDistributionServiceForAG([item]);
      // Act
      bundle.service.resolveGapBySync(item);
      // Assert
      expect(bundle.host.updateEventInfoCalls).assertEqual(1);
    });

    it('normal: distribution_resolve_gap_by_distribution_should_distribute_and_recalculate', 0, async () => {
      // Arrange
      const hooks = new RepoHooksForAG();
      hooks.attachSuccess();
      const c1 = createEventForAG(1, 'c1');
      const c2 = createEventForAG(2, 'c2');
      const gap = createEventForAG(3, 'gap');
      gap.has_gap = true;
      gap.gap_minutes = 40;
      const bundle = createDistributionServiceForAG([c1, c2, gap]);
      const before = c1.duration + c2.duration;
      // Act
      await bundle.service.resolveGapByDistribution(gap);
      hooks.restore();
      // Assert
      expect(c1.duration + c2.duration > before).assertTrue();
      expect(bundle.host.recalculateFromIndexCalls.length).assertEqual(1);
      expect(hooks.updates.length).assertEqual(2);
    });

    it('boundary: distribution_resolve_gap_by_distribution_should_ignore_gap_on_first_index', 0, async () => {
      // Arrange
      const gap = createEventForAG(1, 'gap');
      gap.has_gap = true;
      gap.gap_minutes = 30;
      const bundle = createDistributionServiceForAG([gap]);
      // Act
      await bundle.service.resolveGapByDistribution(gap);
      // Assert
      expect(bundle.host.recalculateFromIndexCalls.length).assertEqual(0);
    });

    it('invalid: distribution_resolve_gap_by_distribution_should_stop_when_locked_candidate_encountered', 0, async () => {
      // Arrange
      const free = createEventForAG(1, 'free');
      const locked = createEventForAG(2, 'locked');
      locked.lock_status = 1;
      const gap = createEventForAG(3, 'gap');
      gap.has_gap = true;
      gap.gap_minutes = 50;
      const bundle = createDistributionServiceForAG([free, locked, gap]);
      const old = free.duration;
      // Act
      await bundle.service.resolveGapByDistribution(gap);
      // Assert
      expect(free.duration).assertEqual(old);
      expect(bundle.host.recalculateFromIndexCalls.length).assertEqual(0);
    });

    it('normal: distribution_get_candidates_should_return_same_day_previous_scheduled_items', 0, () => {
      // Arrange
      const a = createEventForAG(1, 'a', 0);
      const b = createEventForAG(2, 'b', 0);
      const c = createEventForAG(3, 'c', 1);
      const gap = createEventForAG(4, 'gap', 0);
      const bundle = createDistributionServiceForAG([a, b, c, gap]);
      // Act
      const list = bundle.service.getDistributionCandidates(gap);
      // Assert
      expect(list.length).assertEqual(2);
      expect(list[0].id).assertEqual(1);
      expect(list[1].id).assertEqual(2);
    });

    it('boundary: distribution_get_candidates_should_return_empty_when_gap_index_not_positive', 0, () => {
      // Arrange
      const gap = createEventForAG(1, 'gap');
      const bundle = createDistributionServiceForAG([gap]);
      // Act
      const list = bundle.service.getDistributionCandidates(gap);
      // Assert
      expect(list.length).assertEqual(0);
    });

    it('invalid: distribution_get_candidates_should_filter_out_non_schedule_items', 0, () => {
      // Arrange
      const a = createEventForAG(1, 'a');
      a.status = 0;
      const gap = createEventForAG(2, 'gap');
      const bundle = createDistributionServiceForAG([a, gap]);
      // Act
      const list = bundle.service.getDistributionCandidates(gap);
      // Assert
      expect(list.length).assertEqual(0);
    });

    it('normal: distribution_get_safety_cap_should_respect_buffer_and_duration_cap', 0, () => {
      // Arrange
      const c1 = createEventForAG(1, 'c1');
      c1.duration = 100;
      const locked = createEventForAG(2, 'locked');
      locked.lock_status = 1;
      locked.fixed_start_time = '12:00';
      const gap = createEventForAG(3, 'gap');
      gap.gap_minutes = 90;
      const bundle = createDistributionServiceForAG([c1, locked, gap]);
      bundle.host.naturalArrivalMap.set(1, 700);
      // Act
      const cap = bundle.service.getSafetyCap(c1, gap);
      // Assert
      expect(cap >= 0).assertTrue();
      expect(cap <= 140).assertTrue();
    });

    it('boundary: distribution_get_safety_cap_should_return_zero_when_candidate_not_before_gap', 0, () => {
      // Arrange
      const c = createEventForAG(1, 'c');
      const gap = createEventForAG(2, 'gap');
      const bundle = createDistributionServiceForAG([gap, c]);
      // Act
      const cap = bundle.service.getSafetyCap(c, gap);
      // Assert
      expect(cap).assertEqual(0);
    });

    it('invalid: distribution_get_safety_cap_should_return_zero_when_gap_not_in_schedule', 0, () => {
      // Arrange
      const c = createEventForAG(1, 'c');
      const gap = createEventForAG(2, 'gap');
      gap.status = 0;
      const bundle = createDistributionServiceForAG([c, gap]);
      // Act
      const cap = bundle.service.getSafetyCap(c, gap);
      // Assert
      expect(cap).assertEqual(0);
    });

    it('normal: distribution_preview_should_allocate_for_selected_items', 0, () => {
      // Arrange
      const c1 = createEventForAG(1, 'c1');
      const c2 = createEventForAG(2, 'c2');
      const gap = createEventForAG(3, 'gap');
      gap.gap_minutes = 60;
      const bundle = createDistributionServiceForAG([c1, c2, gap]);
      // Act
      const map = bundle.service.calculateDistributionPreview(gap, [c1, c2], new Set<number>([1, 2]), 'EQUAL');
      // Assert
      const add1 = map.get(1) ?? 0;
      const add2 = map.get(2) ?? 0;
      expect(add1 + add2 <= 60).assertTrue();
    });

    it('boundary: distribution_preview_should_return_empty_when_no_selected_items', 0, () => {
      // Arrange
      const c1 = createEventForAG(1, 'c1');
      const gap = createEventForAG(2, 'gap');
      gap.gap_minutes = 30;
      const bundle = createDistributionServiceForAG([c1, gap]);
      // Act
      const map = bundle.service.calculateDistributionPreview(gap, [c1], new Set<number>(), 'SMART');
      // Assert
      expect(map.size).assertEqual(0);
    });

    it('invalid: distribution_preview_should_handle_zero_caps_without_infinite_loop', 0, () => {
      // Arrange
      const c1 = createEventForAG(1, 'c1');
      c1.duration = 240;
      const gap = createEventForAG(2, 'gap');
      gap.gap_minutes = 30;
      const bundle = createDistributionServiceForAG([c1, gap]);
      // Act
      const map = bundle.service.calculateDistributionPreview(gap, [c1], new Set<number>([1]), 'SMART');
      // Assert
      expect((map.get(1) ?? 0)).assertEqual(0);
    });

    it('normal: distribution_get_sorted_gaps_should_return_sorted_valid_gaps', 0, () => {
      // Arrange
      const first = createEventForAG(1, 'first');
      first.has_gap = true;
      first.gap_minutes = 25;
      const second = createEventForAG(2, 'second');
      second.has_gap = true;
      second.gap_minutes = 50;
      const bundle = createDistributionServiceForAG([first, second]);
      // Act
      const gaps = bundle.service.getSortedGaps();
      // Assert
      expect(gaps.length).assertEqual(1);
      expect(gaps[0].id).assertEqual(2);
    });

    it('boundary: distribution_get_sorted_gaps_should_return_empty_when_feature_disabled', 0, () => {
      // Arrange
      const item = createEventForAG(1, 'x');
      item.has_gap = true;
      item.gap_minutes = 100;
      const bundle = createDistributionServiceForAG([item]);
      bundle.host.idleGapDetectionEnabled = false;
      // Act
      const gaps = bundle.service.getSortedGaps();
      // Assert
      expect(gaps.length).assertEqual(0);
    });

    it('invalid: distribution_get_sorted_gaps_should_ignore_cross_day_previous_item', 0, () => {
      // Arrange
      const day0 = createEventForAG(1, 'day0', 0);
      const day1Gap = createEventForAG(2, 'day1_gap', 1);
      day1Gap.has_gap = true;
      day1Gap.gap_minutes = 80;
      const bundle = createDistributionServiceForAG([day0, day1Gap]);
      // Act
      const gaps = bundle.service.getSortedGaps();
      // Assert
      expect(gaps.length).assertEqual(0);
    });

    it('normal: distribution_get_previous_item_name_should_return_previous_name_on_same_day', 0, () => {
      // Arrange
      const prev = createEventForAG(1, 'prev', 0);
      const gap = createEventForAG(2, 'gap', 0);
      const bundle = createDistributionServiceForAG([prev, gap]);
      // Act
      const name = bundle.service.getPreviousItemName(gap);
      // Assert
      expect(name).assertEqual('prev');
    });

    it('boundary: distribution_get_previous_item_name_should_return_day_start_when_idx_not_found_or_first', 0, () => {
      // Arrange
      const gap = createEventForAG(1, 'gap');
      const bundle = createDistributionServiceForAG([gap]);
      // Act
      const name = bundle.service.getPreviousItemName(gap);
      // Assert
      expect(name.length > 0).assertTrue();
    });

    it('invalid: distribution_get_previous_item_name_should_return_same_day_start_when_cross_day', 0, () => {
      // Arrange
      const prev = createEventForAG(1, 'prev', 0);
      const gap = createEventForAG(2, 'gap', 1);
      const bundle = createDistributionServiceForAG([prev, gap]);
      // Act
      const name = bundle.service.getPreviousItemName(gap);
      // Assert
      expect(name.length > 0).assertTrue();
    });

    it('normal: distribution_apply_distribution_should_apply_updates_and_recalculate', 0, async () => {
      // Arrange
      const hooks = new RepoHooksForAG();
      hooks.attachSuccess();
      const a = createEventForAG(1, 'a');
      const b = createEventForAG(2, 'b');
      const bundle = createDistributionServiceForAG([a, b]);
      const distribution = new Map<number, number>();
      distribution.set(1, 20);
      distribution.set(2, 10);
      // Act
      await bundle.service.applyDistribution(distribution);
      hooks.restore();
      // Assert
      expect(a.duration).assertEqual(80);
      expect(b.duration).assertEqual(70);
      expect(bundle.host.recalculateFromIndexCalls.length).assertEqual(1);
      expect(hooks.updates.length).assertEqual(2);
    });

    it('boundary: distribution_apply_distribution_should_noop_when_map_empty', 0, async () => {
      // Arrange
      const bundle = createDistributionServiceForAG([createEventForAG(1, 'a')]);
      // Act
      await bundle.service.applyDistribution(new Map<number, number>());
      // Assert
      expect(bundle.host.recalculateFromIndexCalls.length).assertEqual(0);
    });

    it('invalid: distribution_apply_distribution_should_skip_non_positive_add_or_capped_zero', 0, async () => {
      // Arrange
      const hooks = new RepoHooksForAG();
      hooks.attachSuccess();
      const a = createEventForAG(1, 'a');
      a.duration = 240;
      const bundle = createDistributionServiceForAG([a]);
      const distribution = new Map<number, number>();
      distribution.set(1, 0);
      // Act
      await bundle.service.applyDistribution(distribution);
      hooks.restore();
      // Assert
      expect(bundle.host.recalculateFromIndexCalls.length).assertEqual(0);
      expect(hooks.updates.length).assertEqual(0);
    });

    it('conflict: compression_preview_advance_adjust_should_fail_when_previous_boundary_conflicts', 0, () => {
      // Arrange
      const prev = createEventForAG(1, 'prev');
      prev.fixed_start_time = '08:00';
      prev.duration = 60;
      const current = createEventForAG(2, 'current');
      current.fixed_start_time = '09:00';
      const target = createEventForAG(3, 'target');
      const bundle = createCompressionServiceForAG([prev, current, target]);
      // Act
      const preview = bundle.service.previewAdvanceAdjust(2, new Set<number>([2]), '08:30');
      // Assert
      expect(preview.valid).assertFalse();
      expect(preview.message.length > 0).assertTrue();
    });

    it('regression: compression_calculate_natural_arrival_should_keep_same_day_chain_math', 0, () => {
      // Arrange
      const first = createEventForAG(1, 'first');
      first.duration = 45;
      const second = createEventForAG(2, 'second');
      second.duration = 50;
      second.pre_travel_min = 15;
      const bundle = createCompressionServiceForAG([first, second]);
      // Act
      const natural = bundle.service.calculateNaturalArrival(1);
      // Assert
      expect(natural).assertEqual(540);
    });

    it('combined: compression_plan_and_apply_should_update_duration_and_trigger_recalculate', 0, () => {
      // Arrange
      const hooks = new RepoHooksForAG();
      hooks.attachSuccess();
      const first = createEventForAG(1, 'first');
      first.duration = 100;
      const second = createEventForAG(2, 'second');
      second.duration = 100;
      const target = createEventForAG(3, 'target');
      target.pre_travel_min = 40;
      const bundle = createCompressionServiceForAG([first, second, target]);
      // Act
      const plan = bundle.service.calculateCompressionPlanBySelection(2, '09:30', new Set<number>([1, 2]), 'EQUAL');
      bundle.service.applyCompressionPlan(plan);
      hooks.restore();
      // Assert
      expect(plan.status).assertEqual('COMPRESS_CONFIRM');
      expect(bundle.host.recalculateFromIndexCalls.length).assertEqual(1);
    });

    it('invalid: compression_fix_conflict_should_not_recalculate_when_resolver_returns_false', 0, async () => {
      // Arrange
      const hooks = new ConflictResolverHooksForAG();
      hooks.result = false;
      hooks.attach();
      const target = createEventForAG(20, 'target');
      const bundle = createCompressionServiceForAG([target]);

      // Act
      await bundle.service.fixConflict(target, 25);
      hooks.restore();

      // Assert
      expect(hooks.calls.length).assertEqual(1);
      expect(bundle.host.recalculateFromEventIdCalls.length).assertEqual(0);
    });

    it('boundary: compression_smart_fix_conflict_should_noop_when_target_not_conflict_or_not_in_events', 0, async () => {
      // Arrange
      const missing = createEventForAG(21, 'missing');
      missing.is_conflict = true;
      const plain = createEventForAG(22, 'plain');
      plain.is_conflict = false;
      const bundle = createCompressionServiceForAG([plain]);

      // Act
      await bundle.service.smartFixConflict(plain);
      await bundle.service.smartFixConflict(missing);

      // Assert
      expect(bundle.host.recalculateFromIndexCalls.length).assertEqual(0);
      expect(bundle.host.markHasUnsavedPostponeCalls).assertEqual(0);
    });

    it('invalid: compression_build_selection_context_should_return_null_for_first_target_or_invalid_time', 0, () => {
      // Arrange
      const first = createEventForAG(23, 'first');
      const target = createEventForAG(24, 'target');
      const bundle = createCompressionServiceForAG([first, target]);

      // Act
      const firstTargetContext = bundle.service.buildCompressionSelectionContext(0, '09:00');
      const invalidTimeContext = bundle.service.buildCompressionSelectionContext(1, 'bad-time');

      // Assert
      expect(firstTargetContext === null).assertTrue();
      expect(invalidTimeContext === null).assertTrue();
    });

    it('conflict: compression_preview_advance_adjust_should_reject_non_continuous_selection', 0, () => {
      // Arrange
      const first = createEventForAG(25, 'first');
      first.fixed_start_time = '09:00';
      const second = createEventForAG(26, 'second');
      second.fixed_start_time = '10:00';
      const third = createEventForAG(27, 'third');
      third.fixed_start_time = '11:00';
      const target = createEventForAG(28, 'target');
      target.fixed_start_time = '12:30';
      const bundle = createCompressionServiceForAG([first, second, third, target]);

      // Act
      const preview = bundle.service.previewAdvanceAdjust(3, new Set<number>([25, 27]), '08:30');

      // Assert
      expect(preview.valid).assertFalse();
      expect(preview.message).assertEqual('仅支持选择连续地点');
      expect(preview.selectedCount).assertEqual(2);
    });

    it('boundary: compression_preview_advance_adjust_should_reject_non_earlier_target_start_time', 0, () => {
      // Arrange
      const first = createEventForAG(29, 'first');
      first.fixed_start_time = '09:00';
      const target = createEventForAG(30, 'target');
      target.fixed_start_time = '10:30';
      const bundle = createCompressionServiceForAG([first, target]);

      // Act
      const preview = bundle.service.previewAdvanceAdjust(1, new Set<number>([29]), '09:00');

      // Assert
      expect(preview.valid).assertFalse();
      expect(preview.message).assertEqual('新开始时间必须早于当前计划开始时间');
      expect(preview.selectedCount).assertEqual(1);
    });

    it('conflict: compression_preview_advance_adjust_should_reject_when_next_unselected_item_would_conflict', 0, () => {
      // Arrange
      const first = createEventForAG(31, 'first');
      first.fixed_start_time = '09:00';
      first.duration = 60;
      const second = createEventForAG(32, 'second');
      second.fixed_start_time = '10:10';
      second.duration = 40;
      const blocker = createEventForAG(33, 'blocker');
      blocker.fixed_start_time = '10:10';
      blocker.duration = 30;
      blocker.pre_travel_min = 20;
      const target = createEventForAG(34, 'target');
      target.fixed_start_time = '12:00';
      const bundle = createCompressionServiceForAG([first, second, blocker, target]);

      // Act
      const preview = bundle.service.previewAdvanceAdjust(3, new Set<number>([31, 32]), '08:20');

      // Assert
      expect(preview.valid).assertFalse();
      expect(preview.message).assertEqual('调整后将与后续地点冲突');
      expect(preview.items.length).assertEqual(2);
    });

    it('invalid: compression_preview_advance_adjust_should_reject_invalid_time_and_empty_selection', 0, () => {
      // Arrange
      const first = createEventForAG(35, 'first');
      first.fixed_start_time = '09:00';
      const target = createEventForAG(36, 'target');
      target.fixed_start_time = '10:00';
      const bundle = createCompressionServiceForAG([first, target]);

      // Act
      const invalidTimePreview = bundle.service.previewAdvanceAdjust(1, new Set<number>([35]), 'bad-time');
      const emptySelectionPreview = bundle.service.previewAdvanceAdjust(1, new Set<number>(), '08:30');

      // Assert
      expect(invalidTimePreview.valid).assertFalse();
      expect(invalidTimePreview.message).assertEqual('新开始时间格式无效');
      expect(emptySelectionPreview.valid).assertFalse();
      expect(emptySelectionPreview.message).assertEqual('仅支持选择连续地点');
    });

    it('invalid: compression_apply_advance_adjust_should_return_failure_when_preview_invalid', 0, async () => {
      // Arrange
      const first = createEventForAG(37, 'first');
      first.fixed_start_time = '09:00';
      const target = createEventForAG(38, 'target');
      target.fixed_start_time = '10:00';
      target.gap_minutes = 18;
      const bundle = createCompressionServiceForAG([first, target]);

      // Act
      const result = await bundle.service.applyAdvanceAdjust(1, new Set<number>(), '08:30');

      // Assert
      expect(result.success).assertFalse();
      expect(result.appliedCount).assertEqual(0);
      expect(result.remainingGapMinutes).assertEqual(18);
      expect(bundle.host.recalculateFromIndexCalls.length).assertEqual(0);
    });

    it('invalid: compression_calculate_plan_by_selection_should_return_overload_when_no_selectable_items_chosen', 0, () => {
      // Arrange
      const first = createEventForAG(39, 'first');
      first.duration = 80;
      const target = createEventForAG(40, 'target');
      target.pre_travel_min = 50;
      target.fixed_start_time = '08:40';
      const bundle = createCompressionServiceForAG([first, target]);

      // Act
      const plan = bundle.service.calculateCompressionPlanBySelection(1, '08:40', new Set<number>(), 'RATIO');

      // Assert
      expect(plan.status).assertEqual('OVERLOAD');
      expect(plan.capacityMinutes).assertEqual(0);
      expect((plan.remainingGapMinutes ?? 0) > 0).assertTrue();
    });

    it('boundary: compression_apply_plan_should_noop_when_affected_items_empty', 0, () => {
      // Arrange
      const first = createEventForAG(41, 'first');
      const target = createEventForAG(42, 'target');
      const bundle = createCompressionServiceForAG([first, target]);

      // Act
      bundle.service.applyCompressionPlan({
        status: 'NO_ACTION',
        msg: 'noop',
        affectedItems: []
      });

      // Assert
      expect(bundle.host.recalculateFromIndexCalls.length).assertEqual(0);
      expect(first.duration).assertEqual(60);
    });

    it('boundary: compression_smart_fix_conflict_should_return_when_conflict_item_is_not_rigid', 0, async () => {
      // Arrange
      const first = createEventForAG(43, 'first');
      const target = createEventForAG(44, 'target');
      target.is_conflict = true;
      target.lock_status = 0;
      const bundle = createCompressionServiceForAG([first, target]);

      // Act
      await bundle.service.smartFixConflict(target);

      // Assert
      expect(bundle.host.markHasUnsavedPostponeCalls).assertEqual(0);
      expect(bundle.host.recalculateFromIndexCalls.length).assertEqual(0);
    });

    it('conflict: compression_smart_fix_conflict_should_leave_conflict_for_manual_fix_when_plan_is_not_compressible', 0, async () => {
      // Arrange
      const first = createEventForAG(45, 'first');
      const target = createEventForAG(46, 'target');
      target.is_conflict = true;
      target.lock_status = 1;
      target.fixed_start_time = '09:00';
      const bundle = createCompressionServiceForAG([first, target]);
      Reflect.set(bundle.service as Object, 'calculateCompressionPlan', (): CompressionPlan => {
        return {
          status: 'OVERLOAD',
          msg: 'manual_fix_needed',
          affectedItems: []
        };
      });

      // Act
      await bundle.service.smartFixConflict(target);

      // Assert
      expect(bundle.host.markHasUnsavedPostponeCalls).assertEqual(0);
      expect(bundle.host.recalculateFromIndexCalls.length).assertEqual(0);
    });

    it('combined: compression_build_selection_context_should_skip_cross_day_and_inactive_items_before_collecting_same_day_candidates', 0, () => {
      // Arrange
      const otherDay = createEventForAG(47, 'other_day', 1);
      otherDay.fixed_start_time = '08:00';
      const inactive = createEventForAG(48, 'inactive');
      inactive.status = 0;
      const selectable = createEventForAG(49, 'selectable');
      selectable.duration = 90;
      selectable.fixed_start_time = '09:00';
      const target = createEventForAG(50, 'target');
      target.fixed_start_time = '10:30';
      target.pre_travel_min = 40;
      const bundle = createCompressionServiceForAG([otherDay, inactive, selectable, target]);

      // Act
      const context = bundle.service.buildCompressionSelectionContext(3, '09:40', 20);

      // Assert
      expect(context !== null).assertTrue();
      expect(context?.candidates.length ?? 0).assertEqual(1);
      expect(context?.candidates[0].id ?? 0).assertEqual(49);
      expect(context?.candidates[0].selectable ?? false).assertTrue();
    });

    it('boundary: compression_build_advance_adjust_context_should_skip_rigid_candidate_inside_same_day_chain', 0, () => {
      // Arrange
      const pivot = createEventForAG(51, 'pivot');
      pivot.fixed_start_time = '08:00';
      pivot.lock_status = 1;
      const rigid = createEventForAG(52, 'rigid_middle');
      rigid.fixed_start_time = '09:00';
      rigid.lock_status = 1;
      const movable = createEventForAG(53, 'movable');
      movable.fixed_start_time = '10:00';
      const target = createEventForAG(54, 'target');
      target.fixed_start_time = '11:30';
      const bundle = createCompressionServiceForAG([pivot, rigid, movable, target]);

      // Act
      const context = bundle.service.buildAdvanceAdjustContext(3);

      // Assert
      expect(context !== null).assertTrue();
      expect(context?.candidates.length ?? 0).assertEqual(1);
      expect(context?.candidates[0].id ?? 0).assertEqual(53);
    });

    it('invalid: compression_preview_advance_adjust_should_return_no_candidate_message_when_target_has_no_movable_chain', 0, () => {
      // Arrange
      const target = createEventForAG(55, 'target');
      target.fixed_start_time = '09:30';
      const bundle = createCompressionServiceForAG([target]);

      // Act
      const preview = bundle.service.previewAdvanceAdjust(0, new Set<number>([55]), '08:30');

      // Assert
      expect(preview.valid).assertFalse();
      expect(preview.message).assertEqual('当前无可前移地点');
      expect(preview.items.length).assertEqual(0);
    });

    it('normal: compression_preview_advance_adjust_should_allow_boundary_aligned_start_after_skipping_inactive_previous_item', 0, () => {
      // Arrange
      const rigid = createEventForAG(56, 'rigid');
      rigid.fixed_start_time = '08:00';
      rigid.lock_status = 1;
      const inactive = createEventForAG(57, 'inactive');
      inactive.status = 0;
      const selected = createEventForAG(58, 'selected');
      selected.fixed_start_time = '09:30';
      selected.duration = 60;
      const target = createEventForAG(59, 'target');
      target.fixed_start_time = '11:00';
      const bundle = createCompressionServiceForAG([rigid, inactive, selected, target]);

      // Act
      const preview = bundle.service.previewAdvanceAdjust(3, new Set<number>([58]), '09:00');

      // Assert
      expect(preview.valid).assertTrue();
      expect(preview.firstNewStartTime).assertEqual('09:00');
      expect(preview.remainingGapMinutes >= 0).assertTrue();
    });

    it('normal: compression_preview_advance_adjust_should_ignore_inactive_gap_between_selected_item_and_target', 0, () => {
      // Arrange
      const rigid = createEventForAG(60, 'rigid');
      rigid.fixed_start_time = '08:00';
      rigid.lock_status = 1;
      const selected = createEventForAG(61, 'selected');
      selected.fixed_start_time = '09:30';
      selected.duration = 60;
      const skipped = createEventForAG(62, 'skipped');
      skipped.status = 0;
      const target = createEventForAG(63, 'target');
      target.fixed_start_time = '11:30';
      const bundle = createCompressionServiceForAG([rigid, selected, skipped, target]);

      // Act
      const preview = bundle.service.previewAdvanceAdjust(3, new Set<number>([61]), '09:00');

      // Assert
      expect(preview.valid).assertTrue();
      expect(preview.items.length).assertEqual(1);
      expect(preview.items[0].id).assertEqual(61);
    });

    it('normal: compression_apply_advance_adjust_should_recalculate_from_previous_index_and_finish_without_remaining_gap', 0, async () => {
      // Arrange
      const hooks = new RepoHooksForAG();
      hooks.attachSuccess();
      const rigid = createEventForAG(64, 'rigid');
      rigid.fixed_start_time = '08:00';
      rigid.lock_status = 1;
      const selected = createEventForAG(65, 'selected');
      selected.fixed_start_time = '09:30';
      selected.duration = 60;
      const target = createEventForAG(66, 'target');
      target.fixed_start_time = '11:30';
      target.gap_minutes = 0;
      const bundle = createCompressionServiceForAG([rigid, selected, target]);

      // Act
      const result = await bundle.service.applyAdvanceAdjust(2, new Set<number>([65]), '09:00');
      hooks.restore();

      // Assert
      expect(result.success).assertTrue();
      expect(result.remainingGapMinutes).assertEqual(0);
      expect(result.message).assertEqual('前移调整已应用');
      expect(bundle.host.recalculateFromIndexCalls.length).assertEqual(1);
      expect(bundle.host.recalculateFromIndexCalls[0]).assertEqual(0);
      expect(hooks.updates.length).assertEqual(1);
      expect(selected.fixed_start_time).assertEqual('09:00');
    });
  });
}
