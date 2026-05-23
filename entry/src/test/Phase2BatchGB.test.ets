import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { CompanionView } from '../main/ets/pages/components/views/CompanionView';
import { IndexCompanionOverlay } from '../main/ets/pages/index/IndexCompanionOverlay';
import { CompanionContext, TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

interface CompanionViewCtorParamsGB {
  vm: Object;
  isShow: Object;
}

interface IndexCompanionOverlayParamsGB {
  vm?: TimelineViewModel;
  isVisible?: boolean;
  overlayZIndex?: number;
}

interface IndexCompanionOverlayPrivateGB {
  __vm: Object;
  __isVisible: Object;
}

interface CompanionViewUiContextGB {
  animateTo(options: Object, action: () => void): void;
  showAlertDialog(options: Object): void;
  getHostContext(): Object;
}

interface StartConflictInfoGB {
  name: string;
}

interface UpdateActualTimeCallGB {
  id: number;
  field: string;
  timestamp: number;
}

interface BackfillCallGB {
  id: number;
  startTs: number;
  endTs: number;
}

interface CompanionViewPrivateGB {
  context: CompanionContext;
  handleFocusedPrimaryAction(): Promise<void>;
  applyCompanionCheckinBackfill(eventId: number, startTs: number, endTs: number): Promise<void>;
}

class CompanionViewHostContextMockGB {}

class CompanionViewUiContextMockGB implements CompanionViewUiContextGB {
  private readonly hostContext: Object = new CompanionViewHostContextMockGB() as Object;

  animateTo(_options: Object, action: () => void): void {
    action();
  }

  showAlertDialog(_options: Object): void {}

  getHostContext(): Object {
    return this.hostContext;
  }
}

class CompanionViewVmMockGB {
  scheduleVersion: number = 1;
  orderedEvents: EventEntity[] = [];
  companionContext: CompanionContext = buildCompanionContextGB('IDLE', null, null);
  conflictName: string | null = null;
  canResumeResult: boolean = true;
  canPauseResult: boolean = true;
  updateActualTimeResult: boolean = true;
  backfillResult: boolean = true;
  resumeCalls: number = 0;
  pauseCalls: number = 0;
  updateCalls: UpdateActualTimeCallGB[] = [];
  backfillCalls: BackfillCallGB[] = [];

  getScheduleVersion(): number {
    return this.scheduleVersion;
  }

  getOrderedScheduleEvents(): EventEntity[] {
    return this.orderedEvents;
  }

  getCompanionContext(): CompanionContext {
    return this.companionContext;
  }

  async getStartConflictInfo(_excludeEventId: number): Promise<StartConflictInfoGB | null> {
    if (!this.conflictName) {
      return null;
    }
    const conflict = {} as StartConflictInfoGB;
    conflict.name = this.conflictName;
    return conflict;
  }

  resumeCurrentExecution(): boolean {
    this.resumeCalls += 1;
    return this.canResumeResult;
  }

  pauseCurrentExecution(): boolean {
    this.pauseCalls += 1;
    return this.canPauseResult;
  }

  async updateActualTime(id: number, field: 'actual_start_time' | 'actual_end_time', timestamp: number): Promise<boolean> {
    const call = {} as UpdateActualTimeCallGB;
    call.id = id;
    call.field = field;
    call.timestamp = timestamp;
    this.updateCalls.push(call);
    return this.updateActualTimeResult;
  }

  async backfillCheckinTime(id: number, startTs: number, endTs: number): Promise<boolean> {
    const call = {} as BackfillCallGB;
    call.id = id;
    call.startTs = startTs;
    call.endTs = endTs;
    this.backfillCalls.push(call);
    return this.backfillResult;
  }
}

function buildCompanionEventGB(
  id: number,
  name: string,
  state: 'PENDING' | 'ACTIVE' | 'SKIPPED' = 'PENDING'
): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.status = 1;
  event.completion_status = EventEntity.STATE_PENDING;
  event.actual_start_time = 0;
  event.actual_end_time = 0;
  if (state === 'ACTIVE') {
    event.actual_start_time = Date.now() - 60000;
  }
  if (state === 'SKIPPED') {
    event.completion_status = EventEntity.STATE_SKIPPED;
  }
  return event;
}

