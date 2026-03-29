import { ThemeCenter } from '../common/utils/ThemeCenter';
import { SettingsSubPageHeader } from './components/views/SettingsItems';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { AuthFacade } from '../infrastructure/auth/AuthFacade';

@Entry
@Component
struct SettingsAccountSecurityPage {
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';
  private readonly authFacade: AuthFacade = AuthFacade.getInstance();

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  private async doLogout(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.Context;
    this.authFacade.bindContext(hostContext);
    await this.authFacade.logout();
    promptAction.openToast({ message: '已退出登录' });
    await this.getUIContext().getRouter().replaceUrl({ url: 'pages/LoginPage' });
  }

  build() {
    Column({ space: 12 }) {
      SettingsSubPageHeader({ title: '账号与安全' });

      Column({ space: 8 }) {
        Text('账号状态')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getThemePalette().textPrimary);

        Text('已接入华为账号登录，支持显式登录与静默登录。')
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

