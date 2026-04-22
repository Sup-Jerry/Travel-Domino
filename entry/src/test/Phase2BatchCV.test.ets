import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

class PlanStateManagerStubCV {
  pauseResult: boolean = true;
  resumeResult: boolean = true;
  sampleCalls: number = 0;
  lastLatitude: number = 0;
  lastLongitude: number = 0;
  lastSpeed: number = 0;
  lastAccuracy: number = 0;
  lastSampleTs: number = 0;

  onLocationSampleForStateMachine(
    latitude: number,
    longitude: number,
    speed?: number,
    accuracy?: number,
    sampleTs: number = 0
  ): void {
    this.sampleCalls += 1;
    this.lastLatitude = latitude;
    this.lastLongitude = longitude;
    this.lastSpeed = speed ?? 0;
    this.lastAccuracy = accuracy ?? 0;
    this.lastSampleTs = sampleTs;
  }

  pauseCurrentExecution(): boolean {
    return this.pauseResult;
  }

  resumeCurrentExecution(): boolean {
    return this.resumeResult;
  }
}

function createScheduleEventCV(id: number, sortOrder: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `cv_${id}`;
  event.status = 1;
  event.sort_order = sortOrder;
  event.duration = 30;
  event.day_offset = 0;
  return event;
}

export default function phase2BatchCVTest() {
  describe('phase2BatchCV_timeline_viewmodel_core_methods', () => {
    it('normal: mark_schedule_changed_should_increment_schedule_version', 0, () => {
      // Arrange
      const vm = new TimelineViewModel();
      const before = vm.getScheduleVersion();

      // Act
      vm.markScheduleChanged();
      vm.markScheduleChanged();

      // Assert
      expect(vm.getScheduleVersion()).assertEqual(before + 2);
    });

    it('boundary: get_schedule_orchestrator_should_return_stable_instance', 0, () => {
      // Arrange
      const vm = new TimelineViewModel();

      // Act
      const first = vm.getScheduleOrchestrator();
      const second = vm.getScheduleOrchestrator();

      // Assert
      expect(first === second).assertTrue();
      expect(first !== null).assertTrue();
    });

    it('invalid: regenerate_groups_should_handle_empty_events_without_mutation_noise', 0, () => {
      // Arrange
      const vm = new TimelineViewModel();
      vm.events = [];
      vm.planStartDate = 1733000000000;
      vm.filterStart = 1733000000000;
      vm.filterEnd = 1733086400000;

      // Act
      vm.regenerateGroups();

      // Assert
      expect(vm.groupedEvents.length).assertEqual(0);
      expect(vm.events.length).assertEqual(0);
    });

    it('conflict: refresh_timeline_view_should_clone_event_array_and_keep_grouping_valid', 0, () => {
      // Arrange
      const vm = new TimelineViewModel();
      const event = createScheduleEventCV(7401, 1);
      const original = [event];
      vm.events = original;
      vm.planStartDate = 1733000000000;

      // Act
      vm.refreshTimelineView();

      // Assert
      expect(vm.events === original).assertFalse();
      expect(vm.events.length).assertEqual(1);
      expect(vm.events[0].id).assertEqual(7401);
    });

    it('regression: viewmodel_getters_should_return_current_runtime_values', 0, () => {
      // Arrange
      const vm = new TimelineViewModel();
      vm.idleGapTriggerMinutes = 88;
      vm.currentPlanStatus = PlanStatus.IN_PROGRESS;
      vm.executionWeatherDisplaySource = 'NEXT_FALLBACK';

      // Act
      const gapMinutes = vm.getIdleGapTriggerMinutes();
      const status = vm.getCurrentPlanStatus();
      const source = vm.getExecutionWeatherDisplaySource();

      // Assert
      expect(gapMinutes).assertEqual(88);
      expect(status).assertEqual(PlanStatus.IN_PROGRESS);
      expect(source).assertEqual('NEXT_FALLBACK');
    });

    it('combined: state_machine_facade_methods_should_delegate_to_plan_state_manager', 0, () => {
      // Arrange
      const vm = new TimelineViewModel();
      const manager = new PlanStateManagerStubCV();
      manager.pauseResult = false;
      manager.resumeResult = true;
      Reflect.set(vm as Object, 'planStateManager', manager as Object);

      // Act
      vm.onLocationSampleForStateMachine(31.23, 121.47, 3, 25, 1733000000000);
      const paused = vm.pauseCurrentExecution();
      const resumed = vm.resumeCurrentExecution();

      // Assert
      expect(manager.sampleCalls).assertEqual(1);
      expect(manager.lastLatitude).assertEqual(31.23);
      expect(manager.lastLongitude).assertEqual(121.47);
      expect(manager.lastSpeed).assertEqual(3);
      expect(manager.lastAccuracy).assertEqual(25);
      expect(manager.lastSampleTs).assertEqual(1733000000000);
      expect(paused).assertFalse();
      expect(resumed).assertTrue();
    });
  });
}
