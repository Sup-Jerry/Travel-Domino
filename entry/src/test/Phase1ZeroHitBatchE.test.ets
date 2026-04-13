import { describe, expect, it } from '@ohos/hypium';
import { common } from '@kit.AbilityKit';
import { TimelineInteractionHelper } from '../main/ets/viewmodel/TimelineInteractionHelper';
import { TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { NavigationHelper } from '../main/ets/common/utils/NavigationHelper';

class ExecutionCoordinatorMock {
  public orderedEvents: EventEntity[] = [];

  getOrderedScheduleEvents(): EventEntity[] {
    return this.orderedEvents;
  }
}

class TimelineVmMock {
  public events: EventEntity[] = [];
  public executionCoordinator: ExecutionCoordinatorMock = new ExecutionCoordinatorMock();
  public planStartDate: number = 0;
  public sortedGaps: EventEntity[] = [];
  public updateCallCount: number = 0;
  public addCallCount: number = 0;
  public commuteUpdateCount: number = 0;
  public lastUpdateDayOffset: number = -1;
  public lastAddDayOffset: number = -1;
  public lastAddPreTravel: number = -1;
  public lastCommuteMinutes: number = -1;

  getSortedGaps(): EventEntity[] {
    return this.sortedGaps;
  }

  async updateEventInfo(
    _editingItemId: number,
    _name: string,
    _duration: number,
    _fixedTime?: string,
    dayOffset: number = 0
  ): Promise<void> {
    this.updateCallCount += 1;
    this.lastUpdateDayOffset = dayOffset;
  }

  async addNewItem(
    _name: string,
    _duration: number,
    _isSchedule: boolean,
    _fixedTime?: string,
    dayOffset: number = 0,
    preTravel: number = -1
  ): Promise<void> {
    this.addCallCount += 1;
    this.lastAddDayOffset = dayOffset;
    this.lastAddPreTravel = preTravel;
  }

  updateCommute(_index: number, newMinutes: number): void {
    this.commuteUpdateCount += 1;
    this.lastCommuteMinutes = newMinutes;
  }
}

interface RouterLike {
  getLength(): number;
  back(): void;
  replaceUrl(options: Object): Promise<void>;
  pushUrl(options: Object): Promise<void>;
}

interface PromptActionLike {
  openToast(options: Object): Promise<void>;
}

interface UiContextLike {
  getRouter(): RouterLike;
  getPromptAction(): PromptActionLike;
}

class RouterNavMock implements RouterLike {
  public length: number = 1;
  public backCount: number = 0;
  public replaceCount: number = 0;
  public pushCount: number = 0;
  public replaceReject: boolean = false;
  public pushReject: boolean = false;
  public lastUrl: string = '';
  public hasParams: boolean = false;

  getLength(): number {
    return this.length;
  }

  back(): void {
    this.backCount += 1;
  }

  async replaceUrl(options: Object): Promise<void> {
    this.replaceCount += 1;
    const payload = options as Record<string, Object>;
    this.lastUrl = String(payload['url'] ?? '');
    this.hasParams = payload['params'] !== undefined;
    if (this.replaceReject) {
      throw new Error('replace_failed');
    }
  }

  async pushUrl(options: Object): Promise<void> {
    this.pushCount += 1;
    const payload = options as Record<string, Object>;
    this.lastUrl = String(payload['url'] ?? '');
    this.hasParams = payload['params'] !== undefined;
    if (this.pushReject) {
      throw new Error('push_failed');
    }
  }
}

class PromptActionMock implements PromptActionLike {
  public toastMessages: string[] = [];

  async openToast(options: Object): Promise<void> {
    const payload = options as Record<string, Object>;
    this.toastMessages.push(String(payload['message'] ?? ''));
  }
}

class UiContextNavMock implements UiContextLike {
  public readonly router: RouterNavMock = new RouterNavMock();
  public readonly promptAction: PromptActionMock = new PromptActionMock();

  getRouter(): RouterLike {
    return this.router;
  }

  getPromptAction(): PromptActionLike {
    return this.promptAction;
  }
}

class AbilityContextMock {
  public startType: string = '';
  public destinationName: string = '';
  public destinationLatitude: number = 0;
  public destinationLongitude: number = 0;
  public startCallCount: number = 0;
  public shouldRejectStart: boolean = false;

  startAbilityByType(
    type: string,
    params: Record<string, Object>,
    _callback: common.AbilityStartCallback
  ): Promise<void> {
    this.startCallCount += 1;
    this.startType = type;
    this.destinationName = String(params['destinationName'] ?? '');
    this.destinationLatitude = Number(params['destinationLatitude'] ?? 0);
    this.destinationLongitude = Number(params['destinationLongitude'] ?? 0);
    if (this.shouldRejectStart) {
      return Promise.reject(new Error('start_failed'));
    }
    return Promise.resolve();
  }
}

class NavigationParamsMock {
  from?: Object;
}

function createEvent(
  id: number,
  status: number,
  completionStatus: number,
  actualStartTime: number
): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `event-${id}`;
  event.status = status;
  event.completion_status = completionStatus;
  event.actual_start_time = actualStartTime;
  event.actual_end_time = 0;
  event.day_offset = 2;
  event.dynamic_day_offset = 3;
  event.fixed_start_time = '09:30';
  event.duration = 45;
  return event;
}

