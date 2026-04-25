import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { CompanionView } from '../main/ets/pages/components/views/CompanionView';
import { IndexCompanionOverlay } from '../main/ets/pages/index/IndexCompanionOverlay';
import { CompanionContext, TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

interface CompanionViewCtorParamsFU {
  vm: Object;
  isShow: Object;
}

interface IndexCompanionOverlayParamsFU {
  vm?: TimelineViewModel;
  isVisible?: boolean;
  overlayZIndex?: number;
}

interface IndexCompanionOverlayPrivateFU {
  __vm: Object;
  __isVisible: Object;
}

interface CompanionViewUiContextFU {
  animateTo(options: Object, action: () => void): void;
  showAlertDialog(options: Object): void;
  getHostContext(): Object;
}

interface CompanionViewPrivateFU {
  focusedEventId: number;
  focusedIndex: number;
  cardDisplayEventId: number;
  outgoingCardEventId: number;
  incomingCardEventId: number;
  isCardSwitching: boolean;
  cardSwitchProgress: number;
  companionFilterState: string;
  searchKeyword: string;
  searchResults: EventEntity[];
  cachedScheduledEvents: EventEntity[];
  cachedVisibleScheduledEvents: EventEntity[];
  refreshContext(): void;
  refreshSearchResults(): void;
  getEventById(id: number): EventEntity | null;
  getScheduleIndexById(id: number): number;
  pickDefaultFocusId(): number;
  ensureFocusReady(): void;
  getFocusedEvent(): EventEntity | null;
  canRenderSwitchCards(): boolean;
  getDisplayCardEvent(): EventEntity | null;
  ensureFocusVisible(): void;
}

class CompanionViewHostContextMockFU {}

class CompanionViewUiContextMockFU implements CompanionViewUiContextFU {
  private readonly hostContext: Object = new CompanionViewHostContextMockFU() as Object;

  animateTo(_options: Object, action: () => void): void {
    action();
  }

  showAlertDialog(_options: Object): void {}

  getHostContext(): Object {
    return this.hostContext;
  }
}

class CompanionViewVmMockFU {
  scheduleVersion: number = 1;
  orderedEvents: EventEntity[] = [];
  companionContext: CompanionContext = buildCompanionContextFU('IDLE', null, null);

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

function buildCompanionEventFU(id: number, name: string, address: string = ''): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.address = address;
  event.status = 1;
  event.completion_status = EventEntity.STATE_PENDING;
  event.actual_start_time = 0;
  event.actual_end_time = 0;
  return event;
}

function buildCompanionContextFU(
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

function createCompanionViewInstanceFU(vm: TimelineViewModel, isShow: boolean = true): CompanionViewPrivateFU {
  const overlayParams: IndexCompanionOverlayParamsFU = {
    vm,
    isVisible: isShow,
    overlayZIndex: 10
  };
  const overlay = new IndexCompanionOverlay(
    undefined,
    overlayParams as Object as LocalStorage
  ) as Object as IndexCompanionOverlayPrivateFU;
  const companionParams: CompanionViewCtorParamsFU = {
    vm: overlay.__vm,
    isShow: overlay.__isVisible
  };
  return new CompanionView(
    overlay as Object,
    companionParams as Object as LocalStorage
  ) as Object as CompanionViewPrivateFU;
}

function setCompanionViewUiContextFU(page: CompanionViewPrivateFU, uiContext: CompanionViewUiContextFU): void {
  Reflect.set(page as Object, 'getUIContext', (): CompanionViewUiContextFU => uiContext);
}

export default function phase2BatchFUTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchFU_companion_view_cache_and_focus_methods', () => {
    it('normal: companion_view_cache_methods_should_refresh_search_results_and_lookup_by_id', 0, () => {
      // Arrange
      const museum = buildCompanionEventFU(1, 'Museum', 'Center Road');
      const cafe = buildCompanionEventFU(2, 'Cafe', 'Lake Road');
      const vm = new CompanionViewVmMockFU();
      vm.orderedEvents = [museum, cafe];
      vm.companionContext = buildCompanionContextFU('READY', null, cafe);
      const page = createCompanionViewInstanceFU(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFU(page, new CompanionViewUiContextMockFU());
      page.refreshContext();
      page.searchKeyword = 'lake';

      // Act
      page.refreshSearchResults();
      const found = page.getEventById(cafe.id);
      const missing = page.getEventById(999);
      const index = page.getScheduleIndexById(cafe.id);
      const missingIndex = page.getScheduleIndexById(999);

      // Assert
      expect(page.searchResults.length).assertEqual(1);
      expect(page.searchResults[0].id).assertEqual(cafe.id);
      expect(found?.id ?? -1).assertEqual(cafe.id);
      expect(missing).assertNull();
      expect(index).assertEqual(1);
      expect(missingIndex).assertEqual(-1);
    });

    it('boundary: companion_view_focus_ready_should_reset_all_card_state_when_schedule_is_empty', 0, () => {
      // Arrange
      const vm = new CompanionViewVmMockFU();
      vm.orderedEvents = [];
      vm.companionContext = buildCompanionContextFU('IDLE', null, null);
      const page = createCompanionViewInstanceFU(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFU(page, new CompanionViewUiContextMockFU());
      page.focusedEventId = 12;
      page.focusedIndex = 3;
      page.cardDisplayEventId = 44;
      page.outgoingCardEventId = 55;
      page.incomingCardEventId = 66;
      page.isCardSwitching = true;
      page.cardSwitchProgress = 0;

      // Act
      page.ensureFocusReady();

      // Assert
      expect(page.focusedEventId).assertEqual(-1);
      expect(page.focusedIndex).assertEqual(-1);
      expect(page.cardDisplayEventId).assertEqual(-1);
      expect(page.outgoingCardEventId).assertEqual(-1);
      expect(page.incomingCardEventId).assertEqual(-1);
      expect(page.isCardSwitching).assertFalse();
      expect(page.cardSwitchProgress).assertEqual(1);
    });

    it('invalid: companion_view_focus_methods_should_fallback_when_focused_or_display_event_is_missing', 0, () => {
      // Arrange
      const active = buildCompanionEventFU(11, 'Active');
      active.actual_start_time = Date.now() - 1000;
      const next = buildCompanionEventFU(12, 'Next');
      const vm = new CompanionViewVmMockFU();
      vm.orderedEvents = [active, next];
      vm.companionContext = buildCompanionContextFU('ACTIVE', active, next);
      const page = createCompanionViewInstanceFU(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFU(page, new CompanionViewUiContextMockFU());
      page.focusedEventId = 999;
      page.cardDisplayEventId = 998;
      page.refreshContext();

      // Act
      const focused = page.getFocusedEvent();
      const display = page.getDisplayCardEvent();
      const defaultFocusId = page.pickDefaultFocusId();

      // Assert
      expect(defaultFocusId).assertEqual(active.id);
      expect(page.focusedEventId).assertEqual(active.id);
      expect(page.focusedIndex).assertEqual(0);
      expect(focused?.id ?? -1).assertEqual(active.id);
      expect(display?.id ?? -1).assertEqual(active.id);
    });

    it('regression: companion_view_switch_card_guard_should_require_both_existing_card_ids', 0, () => {
      // Arrange
      const first = buildCompanionEventFU(21, 'First');
      const second = buildCompanionEventFU(22, 'Second');
      const vm = new CompanionViewVmMockFU();
      vm.orderedEvents = [first, second];
      vm.companionContext = buildCompanionContextFU('READY', null, first);
      const page = createCompanionViewInstanceFU(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFU(page, new CompanionViewUiContextMockFU());
      page.refreshContext();
      page.isCardSwitching = true;
      page.outgoingCardEventId = first.id;
      page.incomingCardEventId = second.id;
      const validSwitch = page.canRenderSwitchCards();
      page.incomingCardEventId = 999;

      // Act
      const invalidSwitch = page.canRenderSwitchCards();

      // Assert
      expect(validSwitch).assertTrue();
      expect(invalidSwitch).assertFalse();
    });

    it('combined: companion_view_visible_focus_should_retarget_hidden_focus_to_first_visible_event', 0, () => {
      // Arrange
      const hidden = buildCompanionEventFU(31, 'Hidden');
      const visible = buildCompanionEventFU(32, 'Visible');
      const vm = new CompanionViewVmMockFU();
      vm.orderedEvents = [hidden, visible];
      vm.companionContext = buildCompanionContextFU('READY', null, visible);
      const page = createCompanionViewInstanceFU(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFU(page, new CompanionViewUiContextMockFU());
      page.focusedEventId = hidden.id;
      const retargets: number[] = [];
      Reflect.set(page as Object, 'getVisibleScheduledEvents', (): EventEntity[] => [visible]);
      Reflect.set(page as Object, 'applyFocusById', (targetId: number, _source: string): void => {
        retargets.push(targetId);
      });

      // Act
      page.ensureFocusVisible();

      // Assert
      expect(retargets.length).assertEqual(1);
      expect(retargets[0]).assertEqual(visible.id);
    });
  });
}
