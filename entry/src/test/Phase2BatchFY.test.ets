import { describe, expect, it } from '@ohos/hypium';
import { ThemeCenter } from '../main/ets/common/utils/ThemeCenter';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { CompanionView } from '../main/ets/pages/components/views/CompanionView';
import { IndexCompanionOverlay } from '../main/ets/pages/index/IndexCompanionOverlay';
import { CompanionContext, TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

interface CompanionViewCtorParamsFY {
  vm: Object;
  isShow: Object;
}

interface IndexCompanionOverlayParamsFY {
  vm?: TimelineViewModel;
  isVisible?: boolean;
  overlayZIndex?: number;
}

interface IndexCompanionOverlayPrivateFY {
  __vm: Object;
  __isVisible: Object;
}

interface CompanionViewUiContextFY {
  animateTo(options: Object, action: () => void): void;
  showAlertDialog(options: Object): void;
  getHostContext(): Object;
}

interface TimerLikeFY {
  setInterval(handler: () => void, delay: number): number;
  clearInterval(timerId: number): void;
}

interface CompanionViewPrivateFY {
  effectiveTheme: string;
  context: CompanionContext;
  companionSubMode: string;
  showHistoryPage: boolean;
  showSearchPage: boolean;
  showFilterPage: boolean;
  companionFilterState: string;
  realtimeWatchTimer: number;
  observedScheduleVersion: number;
  observedRuntimeState: string;
  observedBackRequest: number;
  cachedScheduledEvents: EventEntity[];
  cachedVisibleScheduledEvents: EventEntity[];
  safeShowToast(message: string): void;
  getThemePalette(): Object;
  refreshContext(): void;
  startRealtimeWatch(): void;
  stopRealtimeWatch(): void;
  getScheduledEvents(): EventEntity[];
  getVisibleScheduledEvents(): EventEntity[];
}

class StaticPatchFY {
  private readonly target: Object;
  private readonly key: string;
  private readonly original: Object;

  constructor(target: Object, key: string, nextValue: Object) {
    this.target = target;
    this.key = key;
    this.original = Reflect.get(target, key) as Object;
    Reflect.set(target, key, nextValue);
  }

  restore(): void {
    Reflect.set(this.target, this.key, this.original);
  }
}

class CompanionViewHostContextMockFY {}

class CompanionViewUiContextMockFY implements CompanionViewUiContextFY {
  private readonly hostContext: Object = new CompanionViewHostContextMockFY() as Object;

  animateTo(_options: Object, action: () => void): void {
    action();
  }

  showAlertDialog(_options: Object): void {}

  getHostContext(): Object {
    return this.hostContext;
  }
}

class CompanionViewVmMockFY {
  scheduleVersion: number = 1;
  orderedEvents: EventEntity[] = [];
  companionContext: CompanionContext = buildCompanionContextFY('IDLE', null, null);

  getScheduleVersion(): number {
    return this.scheduleVersion;
  }

  getOrderedScheduleEvents(): EventEntity[] {
    return this.orderedEvents;
  }

  getCompanionContext(): CompanionContext {
    return this.companionContext;
  }
}

class IntervalControllerFY {
  callback?: () => void;
  delay: number = -1;
  returnId: number;
  clearedIds: number[] = [];

  constructor(returnId: number) {
    this.returnId = returnId;
  }

  bind(): StaticPatchFY[] {
    const timerTarget = globalThis as Object as TimerLikeFY as Object;
    return [
      new StaticPatchFY(timerTarget, 'setInterval', ((handler: () => void, delay: number): number => {
        this.callback = handler;
        this.delay = delay;
        return this.returnId;
      }) as Object),
      new StaticPatchFY(timerTarget, 'clearInterval', ((timerId: number): void => {
        this.clearedIds.push(timerId);
      }) as Object)
    ];
  }
}

function buildCompanionEventFY(id: number, name: string, active: boolean = false): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.status = 1;
  event.completion_status = EventEntity.STATE_PENDING;
  event.actual_start_time = active ? Date.now() - 1000 : 0;
  event.actual_end_time = 0;
  return event;
}

