import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

class EventMutationManagerStubCW {
  moveArgs: string = '';
  moveAllCalls: number = 0;
  backlogId: number = 0;
  addName: string = '';
  updateId: number = 0;
  hardDeleteId: number = 0;
  conflictBacklogId: number = 0;
  movingPlanId: number = 0;

  async moveEvent(index: number, direction: 'up' | 'down'): Promise<void> {
    this.moveArgs = `${index}:${direction}`;
  }

  async moveAllBacklogToSchedule(): Promise<number> {
    this.moveAllCalls += 1;
    return 3;
  }

  async moveToBacklog(item: TravelPlanItem | EventEntity): Promise<void> {
    this.backlogId = item.id ?? -1;
  }

  async addNewItem(
    name: string,
    _duration: number,
    _isSchedule: boolean,
    _fixedTime?: string,
    _dayOffset?: number,
    _preTravel?: number,
    _isHardLock?: boolean,
    _note?: string,
    _priority?: number,
    _lat?: number,
    _lng?: number
  ): Promise<void> {
    this.addName = name;
  }

  async updateEventInfo(
    id: number,
    _name: string,
    _duration: number,
    _fixedTime?: string,
    _dayOffset?: number,
    _isHardLock?: boolean,
    _note?: string,
    _priority?: number,
    _lat?: number,
    _lng?: number
  ): Promise<void> {
    this.updateId = id;
  }

  async hardDelete(item: EventEntity): Promise<void> {
    this.hardDeleteId = item.id;
  }

  async resolveConflictByBacklog(id: number, _name: string, _duration: number, _note: string, _priority: number): Promise<void> {
    this.conflictBacklogId = id;
  }

  async resolveConflictByMovingPlan(
    id: number,
    _targetDateMs: number,
    _name: string,
    _duration: number,
    _isSchedule: boolean,
    _fixedTime?: string,
    _note?: string,
    _priority?: number
  ): Promise<void> {
    this.movingPlanId = id;
  }
}

class PersistenceStubCW {
  startDatePlanId: number = 0;
  startDateValue: number = 0;
  namePlanId: number = 0;
  nameValue: string = '';

  async updatePlanStartDate(planId: number, startDate: number): Promise<void> {
    this.startDatePlanId = planId;
    this.startDateValue = startDate;
  }

  async updatePlanName(planId: number, name: string): Promise<void> {
    this.namePlanId = planId;
    this.nameValue = name;
  }
}

class RecalculationManagerStubCW {
  calls: string[] = [];
  effectiveMinutes: number = 540;

  testAllCommute(): void {
    this.calls.push('testAllCommute');
  }

  updateTravelMode(item: EventEntity, mode: number): void {
    this.calls.push(`updateTravelMode:${item.id}:${mode}`);
  }

  resolveEffectiveGlobalStartMinutes(): number {
    this.calls.push('resolveEffectiveGlobalStartMinutes');
    return this.effectiveMinutes;
  }

  logTimelineSnapshot(scene: string): void {
    this.calls.push(`log:${scene}`);
  }

  recalculateFromEventId(eventId: number): void {
    this.calls.push(`fromEvent:${eventId}`);
  }

  recalculateFromIndex(startIndex: number): void {
    this.calls.push(`fromIndex:${startIndex}`);
  }

  recalculate(): void {
    this.calls.push('recalculate');
  }

  recalculateTrafficOnly(): void {
    this.calls.push('trafficOnly');
  }
}

class DistributionCoordinatorStubCW {
  gapId: number = 0;

  resolveGapBySync(item: EventEntity): void {
    this.gapId = item.id;
  }
}

class CompanionContextStubCW {
  runtimeState: string = 'ACTIVE';
}

class CompanionManagerStubCW {
  runtimeStateValue: string = 'ACTIVE';

  getCompanionContext(_nowTs?: number): CompanionContextStubCW {
    const context = new CompanionContextStubCW();
    context.runtimeState = this.runtimeStateValue;
    return context;
  }
}

class WeatherFacadeStubCW {
  statusValue: PlanStatus = PlanStatus.DRAFT;
  runtimeStateValue: string = '';

  resolveStage(status: PlanStatus, _events: EventEntity[], runtimeState: string): string {
    this.statusValue = status;
    this.runtimeStateValue = runtimeState;
    return 'IN_PROGRESS';
  }
}

function createEventCW(id: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `cw_${id}`;
  event.status = 1;
  event.duration = 30;
  return event;
}

