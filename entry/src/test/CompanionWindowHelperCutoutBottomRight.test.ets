import { describe, it, expect } from '@ohos/hypium';
import { display, window } from '@kit.ArkUI';
import { resolveCompanionSafeAreaInsets } from '../main/ets/pages/components/views/companion/CompanionWindowHelper';

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

  constructor(sysArea: window.AvoidArea, navArea: window.AvoidArea, cutoutArea: window.AvoidArea) {
    this.sysArea = sysArea;
    this.navArea = navArea;
    this.cutoutArea = cutoutArea;
  }

  getWindowAvoidArea(type: window.AvoidAreaType): window.AvoidArea {
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

export default function companionWindowHelperCutoutBottomRightTest() {
  describe('unit_test_case_generator_autofill_CompanionWindowHelperCutoutBottomRight', () => {
    it('normal: resolve_insets_should_use_bottom_and_right_cutout_when_they_exceed_nav_and_system', 0, () => {
      // Arrange
      const info = display.getDefaultDisplaySync();
      const bottomTop = -18;
      const rightLeft = -12;
      const expectedBottomPx = info.height - bottomTop;
      const expectedRightPx = info.width - rightLeft;
      const sys = buildAvoidArea({ right: 6 });
      const nav = buildAvoidArea({ bottom: 12 });
      const cutout = buildAvoidArea({ bottom: 1, bottomRectTop: bottomTop, right: 1, rightRectLeft: rightLeft });
      const mainWindow = new WindowInsetsMock(sys, nav, cutout);
      const uiContext = new UiContextMock(2);

      // Act
      const insets = resolveCompanionSafeAreaInsets(mainWindow as Object as window.Window, uiContext as Object as UIContext);

      // Assert
      expect(insets.bottom).assertEqual(expectedBottomPx / 2);
      expect(insets.right).assertEqual(expectedRightPx / 2);
    });

    it('boundary: resolve_insets_should_ignore_bottom_and_right_cutout_when_rect_size_is_zero', 0, () => {
      // Arrange
      const info = display.getDefaultDisplaySync();
      const sys = buildAvoidArea({ right: 14 });
      const nav = buildAvoidArea({ bottom: 18 });
      const cutout = buildAvoidArea({ bottom: 0, bottomRectTop: Math.max(0, info.height - 80), right: 0, rightRectLeft: Math.max(0, info.width - 60) });
      const mainWindow = new WindowInsetsMock(sys, nav, cutout);
      const uiContext = new UiContextMock(2);

      // Act
      const insets = resolveCompanionSafeAreaInsets(mainWindow as Object as window.Window, uiContext as Object as UIContext);

      // Assert
      expect(insets.bottom).assertEqual(9);
      expect(insets.right).assertEqual(7);
    });

    it('invalid: resolve_insets_should_not_use_negative_cutout_bottom_or_right_values', 0, () => {
      // Arrange
      const info = display.getDefaultDisplaySync();
      const sys = buildAvoidArea({ right: 10 });
      const nav = buildAvoidArea({ bottom: 16 });
      const cutout = buildAvoidArea({ bottom: 1, bottomRectTop: info.height + 20, right: 1, rightRectLeft: info.width + 10 });
      const mainWindow = new WindowInsetsMock(sys, nav, cutout);
      const uiContext = new UiContextMock(2);

      // Act
      const insets = resolveCompanionSafeAreaInsets(mainWindow as Object as window.Window, uiContext as Object as UIContext);

      // Assert
      expect(insets.bottom).assertEqual(8);
      expect(insets.right).assertEqual(5);
    });

    it('conflict: resolve_insets_should_apply_independent_max_for_bottom_and_right_edges', 0, () => {
      // Arrange
      const info = display.getDefaultDisplaySync();
      const bottomTop = -24;
      const rightLeft = -5;
      const expectedBottomPx = info.height - bottomTop;
      const expectedRightPx = Math.max(14, info.width - rightLeft);
      const sys = buildAvoidArea({ right: 14 });
      const nav = buildAvoidArea({ bottom: 12 });
      const cutout = buildAvoidArea({ bottom: 1, bottomRectTop: bottomTop, right: 1, rightRectLeft: rightLeft });
      const mainWindow = new WindowInsetsMock(sys, nav, cutout);
      const uiContext = new UiContextMock(1);

      // Act
      const insets = resolveCompanionSafeAreaInsets(mainWindow as Object as window.Window, uiContext as Object as UIContext);

      // Assert
      expect(insets.bottom).assertEqual(expectedBottomPx);
      expect(insets.right).assertEqual(expectedRightPx);
    });

    it('regression: resolve_insets_should_depend_on_bottom_top_and_right_left_not_cutout_width_or_height_values', 0, () => {
      // Arrange
      const info = display.getDefaultDisplaySync();
      const bottomTop = Math.max(0, info.height - 24);
      const rightLeft = Math.max(0, info.width - 16);
      const sys = buildAvoidArea({ right: 4 });
      const nav = buildAvoidArea({ bottom: 6 });
      const cutoutNarrow = buildAvoidArea({ bottom: 1, bottomRectTop: bottomTop, right: 1, rightRectLeft: rightLeft });
      const cutoutWide = buildAvoidArea({ bottom: 100, bottomRectTop: bottomTop, right: 200, rightRectLeft: rightLeft });
      const windowNarrow = new WindowInsetsMock(sys, nav, cutoutNarrow);
      const windowWide = new WindowInsetsMock(sys, nav, cutoutWide);
      const uiContext = new UiContextMock(2);

      // Act
      const narrowInsets = resolveCompanionSafeAreaInsets(windowNarrow as Object as window.Window, uiContext as Object as UIContext);
      const wideInsets = resolveCompanionSafeAreaInsets(windowWide as Object as window.Window, uiContext as Object as UIContext);

      // Assert
      expect(narrowInsets.bottom).assertEqual(wideInsets.bottom);
      expect(narrowInsets.right).assertEqual(wideInsets.right);
    });

    it('combined: resolve_insets_should_handle_cutout_bottom_right_and_system_top_left_together', 0, () => {
      // Arrange
      const info = display.getDefaultDisplaySync();
      const bottomTop = Math.max(0, info.height - 22);
      const rightLeft = Math.max(0, info.width - 18);
      const sys = buildAvoidArea({ top: 16, left: 10, right: 6 });
      const nav = buildAvoidArea({ bottom: 8 });
      const cutout = buildAvoidArea({
        top: 6,
        topRectTop: 3,
        left: 4,
        leftRectLeft: 2,
        bottom: 1,
        bottomRectTop: bottomTop,
        right: 1,
        rightRectLeft: rightLeft
      });
      const mainWindow = new WindowInsetsMock(sys, nav, cutout);
      const uiContext = new UiContextMock(2);

      // Act
      const insets = resolveCompanionSafeAreaInsets(mainWindow as Object as window.Window, uiContext as Object as UIContext);

      // Assert
      expect(insets.top).assertEqual(8);
      expect(insets.left).assertEqual(5);
      expect(insets.bottom > 0).assertTrue();
      expect(insets.right > 0).assertTrue();
    });
  });
}