function buildCompanionContextFY(
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
    canResume: true,
    canEnd: true,
    canSkip: true,
    canNavigate: true,
    canViewDetail: true
  };
  return context;
}

function createCompanionViewInstanceFY(vm: TimelineViewModel, isShow: boolean = true): CompanionViewPrivateFY {
  const overlayParams: IndexCompanionOverlayParamsFY = {
    vm,
    isVisible: isShow,
    overlayZIndex: 10
  };
  const overlay = new IndexCompanionOverlay(
    undefined,
    overlayParams as Object as LocalStorage
  ) as Object as IndexCompanionOverlayPrivateFY;
  const companionParams: CompanionViewCtorParamsFY = {
    vm: overlay.__vm,
    isShow: overlay.__isVisible
  };
  return new CompanionView(
    overlay as Object,
    companionParams as Object as LocalStorage
  ) as Object as CompanionViewPrivateFY;
}

function setCompanionViewUiContextFY(page: CompanionViewPrivateFY, uiContext: CompanionViewUiContextFY): void {
  Reflect.set(page as Object, 'getUIContext', (): CompanionViewUiContextFY => uiContext);
}

function restorePatchesFY(patches: StaticPatchFY[]): void {
  patches.forEach((patch: StaticPatchFY) => patch.restore());
}

