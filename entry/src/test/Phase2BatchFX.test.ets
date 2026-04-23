import { describe, expect, it } from '@ohos/hypium';
import { window } from '@kit.ArkUI';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { CompanionView } from '../main/ets/pages/components/views/CompanionView';
import { IndexCompanionOverlay } from '../main/ets/pages/index/IndexCompanionOverlay';
import { CompanionContext, TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

interface CompanionViewCtorParamsFX {
  vm: Object;
  isShow: Object;
}

interface IndexCompanionOverlayParamsFX {
  vm?: TimelineViewModel;
  isVisible?: boolean;
  overlayZIndex?: number;
}

interface IndexCompanionOverlayPrivateFX {
  __vm: Object;
  __isVisible: Object;
}

interface CompanionViewUiContextFX {
  animateTo(options: Object, action: () => void): void;
  showAlertDialog(options: Object): void;
  getHostContext(): Object;
  px2vp(value: number): number;
}

interface CompanionViewPrivateFX {
  immersiveWindow?: Object;
  safeTopInset: number;
  safeBottomInset: number;
  safeLeftInset: number;
  safeRightInset: number;
  cachedVisibleScheduledEvents: EventEntity[];
  bindImmersiveWindowContext(): void;
  unbindImmersiveWindowContext(): void;
  setSystemBarVisible(isVisible: boolean): void;
  updateSafeAreaInsets(): void;
  updateSafeAreaInsetsFromWindow(mainWindow: window.Window): void;
  getVisibleTimelineEvents(): EventEntity[];
  getVisibleTimelineCount(): number;
}

class StaticPatchFX {
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

class CompanionViewHostContextMockFX {}

class CompanionViewUiContextMockFX implements CompanionViewUiContextFX {
  private readonly hostContext: Object = new CompanionViewHostContextMockFX() as Object;

  animateTo(_options: Object, action: () => void): void {
    action();
  }

  showAlertDialog(_options: Object): void {}

  getHostContext(): Object {
    return this.hostContext;
  }

  px2vp(value: number): number {
    return value;
  }
}

class CompanionViewVmMockFX {
  companionContext: CompanionContext = buildCompanionContextFX();

  getScheduleVersion(): number {
    return 1;
  }

  getOrderedScheduleEvents(): EventEntity[] {
    return [];
  }

  getCompanionContext(): CompanionContext {
    return this.companionContext;
  }
}

class RectMockFX {
  top: number;
  left: number;
  width: number;
  height: number;

  constructor(top: number, left: number, width: number, height: number) {
    this.top = top;
    this.left = left;
    this.width = width;
    this.height = height;
  }
}

class AvoidAreaMockFX {
  topRect: RectMockFX = new RectMockFX(0, 0, 0, 0);
  bottomRect: RectMockFX = new RectMockFX(0, 0, 0, 0);
  leftRect: RectMockFX = new RectMockFX(0, 0, 0, 0);
  rightRect: RectMockFX = new RectMockFX(0, 0, 0, 0);
}

class CompanionWindowMockFX {
  public offCalls: string[] = [];
  public onCalls: string[] = [];
  public systemBarCalls: Array<string[]> = [];

  off(eventName: string): void {
    this.offCalls.push(eventName);
  }

  on(eventName: string, _handler: Object): void {
    this.onCalls.push(eventName);
  }

  setWindowSystemBarEnable(types: string[]): Promise<void> {
    this.systemBarCalls.push(types);
    return Promise.resolve();
  }
}

class InsetsWindowMockFX extends CompanionWindowMockFX {
  getWindowAvoidArea(type: number): AvoidAreaMockFX {
    const area = new AvoidAreaMockFX();
    if (type === window.AvoidAreaType.TYPE_SYSTEM) {
      area.topRect = new RectMockFX(0, 0, 0, 40);
      area.leftRect = new RectMockFX(0, 0, 12, 0);
      area.rightRect = new RectMockFX(0, 0, 8, 0);
      return area;
    }
    if (type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
      area.bottomRect = new RectMockFX(0, 0, 0, 30);
      return area;
    }
    return area;
  }
}

class ThrowingInsetsWindowMockFX extends CompanionWindowMockFX {
  getWindowAvoidArea(_type: number): AvoidAreaMockFX {
    throw new Error('avoid_area_failed_fx');
  }
}

function buildCompanionContextFX(): CompanionContext {
  const context = {} as CompanionContext;
  context.runtimeState = 'IDLE';
  context.currentEvent = null;
  context.nextEvent = null;
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

function buildCompanionEventFX(id: number, name: string): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.status = 1;
  event.completion_status = EventEntity.STATE_PENDING;
  return event;
}

function createCompanionViewInstanceFX(vm: TimelineViewModel, isShow: boolean = true): CompanionViewPrivateFX {
  const overlayParams: IndexCompanionOverlayParamsFX = {
    vm,
    isVisible: isShow,
    overlayZIndex: 10
  };
  const overlay = new IndexCompanionOverlay(
    undefined,
    overlayParams as Object as LocalStorage
  ) as Object as IndexCompanionOverlayPrivateFX;
  const companionParams: CompanionViewCtorParamsFX = {
    vm: overlay.__vm,
    isShow: overlay.__isVisible
  };
  return new CompanionView(
    overlay as Object,
    companionParams as Object as LocalStorage
  ) as Object as CompanionViewPrivateFX;
}

function setCompanionViewUiContextFX(page: CompanionViewPrivateFX, uiContext: CompanionViewUiContextFX): void {
  Reflect.set(page as Object, 'getUIContext', (): CompanionViewUiContextFX => uiContext);
}

async function flushMicrotasksFX(): Promise<void> {
  await Promise.resolve();
  await Promise.resolve();
}

export default function phase2BatchFXTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchFX_companion_view_window_methods', () => {
    it('normal: companion_view_bind_window_context_should_keep_state_stable_when_runtime_window_is_unavailable', 0, async () => {
      // Arrange
      const vm = new CompanionViewVmMockFX();
      const page = createCompanionViewInstanceFX(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFX(page, new CompanionViewUiContextMockFX());
      page.safeTopInset = 5;
      page.safeBottomInset = 4;
      page.safeLeftInset = 3;
      page.safeRightInset = 2;

      // Act
      page.bindImmersiveWindowContext();
      await flushMicrotasksFX();

      // Assert
      expect(page.immersiveWindow === undefined).assertTrue();
      expect(page.safeTopInset).assertEqual(5);
      expect(page.safeBottomInset).assertEqual(4);
      expect(page.safeLeftInset).assertEqual(3);
      expect(page.safeRightInset).assertEqual(2);
    });

    it('boundary: companion_view_unbind_window_context_should_clear_cached_window_and_listeners', 0, () => {
      // Arrange
      const vm = new CompanionViewVmMockFX();
      const page = createCompanionViewInstanceFX(vm as Object as TimelineViewModel);
      const mainWindow = new CompanionWindowMockFX();
      page.immersiveWindow = mainWindow as Object;

      // Act
      page.unbindImmersiveWindowContext();

      // Assert
      expect(mainWindow.offCalls.length).assertEqual(2);
      expect(mainWindow.offCalls[0]).assertEqual('avoidAreaChange');
      expect(mainWindow.offCalls[1]).assertEqual('windowSizeChange');
      expect(page.immersiveWindow === undefined).assertTrue();
    });

    it('invalid: companion_view_update_safe_area_from_window_should_fallback_to_zero_when_native_read_throws', 0, () => {
      // Arrange
      const vm = new CompanionViewVmMockFX();
      const page = createCompanionViewInstanceFX(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFX(page, new CompanionViewUiContextMockFX());
      page.safeTopInset = 9;
      page.safeBottomInset = 8;
      page.safeLeftInset = 7;
      page.safeRightInset = 6;
      const mainWindow = new ThrowingInsetsWindowMockFX();

      // Act
      page.updateSafeAreaInsetsFromWindow(mainWindow as Object as window.Window);

      // Assert
      expect(page.safeTopInset).assertEqual(0);
      expect(page.safeBottomInset).assertEqual(0);
      expect(page.safeLeftInset).assertEqual(0);
      expect(page.safeRightInset).assertEqual(0);
    });

    it('conflict: companion_view_set_system_bar_visible_should_apply_to_cached_window', 0, async () => {
      // Arrange
      const vm = new CompanionViewVmMockFX();
      const page = createCompanionViewInstanceFX(vm as Object as TimelineViewModel);
      const mainWindow = new CompanionWindowMockFX();
      page.immersiveWindow = mainWindow as Object;

      // Act
      page.setSystemBarVisible(false);
      await flushMicrotasksFX();

      // Assert
      expect(mainWindow.systemBarCalls.length).assertEqual(1);
      expect(mainWindow.systemBarCalls[0].length).assertEqual(0);
    });

    it('regression: companion_view_update_safe_area_should_delegate_to_cached_window_before_requerying', 0, () => {
      // Arrange
      const vm = new CompanionViewVmMockFX();
      const page = createCompanionViewInstanceFX(vm as Object as TimelineViewModel);
      const mainWindow = new CompanionWindowMockFX();
      page.immersiveWindow = mainWindow as Object;
      let updateWindow: Object | undefined = undefined;
      Reflect.set(page as Object, 'updateSafeAreaInsetsFromWindow', (value: Object): void => {
        updateWindow = value;
      });

      // Act
      page.updateSafeAreaInsets();

      // Assert
      expect(updateWindow === (mainWindow as Object)).assertTrue();
    });

    it('regression: companion_view_update_safe_area_from_window_should_apply_resolved_insets', 0, () => {
      // Arrange
      const vm = new CompanionViewVmMockFX();
      const page = createCompanionViewInstanceFX(vm as Object as TimelineViewModel);
      setCompanionViewUiContextFX(page, new CompanionViewUiContextMockFX());
      const mainWindow = new InsetsWindowMockFX();

      // Act
      page.updateSafeAreaInsetsFromWindow(mainWindow as Object as window.Window);

      // Assert
      expect(page.safeTopInset).assertEqual(40);
      expect(page.safeBottomInset).assertEqual(30);
      expect(page.safeLeftInset).assertEqual(12);
      expect(page.safeRightInset).assertEqual(8);
    });

    it('combined: companion_view_visible_timeline_helpers_should_return_same_events_and_count', 0, () => {
      // Arrange
      const vm = new CompanionViewVmMockFX();
      const page = createCompanionViewInstanceFX(vm as Object as TimelineViewModel);
      const first = buildCompanionEventFX(71, 'museum');
      const second = buildCompanionEventFX(72, 'cafe');
      page.cachedVisibleScheduledEvents = [first, second];
      Reflect.set(page as Object, 'ensureScheduleCacheUpToDate', (): void => {});

      // Act
      const visibleEvents = page.getVisibleTimelineEvents();
      const visibleCount = page.getVisibleTimelineCount();

      // Assert
      expect(visibleEvents.length).assertEqual(2);
      expect(visibleEvents[0].id).assertEqual(71);
      expect(visibleEvents[1].id).assertEqual(72);
      expect(visibleCount).assertEqual(2);
    });
  });
}
