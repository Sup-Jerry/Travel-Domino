import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { CompanionView } from '../main/ets/pages/components/views/CompanionView';
import { IndexCompanionOverlay } from '../main/ets/pages/index/IndexCompanionOverlay';
import { CompanionContext, TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

interface CompanionViewCtorParamsGA {
  vm: Object;
  isShow: Object;
}

interface IndexCompanionOverlayParamsGA {
  vm?: TimelineViewModel;
  isVisible?: boolean;
  overlayZIndex?: number;
}

interface IndexCompanionOverlayPrivateGA {
  __vm: Object;
  __isVisible: Object;
}

interface CompanionViewUiContextGA {
  animateTo(options: Object, action: () => void): void;
  showAlertDialog(options: Object): void;
  getHostContext(): Object;
}

interface StartConflictInfoGA {
  name: string;
}

interface UpdateActualTimeCallGA {
  id: number;
  field: string;
  timestamp: number;
}

interface BackfillCallGA {
  id: number;
  startTs: number;
  endTs: number;
}

interface CompanionViewPrivateGA {
  context: CompanionContext;
  handleFocusedPrimaryAction(): Promise<void>;
  handleFocusedSkip(): Promise<void>;
  handleFocusedReopen(): Promise<void>;
  applyCompanionCheckinBackfill(eventId: number, startTs: number, endTs: number): Promise<void>;
}

class CompanionViewHostContextMockGA {}

class CompanionViewUiContextMockGA implements CompanionViewUiContextGA {
  private readonly hostContext: Object = new CompanionViewHostContextMockGA() as Object;

  animateTo(_options: Object, action: () => void): void {
    action();
  }

  showAlertDialog(_options: Object): void {}

  getHostContext(): Object {
    return this.hostContext;
  }
}

class CompanionViewVmMockGA {
  scheduleVersion: number = 1;
  orderedEvents: EventEntity[] = [];
  companionContext: CompanionContext = buildCompanionContextGA('IDLE', null, null);
  conflictName: string | null = null;
  canResumeResult: boolean = true;
  canPauseResult: boolean = true;
  updateActualTimeResult: boolean = true;
  backfillResult: boolean = true;
  reopenResult: boolean = true;
  resumeCalls: number = 0;
  pauseCalls: number = 0;
  updateCalls: UpdateActualTimeCallGA[] = [];
  backfillCalls: BackfillCallGA[] = [];
  reopenCalls: number[] = [];
  skipCalls: number[] = [];

  getScheduleVersion(): number {
    return this.scheduleVersion;
  }

  getOrderedScheduleEvents(): EventEntity[] {
    return this.orderedEvents;
  }

  getCompanionContext(): CompanionContext {
    return this.companionContext;
  }

  async getStartConflictInfo(_excludeEventId: number): Promise<StartConflictInfoGA | null> {
    if (!this.conflictName) {
      return null;
    }
    const conflict = {} as StartConflictInfoGA;
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
    const call = {} as UpdateActualTimeCallGA;
    call.id = id;
    call.field = field;
    call.timestamp = timestamp;
    this.updateCalls.push(call);
    return this.updateActualTimeResult;
  }

  async backfillCheckinTime(id: number, startTs: number, endTs: number): Promise<boolean> {
    const call = {} as BackfillCallGA;
    call.id = id;
    call.startTs = startTs;
    call.endTs = endTs;
    this.backfillCalls.push(call);
    return this.backfillResult;
  }

  async reopenSkippedEvent(id: number): Promise<boolean> {
    this.reopenCalls.push(id);
    return this.reopenResult;
  }

  async skipEvent(event: EventEntity): Promise<void> {
    this.skipCalls.push(event.id);
  }
}

function buildCompanionEventGA(
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

function buildCompanionContextGA(
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

function createCompanionViewInstanceGA(vm: TimelineViewModel, isShow: boolean = true): CompanionViewPrivateGA {
  const overlayParams: IndexCompanionOverlayParamsGA = {
    vm,
    isVisible: isShow,
    overlayZIndex: 10
  };
  const overlay = new IndexCompanionOverlay(
    undefined,
    overlayParams as Object as LocalStorage
  ) as Object as IndexCompanionOverlayPrivateGA;
  const companionParams: CompanionViewCtorParamsGA = {
    vm: overlay.__vm,
    isShow: overlay.__isVisible
  };
  const instance = new CompanionView(
    overlay as Object,
    companionParams as Object as LocalStorage
  ) as Object as CompanionViewPrivateGA;
  Reflect.set(instance as Object, 'vm', vm);
  Reflect.set(instance as Object, 'context', (vm as Object as CompanionViewVmMockGA).getCompanionContext());
  return instance;
}

function setCompanionViewUiContextGA(page: CompanionViewPrivateGA, uiContext: CompanionViewUiContextGA): void {
  Reflect.set(page as Object, 'getUIContext', (): CompanionViewUiContextGA => uiContext);
}

export default function phase2BatchGATest() {
  describe('unit_test_case_generator_autofill_Phase2BatchGA_companion_view_execution_methods', () => {
    it('normal: companion_view_primary_action_should_resume_and_refocus_when_resume_is_allowed', 0, async () => {
      // Arrange
      const focused = buildCompanionEventGA(131, 'resume_target');
      const vm = new CompanionViewVmMockGA();
      vm.orderedEvents = [focused];
      vm.companionContext = buildCompanionContextGA('PAUSED', null, focused);
      vm.companionContext.actions.canResume = true;
      const page = createCompanionViewInstanceGA(vm as Object as TimelineViewModel);
      setCompanionViewUiContextGA(page, new CompanionViewUiContextMockGA());
      let refreshed = 0;
      let focusedId = -1;
      Reflect.set(page as Object, 'getFocusedEvent', (): EventEntity | null => focused);
      Reflect.set(page as Object, 'refreshContext', (): void => {
        refreshed += 1;
      });
      Reflect.set(page as Object, 'applyFocusById', (id: number): void => {
        focusedId = id;
      });

      // Act
      await page.handleFocusedPrimaryAction();

      // Assert
      expect(vm.resumeCalls).assertEqual(1);
      expect(refreshed).assertEqual(1);
      expect(focusedId).assertEqual(131);
    });

    it('boundary: companion_view_backfill_should_clear_record_and_refresh_when_zero_range_is_confirmed', 0, async () => {
      // Arrange
      const vm = new CompanionViewVmMockGA();
      const page = createCompanionViewInstanceGA(vm as Object as TimelineViewModel);
      setCompanionViewUiContextGA(page, new CompanionViewUiContextMockGA());
      const toasts: string[] = [];
      let refreshed = 0;
      Reflect.set(page as Object, 'safeShowToast', (message: string): void => {
        toasts.push(message);
      });
      Reflect.set(page as Object, 'refreshContext', (): void => {
        refreshed += 1;
      });

      // Act
      await page.applyCompanionCheckinBackfill(132, 0, 0);

      // Assert
      expect(vm.backfillCalls.length).assertEqual(1);
      expect(vm.backfillCalls[0].startTs).assertEqual(0);
      expect(vm.backfillCalls[0].endTs).assertEqual(0);
      expect(toasts[0]).assertEqual('打卡记录已清除');
      expect(refreshed).assertEqual(1);
    });

    it('invalid: companion_view_backfill_should_reject_end_only_range', 0, async () => {
      // Arrange
      const vm = new CompanionViewVmMockGA();
      const page = createCompanionViewInstanceGA(vm as Object as TimelineViewModel);
      setCompanionViewUiContextGA(page, new CompanionViewUiContextMockGA());
      const toasts: string[] = [];
      Reflect.set(page as Object, 'safeShowToast', (message: string): void => {
        toasts.push(message);
      });

      // Act
      await page.applyCompanionCheckinBackfill(133, 0, 2000);

      // Assert
      expect(vm.backfillCalls.length).assertEqual(0);
      expect(toasts.length).assertEqual(1);
      expect(toasts[0]).assertEqual('请先设置开始时间');
    });

    it('conflict: companion_view_primary_action_should_toast_when_pending_event_cannot_start_and_dialog_is_not_shown', 0, async () => {
      // Arrange
      const focused = buildCompanionEventGA(134, 'blocked_pending');
      const active = buildCompanionEventGA(135, 'active_running', 'ACTIVE');
      const vm = new CompanionViewVmMockGA();
      vm.orderedEvents = [focused, active];
      vm.companionContext = buildCompanionContextGA('READY', null, focused);
      const page = createCompanionViewInstanceGA(vm as Object as TimelineViewModel);
      setCompanionViewUiContextGA(page, new CompanionViewUiContextMockGA());
      const toasts: string[] = [];
      Reflect.set(page as Object, 'getFocusedEvent', (): EventEntity | null => focused);
      Reflect.set(page as Object, 'showGlobalActiveConflictDialog', async (_excludeEventId: number): Promise<boolean> => false);
      Reflect.set(page as Object, 'safeShowToast', (message: string): void => {
        toasts.push(message);
      });

      // Act
      await page.handleFocusedPrimaryAction();

      // Assert
      expect(vm.updateCalls.length).assertEqual(0);
      expect(toasts.length).assertEqual(1);
      expect(toasts[0]).assertEqual('请先结束当前进行中的任务');
    });

    it('regression: companion_view_skip_should_delegate_to_vm_and_focus_next_startable_event', 0, async () => {
      // Arrange
      const focused = buildCompanionEventGA(136, 'skip_current');
      const nextStartable = buildCompanionEventGA(137, 'skip_next');
      const vm = new CompanionViewVmMockGA();
      vm.orderedEvents = [focused, nextStartable];
      vm.companionContext = buildCompanionContextGA('READY', null, focused);
      const page = createCompanionViewInstanceGA(vm as Object as TimelineViewModel);
      setCompanionViewUiContextGA(page, new CompanionViewUiContextMockGA());
      let refreshed = 0;
      let focusedId = -1;
      Reflect.set(page as Object, 'getFocusedEvent', (): EventEntity | null => focused);
      Reflect.set(page as Object, 'refreshContext', (): void => {
        refreshed += 1;
      });
      Reflect.set(page as Object, 'applyFocusById', (id: number): void => {
        focusedId = id;
      });

      // Act
      await page.handleFocusedSkip();
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 180);
      });

      // Assert
      expect(vm.skipCalls.length).assertEqual(1);
      expect(vm.skipCalls[0]).assertEqual(136);
      expect(refreshed).assertEqual(1);
      expect(focusedId).assertEqual(137);
    });

    it('combined: companion_view_reopen_should_restart_skipped_event_and_enter_immersive_mode', 0, async () => {
      // Arrange
      const focused = buildCompanionEventGA(138, 'reopen_target', 'SKIPPED');
      const vm = new CompanionViewVmMockGA();
      vm.orderedEvents = [focused];
      vm.companionContext = buildCompanionContextGA('READY', null, focused);
      const page = createCompanionViewInstanceGA(vm as Object as TimelineViewModel);
      setCompanionViewUiContextGA(page, new CompanionViewUiContextMockGA());
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
      await page.handleFocusedReopen();

      // Assert
      expect(vm.reopenCalls.length).assertEqual(1);
      expect(vm.reopenCalls[0]).assertEqual(138);
      expect(vm.updateCalls.length).assertEqual(1);
      expect(vm.updateCalls[0].field).assertEqual('actual_start_time');
      expect(refreshed).assertEqual(1);
      expect(focusedId).assertEqual(138);
      expect(immersiveCalls).assertEqual(1);
    });
  });
}
