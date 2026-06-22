import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { CompanionView } from '../main/ets/pages/components/views/CompanionView';
import { IndexCompanionOverlay } from '../main/ets/pages/index/IndexCompanionOverlay';
import { CompanionContext, TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

interface CompanionViewCtorParamsFZ {
  vm: Object;
  isShow: Object;
}

interface IndexCompanionOverlayParamsFZ {
  vm?: TimelineViewModel;
  isVisible?: boolean;
  overlayZIndex?: number;
}

interface IndexCompanionOverlayPrivateFZ {
  __vm: Object;
  __isVisible: Object;
}

interface CompanionViewUiContextFZ {
  animateTo(options: Object, action: () => void): void;
  showAlertDialog(options: Object): void;
  getHostContext(): Object;
}

interface StartConflictInfoFZ {
  name: string;
}

interface CompanionViewPrivateFZ {
  context: CompanionContext;
  safeShowToast(message: string): void;
  refreshContext(): void;
  showGlobalActiveConflictDialog(excludeEventId: number): Promise<boolean>;
  startNavigation(target?: EventEntity): void;
  handleFocusedAdjust(event?: EventEntity): void;
  openRecordCorrectionDialog(event: EventEntity): void;
}

class CompanionViewHostContextMockFZ {}

class CompanionViewUiContextMockFZ implements CompanionViewUiContextFZ {
  private readonly hostContext: Object = new CompanionViewHostContextMockFZ() as Object;

  animateTo(_options: Object, action: () => void): void {
    action();
  }

  showAlertDialog(_options: Object): void {}

  getHostContext(): Object {
    return this.hostContext;
  }
}

class CompanionViewVmMockFZ {
  scheduleVersion: number = 1;
  orderedEvents: EventEntity[] = [];
  companionContext: CompanionContext = buildCompanionContextFZ('IDLE', null, null);
  conflictName: string | null = null;

  getScheduleVersion(): number {
    return this.scheduleVersion;
  }

  getOrderedScheduleEvents(): EventEntity[] {
    return this.orderedEvents;
  }

  getCompanionContext(): CompanionContext {
    return this.companionContext;
  }

  async getStartConflictInfo(_excludeEventId: number): Promise<StartConflictInfoFZ | null> {
    if (!this.conflictName) {
      return null;
    }
    const conflict = {} as StartConflictInfoFZ;
    conflict.name = this.conflictName;
    return conflict;
  }
}

function buildCompanionEventFZ(id: number, name: string, latitude: number = 0, longitude: number = 0): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.status = 1;
  event.completion_status = EventEntity.STATE_PENDING;
  event.latitude = latitude;
  event.longitude = longitude;
  return event;
}

