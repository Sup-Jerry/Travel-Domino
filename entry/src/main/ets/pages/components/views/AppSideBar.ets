import { promptAction, router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ThemeCenter } from '../../../common/utils/ThemeCenter';

export type AppNavKey = 'plans' | 'archive' | 'trash' | 'settings';

export function getAppSideBarRouteByKey(key: AppNavKey): string {
  if (key === 'plans') {
    return 'pages/PlanListPage';
  }
  if (key === 'archive') {
    return 'pages/ArchivePage';
  }
  if (key === 'trash') {
    return 'pages/TrashPage';
  }
  return 'pages/SettingsPage';
}

export function shouldAppSideBarNavigate(current: AppNavKey, target: AppNavKey): boolean {
  return current !== target;
}

class RouterUrlOptions {
  url: string = '';
}

@Component
export struct AppSideBar {
  @Link isSideBarShow: boolean;
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';
  current: AppNavKey = 'plans';

  private getPalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  private createRouteOptions(url: string): RouterUrlOptions {
    const options: RouterUrlOptions = new RouterUrlOptions();
    options.url = url;
    return options;
  }

  private async safeReplaceUrl(url: string): Promise<void> {
    try {
      await this.getUIContext().getRouter().replaceUrl(this.createRouteOptions(url));
    } catch (error) {
      hilog.warn(0x0000, 'AppSideBar', `[SIDEBAR][route_failed] to=${url}, reason=${JSON.stringify(error)}`);
      promptAction.openToast({ message: '页面跳转失败，请重试' });
    }
  }

  @Builder
  private NavItem(title: string, icon: string, active: boolean, onClick: () => void) {
    Row() {
      Text(icon)
        .fontSize(20)
        .margin({ right: 12 });

      Text(title)
        .fontSize(18)
        .fontColor(active ? this.getPalette().primary : this.getPalette().textPrimary)
        .fontWeight(active ? FontWeight.Bold : FontWeight.Normal);
    }
    .width('100%')
    .height(60)
    .onClick(() => {
      this.isSideBarShow = false;
      onClick();
    });
  }

  build() {
    Column() {
      Text('TravelDomino')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getPalette().textPrimary)
        .margin({ top: 25, bottom: 40 });

      this.NavItem('All Plans', '[P]', this.current === 'plans', () => {
        if (shouldAppSideBarNavigate(this.current, 'plans')) {
          void this.safeReplaceUrl(getAppSideBarRouteByKey('plans'));
        }
      });

      this.NavItem('Archive', '[A]', this.current === 'archive', () => {
        if (shouldAppSideBarNavigate(this.current, 'archive')) {
          void this.safeReplaceUrl(getAppSideBarRouteByKey('archive'));
        }
      });

      this.NavItem('Trash', '[T]', this.current === 'trash', () => {
        if (shouldAppSideBarNavigate(this.current, 'trash')) {
          void this.safeReplaceUrl(getAppSideBarRouteByKey('trash'));
        }
      });

      Divider()
        .color(this.getPalette().divider)
        .margin({ top: 12, bottom: 12, right: 20 });

      this.NavItem('Settings', '[S]', this.current === 'settings', () => {
        if (shouldAppSideBarNavigate(this.current, 'settings')) {
          void this.safeReplaceUrl(getAppSideBarRouteByKey('settings'));
        }
      });

      Blank();
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getPalette().pageBg)
    .padding({ left: 20 });
  }
}










