import { describe, expect, it } from '@ohos/hypium';
import { PreferenceManager } from '../main/ets/common/utils/PreferenceManager';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import { PlanEventsSnapshot } from '../main/ets/viewmodel/internal/PlanPersistenceFacade';
import { TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

class PreferenceHookCY {
  private readonly originalGetInstance: Object;

  constructor() {
    this.originalGetInstance = Reflect.get(PreferenceManager as Object, 'getInstance') as Object;
  }

  set(instance: Object): void {
    Reflect.set(PreferenceManager as Object, 'getInstance', (): Object => instance);
  }

  restore(): void {
    Reflect.set(PreferenceManager as Object, 'getInstance', this.originalGetInstance);
  }
}

class PreferenceStubCY {
  minDuration: number = 45;
  idleEnabled: boolean = true;
  idleMinutes: number = 20;
  amapEnabled: boolean = true;
  throwMin: boolean = false;
  throwAmap: boolean = false;

  async getMinEventDuration(): Promise<number> {
    if (this.throwMin) {
      throw new Error('min_duration_fail_cy');
    }
    return this.minDuration;
  }

  async getIdleGapDetectionEnabled(): Promise<boolean> {
    return this.idleEnabled;
  }

  async getIdleGapTriggerMinutes(): Promise<number> {
    return this.idleMinutes;
  }

  async isAmapRouteApiEnabled(): Promise<boolean> {
    if (this.throwAmap) {
      throw new Error('amap_fail_cy');
    }
    return this.amapEnabled;
  }
}

class PlanRecordCY {
  id: number = 1;
  title: string = 'loaded_plan_cy';
  createdAt: number = 1;
  startDate: number = 1733000000000;
  status: number = 0;
  enableAutoAmapRoute: number = 1;
  strategyMode: number = 2;
}

class TravelPlanItemCY implements TravelPlanItem {
  id?: number;
  name: string = '';
  status: number = 1;
  duration: number = 30;
  preTravelMinutes: number = 0;
  sortOrder: number = 0;
  type: string = 'FLOW';
  dayOffset?: number;
  actualStartTime?: number;
  actualEndTime?: number;
  completionStatus?: number;

  constructor(id: number, name: string, sortOrder: number, dayOffset: number) {
    this.id = id;
    this.name = name;
    this.sortOrder = sortOrder;
    this.dayOffset = dayOffset;
  }
}

class PlanEventsSnapshotCY implements PlanEventsSnapshot {
  plan?: PlanRecordCY;
  events: TravelPlanItem[] = [];
}

class PersistenceStubCY {
  calls: number = 0;
  snapshot: PlanEventsSnapshot = new PlanEventsSnapshotCY();

  async getPlanAndEvents(_planId: number): Promise<PlanEventsSnapshot> {
    this.calls += 1;
    return this.snapshot;
  }
}

class WeatherCoordinatorStubCY {
  restoredPlanId: number = 0;
  reloadCalls: number = 0;

  restorePlanningWeatherSnapshot(planId: number): void {
    this.restoredPlanId = planId;
  }

  async reloadWeatherUserPreference(): Promise<void> {
    this.reloadCalls += 1;
  }
}

class RecalculationManagerStubCY {
  calls: number = 0;

  recalculate(): void {
    this.calls += 1;
  }
}

class PlanStateManagerStubCY {
  boundPlanId: number = 0;

  bindPlanState(planId: number): void {
    this.boundPlanId = planId;
  }
}

function createEventCY(id: number, name: string, dayOffset: number, sortOrder: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.status = 1;
  event.duration = 30;
  event.day_offset = dayOffset;
  event.dynamic_day_offset = dayOffset;
  event.sort_order = sortOrder;
  return event;
}

export default function phase2BatchCYTest() {
  describe('phase2BatchCY_timeline_viewmodel_load_preferences_and_grouping', () => {
    it('normal: preference_backed_methods_should_load_min_duration_and_route_switches', 0, async () => {
      // Arrange
      const vm = new TimelineViewModel();
      const pref = new PreferenceStubCY();
      const weather = new WeatherCoordinatorStubCY();
      const hook = new PreferenceHookCY();
      Reflect.set(vm as Object, 'weatherCoordinator', weather as Object);
      hook.set(pref as Object);
      try {
        // Act
        await vm.reloadMinEventDurationLimit();
        await vm.reloadRouteSwitches();

        // Assert
        expect(vm.getMinEventDurationLimit()).assertEqual(45);
        expect(vm.getIdleGapTriggerMinutes()).assertEqual(20);
        expect(vm.isAutoRouteEnabled()).assertTrue();
        expect(weather.reloadCalls).assertEqual(1);
      } finally {
        hook.restore();
      }
    });

    it('boundary: load_data_should_map_snapshot_events_and_restore_planning_state', 0, async () => {
      // Arrange
      const vm = new TimelineViewModel();
      const pref = new PreferenceStubCY();
      const hook = new PreferenceHookCY();
      const persistence = new PersistenceStubCY();
      const weather = new WeatherCoordinatorStubCY();
      const recalculation = new RecalculationManagerStubCY();
      const planState = new PlanStateManagerStubCY();
      const itemA = new TravelPlanItemCY(9601, 'load_a_cy', 2, 1);
      const itemB = new TravelPlanItemCY(9602, 'load_b_cy', 1, 0);
      const plan = new PlanRecordCY();
      const snapshot = new PlanEventsSnapshotCY();
      snapshot.plan = plan;
      snapshot.events = [itemA, itemB];
      persistence.snapshot = snapshot;
      Reflect.set(vm as Object, 'persistence', persistence as Object);
      Reflect.set(vm as Object, 'weatherCoordinator', weather as Object);
      Reflect.set(vm as Object, 'recalculationManager', recalculation as Object);
      Reflect.set(vm as Object, 'planStateManager', planState as Object);
      hook.set(pref as Object);
      try {
        // Act
        await vm.loadData(9600);

        // Assert
        expect(persistence.calls).assertEqual(1);
        expect(vm.planName).assertEqual('loaded_plan_cy');
        expect(vm.events.length).assertEqual(2);
        expect(vm.groupedEvents.length).assertLarger(0);
        expect(weather.restoredPlanId).assertEqual(9600);
        expect(recalculation.calls).assertEqual(1);
        expect(planState.boundPlanId).assertEqual(9600);
      } finally {
        hook.restore();
      }
    });

    it('invalid: preference_failures_should_fallback_without_breaking_route_reload', 0, async () => {
      // Arrange
      const vm = new TimelineViewModel();
      const pref = new PreferenceStubCY();
      const weather = new WeatherCoordinatorStubCY();
      const hook = new PreferenceHookCY();
      pref.throwMin = true;
      pref.throwAmap = true;
      Reflect.set(vm as Object, 'weatherCoordinator', weather as Object);
      hook.set(pref as Object);
      try {
        // Act
        await vm.reloadMinEventDurationLimit();
        await vm.reloadRouteSwitches();

        // Assert
        expect(vm.getMinEventDurationLimit()).assertEqual(30);
        expect(vm.isAutoRouteEnabled()).assertFalse();
        expect(weather.reloadCalls).assertEqual(1);
      } finally {
        hook.restore();
      }
    });

    it('conflict: sorted_gaps_should_exclude_first_day_item_and_keep_same_day_gaps', 0, () => {
      // Arrange
      const vm = new TimelineViewModel();
      const first = createEventCY(9701, 'first_cy', 0, 1);
      const sameDayGap = createEventCY(9702, 'same_gap_cy', 0, 2);
      const nextDayGap = createEventCY(9703, 'next_gap_cy', 1, 3);
      first.has_gap = true;
      first.gap_minutes = 50;
      sameDayGap.has_gap = true;
      sameDayGap.gap_minutes = 60;
      nextDayGap.has_gap = true;
      nextDayGap.gap_minutes = 70;
      vm.events = [nextDayGap, sameDayGap, first];
      Reflect.set(vm as Object, 'idleGapDetectionEnabled', true);
      Reflect.set(vm as Object, 'idleGapTriggerMinutes', 30);

      // Act
      const gaps = vm.getSortedGaps();

      // Assert
      expect(gaps.length).assertEqual(1);
      expect(gaps[0].id).assertEqual(9702);
    });

    it('regression: weather_preference_and_postpone_marker_should_use_vm_state', 0, () => {
      // Arrange
      const vm = new TimelineViewModel();
      vm.weatherUserPreference = {
        heatSensitivity: 2,
        rainSensitivity: 0,
        weatherRiskTolerance: 1
      };
      vm.setHasUnsavedPostponeStorageKey('phase2_cy_unsaved_postpone');

      // Act
      const pref = vm.getWeatherUserPreference();
      vm.markHasUnsavedPostpone();

      // Assert
      expect(pref.heatSensitivity).assertEqual(2);
      expect(pref.rainSensitivity).assertEqual(0);
      expect(pref.weatherRiskTolerance).assertEqual(1);
    });

    it('combined: place_checkin_summaries_should_group_completed_and_skipped_records', 0, () => {
      // Arrange
      const vm = new TimelineViewModel();
      const completed = createEventCY(9801, 'Museum_CY', 0, 1);
      completed.actual_start_time = 1000;
      completed.actual_end_time = 1000 + 60 * 60000;
      completed.completion_status = EventEntity.STATE_COMPLETED;
      const skipped = createEventCY(9802, 'Museum_CY', 1, 2);
      skipped.actual_start_time = 2000;
      skipped.actual_end_time = 2000;
      skipped.completion_status = EventEntity.STATE_SKIPPED;
      const pending = createEventCY(9803, 'Cafe_CY', 0, 3);
      pending.completion_status = EventEntity.STATE_PENDING;
      vm.events = [completed, skipped, pending];

      // Act
      const summaries = vm.getAllPlaceCheckinSummaries();
      const museum = vm.getPlaceCheckinSummary('museum_cy');

      // Assert
      expect(summaries.length).assertEqual(1);
      expect(museum.totalRecords).assertEqual(2);
      expect(museum.completedRecords).assertEqual(1);
      expect(museum.skippedRecords).assertEqual(1);
      expect(museum.avgStayMinutes).assertEqual(60);
    });
  });
}
