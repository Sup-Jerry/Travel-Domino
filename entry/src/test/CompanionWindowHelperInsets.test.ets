import { describe, it, expect } from '@ohos/hypium';
import { window } from '@kit.ArkUI';
import {
  createCompanionZeroInsets,
  resolveCompanionSafeAreaInsets
} from '../main/ets/pages/components/views/companion/CompanionWindowHelper';

interface AvoidRectSeed {
  top?: number;
  bottom?: number;
  left?: number;
  right?: number;
  topRectTop?: number;
  bottomRectTop?: number;
  leftRectLeft?: number;
  rightRectLeft?: number;
}

function buildAvoidArea(seed: AvoidRectSeed): window.AvoidArea {
  return {
    topRect: {
      left: 0,
      top: seed.topRectTop ?? 0,
      width: 0,
      height: seed.top ?? 0
    },
    bottomRect: {
      left: 0,
      top: seed.bottomRectTop ?? 0,
      width: 0,
      height: seed.bottom ?? 0
    },
    leftRect: {
      left: seed.leftRectLeft ?? 0,
      top: 0,
      width: seed.left ?? 0,
      height: 0
    },
    rightRect: {
      left: seed.rightRectLeft ?? 0,
      top: 0,
      width: seed.right ?? 0,
      height: 0
    }
  } as window.AvoidArea;
}

class WindowInsetsMock {
  private readonly sysArea: window.AvoidArea;
  private readonly navArea: window.AvoidArea;
  private readonly cutoutArea: window.AvoidArea;
  private readonly shouldThrow: boolean;

  constructor(
    sysArea: window.AvoidArea,
    navArea: window.AvoidArea,
    cutoutArea: window.AvoidArea,
    shouldThrow: boolean = false
  ) {
    this.sysArea = sysArea;
    this.navArea = navArea;
    this.cutoutArea = cutoutArea;
    this.shouldThrow = shouldThrow;
  }

  getWindowAvoidArea(type: window.AvoidAreaType): window.AvoidArea {
    if (this.shouldThrow) {
      throw new Error('avoid_area_failed');
    }
    if (type === window.AvoidAreaType.TYPE_SYSTEM) {
      return this.sysArea;
    }
    if (type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
      return this.navArea;
    }
    return this.cutoutArea;
  }
}

class UiContextMock {
  private readonly divisor: number;

  constructor(divisor: number) {
    this.divisor = divisor;
  }

  px2vp(px: number): number {
    return px / this.divisor;
  }
}

export default function companionWindowHelperInsetsTest() {
  describe('unit_test_case_generator_autofill_CompanionWindowHelperInsets', () => {
    it('normal: resolve_insets_should_use_system_top_nav_bottom_and_convert_to_vp', 0, () => {
      // Arrange
      const sys = buildAvoidArea({ top: 20, left: 8, right: 6 });
      const nav = buildAvoidArea({ bottom: 16 });
      const cutout = buildAvoidArea({});
      const mainWindow = new WindowInsetsMock(sys, nav, cutout);
      const uiContext = new UiContextMock(2);

      // Act
      const insets = resolveCompanionSafeAreaInsets(mainWindow as Object as window.Window, uiContext as Object as UIContext);

      // Assert
      expect(insets.top).assertEqual(10);
      expect(insets.bottom).assertEqual(8);
      expect(insets.left).assertEqual(4);
      expect(insets.right).assertEqual(3);
    });

    it('boundary: resolve_insets_should_use_cutout_top_and_left_when_they_are_larger', 0, () => {
      // Arrange
      const sys = buildAvoidArea({ top: 12, left: 4, right: 0 });
      const nav = buildAvoidArea({ bottom: 10 });
      const cutout = buildAvoidArea({ top: 18, topRectTop: 4, left: 6, leftRectLeft: 3 });
      const mainWindow = new WindowInsetsMock(sys, nav, cutout);
      const uiContext = new UiContextMock(1);

      // Act
      const insets = resolveCompanionSafeAreaInsets(mainWindow as Object as window.Window, uiContext as Object as UIContext);

      // Assert
      expect(insets.top).assertEqual(22);
      expect(insets.left).assertEqual(9);
      expect(insets.bottom).assertEqual(10);
      expect(insets.right).assertEqual(0);
    });

    it('invalid: resolve_insets_should_throw_when_window_avoid_area_query_fails', 0, () => {
      // Arrange
      const sys = buildAvoidArea({ top: 10 });
      const nav = buildAvoidArea({ bottom: 8 });
      const cutout = buildAvoidArea({});
      const mainWindow = new WindowInsetsMock(sys, nav, cutout, true);
      const uiContext = new UiContextMock(1);
      let thrown = false;

      // Act
      try {
        resolveCompanionSafeAreaInsets(mainWindow as Object as window.Window, uiContext as Object as UIContext);
      } catch (_error) {
        thrown = true;
      }

      // Assert
      expect(thrown).assertTrue();
    });

    it('conflict: resolve_insets_should_apply_max_strategy_per_edge', 0, () => {
      // Arrange
      const sys = buildAvoidArea({ top: 24, left: 2, right: 7 });
      const nav = buildAvoidArea({ bottom: 5 });
      const cutout = buildAvoidArea({ top: 8, topRectTop: 2, left: 10, leftRectLeft: 1 });
      const mainWindow = new WindowInsetsMock(sys, nav, cutout);
      const uiContext = new UiContextMock(1);

      // Act
      const insets = resolveCompanionSafeAreaInsets(mainWindow as Object as window.Window, uiContext as Object as UIContext);

      // Assert
      expect(insets.top).assertEqual(24);
      expect(insets.left).assertEqual(11);
      expect(insets.bottom).assertEqual(5);
      expect(insets.right).assertEqual(7);
    });

    it('regression: resolve_insets_should_apply_px2vp_conversion_on_all_edges', 0, () => {
      // Arrange
      const sys = buildAvoidArea({ top: 30, left: 12, right: 6 });
      const nav = buildAvoidArea({ bottom: 18 });
      const cutout = buildAvoidArea({});
      const mainWindow = new WindowInsetsMock(sys, nav, cutout);
      const uiContext = new UiContextMock(3);

      // Act
      const insets = resolveCompanionSafeAreaInsets(mainWindow as Object as window.Window, uiContext as Object as UIContext);

      // Assert
      expect(insets.top).assertEqual(10);
      expect(insets.bottom).assertEqual(6);
      expect(insets.left).assertEqual(4);
      expect(insets.right).assertEqual(2);
    });

    it('combined: zero_insets_and_resolved_insets_should_remain_independent_objects', 0, () => {
      // Arrange
      const zeroInsets = createCompanionZeroInsets();
      const sys = buildAvoidArea({ top: 14, left: 4, right: 2 });
      const nav = buildAvoidArea({ bottom: 10 });
      const cutout = buildAvoidArea({});
      const mainWindow = new WindowInsetsMock(sys, nav, cutout);
      const uiContext = new UiContextMock(2);

      // Act
      const resolved = resolveCompanionSafeAreaInsets(mainWindow as Object as window.Window, uiContext as Object as UIContext);
      resolved.top = 99;

      // Assert
      expect(zeroInsets.top).assertEqual(0);
      expect(zeroInsets.bottom).assertEqual(0);
      expect(zeroInsets.left).assertEqual(0);
      expect(zeroInsets.right).assertEqual(0);
    });
  });
}