export default function phase2BatchCWTest() {
  describe('phase2BatchCW_timeline_viewmodel_delegate_methods', () => {
    it('normal: event_mutation_facade_should_delegate_move_and_backlog_operations', 0, async () => {
      // Arrange
      const vm = new TimelineViewModel();
      const manager = new EventMutationManagerStubCW();
      const event = createEventCW(8101);
      Reflect.set(vm as Object, 'eventMutationManager', manager as Object);

      // Act
      await vm.moveEvent(2, 'down');
      const moved = await vm.moveAllBacklogToSchedule();
      await vm.moveToBacklog(event);

      // Assert
      expect(manager.moveArgs).assertEqual('2:down');
      expect(moved).assertEqual(3);
      expect(manager.moveAllCalls).assertEqual(1);
      expect(manager.backlogId).assertEqual(8101);
    });

    it('boundary: event_mutation_facade_should_delegate_add_update_and_delete_operations', 0, async () => {
      // Arrange
      const vm = new TimelineViewModel();
      const manager = new EventMutationManagerStubCW();
      const event = createEventCW(8102);
      Reflect.set(vm as Object, 'eventMutationManager', manager as Object);

      // Act
      await vm.addNewItem('new_place_cw', 45, true, '10:00', 0, 5, false, 'note', 2, 31.2, 121.4);
      await vm.updateEventInfo(8102, 'updated_cw', 60, '11:00', 1, true, 'note2', 3, 31.3, 121.5);
      await vm.hardDelete(event);

      // Assert
      expect(manager.addName).assertEqual('new_place_cw');
      expect(manager.updateId).assertEqual(8102);
      expect(manager.hardDeleteId).assertEqual(8102);
    });

    it('invalid: conflict_resolution_facade_should_delegate_both_conflict_paths', 0, async () => {
      // Arrange
      const vm = new TimelineViewModel();
      const manager = new EventMutationManagerStubCW();
      Reflect.set(vm as Object, 'eventMutationManager', manager as Object);

      // Act
      await vm.resolveConflictByBacklog(8201, 'backlog_cw', 30, 'note', 1);
      await vm.resolveConflictByMovingPlan(8202, 1733000000000, 'move_cw', 45, true, '09:00', 'note2', 2);

      // Assert
      expect(manager.conflictBacklogId).assertEqual(8201);
      expect(manager.movingPlanId).assertEqual(8202);
    });

    it('conflict: persistence_facade_methods_should_delegate_plan_name_and_start_date', 0, async () => {
      // Arrange
      const vm = new TimelineViewModel();
      const persistence = new PersistenceStubCW();
      Reflect.set(vm as Object, 'persistence', persistence as Object);

      // Act
      await vm.persistPlanStartDate(8301, 1733000000000);
      await vm.persistPlanName(8302, 'plan_name_cw');

      // Assert
      expect(persistence.startDatePlanId).assertEqual(8301);
      expect(persistence.startDateValue).assertEqual(1733000000000);
      expect(persistence.namePlanId).assertEqual(8302);
      expect(persistence.nameValue).assertEqual('plan_name_cw');
    });

    it('regression: recalculation_facade_should_delegate_all_recalculation_entrypoints', 0, () => {
      // Arrange
      const vm = new TimelineViewModel();
      const manager = new RecalculationManagerStubCW();
      const event = createEventCW(8401);
      Reflect.set(vm as Object, 'recalculationManager', manager as Object);

      // Act
      vm.testAllCommute();
      vm.updateTravelMode(event, 3);
      const minutes = vm.resolveEffectiveGlobalStartMinutes();
      vm.logTimelineSnapshot('scene_cw');
      vm.recalculateFromEventId(8401);
      vm.recalculateFromIndex(2);
      vm.recalculate();
      vm.recalculateTrafficOnly();

      // Assert
      expect(minutes).assertEqual(540);
      expect(manager.calls.indexOf('testAllCommute') >= 0).assertTrue();
      expect(manager.calls.indexOf('updateTravelMode:8401:3') >= 0).assertTrue();
      expect(manager.calls.indexOf('resolveEffectiveGlobalStartMinutes') >= 0).assertTrue();
      expect(manager.calls.indexOf('log:scene_cw') >= 0).assertTrue();
      expect(manager.calls.indexOf('fromEvent:8401') >= 0).assertTrue();
      expect(manager.calls.indexOf('fromIndex:2') >= 0).assertTrue();
      expect(manager.calls.indexOf('recalculate') >= 0).assertTrue();
      expect(manager.calls.indexOf('trafficOnly') >= 0).assertTrue();
    });

    it('combined: weather_stage_and_gap_sync_facades_should_delegate_runtime_context', 0, () => {
      // Arrange
      const vm = new TimelineViewModel();
      const distribution = new DistributionCoordinatorStubCW();
      const companion = new CompanionManagerStubCW();
      const weather = new WeatherFacadeStubCW();
      const event = createEventCW(8501);
      vm.currentPlanStatus = PlanStatus.IN_PROGRESS;
      Reflect.set(vm as Object, 'distributionCoordinator', distribution as Object);
      Reflect.set(vm as Object, 'companionManager', companion as Object);
      Reflect.set(vm as Object, 'weatherFacade', weather as Object);

      // Act
      vm.resolveGapBySync(event);
      const stage = vm.resolveCurrentWeatherStage();

      // Assert
      expect(distribution.gapId).assertEqual(8501);
      expect(stage).assertEqual('IN_PROGRESS');
      expect(weather.statusValue).assertEqual(PlanStatus.IN_PROGRESS);
      expect(weather.runtimeStateValue).assertEqual('ACTIVE');
    });
  });
}