function buildCompanionContextGB(
  runtimeState: 'IDLE' | 'READY' | 'ACTIVE' | 'PAUSED' | 'GAP',
  currentEvent: EventEntity | null,
  nextEvent: EventEntity | null
): CompanionContext {
  const context = {} as CompanionContext;
  context.runtimeState = runtimeState;
  context.currentEvent = currentEvent;
  context.nextEvent = nextEvent;
  context.hint = null;
  context.actions = {
    canStart: true,
    canPause: true,
    canResume: false,
    canEnd: true,
    canSkip: true,
    canNavigate: true,
    canViewDetail: true
  };
  return context;
}

function createCompanionViewInstanceGB(vm: TimelineViewModel, isShow: boolean = true): CompanionViewPrivateGB {
  const overlayParams: IndexCompanionOverlayParamsGB = {
    vm,
    isVisible: isShow,
    overlayZIndex: 10
  };
  const overlay = new IndexCompanionOverlay(
    undefined,
    overlayParams as Object as LocalStorage
  ) as Object as IndexCompanionOverlayPrivateGB;
  const companionParams: CompanionViewCtorParamsGB = {
    vm: overlay.__vm,
    isShow: overlay.__isVisible
  };
  const instance = new CompanionView(
    overlay as Object,
    companionParams as Object as LocalStorage
  ) as Object as CompanionViewPrivateGB;
  Reflect.set(instance as Object, 'vm', vm);
  Reflect.set(instance as Object, 'context', (vm as Object as CompanionViewVmMockGB).getCompanionContext());
  return instance;
}

function setCompanionViewUiContextGB(page: CompanionViewPrivateGB, uiContext: CompanionViewUiContextGB): void {
  Reflect.set(page as Object, 'getUIContext', (): CompanionViewUiContextGB => uiContext);
}

