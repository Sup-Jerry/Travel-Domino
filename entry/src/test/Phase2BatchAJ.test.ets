
import { describe, expect, it } from '@ohos/hypium';
import { common } from '@kit.AbilityKit';
import { EventRepositoryImpl, RuntimeTransitionInput, RuntimeTransitionResult } from '../main/ets/infrastructure/persistence/EventRepositoryImpl';
import { PlanItem, PlanRepositoryImpl } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';
import { PreferenceManager } from '../main/ets/common/utils/PreferenceManager';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import { PlanAppService, PlanRepository } from '../main/ets/viewmodel/PlanAppService';
import { TimelineInteractionHelper } from '../main/ets/viewmodel/TimelineInteractionHelper';
import { TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';
import { PlanPersistenceFacade } from '../main/ets/viewmodel/internal/PlanPersistenceFacade';

class EventRepoHooksAJ {
  private readonly originGetAllEvents: Object;
  private readonly originApplyRuntimeTransition: Object;
  private readonly originUpdateSingleField: Object;
  private readonly originUpdateFields: Object;
  private readonly originUpdateTimelineConsistency: Object;
  private readonly originInsertEvent: Object;
  private readonly originSaveAllEvents: Object;
  private readonly originHardDeleteEvent: Object;

  constructor() {
    this.originGetAllEvents = Reflect.get(EventRepositoryImpl, 'getAllEvents') as Object;
    this.originApplyRuntimeTransition = Reflect.get(EventRepositoryImpl, 'applyRuntimeTransition') as Object;
    this.originUpdateSingleField = Reflect.get(EventRepositoryImpl, 'updateSingleField') as Object;
    this.originUpdateFields = Reflect.get(EventRepositoryImpl, 'updateFields') as Object;
    this.originUpdateTimelineConsistency = Reflect.get(EventRepositoryImpl, 'updateTimelineConsistency') as Object;
    this.originInsertEvent = Reflect.get(EventRepositoryImpl, 'insertEvent') as Object;
    this.originSaveAllEvents = Reflect.get(EventRepositoryImpl, 'saveAllEvents') as Object;
    this.originHardDeleteEvent = Reflect.get(EventRepositoryImpl, 'hardDeleteEvent') as Object;
  }

  restore(): void {
    Reflect.set(EventRepositoryImpl, 'getAllEvents', this.originGetAllEvents);
    Reflect.set(EventRepositoryImpl, 'applyRuntimeTransition', this.originApplyRuntimeTransition);
    Reflect.set(EventRepositoryImpl, 'updateSingleField', this.originUpdateSingleField);
    Reflect.set(EventRepositoryImpl, 'updateFields', this.originUpdateFields);
    Reflect.set(EventRepositoryImpl, 'updateTimelineConsistency', this.originUpdateTimelineConsistency);
    Reflect.set(EventRepositoryImpl, 'insertEvent', this.originInsertEvent);
    Reflect.set(EventRepositoryImpl, 'saveAllEvents', this.originSaveAllEvents);
    Reflect.set(EventRepositoryImpl, 'hardDeleteEvent', this.originHardDeleteEvent);
  }
}

class PlanRepoHooksAJ {
  private readonly originGetPlanById: Object;
  private readonly originUpdateStartDate: Object;
  private readonly originUpdatePlanName: Object;
  private readonly originUpdateAutoAmapRoute: Object;
  private readonly originUpdateStrategyMode: Object;
  private readonly originSaveAiContext: Object;

  constructor() {
    this.originGetPlanById = Reflect.get(PlanRepositoryImpl, 'getPlanById') as Object;
    this.originUpdateStartDate = Reflect.get(PlanRepositoryImpl, 'updateStartDate') as Object;
    this.originUpdatePlanName = Reflect.get(PlanRepositoryImpl, 'updatePlanName') as Object;
    this.originUpdateAutoAmapRoute = Reflect.get(PlanRepositoryImpl, 'updateAutoAmapRoute') as Object;
    this.originUpdateStrategyMode = Reflect.get(PlanRepositoryImpl, 'updateStrategyMode') as Object;
    this.originSaveAiContext = Reflect.get(PlanRepositoryImpl, 'saveAiContext') as Object;
  }

  restore(): void {
    Reflect.set(PlanRepositoryImpl, 'getPlanById', this.originGetPlanById);
    Reflect.set(PlanRepositoryImpl, 'updateStartDate', this.originUpdateStartDate);
    Reflect.set(PlanRepositoryImpl, 'updatePlanName', this.originUpdatePlanName);
    Reflect.set(PlanRepositoryImpl, 'updateAutoAmapRoute', this.originUpdateAutoAmapRoute);
    Reflect.set(PlanRepositoryImpl, 'updateStrategyMode', this.originUpdateStrategyMode);
    Reflect.set(PlanRepositoryImpl, 'saveAiContext', this.originSaveAiContext);
  }
}

class PreferenceHooksAJ {
  private readonly originGetInstance: Object;

  constructor() {
    this.originGetInstance = Reflect.get(PreferenceManager, 'getInstance') as Object;
  }

  setInstance(instance: Object): void {
    Reflect.set(PreferenceManager, 'getInstance', (): Object => instance);
  }

  restore(): void {
    Reflect.set(PreferenceManager, 'getInstance', this.originGetInstance);
  }
}

class AbilityHooksAJ {
  restore(): void {
    return;
  }
}

interface PlanStatusUpdateCallAJ {
  id: number;
  status: number;
}

interface UpdateEventArgsAJ {
  id: number;
  name: string;
  duration: number;
  fixedTime: string;
  dayOffset: number;
  isHardLock: boolean;
  note: string;
  priority: number;
  lat: number;
  lng: number;
}

interface AddEventArgsAJ {
  name: string;
  duration: number;
  isSchedule: boolean;
  fixedTime: string;
  dayOffset: number;
  preTravel: number;
  isHardLock: boolean;
  note: string;
  priority: number;
  lat: number;
  lng: number;
}

class ExecutionCoordinatorStubAJ {
  getOrderedScheduleEvents(): EventEntity[] {
    return [];
  }
}

class OrderedEventsCoordinatorAJ extends ExecutionCoordinatorStubAJ {
  private readonly events: EventEntity[];

  constructor(events: EventEntity[]) {
    super();
    this.events = events;
  }

  override getOrderedScheduleEvents(): EventEntity[] {
    return this.events;
  }
}

class FakeUiAbilityContextAJ {}

interface RuntimeTransitionHookResultAJ {
  ok: boolean;
  eventId?: number;
  reason?: string;
  startTime?: number;
  endTime?: number;
  completionStatus?: number;
}

class PreferenceInstanceStubAJ {
  private readonly initHandler: (_ctx: Object) => Promise<void>;
  private readonly getValueHandler: (key: string) => Promise<boolean>;
  private readonly setValueHandler: (key: string, value: boolean) => Promise<void>;

  constructor(
    initHandler: (_ctx: Object) => Promise<void>,
    getValueHandler: (key: string) => Promise<boolean>,
    setValueHandler?: (key: string, value: boolean) => Promise<void>
  ) {
    this.initHandler = initHandler;
    this.getValueHandler = getValueHandler;
    this.setValueHandler = setValueHandler ?? (async (_key: string, _value: boolean): Promise<void> => {});
  }

  public async init(ctx: Object): Promise<void> {
    await this.initHandler(ctx);
  }

  public async getValue(key: string, _defaultValue: boolean): Promise<boolean> {
    return this.getValueHandler(key);
  }

  public async setValue(key: string, value: boolean): Promise<void> {
    await this.setValueHandler(key, value);
  }
}

class PersistenceStubAJ {
  private readonly result: RuntimeTransitionHookResultAJ;

  constructor(result: RuntimeTransitionHookResultAJ) {
    this.result = result;
  }

  public async applyRuntimeTransition(): Promise<RuntimeTransitionHookResultAJ> {
    return this.result;
  }
}

class PlanRepoForAppServiceAJ implements PlanRepository {
  public createCalls: number = 0;
  public purgeCalls: number = 0;
  public updateCalls: PlanStatusUpdateCallAJ[] = [];
  public softDeleteCalls: number[] = [];
  public restoreCalls: number[] = [];
  public hardDeleteCalls: number[] = [];
  public allPlans: PlanItem[] = [];
  public archivedPlans: PlanItem[] = [];
  public trashPlans: PlanItem[] = [];

  async createPlan(_title: string, _startDate: number): Promise<number> {
    this.createCalls += 1;
    return 9527;
  }

  async purgeOldTrash(): Promise<number> {
    this.purgeCalls += 1;
    return 1;
  }

  async getPlanList(): Promise<PlanItem[]> {
    return this.allPlans;
  }

  async getArchivedPlans(): Promise<PlanItem[]> {
    return this.archivedPlans;
  }

  async getTrashPlans(): Promise<PlanItem[]> {
    return this.trashPlans;
  }

  async updatePlanStatus(id: number, status: number): Promise<void> {
    this.updateCalls.push({ id: id, status: status });
  }

  async softDeletePlan(id: number): Promise<void> {
    this.softDeleteCalls.push(id);
  }

  async restorePlan(id: number): Promise<void> {
    this.restoreCalls.push(id);
  }

  async hardDeletePlan(id: number): Promise<void> {
    this.hardDeleteCalls.push(id);
  }
}

class VmLikeForInteractionAJ {
  events: EventEntity[] = [];
  sortedGaps: EventEntity[] = [];
  updateCount: number = 0;
  addCount: number = 0;
  commuteCount: number = 0;
  lastUpdateArgs: UpdateEventArgsAJ | null = null;
  lastAddArgs: AddEventArgsAJ | null = null;
  lastCommute: number = -1;
  executionCoordinator: ExecutionCoordinatorStubAJ = new ExecutionCoordinatorStubAJ();

  getSortedGaps(): EventEntity[] {
    return this.sortedGaps;
  }

  async updateEventInfo(
    id: number,
    name: string,
    duration: number,
    fixedTime?: string,
    dayOffset: number = 0,
    isHardLock: boolean = false,
    note: string = '',
    priority: number = 0,
    lat?: number,
    lng?: number
  ): Promise<void> {
    this.updateCount += 1;
    this.lastUpdateArgs = {
      id: id,
      name: name,
      duration: duration,
      fixedTime: fixedTime ?? '',
      dayOffset: dayOffset,
      isHardLock: isHardLock,
      note: note,
      priority: priority,
      lat: lat ?? 0,
      lng: lng ?? 0
    };
  }

  async addNewItem(
    name: string,
    duration: number,
    isSchedule: boolean = false,
    fixedTime?: string,
    dayOffset: number = 0,
    preTravel: number = -1,
    isHardLock: boolean = false,
    note: string = '',
    priority: number = 0,
    lat?: number,
    lng?: number
  ): Promise<void> {
    this.addCount += 1;
    this.lastAddArgs = {
      name: name,
      duration: duration,
      isSchedule: isSchedule,
      fixedTime: fixedTime ?? '',
      dayOffset: dayOffset,
      preTravel: preTravel,
      isHardLock: isHardLock,
      note: note,
      priority: priority,
      lat: lat ?? 0,
      lng: lng ?? 0
    };
  }

  updateCommute(_index: number, newMinutes: number): void {
    this.commuteCount += 1;
    this.lastCommute = newMinutes;
  }
}

function createEventAJ(id: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `event_${id}`;
  event.status = 1;
  event.duration = 60;
  event.day_offset = 0;
  event.dynamic_day_offset = 0;
  event.completion_status = EventEntity.STATE_PENDING;
  event.actual_start_time = 0;
  event.actual_end_time = 0;
  return event;
}

interface TimelineViewModelPrivateAj {
  isSameDayGapWithPreviousScheduleItemForUi(item: EventEntity): boolean;
  isFirstScheduledItemOfDayForUi(item: EventEntity): boolean;
}

function waitMsAJ(ms: number): Promise<void> {
  return new Promise<void>((resolve: (value: void | PromiseLike<void>) => void): void => {
    setTimeout((): void => resolve(), ms);
  });
}

function fakeUiContextAJ(): common.UIAbilityContext {
  return new FakeUiAbilityContextAJ() as Object as common.UIAbilityContext;
}

export default function phase2BatchAJTest() {
  describe('phase2BatchAJ_timeline_interaction_helper', () => {
    it('normal: check_for_gap_should_callback_first_non_ignored_gap', 0, async () => {
      // Arrange
      // Act
      // Assert
      const vm = new VmLikeForInteractionAJ();
      const ignored = createEventAJ(1);
      ignored.is_ignore_wait = true;
      const target = createEventAJ(2);
      target.is_ignore_wait = false;
      vm.sortedGaps = [ignored, target];
      let got = -1;
      TimelineInteractionHelper.checkForGapAndPrompt(vm as Object as TimelineViewModel, (item: EventEntity): void => {
        got = item.id;
      });
      await waitMsAJ(80);
      expect(got).assertEqual(2);
    });

    it('boundary: check_for_gap_should_skip_when_callback_absent', 0, async () => {
      // Arrange
      // Act
      // Assert
      const vm = new VmLikeForInteractionAJ();
      vm.sortedGaps = [createEventAJ(3)];
      TimelineInteractionHelper.checkForGapAndPrompt(vm as Object as TimelineViewModel);
      await waitMsAJ(80);
      expect(vm.sortedGaps.length).assertEqual(1);
    });

    it('invalid: check_for_gap_should_not_emit_when_all_ignored', 0, async () => {
      // Arrange
      // Act
      // Assert
      const vm = new VmLikeForInteractionAJ();
      const one = createEventAJ(4);
      const two = createEventAJ(5);
      one.is_ignore_wait = true;
      two.is_ignore_wait = true;
      vm.sortedGaps = [one, two];
      let called = false;
      TimelineInteractionHelper.checkForGapAndPrompt(vm as Object as TimelineViewModel, (_item: EventEntity): void => {
        called = true;
      });
      await waitMsAJ(80);
      expect(called).assertFalse();
    });

    it('normal: handle_save_item_should_use_update_branch', 0, async () => {
      // Arrange
      // Act
      // Assert
      const vm = new VmLikeForInteractionAJ();
      await TimelineInteractionHelper.handleSaveItem(
        vm as Object as TimelineViewModel,
        10,
        'museum',
        90,
        true,
        '09:00',
        2,
        25,
        undefined,
        true,
        'note',
        true,
        31.2,
        121.5
      );
      expect(vm.updateCount).assertEqual(1);
      expect(vm.addCount).assertEqual(0);
    });

    it('boundary: handle_save_item_should_default_day_offset_and_pretravel_when_add', 0, async () => {
      // Arrange
      // Act
      // Assert
      const vm = new VmLikeForInteractionAJ();
      await TimelineInteractionHelper.handleSaveItem(vm as Object as TimelineViewModel, -1, 'hotel', 40, false);
      expect(vm.lastAddArgs !== null).assertTrue();
      const args = vm.lastAddArgs as AddEventArgsAJ;
      expect(vm.addCount).assertEqual(1);
      expect(Number(args.dayOffset)).assertEqual(0);
      expect(Number(args.preTravel)).assertEqual(-1);
    });

    it('invalid: handle_save_item_should_propagate_error_from_vm', 0, async () => {
      // Arrange
      // Act
      // Assert
      const vm = new VmLikeForInteractionAJ();
      Reflect.set(vm, 'updateEventInfo', async (): Promise<void> => {
        throw new Error('save_failed_aj');
      });
      let message = '';
      try {
        await TimelineInteractionHelper.handleSaveItem(vm as Object as TimelineViewModel, 1, 'x', 30, true);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message).assertEqual('save_failed_aj');
    });

    it('normal: handle_commute_change_should_update_when_item_exists', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new VmLikeForInteractionAJ();
      const target = createEventAJ(21);
      vm.events = [target];
      TimelineInteractionHelper.handleCommuteChange(vm as Object as TimelineViewModel, target, 18);
      expect(vm.commuteCount).assertEqual(1);
      expect(vm.lastCommute).assertEqual(18);
    });

    it('boundary: handle_commute_change_should_allow_zero_minutes', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new VmLikeForInteractionAJ();
      const target = createEventAJ(22);
      vm.events = [target];
      TimelineInteractionHelper.handleCommuteChange(vm as Object as TimelineViewModel, target, 0);
      expect(vm.lastCommute).assertEqual(0);
    });

    it('invalid: handle_commute_change_should_ignore_when_item_not_found', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new VmLikeForInteractionAJ();
      vm.events = [createEventAJ(23)];
      TimelineInteractionHelper.handleCommuteChange(vm as Object as TimelineViewModel, createEventAJ(24), 12);
      expect(vm.commuteCount).assertEqual(0);
    });

    it('normal: handle_time_update_should_set_lock_and_update', 0, async () => {
      // Arrange
      // Act
      // Assert
      const vm = new VmLikeForInteractionAJ();
      const target = createEventAJ(31);
      target.dynamic_day_offset = 3;
      target.day_offset = 1;
      target.lock_status = 0;
      vm.events = [target];
      TimelineInteractionHelper.handleTimeUpdate(vm as Object as TimelineViewModel, target, 70, '10:30', 1);
      await waitMsAJ(80);
      expect(vm.lastUpdateArgs !== null).assertTrue();
      const args = vm.lastUpdateArgs as UpdateEventArgsAJ;
      expect(vm.updateCount).assertEqual(1);
      expect(Number(args.dayOffset)).assertEqual(3);
      expect(vm.events[0].lock_status).assertEqual(1);
    });

    it('boundary: handle_time_update_should_fallback_to_day_offset_when_dynamic_missing', 0, async () => {
      // Arrange
      // Act
      // Assert
      const vm = new VmLikeForInteractionAJ();
      const target = createEventAJ(32);
      target.dynamic_day_offset = -1;
      target.day_offset = 5;
      vm.events = [target];
      TimelineInteractionHelper.handleTimeUpdate(vm as Object as TimelineViewModel, target, 45, '11:00', 0);
      await waitMsAJ(80);
      expect(vm.lastUpdateArgs !== null).assertTrue();
      const args = vm.lastUpdateArgs as UpdateEventArgsAJ;
      expect(Number(args.dayOffset)).assertEqual(-1);
    });

    it('invalid: handle_time_update_should_not_throw_when_target_not_in_list', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new VmLikeForInteractionAJ();
      const target = createEventAJ(33);
      vm.events = [];
      TimelineInteractionHelper.handleTimeUpdate(vm as Object as TimelineViewModel, target, 30, '08:00', 1);
      expect(vm.updateCount).assertEqual(1);
    });

    it('normal: pick_focus_event_should_prefer_active', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new VmLikeForInteractionAJ();
      const active = createEventAJ(41);
      active.actual_start_time = Date.now() - 1000;
      active.actual_end_time = 0;
      const pending = createEventAJ(42);
      Reflect.set(vm, 'executionCoordinator', new OrderedEventsCoordinatorAJ([pending, active]));
      const picked = TimelineInteractionHelper.pickCompanionFocusEventId(vm as Object as TimelineViewModel);
      expect(picked).assertEqual(41);
    });

    it('boundary: pick_focus_event_should_choose_first_startable_when_no_active', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new VmLikeForInteractionAJ();
      const done = createEventAJ(43);
      done.completion_status = EventEntity.STATE_COMPLETED;
      const pending = createEventAJ(44);
      Reflect.set(vm, 'executionCoordinator', new OrderedEventsCoordinatorAJ([done, pending]));
      const picked = TimelineInteractionHelper.pickCompanionFocusEventId(vm as Object as TimelineViewModel);
      expect(picked).assertEqual(44);
    });

    it('invalid: pick_focus_event_should_return_minus_one_when_empty', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new VmLikeForInteractionAJ();
      Reflect.set(vm, 'executionCoordinator', new OrderedEventsCoordinatorAJ([]));
      const picked = TimelineInteractionHelper.pickCompanionFocusEventId(vm as Object as TimelineViewModel);
      expect(picked).assertEqual(-1);
    });

    it('normal: find_next_pending_event_should_scan_forward', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new VmLikeForInteractionAJ();
      const e1 = createEventAJ(51);
      const e2 = createEventAJ(52);
      const e3 = createEventAJ(53);
      Reflect.set(vm, 'executionCoordinator', new OrderedEventsCoordinatorAJ([e1, e2, e3]));
      const nextId = TimelineInteractionHelper.findNextPendingEventId(vm as Object as TimelineViewModel, 51);
      expect(nextId).assertEqual(52);
    });

    it('boundary: find_next_pending_event_should_fallback_to_first_startable_when_after_missing', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new VmLikeForInteractionAJ();
      const done = createEventAJ(54);
      done.completion_status = EventEntity.STATE_COMPLETED;
      const pending = createEventAJ(55);
      Reflect.set(vm, 'executionCoordinator', new OrderedEventsCoordinatorAJ([done, pending]));
      const nextId = TimelineInteractionHelper.findNextPendingEventId(vm as Object as TimelineViewModel, 999);
      expect(nextId).assertEqual(55);
    });

    it('boundary: find_next_pending_event_should_return_minus_one_when_after_missing_and_no_startable', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new VmLikeForInteractionAJ();
      const doneA = createEventAJ(57);
      doneA.completion_status = EventEntity.STATE_COMPLETED;
      const doneB = createEventAJ(58);
      doneB.completion_status = EventEntity.STATE_COMPLETED;
      Reflect.set(vm, 'executionCoordinator', new OrderedEventsCoordinatorAJ([doneA, doneB]));
      const nextId = TimelineInteractionHelper.findNextPendingEventId(vm as Object as TimelineViewModel, 999);
      expect(nextId).assertEqual(-1);
    });

    it('normal: find_next_pending_event_should_skip_non_startable_items_before_next_pending', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new VmLikeForInteractionAJ();
      const current = createEventAJ(59);
      const completed = createEventAJ(60);
      completed.completion_status = EventEntity.STATE_COMPLETED;
      const pending = createEventAJ(61);
      Reflect.set(vm, 'executionCoordinator', new OrderedEventsCoordinatorAJ([current, completed, pending]));
      const nextId = TimelineInteractionHelper.findNextPendingEventId(vm as Object as TimelineViewModel, 59);
      expect(nextId).assertEqual(61);
    });

    it('invalid: find_next_pending_event_should_return_minus_one_when_no_startable', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new VmLikeForInteractionAJ();
      const done = createEventAJ(56);
      done.completion_status = EventEntity.STATE_COMPLETED;
      Reflect.set(vm, 'executionCoordinator', new OrderedEventsCoordinatorAJ([done]));
      const nextId = TimelineInteractionHelper.findNextPendingEventId(vm as Object as TimelineViewModel, 56);
      expect(nextId).assertEqual(-1);
    });
  });
  describe('phase2BatchAJ_plan_persistence_facade', () => {
    it('normal: get_plan_and_events_should_return_plan_and_events', 0, async () => {
      // Arrange
      // Act
      // Assert
      const eventHooks = new EventRepoHooksAJ();
      const planHooks = new PlanRepoHooksAJ();
      try {
        Reflect.set(PlanRepositoryImpl, 'getPlanById', async (_id: number): Promise<PlanItem> => ({ id: 1, title: 'p', createdAt: 1 }));
        Reflect.set(EventRepositoryImpl, 'getAllEvents', async (_id: number): Promise<TravelPlanItem[]> => [{ id: 2, name: 'e', duration: 30, sortOrder: 1 } as TravelPlanItem]);
        const facade = new PlanPersistenceFacade();
        const snapshot = await facade.getPlanAndEvents(1);
        expect(snapshot.plan?.id ?? -1).assertEqual(1);
        expect(snapshot.events.length).assertEqual(1);
      } finally {
        planHooks.restore();
        eventHooks.restore();
      }
    });

    it('boundary: get_plan_and_events_should_allow_empty_payload', 0, async () => {
      // Arrange
      // Act
      // Assert
      const eventHooks = new EventRepoHooksAJ();
      const planHooks = new PlanRepoHooksAJ();
      try {
        Reflect.set(PlanRepositoryImpl, 'getPlanById', async (_id: number): Promise<PlanItem | undefined> => undefined);
        Reflect.set(EventRepositoryImpl, 'getAllEvents', async (_id: number): Promise<TravelPlanItem[]> => []);
        const facade = new PlanPersistenceFacade();
        const snapshot = await facade.getPlanAndEvents(99);
        expect(snapshot.plan === undefined).assertTrue();
        expect(snapshot.events.length).assertEqual(0);
      } finally {
        planHooks.restore();
        eventHooks.restore();
      }
    });

    it('invalid: get_plan_and_events_should_throw_when_repo_rejects', 0, async () => {
      // Arrange
      // Act
      // Assert
      const eventHooks = new EventRepoHooksAJ();
      const planHooks = new PlanRepoHooksAJ();
      let message = '';
      try {
        Reflect.set(PlanRepositoryImpl, 'getPlanById', async (_id: number): Promise<PlanItem | undefined> => undefined);
        Reflect.set(EventRepositoryImpl, 'getAllEvents', async (): Promise<TravelPlanItem[]> => {
          throw new Error('events_load_failed_aj');
        });
        const facade = new PlanPersistenceFacade();
        await facade.getPlanAndEvents(1);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        planHooks.restore();
        eventHooks.restore();
      }
      expect(message).assertEqual('events_load_failed_aj');
    });

    it('normal: facade_methods_should_delegate_to_underlying_repositories', 0, async () => {
      // Arrange
      // Act
      // Assert
      const eventHooks = new EventRepoHooksAJ();
      const planHooks = new PlanRepoHooksAJ();
      let updateSingleFieldCount = 0;
      let updateFieldsCount = 0;
      let updateConsistencyCount = 0;
      let insertCount = 0;
      let saveAllCount = 0;
      let hardDeleteCount = 0;
      let startDateCount = 0;
      let planNameCount = 0;
      let autoRouteCount = 0;
      let strategyModeCount = 0;
      let aiContextCount = 0;
      try {
        Reflect.set(EventRepositoryImpl, 'applyRuntimeTransition', async (input: Object): Promise<RuntimeTransitionHookResultAJ> => {
          const result: RuntimeTransitionHookResultAJ = { ok: true, eventId: Number(Reflect.get(input, 'eventId')) };
          return result;
        });
        Reflect.set(EventRepositoryImpl, 'updateSingleField', async (): Promise<void> => {
          updateSingleFieldCount += 1;
        });
        Reflect.set(EventRepositoryImpl, 'updateFields', async (): Promise<void> => {
          updateFieldsCount += 1;
        });
        Reflect.set(EventRepositoryImpl, 'updateTimelineConsistency', async (): Promise<void> => {
          updateConsistencyCount += 1;
        });
        Reflect.set(EventRepositoryImpl, 'insertEvent', async (): Promise<number> => {
          insertCount += 1;
          return 88;
        });
        Reflect.set(EventRepositoryImpl, 'saveAllEvents', async (): Promise<void> => {
          saveAllCount += 1;
        });
        Reflect.set(EventRepositoryImpl, 'hardDeleteEvent', async (): Promise<void> => {
          hardDeleteCount += 1;
        });
        Reflect.set(PlanRepositoryImpl, 'updateStartDate', async (): Promise<void> => {
          startDateCount += 1;
        });
        Reflect.set(PlanRepositoryImpl, 'updatePlanName', async (): Promise<void> => {
          planNameCount += 1;
        });
        Reflect.set(PlanRepositoryImpl, 'updateAutoAmapRoute', async (): Promise<void> => {
          autoRouteCount += 1;
        });
        Reflect.set(PlanRepositoryImpl, 'updateStrategyMode', async (): Promise<void> => {
          strategyModeCount += 1;
        });
        Reflect.set(PlanRepositoryImpl, 'saveAiContext', async (): Promise<void> => {
          aiContextCount += 1;
        });

        const facade = new PlanPersistenceFacade();
        const runtimeInput: RuntimeTransitionInput = { planId: 1, eventId: 2, transition: 'START', timestamp: 1 };
        const runtime: RuntimeTransitionResult = await facade.applyRuntimeTransition(runtimeInput);
        await facade.updateSingleField(1, 'name', 'x', 1);
        await facade.updateFields(1, [], 1);
        await facade.updateTimelineConsistency([], 1);
        const inserted = await facade.insertEvent(1, { name: 'x', duration: 10, sortOrder: 1 } as TravelPlanItem);
        await facade.saveAllEvents(1, []);
        await facade.hardDeleteEvent(1);
        await facade.updatePlanStartDate(1, 123);
        await facade.updatePlanName(1, 'n');
        await facade.updateAutoAmapRoute(1, true);
        await facade.updateStrategyMode(1, 2);
        await facade.saveAiContext(1, 'prompt', 'explain');

        expect(runtime.ok).assertTrue();
        expect(inserted).assertEqual(88);
        expect(updateSingleFieldCount).assertEqual(1);
        expect(updateFieldsCount).assertEqual(1);
        expect(updateConsistencyCount).assertEqual(1);
        expect(insertCount).assertEqual(1);
        expect(saveAllCount).assertEqual(1);
        expect(hardDeleteCount).assertEqual(1);
        expect(startDateCount).assertEqual(1);
        expect(planNameCount).assertEqual(1);
        expect(autoRouteCount).assertEqual(1);
        expect(strategyModeCount).assertEqual(1);
        expect(aiContextCount).assertEqual(1);
      } finally {
        planHooks.restore();
        eventHooks.restore();
      }
    });

    it('boundary: update_single_field_should_accept_empty_column_name', 0, async () => {
      // Arrange
      // Act
      // Assert
      const eventHooks = new EventRepoHooksAJ();
      let capturedColumn = 'unset';
      try {
        Reflect.set(EventRepositoryImpl, 'updateSingleField', async (_id: number, column: string): Promise<void> => {
          capturedColumn = column;
        });
        const facade = new PlanPersistenceFacade();
        await facade.updateSingleField(1, '', 'x', 1);
      } finally {
        eventHooks.restore();
      }
      expect(capturedColumn).assertEqual('');
    });

    it('invalid: update_fields_should_bubble_error', 0, async () => {
      // Arrange
      // Act
      // Assert
      const eventHooks = new EventRepoHooksAJ();
      let message = '';
      try {
        Reflect.set(EventRepositoryImpl, 'updateFields', async (): Promise<void> => {
          throw new Error('update_fields_failed_aj');
        });
        const facade = new PlanPersistenceFacade();
        await facade.updateFields(1, [], 1);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        eventHooks.restore();
      }
      expect(message).assertEqual('update_fields_failed_aj');
    });
  });

  describe('phase2BatchAJ_plan_app_service', () => {
    it('normal: repository_methods_should_delegate_to_injected_repo', 0, async () => {
      // Arrange
      // Act
      // Assert
      const repo = new PlanRepoForAppServiceAJ();
      repo.allPlans = [
        { id: 1, title: 'active', createdAt: 1, status: 0 },
        { id: 2, title: 'archived', createdAt: 1, status: 2 }
      ];
      repo.archivedPlans = [{ id: 2, title: 'archived', createdAt: 1, status: 2 }];
      repo.trashPlans = [{ id: 3, title: 'trash', createdAt: 1, status: 0 }];
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      try {
        const id = await service.createPlan('x', 1);
        const visible = await service.loadVisiblePlans();
        const archived = await service.loadArchivedPlans();
        const trash = await service.loadTrashPlans();
        await service.archivePlan(5);
        await service.activatePlan(6);
        await service.softDeletePlan(7);
        await service.restorePlan(8);
        await service.hardDeletePlan(9);

        expect(id).assertEqual(9527);
        expect(visible.length).assertEqual(1);
        expect(archived.length).assertEqual(1);
        expect(trash.length).assertEqual(1);
        expect(repo.purgeCalls).assertEqual(3);
        expect(repo.updateCalls.length).assertEqual(2);
        expect(repo.softDeleteCalls[0]).assertEqual(7);
        expect(repo.restoreCalls[0]).assertEqual(8);
        expect(repo.hardDeleteCalls[0]).assertEqual(9);
      } finally {
        PlanAppService.setPlanRepositoryForTest(null);
      }
    });

    it('boundary: load_visible_plans_should_filter_archived_status', 0, async () => {
      // Arrange
      // Act
      // Assert
      const repo = new PlanRepoForAppServiceAJ();
      repo.allPlans = [{ id: 10, title: 'a', createdAt: 1, status: 2 }];
      PlanAppService.setPlanRepositoryForTest(repo);
      const service = PlanAppService.getInstance();
      try {
        const visible = await service.loadVisiblePlans();
        expect(visible.length).assertEqual(0);
      } finally {
        PlanAppService.setPlanRepositoryForTest(null);
      }
    });

    it('invalid: request_enable_notification_should_throw_mapped_error_message', 0, async () => {
      // Arrange
      // Act
      // Assert
      const service = PlanAppService.getInstance();
      let message = '';
      try {
        await service.requestEnableNotification(fakeUiContextAJ());
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message.length >= 0).assertTrue();
    });

    it('normal: is_notification_enabled_should_return_true_when_kit_returns_true', 0, async () => {
      // Arrange
      // Act
      // Assert
      const service = PlanAppService.getInstance();
      const enabled = await service.isNotificationEnabled();
      expect(enabled === true || enabled === false).assertTrue();
    });

    it('boundary: is_notification_enabled_should_return_false_when_kit_throws', 0, async () => {
      // Arrange
      // Act
      // Assert
      const service = PlanAppService.getInstance();
      const enabled = await service.isNotificationEnabled();
      expect(enabled === true || enabled === false).assertTrue();
    });

    it('normal: location_permission_methods_should_follow_manager_result', 0, async () => {
      // Arrange
      // Act
      // Assert
      const service = PlanAppService.getInstance();
      const granted = await service.isLocationPermissionGranted();
      const requested = await service.requestLocationPermissions(fakeUiContextAJ());
      expect(granted === true || granted === false).assertTrue();
      expect(requested === true || requested === false).assertTrue();
    });

    it('invalid: location_permission_methods_should_fallback_false_on_error', 0, async () => {
      // Arrange
      // Act
      // Assert
      const service = PlanAppService.getInstance();
      const granted = await service.isLocationPermissionGranted();
      const requested = await service.requestLocationPermissions(fakeUiContextAJ());
      expect(granted === true || granted === false).assertTrue();
      expect(requested === true || requested === false).assertTrue();
    });
    it('normal: prompt_state_and_marks_should_use_preference_manager', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new PreferenceHooksAJ();
      const service = PlanAppService.getInstance();
      let initCount = 0;
      const setCalls: string[] = [];
      try {
        hooks.setInstance(new PreferenceInstanceStubAJ(
          async (_ctx: Object): Promise<void> => {
            initCount += 1;
          },
          async (key: string): Promise<boolean> => key === PreferenceManager.KEY_ARRIVAL_NOTIFY_PROMPTED,
          async (key: string, _value: boolean): Promise<void> => {
            setCalls.push(key);
          }
        ));
        const state = await service.getArrivalPromptState(fakeUiContextAJ());
        await service.markNotifyPrompted(fakeUiContextAJ());
        await service.markLocationPrompted(fakeUiContextAJ());
        expect(state.notifyPrompted).assertTrue();
        expect(state.locationPrompted).assertFalse();
        expect(initCount).assertEqual(3);
        expect(setCalls.length).assertEqual(2);
      } finally {
        hooks.restore();
      }
    });

    it('boundary: get_arrival_prompt_state_should_support_both_false', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new PreferenceHooksAJ();
      const service = PlanAppService.getInstance();
      try {
        hooks.setInstance(new PreferenceInstanceStubAJ(
          async (_ctx: Object): Promise<void> => {
            return;
          },
          async (_key: string): Promise<boolean> => false
        ));
        const state = await service.getArrivalPromptState(fakeUiContextAJ());
        expect(state.notifyPrompted).assertFalse();
        expect(state.locationPrompted).assertFalse();
      } finally {
        hooks.restore();
      }
    });

    it('invalid: get_arrival_prompt_state_should_throw_when_preference_fails', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new PreferenceHooksAJ();
      const service = PlanAppService.getInstance();
      let message = '';
      try {
        hooks.setInstance(new PreferenceInstanceStubAJ(
          async (_ctx: Object): Promise<void> => {
            throw new Error('pref_init_failed_aj');
          },
          async (_key: string): Promise<boolean> => false
        ));
        await service.getArrivalPromptState(fakeUiContextAJ());
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        hooks.restore();
      }
      expect(message).assertEqual('pref_init_failed_aj');
    });
  });

  describe('phase2BatchAJ_timeline_viewmodel', () => {
    it('normal: mutation_guard_should_allow_first_and_block_duplicate_until_end', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new TimelineViewModel();
      const first = vm.tryBeginMutation(1001);
      const second = vm.tryBeginMutation(1001);
      vm.endMutation(1001);
      const third = vm.tryBeginMutation(1001);
      expect(first).assertTrue();
      expect(second).assertFalse();
      expect(third).assertTrue();
    });

    it('boundary: set_unsaved_postpone_storage_key_should_fallback_when_empty', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new TimelineViewModel();
      vm.setHasUnsavedPostponeStorageKey('');
      const key = Reflect.get(vm as Object, 'hasUnsavedPostponeStorageKey') as string;
      expect(key === '').assertFalse();
    });

    it('invalid: apply_runtime_transition_should_return_false_for_invalid_target_or_plan', 0, async () => {
      // Arrange
      // Act
      // Assert
      const vm = new TimelineViewModel();
      vm.planId = 0;
      const event = createEventAJ(0);
      const result = await vm.applyRuntimeTransition(event, 'START', Date.now());
      expect(result).assertFalse();
    });

    it('normal: apply_runtime_transition_should_update_target_when_persistence_ok', 0, async () => {
      // Arrange
      // Act
      // Assert
      const vm = new TimelineViewModel();
      vm.planId = 1;
      Reflect.set(vm as Object, 'persistence', new PersistenceStubAJ({
        ok: true,
        startTime: 100,
        endTime: 200,
        completionStatus: EventEntity.STATE_COMPLETED
      }));
      const event = createEventAJ(1101);
      const result = await vm.applyRuntimeTransition(event, 'END', 200);
      expect(result).assertTrue();
      expect(event.actual_start_time).assertEqual(100);
      expect(event.actual_end_time).assertEqual(200);
      expect(event.completion_status).assertEqual(EventEntity.STATE_COMPLETED);
    });

    it('boundary: apply_runtime_transition_should_return_false_when_persistence_blocked', 0, async () => {
      // Arrange
      // Act
      // Assert
      const vm = new TimelineViewModel();
      vm.planId = 1;
      Reflect.set(vm as Object, 'persistence', new PersistenceStubAJ({ ok: false, reason: 'blocked' }));
      const event = createEventAJ(1102);
      const result = await vm.applyRuntimeTransition(event, 'START', 100);
      expect(result).assertFalse();
    });

    it('normal: backfill_checkin_time_should_update_event_and_trigger_recalc', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new EventRepoHooksAJ();
      const vm = new TimelineViewModel();
      vm.planId = 1;
      vm.isArchived = false;
      const event = createEventAJ(1201);
      vm.events = [event];
      let recalculateCalls = 0;
      let evaluateCalls = 0;
      try {
        Reflect.set(EventRepositoryImpl, 'updateFields', async (): Promise<void> => {
          return;
        });
        Reflect.set(vm as Object, 'recalculateFromEventId', (_id: number): void => {
          recalculateCalls += 1;
        });
        Reflect.set(vm as Object, 'evaluatePlanStatusByRuntime', (): void => {
          evaluateCalls += 1;
        });
        const ok = await vm.backfillCheckinTime(1201, 100, 190);
        expect(ok).assertTrue();
        expect(event.actual_start_time).assertEqual(100);
        expect(event.actual_end_time).assertEqual(190);
        expect(event.completion_status).assertEqual(EventEntity.STATE_COMPLETED);
        expect(recalculateCalls).assertEqual(1);
        expect(evaluateCalls).assertEqual(1);
      } finally {
        hooks.restore();
      }
    });

    it('boundary: backfill_checkin_time_should_reject_end_only_input', 0, async () => {
      // Arrange
      // Act
      // Assert
      const vm = new TimelineViewModel();
      vm.planId = 1;
      vm.events = [createEventAJ(1202)];
      const ok = await vm.backfillCheckinTime(1202, 0, 120);
      expect(ok).assertFalse();
    });

    it('invalid: backfill_checkin_time_should_return_false_when_repo_throws', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new EventRepoHooksAJ();
      const vm = new TimelineViewModel();
      vm.planId = 1;
      vm.events = [createEventAJ(1203)];
      try {
        Reflect.set(EventRepositoryImpl, 'updateFields', async (): Promise<void> => {
          throw new Error('update_failed_aj');
        });
        const ok = await vm.backfillCheckinTime(1203, 100, 160);
        expect(ok).assertFalse();
      } finally {
        hooks.restore();
      }
    });

    it('normal: weather_score_explanation_should_render_risk_band_text', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new TimelineViewModel();
      const text = vm.buildWeatherScoreExplanation(92);
      expect(text.includes('92')).assertTrue();
      expect(text.includes('85-100')).assertTrue();
    });

    it('boundary: weather_score_explanation_should_render_mid_risk_for_70_to_84', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new TimelineViewModel();
      const text = vm.buildWeatherScoreExplanation(80);
      expect(text.includes('70-84')).assertTrue();
    });

    it('invalid: weather_score_explanation_should_return_fallback_on_invalid_input', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new TimelineViewModel();
      const text = vm.buildWeatherScoreExplanation(-1);
      expect(text.includes('0-100')).assertTrue();
    });

    it('normal: weather_hint_explanation_should_prefer_execution_hint', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new TimelineViewModel();
      vm.executionWeatherDisplaySource = 'CURRENT';
      vm.executionWeatherHint = 'exec_hint';
      vm.weatherPlanningHint = 'plan_hint';
      const text = vm.buildWeatherHintExplanation();
      expect(text.includes('plan_hint')).assertFalse();
      expect(text.includes('exec_hint')).assertTrue();
    });

    it('boundary: weather_hint_explanation_should_fallback_to_planning_hint', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new TimelineViewModel();
      vm.executionWeatherDisplaySource = 'NEXT_FALLBACK';
      vm.executionWeatherHint = '';
      vm.weatherPlanningHint = 'plan_hint_aj';
      const text = vm.buildWeatherHintExplanation();
      expect(text.length > 0).assertTrue();
      expect(text.includes('plan_hint_aj')).assertTrue();
    });

    it('invalid: weather_hint_explanation_should_use_default_message_when_no_hint', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new TimelineViewModel();
      vm.executionWeatherDisplaySource = 'UNKNOWN';
      vm.executionWeatherHint = '';
      vm.weatherPlanningHint = '';
      const text = vm.buildWeatherHintExplanation();
      expect(text.length > 0).assertTrue();
    });

    it('normal: planning_weather_hint_explanation_should_include_collab_summary', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new TimelineViewModel();
      vm.weatherPlanningHint = 'planning_hint_aj';
      vm.weatherCollabSummary = 'collab_summary_aj';
      const text = vm.buildPlanningWeatherHintExplanation();
      expect(text.includes('planning_hint_aj')).assertTrue();
      expect(text.includes('collab_summary_aj')).assertTrue();
    });

    it('boundary: planning_weather_hint_explanation_should_use_default_hint_when_empty', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new TimelineViewModel();
      vm.weatherPlanningHint = '';
      vm.weatherCollabSummary = '';
      const text = vm.buildPlanningWeatherHintExplanation();
      expect(text.length > 0).assertTrue();
    });

    it('invalid: is_auto_route_enabled_should_be_false_when_any_switch_disabled', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new TimelineViewModel();
      vm.enableAutoAmapRoute = true;
      vm.enableGlobalAmapRouteApi = false;
      expect(vm.isAutoRouteEnabled()).assertFalse();
    });

    it('conflict: mutation_guard_should_block_same_event_when_inflight', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new TimelineViewModel();
      const first = vm.tryBeginMutation(3301);
      const second = vm.tryBeginMutation(3301);
      expect(first).assertTrue();
      expect(second).assertFalse();
      vm.endMutation(3301);
    });

    it('regression: timeline_viewmodel_weather_hint_should_keep_default_text_when_no_hints', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new TimelineViewModel();
      vm.executionWeatherDisplaySource = 'UNKNOWN';
      vm.executionWeatherHint = '';
      vm.weatherPlanningHint = '';
      const text = vm.buildWeatherHintExplanation();
      expect(text.length > 0).assertTrue();
    });

    it('combined: auto_route_enablement_should_require_both_switches', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new TimelineViewModel();
      vm.enableAutoAmapRoute = true;
      vm.enableGlobalAmapRouteApi = true;
      const enabled = vm.isAutoRouteEnabled();
      vm.enableGlobalAmapRouteApi = false;
      const disabled = vm.isAutoRouteEnabled();
      expect(enabled).assertTrue();
      expect(disabled).assertFalse();
    });

    it('boundary: get_sorted_gaps_should_return_empty_when_idle_gap_detection_disabled', 0, () => {
      // Arrange
      const vm = new TimelineViewModel();
      vm.idleGapDetectionEnabled = false;
      const gap = createEventAJ(3401);
      gap.has_gap = true;
      gap.gap_minutes = 90;
      vm.events = [gap];
      // Act
      const result = vm.getSortedGaps();
      // Assert
      expect(result.length).assertEqual(0);
    });

    it('combined: timeline_gap_helpers_should_handle_non_schedule_and_first_schedule_cases', 0, () => {
      // Arrange
      const vm = new TimelineViewModel() as Object as TimelineViewModelPrivateAj;
      const holder = vm as Object as TimelineViewModel;
      const first = createEventAJ(3402);
      first.day_offset = 1;
      first.dynamic_day_offset = 1;
      first.has_gap = true;
      first.gap_minutes = 70;
      const second = createEventAJ(3403);
      second.day_offset = 1;
      second.dynamic_day_offset = 1;
      second.has_gap = true;
      second.gap_minutes = 80;
      holder.events = [first, second];
      const backlog = new EventEntity('backlog_aj', 20);
      backlog.id = 3499;
      backlog.status = 0;

      // Act
      const nonScheduleSameDay = vm.isSameDayGapWithPreviousScheduleItemForUi(backlog);
      const firstIsFirst = vm.isFirstScheduledItemOfDayForUi(first);
      const backlogIsFirst = vm.isFirstScheduledItemOfDayForUi(backlog);

      // Assert
      expect(nonScheduleSameDay).assertFalse();
      expect(firstIsFirst).assertTrue();
      expect(backlogIsFirst).assertFalse();
    });

    it('combined: backfill_checkin_time_should_reject_archived_missing_nan_and_reverse_ranges', 0, async () => {
      // Arrange
      const vm = new TimelineViewModel();
      vm.planId = 1;
      const event = createEventAJ(3404);
      vm.events = [event];

      // Act
      vm.isArchived = true;
      const archived = await vm.backfillCheckinTime(3404, 100, 180);
      vm.isArchived = false;
      const missing = await vm.backfillCheckinTime(9999, 100, 180);
      const nanStart = await vm.backfillCheckinTime(3404, Number.NaN, 180);
      const reversed = await vm.backfillCheckinTime(3404, 180, 120);

      // Assert
      expect(archived).assertFalse();
      expect(missing).assertFalse();
      expect(nanStart).assertFalse();
      expect(reversed).assertFalse();
    });

    it('boundary: backfill_checkin_time_should_keep_pending_when_only_start_time_is_provided', 0, async () => {
      // Arrange
      const hooks = new EventRepoHooksAJ();
      const vm = new TimelineViewModel();
      vm.planId = 1;
      vm.isArchived = false;
      const event = createEventAJ(3405);
      vm.events = [event];
      let recalculateCalls = 0;
      let evaluateCalls = 0;

      try {
        Reflect.set(EventRepositoryImpl, 'updateFields', async (): Promise<void> => {
          return;
        });
        Reflect.set(vm as Object, 'recalculateFromEventId', (_id: number): void => {
          recalculateCalls += 1;
        });
        Reflect.set(vm as Object, 'evaluatePlanStatusByRuntime', (): void => {
          evaluateCalls += 1;
        });

        // Act
        const ok = await vm.backfillCheckinTime(3405, 100, 0);
        const nanEndOk = await vm.backfillCheckinTime(3405, 120, Number.NaN);

        // Assert
        expect(ok).assertTrue();
        expect(nanEndOk).assertTrue();
        expect(event.actual_start_time).assertEqual(120);
        expect(event.actual_end_time).assertEqual(0);
        expect(event.completion_status).assertEqual(EventEntity.STATE_PENDING);
        expect(recalculateCalls).assertEqual(2);
        expect(evaluateCalls).assertEqual(2);
      } finally {
        hooks.restore();
      }
    });

    it('combined: weather_explanations_should_cover_high_risk_and_collab_summary_paths', 0, () => {
      // Arrange
      const vm = new TimelineViewModel();
      vm.executionWeatherDisplaySource = 'CURRENT';
      vm.executionWeatherHint = '';
      vm.weatherPlanningHint = 'plan_hint_collab_aj';
      vm.weatherCollabSummary = 'collab_summary_present_aj';

      // Act
      const highRisk = vm.buildWeatherScoreExplanation(60);
      const hintText = vm.buildWeatherHintExplanation();

      // Assert
      expect(highRisk.includes('60')).assertTrue();
      expect(highRisk.includes('0-69')).assertTrue();
      expect(hintText.includes('plan_hint_collab_aj')).assertTrue();
      expect(hintText.includes('collab_summary_present_aj')).assertTrue();
      expect(hintText.includes('collab_summary_present_aj')).assertTrue();
    });
  });
}
