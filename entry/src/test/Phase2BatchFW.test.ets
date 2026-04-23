import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { CompanionView } from '../main/ets/pages/components/views/CompanionView';
import { IndexCompanionOverlay } from '../main/ets/pages/index/IndexCompanionOverlay';
import { CompanionContext, TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

interface CompanionViewCtorParamsFW {
  vm: Object;
  isShow: Object;
}

interface IndexCompanionOverlayParamsFW {
  vm?: TimelineViewModel;
  isVisible?: boolean;
  overlayZIndex?: number;
}

interface IndexCompanionOverlayPrivateFW {
  __vm: Object;
  __isVisible: Object;
}

interface CompanionViewUiContextFW {
  animateTo(options: Object, action: () => void): void;
  showAlertDialog(options: Object): void;
  getHostContext(): Object;
}

interface GestureEventLikeFW {
  offsetY: number;
}

interface CompanionViewPrivateFW {
  companionSubMode: string;
  interactionMode: string;
  swipeStartTs: number;
  swipeLastTs: number;
  swipePeakDistance: number;
  immersiveDragOffsetY: number;
  focusedEventId: number;
  cachedVisibleIndexById: Map<number, number>;
  handleImmersiveSwipeStart(): void;
  handleImmersiveSwipeUpdate(event: GestureEventLikeFW): void;
  resetImmersiveSwipe(): void;
  handleImmersiveSwipeEnd(event: GestureEventLikeFW): void;
  getVisibleFocusPosition(): number;
}

class CompanionViewHostContextMockFW {}

class CompanionViewUiContextMockFW implements CompanionViewUiContextFW {
  private readonly hostContext: Object = new CompanionViewHostContextMockFW() as Object;

  animateTo(_options: Object, action: () => void): void {
    action();
  }

  showAlertDialog(_options: Object): void {}

  getHostContext(): Object {
    return this.hostContext;
  }
}

class CompanionViewCountingUiContextMockFW implements CompanionViewUiContextFW {
  private readonly hostContext: Object = new CompanionViewHostContextMockFW() as Object;
  animateCount: number = 0;

  animateTo(_options: Object, action: () => void): void {
    this.animateCount += 1;
    action();
  }

  showAlertDialog(_options: Object): void {}

  getHostContext(): Object {
    return this.hostContext;
  }
}

class CompanionViewVmMockFW {
  scheduleVersion: number = 1;
  orderedEvents: EventEntity[] = [];
  companionContext: CompanionContext = buildCompanionContextFW('IDLE', null, null);

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

function buildCompanionEventFW(id: number, name: string): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.status = 1;
  event.completion_status = EventEntity.STATE_PENDING;
  return event;
}

function buildCompanionContextFW(
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

function createCompanionViewInstanceFW(vm: TimelineViewModel, isShow: boolean = true): CompanionViewPrivateFW {
  const overlayParams: IndexCompanionOverlayParamsFW = {
    vm,
    isVisible: isShow,
    overlayZIndex: 10
  };
  const overlay = new IndexCompanionOverlay(
    undefined,
    overlayParams as Object as LocalStorage
  ) as Object as IndexCompanionOverlayPrivateFW;
  const companionParams: CompanionViewCtorParamsFW = {
    vm: overlay.__vm,
    isShow: overlay.__isVisible
  };
  return new CompanionView(
    overlay as Object,
    companionParams as Object as LocalStorage
  ) as Object as CompanionViewPrivateFW;
}

function setCompanionViewUiContextFW(page: CompanionViewPrivateFW, uiContext: CompanionViewUiContextFW): void {
  Reflect.set(page as Object, 'getUIContext', (): CompanionViewUiContextFW => uiContext);
}

export default function phase2BatchFWTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchFW_companion_view_swipe_methods', () => {
    it('normal: companion_view_swipe_update_should_record_peak_and_damped_drag_in_immersive_mode', 0, () => {
      // Arrange
      const vm = new CompanionViewVmMockFW();
      const page = createCompanionViewInstanceFW(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFW(page, new CompanionViewUiContextMockFW());
      page.companionSubMode = 'immersive';

      // Act
      page.handleImmersiveSwipeStart();
      page.handleImmersiveSwipeUpdate({ offsetY: -600 });

      // Assert
      expect(page.swipeStartTs > 0).assertTrue();
      expect(page.swipeLastTs > 0).assertTrue();
      expect(page.swipePeakDistance).assertEqual(600);
      expect(page.immersiveDragOffsetY).assertEqual(-150);
    });

    it('boundary: companion_view_swipe_update_should_ignore_non_immersive_mode_and_positive_offset', 0, () => {
      // Arrange
      const vm = new CompanionViewVmMockFW();
      const page = createCompanionViewInstanceFW(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFW(page, new CompanionViewUiContextMockFW());
      page.companionSubMode = 'control';
      page.swipePeakDistance = 12;
      page.immersiveDragOffsetY = -20;

      // Act
      page.handleImmersiveSwipeUpdate({ offsetY: -60 });
      page.companionSubMode = 'immersive';
      page.handleImmersiveSwipeUpdate({ offsetY: 30 });

      // Assert
      expect(page.swipePeakDistance).assertEqual(12);
      expect(page.immersiveDragOffsetY).assertEqual(0);
    });

    it('invalid: companion_view_reset_swipe_should_skip_animation_when_drag_is_already_zero', 0, () => {
      // Arrange
      const vm = new CompanionViewVmMockFW();
      const page = createCompanionViewInstanceFW(vm as Object as TimelineViewModel);
      const uiContext = new CompanionViewCountingUiContextMockFW();
      setCompanionViewUiContextFW(page, uiContext);
      page.immersiveDragOffsetY = 0;

      // Act
      page.resetImmersiveSwipe();

      // Assert
      expect(uiContext.animateCount).assertEqual(0);
      expect(page.immersiveDragOffsetY).assertEqual(0);
    });

    it('regression: companion_view_swipe_end_should_enter_control_when_threshold_is_met', 0, () => {
      // Arrange
      const vm = new CompanionViewVmMockFW();
      const page = createCompanionViewInstanceFW(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFW(page, new CompanionViewUiContextMockFW());
      let enterControlCount = 0;
      Reflect.set(page as Object, 'enterControlMode', (): void => {
        enterControlCount += 1;
      });
      page.swipeStartTs = Date.now() - 200;
      page.swipePeakDistance = 120;
      page.immersiveDragOffsetY = -40;

      // Act
      page.handleImmersiveSwipeEnd({ offsetY: -100 });

      // Assert
      expect(enterControlCount).assertEqual(1);
      expect(page.swipeStartTs).assertEqual(0);
      expect(page.swipeLastTs).assertEqual(0);
      expect(page.swipePeakDistance).assertEqual(0);
    });

    it('combined: companion_view_swipe_end_and_focus_position_should_reset_drag_and_report_visible_position', 0, () => {
      // Arrange
      const vm = new CompanionViewVmMockFW();
      const page = createCompanionViewInstanceFW(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFW(page, new CompanionViewUiContextMockFW());
      page.focusedEventId = 32;
      page.cachedVisibleIndexById.set(31, 0);
      page.cachedVisibleIndexById.set(32, 3);
      Reflect.set(page as Object, 'ensureScheduleCacheUpToDate', (): void => {});
      page.swipeStartTs = Date.now() - 1000;
      page.swipePeakDistance = 20;
      page.immersiveDragOffsetY = -80;

      // Act
      page.handleImmersiveSwipeEnd({ offsetY: -10 });
      const visiblePosition = page.getVisibleFocusPosition();

      // Assert
      expect(page.immersiveDragOffsetY).assertEqual(0);
      expect(visiblePosition).assertEqual(4);
    });
  });
}