export default function phase2BatchGBTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchGB_companion_view_primary_branches', () => {
    it('normal: companion_view_primary_action_should_start_pending_event_and_enter_immersive_mode', 0, async () => {
      // Arrange
      const focused = buildCompanionEventGB(141, 'start_target');
      const vm = new CompanionViewVmMockGB();
      vm.orderedEvents = [focused];
      vm.companionContext = buildCompanionContextGB('READY', null, focused);
      const page = createCompanionViewInstanceGB(vm as Object as TimelineViewModel);
      setCompanionViewUiContextGB(page, new CompanionViewUiContextMockGB());
      let refreshed = 0;
      let focusedId = -1;
      let immersiveCalls = 0;
      Reflect.set(page as Object, 'getFocusedEvent', (): EventEntity | null => focused);
      Reflect.set(page as Object, 'refreshContext', (): void => {
        refreshed += 1;
      });
      Reflect.set(page as Object, 'applyFocusById', (id: number): void => {
        focusedId = id;
      });
      Reflect.set(page as Object, 'enterImmersiveMode', (): void => {
        immersiveCalls += 1;
      });

      // Act
      await page.handleFocusedPrimaryAction();

      // Assert
      expect(vm.updateCalls.length).assertEqual(1);
      expect(vm.updateCalls[0].id).assertEqual(141);
      expect(vm.updateCalls[0].field).assertEqual('actual_start_time');
      expect(refreshed).assertEqual(1);
      expect(focusedId).assertEqual(141);
      expect(immersiveCalls).assertEqual(1);
    });

    it('boundary: companion_view_primary_action_should_block_pause_when_context_disallows_it', 0, async () => {
      // Arrange
      const focused = buildCompanionEventGB(142, 'active_blocked', 'ACTIVE');
      const vm = new CompanionViewVmMockGB();
      vm.orderedEvents = [focused];
      vm.companionContext = buildCompanionContextGB('ACTIVE', focused, null);
      vm.companionContext.actions.canPause = false;
      const page = createCompanionViewInstanceGB(vm as Object as TimelineViewModel);
      setCompanionViewUiContextGB(page, new CompanionViewUiContextMockGB());
      const toasts: string[] = [];
      Reflect.set(page as Object, 'getFocusedEvent', (): EventEntity | null => focused);
      Reflect.set(page as Object, 'safeShowToast', (message: string): void => {
        toasts.push(message);
      });

      // Act
      await page.handleFocusedPrimaryAction();

      // Assert
      expect(vm.pauseCalls).assertEqual(0);
      expect(toasts[0]).assertEqual('当前状态不可暂停');
    });

    it('invalid: companion_view_primary_action_should_toast_when_resume_fails', 0, async () => {
      // Arrange
      const focused = buildCompanionEventGB(143, 'resume_failed');
      const vm = new CompanionViewVmMockGB();
      vm.canResumeResult = false;
      vm.orderedEvents = [focused];
      vm.companionContext = buildCompanionContextGB('PAUSED', null, focused);
      vm.companionContext.actions.canResume = true;
      const page = createCompanionViewInstanceGB(vm as Object as TimelineViewModel);
      setCompanionViewUiContextGB(page, new CompanionViewUiContextMockGB());
      const toasts: string[] = [];
      Reflect.set(page as Object, 'getFocusedEvent', (): EventEntity | null => focused);
      Reflect.set(page as Object, 'safeShowToast', (message: string): void => {
        toasts.push(message);
      });

      // Act
      await page.handleFocusedPrimaryAction();

      // Assert
      expect(vm.resumeCalls).assertEqual(1);
      expect(toasts[0]).assertEqual('继续失败，请稍后重试');
    });

    it('conflict: companion_view_primary_action_should_toast_when_start_update_fails_without_conflict_dialog', 0, async () => {
      // Arrange
      const focused = buildCompanionEventGB(144, 'start_failed');
      const vm = new CompanionViewVmMockGB();
      vm.updateActualTimeResult = false;
      vm.orderedEvents = [focused];
      vm.companionContext = buildCompanionContextGB('READY', null, focused);
      const page = createCompanionViewInstanceGB(vm as Object as TimelineViewModel);
      setCompanionViewUiContextGB(page, new CompanionViewUiContextMockGB());
      const toasts: string[] = [];
      Reflect.set(page as Object, 'getFocusedEvent', (): EventEntity | null => focused);
      Reflect.set(page as Object, 'showGlobalActiveConflictDialog', async (_excludeEventId: number): Promise<boolean> => false);
      Reflect.set(page as Object, 'safeShowToast', (message: string): void => {
        toasts.push(message);
      });

      // Act
      await page.handleFocusedPrimaryAction();

      // Assert
      expect(vm.updateCalls.length).assertEqual(1);
      expect(toasts[0]).assertEqual('开始打卡失败，请稍后重试');
    });

    it('regression: companion_view_primary_action_should_pause_active_event_and_refresh_context', 0, async () => {
      // Arrange
      const focused = buildCompanionEventGB(145, 'pause_target', 'ACTIVE');
      const vm = new CompanionViewVmMockGB();
      vm.orderedEvents = [focused];
      vm.companionContext = buildCompanionContextGB('ACTIVE', focused, null);
      const page = createCompanionViewInstanceGB(vm as Object as TimelineViewModel);
      setCompanionViewUiContextGB(page, new CompanionViewUiContextMockGB());
      let refreshed = 0;
      Reflect.set(page as Object, 'getFocusedEvent', (): EventEntity | null => focused);
      Reflect.set(page as Object, 'refreshContext', (): void => {
        refreshed += 1;
      });

      // Act
      await page.handleFocusedPrimaryAction();

      // Assert
      expect(vm.pauseCalls).assertEqual(1);
      expect(refreshed).assertEqual(1);
    });

    it('combined: companion_view_backfill_should_reject_end_time_before_start_time', 0, async () => {
      // Arrange
      const vm = new CompanionViewVmMockGB();
      const page = createCompanionViewInstanceGB(vm as Object as TimelineViewModel);
      setCompanionViewUiContextGB(page, new CompanionViewUiContextMockGB());
      const toasts: string[] = [];
      Reflect.set(page as Object, 'safeShowToast', (message: string): void => {
        toasts.push(message);
      });

      // Act
      await page.applyCompanionCheckinBackfill(146, 5000, 2000);

      // Assert
      expect(vm.backfillCalls.length).assertEqual(0);
      expect(toasts[0]).assertEqual('结束时间不能早于开始时间');
    });
  });
}
