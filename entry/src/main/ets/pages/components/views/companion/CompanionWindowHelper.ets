import { display, window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';

export interface CompanionSafeAreaInsets {
  top: number;
  bottom: number;
  left: number;
  right: number;
}

export function createCompanionZeroInsets(): CompanionSafeAreaInsets {
  return { top: 0, bottom: 0, left: 0, right: 0 };
}

export function resolveCompanionSafeAreaInsets(mainWindow: window.Window, uiContext: UIContext): CompanionSafeAreaInsets {
  const sysArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
  const navArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
  const cutoutArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
  const displayInfo = display.getDefaultDisplaySync();

  const cutoutTopPx = cutoutArea.topRect.height > 0 ? cutoutArea.topRect.top + cutoutArea.topRect.height : 0;
  const cutoutBottomPx = cutoutArea.bottomRect.height > 0 ? displayInfo.height - cutoutArea.bottomRect.top : 0;
  const cutoutLeftPx = cutoutArea.leftRect.width > 0 ? cutoutArea.leftRect.left + cutoutArea.leftRect.width : 0;
  const cutoutRightPx = cutoutArea.rightRect.width > 0 ? displayInfo.width - cutoutArea.rightRect.left : 0;

  const safeTopPx = Math.max(sysArea.topRect.height, cutoutTopPx);
  const safeBottomPx = Math.max(navArea.bottomRect.height, cutoutBottomPx);
  const safeLeftPx = Math.max(sysArea.leftRect.width, cutoutLeftPx);
  const safeRightPx = Math.max(sysArea.rightRect.width, cutoutRightPx);

  return {
    top: uiContext.px2vp(safeTopPx),
    bottom: uiContext.px2vp(safeBottomPx),
    left: uiContext.px2vp(safeLeftPx),
    right: uiContext.px2vp(safeRightPx)
  };
}

export function applyCompanionSystemBarVisible(targetWindow: window.Window, isVisible: boolean): void {
  targetWindow.setWindowSystemBarEnable(isVisible ? ['status', 'navigation'] : []).catch((_error: BusinessError) => {
    // Ignore recoverable UI chrome updates.
  });
}