export default function phase2BatchFYTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchFY_companion_view_cache_and_watch_methods', () => {
    it('normal: companion_view_theme_and_toast_methods_should_follow_effective_theme', 0, () => {
      // Arrange
      const vm = new CompanionViewVmMockFY();
      const page = createCompanionViewInstanceFY(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFY(page, new CompanionViewUiContextMockFY());
      page.effectiveTheme = 'dark';

      // Act
      const palette = page.getThemePalette();
      page.safeShowToast('fy_toast_message');

      // Assert
      expect(Reflect.get(palette, 'pageBg')).assertEqual(ThemeCenter.getPalette('dark').pageBg);
      expect(Reflect.get(palette, 'textPrimary')).assertEqual(ThemeCenter.getPalette('dark').textPrimary);
    });

    it('boundary: companion_view_cached_schedule_accessors_should_return_cached_lists_after_guard_passes', 0, () => {
      // Arrange
      const active = buildCompanionEventFY(81, 'active', true);
      const pending = buildCompanionEventFY(82, 'pending');
      const vm = new CompanionViewVmMockFY();
      vm.orderedEvents = [active, pending];
      vm.companionContext = buildCompanionContextFY('ACTIVE', active, pending);
      const page = createCompanionViewInstanceFY(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFY(page, new CompanionViewUiContextMockFY());
      page.cachedScheduledEvents = [active, pending];
      page.cachedVisibleScheduledEvents = [pending];
      Reflect.set(page as Object, 'ensureScheduleCacheUpToDate', (): void => {});

      // Act
      const scheduledEvents = page.getScheduledEvents();
      const visibleEvents = page.getVisibleScheduledEvents();

      // Assert
      expect(scheduledEvents.length).assertEqual(2);
      expect(page.cachedScheduledEvents.length).assertEqual(2);
      expect(visibleEvents.length).assertEqual(1);
      expect(visibleEvents[0].id).assertEqual(pending.id);
      expect(page.cachedVisibleScheduledEvents.length).assertEqual(1);
    });

    it('invalid: companion_view_stop_realtime_watch_should_reset_when_no_timer_is_running', 0, () => {
      // Arrange
      const vm = new CompanionViewVmMockFY();
      const page = createCompanionViewInstanceFY(vm as Object as TimelineViewModel);
      page.realtimeWatchTimer = -1;
      AppStorage.setOrCreate('COMPANION_BACK_LEVEL', 'immersive');

      // Act
      page.stopRealtimeWatch();

      // Assert
      expect(page.realtimeWatchTimer).assertEqual(-1);
      expect(String(AppStorage.get('COMPANION_BACK_LEVEL') || '')).assertEqual('none');
    });

    it('conflict: companion_view_start_realtime_watch_should_clear_existing_timer_before_replacing_it', 0, () => {
      // Arrange
      const current = buildCompanionEventFY(91, 'current', true);
      const next = buildCompanionEventFY(92, 'next');
      const vm = new CompanionViewVmMockFY();
      vm.orderedEvents = [current, next];
      vm.companionContext = buildCompanionContextFY('ACTIVE', current, next);
      const page = createCompanionViewInstanceFY(vm as Object as TimelineViewModel);
      page.context = vm.companionContext;
      page.realtimeWatchTimer = 33;
      AppStorage.setOrCreate('COMPANION_BACK_REQUEST', 0);
      const intervalController = new IntervalControllerFY(77);
      const patches = intervalController.bind();

      // Act
      page.startRealtimeWatch();
      restorePatchesFY(patches);

      // Assert
      expect(intervalController.clearedIds.length).assertEqual(1);
      expect(intervalController.clearedIds[0]).assertEqual(33);
      expect(intervalController.delay).assertEqual(300);
      expect(page.realtimeWatchTimer).assertEqual(77);
      expect(page.observedScheduleVersion).assertEqual(1);
      expect(page.observedRuntimeState).assertEqual('ACTIVE');
      expect(page.observedBackRequest).assertEqual(0);
    });

    it('regression: companion_view_realtime_watch_tick_should_sync_back_request_and_refresh_context', 0, () => {
      // Arrange
      const current = buildCompanionEventFY(101, 'current', true);
      const next = buildCompanionEventFY(102, 'next');
      const vm = new CompanionViewVmMockFY();
      vm.orderedEvents = [current, next];
      vm.companionContext = buildCompanionContextFY('ACTIVE', current, next);
      const page = createCompanionViewInstanceFY(vm as Object as TimelineViewModel);
      page.context = vm.companionContext;
      page.companionSubMode = 'control';
      page.showHistoryPage = false;
      page.showSearchPage = false;
      page.showFilterPage = false;
      AppStorage.setOrCreate('COMPANION_BACK_LEVEL', '');
      AppStorage.setOrCreate('COMPANION_BACK_REQUEST', 0);
      const intervalController = new IntervalControllerFY(66);
      const patches = intervalController.bind();
      let backHandledCount = 0;
      let refreshCount = 0;
      Reflect.set(page as Object, 'handleCompanionBackNavigation', (): boolean => {
        backHandledCount += 1;
        return true;
      });
      Reflect.set(page as Object, 'refreshContext', (): void => {
        refreshCount += 1;
      });

      // Act
      page.startRealtimeWatch();
      page.showHistoryPage = true;
      vm.scheduleVersion = 2;
      vm.companionContext = buildCompanionContextFY('READY', null, next);
      AppStorage.setOrCreate('COMPANION_BACK_REQUEST', 1);
      intervalController.callback?.();
      restorePatchesFY(patches);

      // Assert
      expect(String(AppStorage.get('COMPANION_BACK_LEVEL') || '')).assertEqual('overlay');
      expect(page.observedBackRequest).assertEqual(1);
      expect(backHandledCount).assertEqual(1);
      expect(refreshCount).assertEqual(0);
    });

    it('combined: companion_view_realtime_watch_should_start_then_stop_and_clear_back_level', 0, () => {
      // Arrange
      const current = buildCompanionEventFY(111, 'current', true);
      const next = buildCompanionEventFY(112, 'next');
      const vm = new CompanionViewVmMockFY();
      vm.orderedEvents = [current, next];
      vm.companionContext = buildCompanionContextFY('ACTIVE', current, next);
      const page = createCompanionViewInstanceFY(vm as Object as TimelineViewModel);
      page.context = vm.companionContext;
      AppStorage.setOrCreate('COMPANION_BACK_REQUEST', 0);
      AppStorage.setOrCreate('COMPANION_BACK_LEVEL', '');
      const intervalController = new IntervalControllerFY(55);
      const patches = intervalController.bind();

      // Act
      page.startRealtimeWatch();
      page.stopRealtimeWatch();
      restorePatchesFY(patches);

      // Assert
      expect(page.realtimeWatchTimer).assertEqual(-1);
      expect(intervalController.clearedIds.length).assertEqual(1);
      expect(intervalController.clearedIds[0]).assertEqual(55);
      expect(String(AppStorage.get('COMPANION_BACK_LEVEL') || '')).assertEqual('none');
    });
  });
}
