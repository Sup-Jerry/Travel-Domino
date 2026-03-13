// 文件路径: ets/common/utils/NavigationHelper.ets

import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { UIContext } from '@ohos.arkui.UIContext';

interface RouterPageOptions {
  url: string;
  params?: Object;
}

interface ToastOptions {
  message: string;
}

export class NavigationHelper {
  private static safeShowToast(uiContext: UIContext | undefined, message: string): void {
    try {
      if (uiContext) {
        const options: ToastOptions = { message: message };
        void uiContext.getPromptAction().openToast(options);
      }
    } catch (error) {
      console.error(`showToast failed: ${JSON.stringify(error)}`);
    }
  }

  /**
   * 拉起系统导航面板 (策略B: 端水大师)
   * @param context 当前 UI 的 context
   * @param destName 目的地名称
   * @param destLat 目的地纬度 (GCJ-02坐标系)
   * @param destLng 目的地经度 (GCJ-02坐标系)
   */
  public static startNavigation(context: common.UIAbilityContext, destName: string, destLat: number, destLng: number) {
    // 构建导航参数
    let wantParam: Record<string, Object> = {
      'sceneType': 1, // 1 表示路线规划 (RoutePlan)，2 表示直接导航 (Navigation)
      'destinationName': destName,
      'destinationLatitude': destLat,
      'destinationLongitude': destLng,
      // 不传 startLatitude 和 startLongitude，系统默认使用当前 GPS 真实位置 (场景A)
    };

    let abilityStartCallback: common.AbilityStartCallback = {
      onError: (code: number, name: string, message: string) => {
        console.error(`导航面板拉起失败: code ${code}, name: ${name}, message: ${message}`);
        NavigationHelper.safeShowToast(undefined, '拉起导航失败，请检查是否安装地图应用');
      }
    };

    // 核心调用：拉起 "navigation" 类型的垂直面板
    context.startAbilityByType("navigation", wantParam, abilityStartCallback)
      .then(() => {
        console.info('成功拉起系统导航面板');
      })
      .catch((err: BusinessError) => {
        console.error(`startAbilityByType 失败, 错误: ${JSON.stringify(err)}`);
        NavigationHelper.safeShowToast(undefined, '当前设备不支持系统级导航面板');
      });
  }

  public static async backOrFallbackToPlanList(uiContext: UIContext, params?: Object): Promise<void> {
    const routerProxy = uiContext.getRouter();
    const stackLength = Number(routerProxy.getLength());
    if (Number.isFinite(stackLength) && stackLength > 1) {
      routerProxy.back();
      return;
    }

    const fallbackOptions: RouterPageOptions = { url: 'pages/PlanListPage' };
    if (params !== undefined) {
      fallbackOptions.params = params;
    }

    try {
      await routerProxy.replaceUrl(fallbackOptions);
    } catch (_replaceError) {
      try {
        await routerProxy.pushUrl(fallbackOptions);
        NavigationHelper.safeShowToast(uiContext, '无上级页面，已返回计划列表');
      } catch (_pushError) {
        NavigationHelper.safeShowToast(uiContext, '返回失败，请手动回到计划列表');
      }
    }
  }
}