function buildCompanionContextFZ(
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

function createCompanionViewInstanceFZ(vm: TimelineViewModel, isShow: boolean = true): CompanionViewPrivateFZ {
  const overlayParams: IndexCompanionOverlayParamsFZ = {
    vm,
    isVisible: isShow,
    overlayZIndex: 10
  };
  const overlay = new IndexCompanionOverlay(
    undefined,
    overlayParams as Object as LocalStorage
  ) as Object as IndexCompanionOverlayPrivateFZ;
  const companionParams: CompanionViewCtorParamsFZ = {
    vm: overlay.__vm,
    isShow: overlay.__isVisible
  };
  return new CompanionView(
    overlay as Object,
    companionParams as Object as LocalStorage
  ) as Object as CompanionViewPrivateFZ;
}

function setCompanionViewUiContextFZ(page: CompanionViewPrivateFZ, uiContext: CompanionViewUiContextFZ): void {
  Reflect.set(page as Object, 'getUIContext', (): CompanionViewUiContextFZ => uiContext);
}

export default function phase2BatchFZTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchFZ_companion_view_action_methods', () => {
    it('normal: companion_view_conflict_dialog_should_delegate_name_when_repository_returns_conflict', 0, async () => {
      // Arrange
      const focused = buildCompanionEventFZ(121, 'focused');
      const vm = new CompanionViewVmMockFZ();
      vm.orderedEvents = [focused];
      vm.companionContext = buildCompanionContextFZ('READY', null, focused);
      vm.conflictName = 'running_place_fz';
      const page = createCompanionViewInstanceFZ(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFZ(page, new CompanionViewUiContextMockFZ());
      let shownName = '';
      Reflect.set(page as Object, 'showActiveConflictDialog', (name: string): void => {
        shownName = name;
      });

      // Act
      const shown = await page.showGlobalActiveConflictDialog(focused.id);

      // Assert
      expect(shown).assertTrue();
      expect(shownName).assertEqual('running_place_fz');
    });

    it('boundary: companion_view_navigation_should_toast_when_no_target_is_available', 0, () => {
      // Arrange
      const vm = new CompanionViewVmMockFZ();
      vm.companionContext = buildCompanionContextFZ('IDLE', null, null);
      const page = createCompanionViewInstanceFZ(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFZ(page, new CompanionViewUiContextMockFZ());
      const toasts: string[] = [];
      Reflect.set(page as Object, 'safeShowToast', (message: string): void => {
        toasts.push(message);
      });
      Reflect.set(page as Object, 'getFocusedEvent', (): EventEntity | null => null);

      // Act
      page.startNavigation();

      // Assert
      expect(toasts.length).assertEqual(1);
      expect(toasts[0]).assertEqual('暂无可导航目的地');
    });

    it('invalid: companion_view_navigation_should_toast_when_target_coordinates_are_missing', 0, () => {
      // Arrange
      const vm = new CompanionViewVmMockFZ();
      const target = buildCompanionEventFZ(122, 'target_without_coord');
      vm.companionContext = buildCompanionContextFZ('READY', null, target);
      const page = createCompanionViewInstanceFZ(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFZ(page, new CompanionViewUiContextMockFZ());
      const toasts: string[] = [];
      Reflect.set(page as Object, 'safeShowToast', (message: string): void => {
        toasts.push(message);
      });

      // Act
      page.startNavigation(target);

      // Assert
      expect(toasts.length).assertEqual(1);
      expect(toasts[0]).assertEqual('[target_without_coord] 缺少有效坐标');
    });

    it('conflict: companion_view_adjust_should_fallback_to_focused_event_before_opening_dialog', 0, () => {
      // Arrange
      const focused = buildCompanionEventFZ(123, 'focused_adjust');
      const vm = new CompanionViewVmMockFZ();
      vm.orderedEvents = [focused];
      vm.companionContext = buildCompanionContextFZ('READY', null, focused);
      const page = createCompanionViewInstanceFZ(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFZ(page, new CompanionViewUiContextMockFZ());
      let openedId = -1;
      Reflect.set(page as Object, 'getFocusedEvent', (): EventEntity | null => focused);
      Reflect.set(page as Object, 'openRecordCorrectionDialog', (event: EventEntity): void => {
        openedId = event.id;
      });

      // Act
      page.handleFocusedAdjust();

      // Assert
      expect(openedId).assertEqual(123);
    });

    it('regression: companion_view_adjust_should_toast_when_neither_argument_nor_focus_exists', 0, () => {
      // Arrange
      const vm = new CompanionViewVmMockFZ();
      const page = createCompanionViewInstanceFZ(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFZ(page, new CompanionViewUiContextMockFZ());
      const toasts: string[] = [];
      Reflect.set(page as Object, 'getFocusedEvent', (): EventEntity | null => null);
      Reflect.set(page as Object, 'safeShowToast', (message: string): void => {
        toasts.push(message);
      });

      // Act
      page.handleFocusedAdjust();

      // Assert
      expect(toasts.length).assertEqual(1);
      expect(toasts[0]).assertEqual('暂无可补打卡的地点');
    });

    it('combined: companion_view_record_dialog_should_toast_when_target_event_is_missing', 0, () => {
      // Arrange
      const missing = buildCompanionEventFZ(124, 'missing_dialog_target');
      const existing = buildCompanionEventFZ(125, 'existing_dialog_target');
      const vm = new CompanionViewVmMockFZ();
      vm.orderedEvents = [existing];
      vm.companionContext = buildCompanionContextFZ('READY', null, existing);
      const page = createCompanionViewInstanceFZ(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFZ(page, new CompanionViewUiContextMockFZ());
      const toasts: string[] = [];
      Reflect.set(page as Object, 'safeShowToast', (message: string): void => {
        toasts.push(message);
      });

      // Act
      page.openRecordCorrectionDialog(missing);

      // Assert
      expect(toasts.length).assertEqual(1);
      expect(toasts[0]).assertEqual('地点不存在或已删除');
    });
  });
}
