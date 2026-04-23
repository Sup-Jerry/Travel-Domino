import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { CompanionView } from '../main/ets/pages/components/views/CompanionView';
import { IndexCompanionOverlay } from '../main/ets/pages/index/IndexCompanionOverlay';
import { CompanionContext, HistoryTimelineItem, PlaceCheckinSummary, TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

interface CompanionViewCtorParamsFV {
  vm: Object;
  isShow: Object;
}

interface IndexCompanionOverlayParamsFV {
  vm?: TimelineViewModel;
  isVisible?: boolean;
  overlayZIndex?: number;
}

interface IndexCompanionOverlayPrivateFV {
  __vm: Object;
  __isVisible: Object;
}

interface CompanionViewUiContextFV {
  animateTo(options: Object, action: () => void): void;
  showAlertDialog(options: Object): void;
  getHostContext(): Object;
}

interface CompanionViewPrivateFV {
  isShow: boolean;
  companionSubMode: string;
  interactionMode: string;
  immersiveDragOffsetY: number;
  showHistoryPage: boolean;
  showSearchPage: boolean;
  showFilterPage: boolean;
  historyViewMode: string;
  selectedHistoryTimelineItem: HistoryTimelineItem | null;
  selectedHistoryPlaceName: string;
  historySummary: PlaceCheckinSummary | null;
  refreshContext(): void;
  enterControlMode(): void;
  enterImmersiveMode(): void;
  exitCompanion(): void;
  handleCompanionBackNavigation(): boolean;
}

class CompanionViewHostContextMockFV {}

class CompanionViewUiContextMockFV implements CompanionViewUiContextFV {
  private readonly hostContext: Object = new CompanionViewHostContextMockFV() as Object;

  animateTo(_options: Object, action: () => void): void {
    action();
  }

  showAlertDialog(_options: Object): void {}

  getHostContext(): Object {
    return this.hostContext;
  }
}

class CompanionViewVmMockFV {
  scheduleVersion: number = 1;
  orderedEvents: EventEntity[] = [];
  companionContext: CompanionContext = buildCompanionContextFV('IDLE', null, null);

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

function buildCompanionEventFV(id: number, name: string): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.status = 1;
  event.completion_status = EventEntity.STATE_PENDING;
  return event;
}

function buildCompanionContextFV(
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

function createCompanionViewInstanceFV(vm: TimelineViewModel, isShow: boolean = true): CompanionViewPrivateFV {
  const overlayParams: IndexCompanionOverlayParamsFV = {
    vm,
    isVisible: isShow,
    overlayZIndex: 10
  };
  const overlay = new IndexCompanionOverlay(
    undefined,
    overlayParams as Object as LocalStorage
  ) as Object as IndexCompanionOverlayPrivateFV;
  const companionParams: CompanionViewCtorParamsFV = {
    vm: overlay.__vm,
    isShow: overlay.__isVisible
  };
  return new CompanionView(
    overlay as Object,
    companionParams as Object as LocalStorage
  ) as Object as CompanionViewPrivateFV;
}

function setCompanionViewUiContextFV(page: CompanionViewPrivateFV, uiContext: CompanionViewUiContextFV): void {
  Reflect.set(page as Object, 'getUIContext', (): CompanionViewUiContextFV => uiContext);
}

export default function phase2BatchFVTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchFV_companion_view_mode_and_back_methods', () => {
    it('normal: companion_view_mode_methods_should_switch_between_control_and_immersive_states', 0, () => {
      // Arrange
      const current = buildCompanionEventFV(1, 'Current');
      const next = buildCompanionEventFV(2, 'Next');
      const vm = new CompanionViewVmMockFV();
      vm.orderedEvents = [current, next];
      vm.companionContext = buildCompanionContextFV('ACTIVE', current, next);
      const page = createCompanionViewInstanceFV(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFV(page, new CompanionViewUiContextMockFV());
      page.companionSubMode = 'immersive';
      page.immersiveDragOffsetY = 25;

      // Act
      page.enterControlMode();
      page.showHistoryPage = true;
      page.showSearchPage = true;
      page.showFilterPage = true;
      page.companionSubMode = 'control';
      page.enterImmersiveMode();

      // Assert
      expect(page.companionSubMode).assertEqual('immersive');
      expect(page.interactionMode).assertEqual('both');
      expect(page.immersiveDragOffsetY).assertEqual(0);
      expect(page.showHistoryPage).assertFalse();
      expect(page.showSearchPage).assertFalse();
      expect(page.showFilterPage).assertFalse();
    });

    it('boundary: companion_view_exit_should_clear_overlay_flags_and_hide_component', 0, () => {
      // Arrange
      const vm = new CompanionViewVmMockFV();
      const page = createCompanionViewInstanceFV(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFV(page, new CompanionViewUiContextMockFV());
      page.showHistoryPage = true;
      page.showSearchPage = true;
      page.showFilterPage = true;
      page.immersiveDragOffsetY = 30;
      page.isShow = true;

      // Act
      page.exitCompanion();

      // Assert
      expect(page.showHistoryPage).assertFalse();
      expect(page.showSearchPage).assertFalse();
      expect(page.showFilterPage).assertFalse();
      expect(page.immersiveDragOffsetY).assertEqual(0);
      expect(page.isShow).assertFalse();
    });

    it('combined: companion_view_back_navigation_should_close_overlay_and_reset_history_detail_state', 0, () => {
      // Arrange
      const vm = new CompanionViewVmMockFV();
      const page = createCompanionViewInstanceFV(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFV(page, new CompanionViewUiContextMockFV());
      const toasts: string[] = [];
      Reflect.set(page as Object, 'safeShowToast', (message: string): void => {
        toasts.push(message);
      });
      page.showHistoryPage = true;
      page.showSearchPage = true;
      page.showFilterPage = true;
      page.historyViewMode = 'detail';
      page.selectedHistoryTimelineItem = {} as HistoryTimelineItem;
      page.selectedHistoryPlaceName = 'Old Place';
      page.historySummary = {} as PlaceCheckinSummary;

      // Act
      const handled = page.handleCompanionBackNavigation();

      // Assert
      expect(handled).assertTrue();
      expect(page.showHistoryPage).assertFalse();
      expect(page.showSearchPage).assertFalse();
      expect(page.showFilterPage).assertFalse();
      expect(page.historyViewMode).assertEqual('timeline');
      expect(page.selectedHistoryTimelineItem).assertNull();
      expect(page.selectedHistoryPlaceName).assertEqual('');
      expect(page.historySummary).assertNull();
      expect(toasts.length).assertEqual(1);
    });

    it('regression: companion_view_back_navigation_should_delegate_control_mode_back_to_immersive', 0, () => {
      // Arrange
      const vm = new CompanionViewVmMockFV();
      const page = createCompanionViewInstanceFV(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFV(page, new CompanionViewUiContextMockFV());
      const toasts: string[] = [];
      let immersiveEntered = 0;
      Reflect.set(page as Object, 'safeShowToast', (message: string): void => {
        toasts.push(message);
      });
      Reflect.set(page as Object, 'enterImmersiveMode', (): void => {
        immersiveEntered += 1;
      });
      page.companionSubMode = 'control';

      // Act
      const handled = page.handleCompanionBackNavigation();

      // Assert
      expect(handled).assertTrue();
      expect(immersiveEntered).assertEqual(1);
      expect(toasts.length).assertEqual(1);
    });

    it('invalid: companion_view_back_navigation_should_exit_when_no_overlay_or_control_layer_exists', 0, () => {
      // Arrange
      const vm = new CompanionViewVmMockFV();
      const page = createCompanionViewInstanceFV(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFV(page, new CompanionViewUiContextMockFV());
      page.companionSubMode = 'immersive';
      page.isShow = true;

      // Act
      const handled = page.handleCompanionBackNavigation();

      // Assert
      expect(handled).assertTrue();
      expect(page.isShow).assertFalse();
    });
  });
}
