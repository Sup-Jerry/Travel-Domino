import { ThemeCenter } from '../common/utils/ThemeCenter';
import { SettingsSubPageHeader } from './components/views/SettingsItems';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { AuthFacade } from '../infrastructure/auth/AuthFacade';
import { ProfileViewModel } from '../viewmodel/ProfileViewModel';

export function resolveLogoutToastMessage(success: boolean): string {
  return success ? '已退出登录' : '退出登录失败';
}

export function resolveLogoutRedirectUrl(): string {
  return 'pages/LoginPage';
}

@Entry
@Component
struct SettingsAccountSecurityPage {
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';
  private readonly authFacade: AuthFacade = AuthFacade.getInstance();

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  private safeShowToast(message: string): void {
    try {
      promptAction.openToast({ message: message });
    } catch (_error) {
    }
  }

  private async doLogout(): Promise<void> {
    try {
      const hostContext = this.getUIContext().getHostContext() as common.Context;
      this.authFacade.bindContext(hostContext);
      await this.authFacade.logout();
      ProfileViewModel.getInstance().reset();
      this.safeShowToast(resolveLogoutToastMessage(true));
      await this.getUIContext().getRouter().replaceUrl({ url: resolveLogoutRedirectUrl() });
    } catch (_error) {
      this.safeShowToast(resolveLogoutToastMessage(false));
    }
  }

  build() {
    Column({ space: 12 }) {
      SettingsSubPageHeader({ title: '账号与安全' });

      Column({ space: 8 }) {
        Text('账号状态')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getThemePalette().textPrimary);

        Text('支持显式登录与启动静默登录策略控制。')
          .fontSize(13)
          .fontColor(this.getThemePalette().textSecondary)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis });

        Button('退出登录')
          .width('100%')
          .height(44)
          .margin({ top: 10 })
          .backgroundColor('#EF4444')
          .fontColor('#FFFFFF')
          .borderRadius(10)
          .onClick(() => {
            void this.doLogout();
          });
      }
      .width('100%')
      .padding(16)
      .backgroundColor(this.getThemePalette().cardBg)
      .borderRadius(12)
      .margin({ left: 16, right: 16, top: 8 });

      Blank().layoutWeight(1);
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(this.getThemePalette().pageBg);
  }
}

export function createSettingsAccountSecurityPageForTest(): Object {
  return new SettingsAccountSecurityPage(undefined, {} as LocalStorage);
}