function waitMs(ms: number): Promise<void> {
  return new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
    setTimeout(() => resolve(), ms);
  });
}

export default function phase1ZeroHitBatchETest() {
  describe('phase1ZeroHitBatchETest', () => {
    it('normal: handle_save_item_should_use_update_branch_and_emit_gap', 0, async (done: Function) => {
      // Arrange
      const vm = new TimelineVmMock();
      const gap = new EventEntity();
      gap.id = 901;
      gap.is_ignore_wait = false;
      vm.sortedGaps = [gap];
      let gapId = -1;
      // Act
      await TimelineInteractionHelper.handleSaveItem(
        vm as Object as TimelineViewModel,
        8,
        'museum',
        60,
        true,
        '10:00',
        2,
        20,
        (item: EventEntity) => {
          gapId = item.id;
        }
      );
      await waitMs(80);
      // Assert
      expect(vm.updateCallCount).assertEqual(1);
      expect(vm.addCallCount).assertEqual(0);
      expect(gapId).assertEqual(901);
      done();
    });

    it('boundary: handle_save_item_should_default_day_offset_and_pre_travel_for_add', 0, async (done: Function) => {
      // Arrange
      const vm = new TimelineVmMock();
      vm.sortedGaps = [];
      // Act
      await TimelineInteractionHelper.handleSaveItem(
        vm as Object as TimelineViewModel,
        -1,
        'hotel',
        30,
        true
      );
      await waitMs(80);
      // Assert
      expect(vm.updateCallCount).assertEqual(0);
      expect(vm.addCallCount).assertEqual(1);
      expect(vm.lastAddDayOffset).assertEqual(0);
      expect(vm.lastAddPreTravel).assertEqual(-1);
      done();
    });

    it('invalid: handle_commute_change_should_ignore_item_outside_events', 0, () => {
      // Arrange
      const vm = new TimelineVmMock();
      const inside = createEvent(10, 1, EventEntity.STATE_PENDING, 0);
      const outside = createEvent(11, 1, EventEntity.STATE_PENDING, 0);
      vm.events = [inside];
      let gapCallbackCount = 0;
      // Act
      TimelineInteractionHelper.handleCommuteChange(
        vm as Object as TimelineViewModel,
        outside,
        18,
        (_item: EventEntity) => {
          gapCallbackCount += 1;
        }
      );
      // Assert
      expect(vm.commuteUpdateCount).assertEqual(0);
      expect(vm.lastCommuteMinutes).assertEqual(-1);
      expect(gapCallbackCount).assertEqual(0);
    });

    it('conflict: handle_time_update_should_update_lock_status_and_day_offset', 0, async (done: Function) => {
      // Arrange
      const vm = new TimelineVmMock();
      const target = createEvent(12, 1, EventEntity.STATE_PENDING, 0);
      target.lock_status = 0;
      vm.events = [target];
      vm.sortedGaps = [];
      // Act
      TimelineInteractionHelper.handleTimeUpdate(
        vm as Object as TimelineViewModel,
        target,
        40,
        '11:20',
        1
      );
      await waitMs(80);
      // Assert
      expect(vm.updateCallCount).assertEqual(1);
      expect(vm.lastUpdateDayOffset).assertEqual(3);
      expect(vm.events[0].lock_status).assertEqual(1);
      done();
    });

    it('regression: pick_focus_event_should_prefer_active_then_pending_then_head', 0, () => {
      // Arrange
      const vm = new TimelineVmMock();
      const active = createEvent(21, 1, EventEntity.STATE_PENDING, 1000);
      const pending = createEvent(22, 1, EventEntity.STATE_PENDING, 0);
      const completed = createEvent(23, 1, EventEntity.STATE_COMPLETED, 0);
      vm.executionCoordinator.orderedEvents = [completed, active, pending];
      // Act
      const firstPick = TimelineInteractionHelper.pickCompanionFocusEventId(vm as Object as TimelineViewModel);
      vm.executionCoordinator.orderedEvents = [completed, pending];
      const secondPick = TimelineInteractionHelper.pickCompanionFocusEventId(vm as Object as TimelineViewModel);
      vm.executionCoordinator.orderedEvents = [completed];
      const thirdPick = TimelineInteractionHelper.pickCompanionFocusEventId(vm as Object as TimelineViewModel);
      // Assert
      expect(firstPick).assertEqual(21);
      expect(secondPick).assertEqual(22);
      expect(thirdPick).assertEqual(23);
    });

    it('combined: find_next_pending_event_should_support_forward_scan_and_fallback', 0, () => {
      // Arrange
      const vm = new TimelineVmMock();
      const a = createEvent(31, 1, EventEntity.STATE_PENDING, 100);
      const b = createEvent(32, 1, EventEntity.STATE_PENDING, 0);
      const c = createEvent(33, 1, EventEntity.STATE_COMPLETED, 0);
      const d = createEvent(34, 1, EventEntity.STATE_PENDING, 0);
      vm.executionCoordinator.orderedEvents = [a, b, c, d];
      // Act
      const from31 = TimelineInteractionHelper.findNextPendingEventId(vm as Object as TimelineViewModel, 31);
      const from34 = TimelineInteractionHelper.findNextPendingEventId(vm as Object as TimelineViewModel, 34);
      const fromMissing = TimelineInteractionHelper.findNextPendingEventId(vm as Object as TimelineViewModel, 999);
      vm.executionCoordinator.orderedEvents = [];
      const fromEmpty = TimelineInteractionHelper.findNextPendingEventId(vm as Object as TimelineViewModel, 1);
      // Assert
      expect(from31).assertEqual(32);
      expect(from34).assertEqual(-1);
      expect(fromMissing).assertEqual(32);
      expect(fromEmpty).assertEqual(-1);
    });

    it('normal: navigation_back_or_fallback_should_back_when_stack_has_parent', 0, async (done: Function) => {
      // Arrange
      const uiContext = new UiContextNavMock();
      uiContext.router.length = 2;
      // Act
      await NavigationHelper.backOrFallbackToPlanList(uiContext as Object as UIContext);
      // Assert
      expect(uiContext.router.backCount).assertEqual(1);
      expect(uiContext.router.replaceCount).assertEqual(0);
      expect(uiContext.router.pushCount).assertEqual(0);
      done();
    });

    it('boundary: navigation_back_or_fallback_should_replace_to_plan_list_with_params', 0, async (done: Function) => {
      // Arrange
      const uiContext = new UiContextNavMock();
      uiContext.router.length = 1;
      const params = new NavigationParamsMock();
      params.from = 'timeline';
      // Act
      await NavigationHelper.backOrFallbackToPlanList(uiContext as Object as UIContext, params as Object);
      // Assert
      expect(uiContext.router.backCount).assertEqual(0);
      expect(uiContext.router.replaceCount).assertEqual(1);
      expect(uiContext.router.lastUrl).assertEqual('pages/PlanListPage');
      expect(uiContext.router.hasParams).assertTrue();
      done();
    });

    it('invalid: navigation_back_or_fallback_should_push_and_toast_when_replace_fails', 0, async (done: Function) => {
      // Arrange
      const uiContext = new UiContextNavMock();
      uiContext.router.length = 1;
      uiContext.router.replaceReject = true;
      // Act
      await NavigationHelper.backOrFallbackToPlanList(uiContext as Object as UIContext);
      // Assert
      expect(uiContext.router.replaceCount).assertEqual(1);
      expect(uiContext.router.pushCount).assertEqual(1);
      expect(uiContext.promptAction.toastMessages.length).assertEqual(1);
      expect(uiContext.promptAction.toastMessages[0]).assertEqual('无上级页面，已返回计划列表');
      done();
    });

    it('conflict: navigation_back_or_fallback_should_toast_failure_when_replace_and_push_fail', 0, async (done: Function) => {
      // Arrange
      const uiContext = new UiContextNavMock();
      uiContext.router.length = 1;
      uiContext.router.replaceReject = true;
      uiContext.router.pushReject = true;
      // Act
      await NavigationHelper.backOrFallbackToPlanList(uiContext as Object as UIContext);
      // Assert
      expect(uiContext.router.replaceCount).assertEqual(1);
      expect(uiContext.router.pushCount).assertEqual(1);
      expect(uiContext.promptAction.toastMessages.length).assertEqual(1);
      expect(uiContext.promptAction.toastMessages[0]).assertEqual('返回失败，请手动回到计划列表');
      done();
    });

    it('regression: navigation_start_should_forward_destination_to_system_panel', 0, async (done: Function) => {
      // Arrange
      const abilityContext = new AbilityContextMock();
      // Act
      NavigationHelper.startNavigation(
        abilityContext as Object as common.UIAbilityContext,
        'bund',
        31.2304,
        121.4737
      );
      await waitMs(20);
      // Assert
      expect(abilityContext.startCallCount).assertEqual(1);
      expect(abilityContext.startType).assertEqual('navigation');
      expect(abilityContext.destinationName).assertEqual('bund');
      expect(abilityContext.destinationLatitude).assertEqual(31.2304);
      expect(abilityContext.destinationLongitude).assertEqual(121.4737);
      done();
    });

    it('combined: navigation_start_should_not_throw_when_system_panel_rejects', 0, async (done: Function) => {
      // Arrange
      const abilityContext = new AbilityContextMock();
      abilityContext.shouldRejectStart = true;
      let reached = false;
      // Act
      NavigationHelper.startNavigation(
        abilityContext as Object as common.UIAbilityContext,
        'station',
        30.0,
        120.0
      );
      await waitMs(20);
      reached = true;
      // Assert
      expect(reached).assertTrue();
      expect(abilityContext.startCallCount).assertEqual(1);
      done();
    });
  });
}
