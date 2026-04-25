import { describe, expect, it } from '@ohos/hypium';
import { CompanionView } from '../main/ets/pages/components/views/CompanionView';
import { IndexCompanionOverlay } from '../main/ets/pages/index/IndexCompanionOverlay';
import { TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

interface CompanionViewCtorParamsGC {
  vm: Object;
  isShow: Object;
}

interface IndexCompanionOverlayParamsGC {
  vm?: TimelineViewModel;
  isVisible?: boolean;
  overlayZIndex?: number;
}

interface IndexCompanionOverlayPrivateGC {
  __vm: Object;
  __isVisible: Object;
}

interface CompanionViewUiContextGC {
  animateTo(options: Object, action: () => void): void;
  showAlertDialog(options: Object): void;
  getHostContext(): Object;
}

interface GestureEventGC {
  offsetY: number;
}

interface HistoryTimelineItemPlaceholderGC {
  marker: string;
}

interface HistorySummaryPlaceholderGC {
  marker: string;
}

interface CompanionViewPrivateGC {
  exitCompanion(): void;
  handleCompanionBackNavigation(): boolean;
  handleImmersiveSwipeStart(): void;
  handleImmersiveSwipeUpdate(event: GestureEvent): void;
  resetImmersiveSwipe(): void;
  handleImmersiveSwipeEnd(event: GestureEvent): void;
}

class CompanionViewHostContextMockGC {}

class CompanionViewUiContextMockGC implements CompanionViewUiContextGC {
  private readonly hostContext: Object = new CompanionViewHostContextMockGC() as Object;

  animateTo(_options: Object, action: () => void): void {
    action();
  }

  showAlertDialog(_options: Object): void {}

  getHostContext(): Object {
    return this.hostContext;
  }
}

class CompanionViewVmMockGC {
  getScheduleVersion(): number {
    return 1;
  }

  getOrderedScheduleEvents(): Object[] {
    return [];
  }
}

function createCompanionViewInstanceGC(vm: TimelineViewModel, isShow: boolean = true): CompanionViewPrivateGC {
  const overlayParams: IndexCompanionOverlayParamsGC = {
    vm,
    isVisible: isShow,
    overlayZIndex: 10
  };
  const overlay = new IndexCompanionOverlay(
    undefined,
    overlayParams as Object as LocalStorage
  ) as Object as IndexCompanionOverlayPrivateGC;
  const companionParams: CompanionViewCtorParamsGC = {
    vm: overlay.__vm,
    isShow: overlay.__isVisible
  };
  const instance = new CompanionView(
    overlay as Object,
    companionParams as Object as LocalStorage
  ) as Object as CompanionViewPrivateGC;
  Reflect.set(instance as Object, 'vm', vm);
  return instance;
}

function setCompanionViewUiContextGC(page: CompanionViewPrivateGC, uiContext: CompanionViewUiContextGC): void {
  Reflect.set(page as Object, 'getUIContext', (): CompanionViewUiContextGC => uiContext);
}

function buildGestureEventGC(offsetY: number): GestureEventGC {
  const event = {} as GestureEventGC;
  event.offsetY = offsetY;
  return event;
}

function buildHistoryTimelineItemPlaceholderGC(): HistoryTimelineItemPlaceholderGC {
  const item = {} as HistoryTimelineItemPlaceholderGC;
  item.marker = 'timeline';
  return item;
}

function buildHistorySummaryPlaceholderGC(): HistorySummaryPlaceholderGC {
  const summary = {} as HistorySummaryPlaceholderGC;
  summary.marker = 'summary';
  return summary;
}

export default function phase2BatchGCTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchGC_companion_view_navigation_and_swipe', () => {
    it('normal: companion_view_back_navigation_should_close_overlay_and_reset_history_state', 0, () => {
      // Arrange
      const vm = new CompanionViewVmMockGC();
      const page = createCompanionViewInstanceGC(vm as Object as TimelineViewModel);
      setCompanionViewUiContextGC(page, new CompanionViewUiContextMockGC());
      const toasts: string[] = [];
      Reflect.set(page as Object, 'showHistoryPage', true);
      Reflect.set(page as Object, 'showSearchPage', true);
      Reflect.set(page as Object, 'showFilterPage', true);
      Reflect.set(page as Object, 'historyViewMode', 'detail');
      Reflect.set(page as Object, 'selectedHistoryTimelineItem', buildHistoryTimelineItemPlaceholderGC() as Object);
      Reflect.set(page as Object, 'selectedHistoryPlaceName', 'old_place');
      Reflect.set(page as Object, 'historySummary', buildHistorySummaryPlaceholderGC() as Object);
      Reflect.set(page as Object, 'safeShowToast', (message: string): void => {
        toasts.push(message);
      });

      // Act
      const handled = page.handleCompanionBackNavigation();

      // Assert
      expect(handled).assertTrue();
      expect(Reflect.get(page as Object, 'showHistoryPage') as boolean).assertFalse();
      expect(Reflect.get(page as Object, 'showSearchPage') as boolean).assertFalse();
      expect(Reflect.get(page as Object, 'showFilterPage') as boolean).assertFalse();
      expect(Reflect.get(page as Object, 'historyViewMode') as string).assertEqual('timeline');
      expect(Reflect.get(page as Object, 'selectedHistoryPlaceName') as string).assertEqual('');
      expect(toasts[0]).assertEqual('已返回伴游上一级');
    });

    it('boundary: companion_view_back_navigation_should_return_to_immersive_from_control_mode', 0, () => {
      // Arrange
      const vm = new CompanionViewVmMockGC();
      const page = createCompanionViewInstanceGC(vm as Object as TimelineViewModel);
      setCompanionViewUiContextGC(page, new CompanionViewUiContextMockGC());
      const toasts: string[] = [];
      let immersiveCalls = 0;
      Reflect.set(page as Object, 'companionSubMode', 'control');
      Reflect.set(page as Object, 'safeShowToast', (message: string): void => {
        toasts.push(message);
      });
      Reflect.set(page as Object, 'enterImmersiveMode', (): void => {
        immersiveCalls += 1;
      });

      // Act
      const handled = page.handleCompanionBackNavigation();

      // Assert
      expect(handled).assertTrue();
      expect(immersiveCalls).assertEqual(1);
      expect(toasts[0]).assertEqual('已返回沉浸模式');
    });

    it('invalid: companion_view_exit_should_hide_overlay_and_reset_drag_offset', 0, () => {
      // Arrange
      const vm = new CompanionViewVmMockGC();
      const page = createCompanionViewInstanceGC(vm as Object as TimelineViewModel);
      setCompanionViewUiContextGC(page, new CompanionViewUiContextMockGC());
      Reflect.set(page as Object, 'showHistoryPage', true);
      Reflect.set(page as Object, 'showSearchPage', true);
      Reflect.set(page as Object, 'showFilterPage', true);
      Reflect.set(page as Object, 'immersiveDragOffsetY', 64);
      Reflect.set(page as Object, 'isShow', true);

      // Act
      page.exitCompanion();

      // Assert
      expect(Reflect.get(page as Object, 'showHistoryPage') as boolean).assertFalse();
      expect(Reflect.get(page as Object, 'showSearchPage') as boolean).assertFalse();
      expect(Reflect.get(page as Object, 'showFilterPage') as boolean).assertFalse();
      expect(Reflect.get(page as Object, 'immersiveDragOffsetY') as number).assertEqual(0);
      expect(Reflect.get(page as Object, 'isShow') as boolean).assertFalse();
    });

    it('conflict: companion_view_swipe_update_should_ignore_non_immersive_mode', 0, () => {
      // Arrange
      const vm = new CompanionViewVmMockGC();
      const page = createCompanionViewInstanceGC(vm as Object as TimelineViewModel);
      setCompanionViewUiContextGC(page, new CompanionViewUiContextMockGC());
      Reflect.set(page as Object, 'companionSubMode', 'control');
      Reflect.set(page as Object, 'immersiveDragOffsetY', 12);
      Reflect.set(page as Object, 'swipePeakDistance', 20);
      const event = buildGestureEventGC(80) as Object as GestureEvent;

      // Act
      page.handleImmersiveSwipeUpdate(event);

      // Assert
      expect(Reflect.get(page as Object, 'immersiveDragOffsetY') as number).assertEqual(12);
      expect(Reflect.get(page as Object, 'swipePeakDistance') as number).assertEqual(20);
    });

    it('regression: companion_view_swipe_reset_should_animate_drag_offset_back_to_zero', 0, () => {
      // Arrange
      const vm = new CompanionViewVmMockGC();
      const page = createCompanionViewInstanceGC(vm as Object as TimelineViewModel);
      setCompanionViewUiContextGC(page, new CompanionViewUiContextMockGC());
      Reflect.set(page as Object, 'immersiveDragOffsetY', 48);

      // Act
      page.resetImmersiveSwipe();

      // Assert
      expect(Reflect.get(page as Object, 'immersiveDragOffsetY') as number).assertEqual(0);
    });

    it('combined: companion_view_swipe_end_should_enter_control_when_threshold_is_reached', 0, () => {
      // Arrange
      const vm = new CompanionViewVmMockGC();
      const page = createCompanionViewInstanceGC(vm as Object as TimelineViewModel);
      setCompanionViewUiContextGC(page, new CompanionViewUiContextMockGC());
      let controlCalls = 0;
      Reflect.set(page as Object, 'companionSubMode', 'immersive');
      Reflect.set(page as Object, 'swipePeakDistance', 180);
      Reflect.set(page as Object, 'swipeStartTs', Date.now() - 200);
      Reflect.set(page as Object, 'swipeLastTs', Date.now() - 50);
      Reflect.set(page as Object, 'immersiveDistanceTrigger', 120);
      Reflect.set(page as Object, 'immersiveVelocityTrigger', 0.35);
      Reflect.set(page as Object, 'enterControlMode', (): void => {
        controlCalls += 1;
      });
      const event = buildGestureEventGC(180) as Object as GestureEvent;

      // Act
      page.handleImmersiveSwipeEnd(event);

      // Assert
      expect(controlCalls).assertEqual(1);
      expect(Reflect.get(page as Object, 'swipePeakDistance') as number).assertEqual(0);
      expect(Reflect.get(page as Object, 'swipeStartTs') as number).assertEqual(0);
    });
  });
}
