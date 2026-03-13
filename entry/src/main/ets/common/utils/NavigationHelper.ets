// 文件路径: ets/common/utils/NavigationHelper.ets

import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { promptAction, router } from '@kit.ArkUI';

interface RouterPageOptions {
  url: string;
  params?: Object;
}

export class NavigationHelper {

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
        promptAction.showToast({ message: '拉起导航失败，请检查是否安装地图应用' });
      }
    };

    // 核心调用：拉起 "navigation" 类型的垂直面板
    context.startAbilityByType("navigation", wantParam, abilityStartCallback)
      .then(() => {
        console.info('成功拉起系统导航面板');
      })
      .catch((err: BusinessError) => {
        console.error(`startAbilityByType 失败, 错误: ${JSON.stringify(err)}`);
        promptAction.showToast({ message: '当前设备不支持系统级导航面板' });
      });
  }

  public static async backOrFallbackToPlanList(params?: Object): Promise<void> {
    const stackLength = Number(router.getLength());
    if (Number.isFinite(stackLength) && stackLength > 1) {
      router.back();
      return;
    }

    const fallbackOptions: RouterPageOptions = { url: 'pages/PlanListPage' };
    if (params !== undefined) {
      fallbackOptions.params = params;
    }

    try {
      await router.replaceUrl(fallbackOptions);
    } catch (_replaceError) {
      try {
        await router.pushUrl(fallbackOptions);
        promptAction.showToast({ message: '无上级页面，已返回计划列表' });
      } catch (_pushError) {
        promptAction.showToast({ message: '返回失败，请手动回到计划列表' });
      }
    }
  }
}
