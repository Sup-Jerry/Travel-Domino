import { GlobalBottomNavBar } from './components/views/BottomNavBar';
import { ThemeCenter } from '../common/utils/ThemeCenter';
import { common } from '@kit.AbilityKit';
import { AuthFacade } from '../infrastructure/auth/AuthFacade';

const DEFAULT_USER_NAME = '游客用户';

@Entry
@Component
struct MyPage {
  @State userName: string = DEFAULT_USER_NAME;
  @State loadingProfile: boolean = false;
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';
  private readonly authFacade: AuthFacade = AuthFacade.getInstance();

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  aboutToAppear(): void {
    void this.loadUserProfile();
  }

  private async loadUserProfile(): Promise<void> {
    if (this.loadingProfile) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.Context;
    this.authFacade.bindContext(hostContext);
    this.loadingProfile = true;
    try {
      this.userName = await this.authFacade.getCurrentNickname(DEFAULT_USER_NAME);
    } catch (_error) {
      this.userName = DEFAULT_USER_NAME;
    } finally {
      this.loadingProfile = false;
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column({ space: 16 }) {
        Row() {
          Text('我的')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getThemePalette().textPrimary);
        }
        .width('100%')
        .padding({ left: 16, top: 22, right: 16, bottom: 6 });

        Column({ space: 14 }) {
          Stack({ alignContent: Alignment.Center }) {
            Circle()
              .width(84)
              .height(84)
              .fill(this.getThemePalette().cardBgSoft);
            Circle()
              .width(32)
              .height(32)
              .fill(this.getThemePalette().textTertiary)
              .margin({ top: -14 });
            Row()
              .width(44)
              .height(24)
              .backgroundColor(this.getThemePalette().textTertiary)
              .borderRadius(12)
              .margin({ top: 26 });
          }

          Text(this.userName)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.getThemePalette().textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
        .width('100%')
        .padding({ top: 26, bottom: 26 })
        .backgroundColor(this.getThemePalette().cardBg)
        .borderRadius(14);

        Button('设置')
          .width('100%')
          .height(48)
          .borderRadius(12)
          .backgroundColor(this.getThemePalette().primary)
          .fontColor(Color.White)
          .fontSize(16)
          .onClick(() => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/SettingsPage' });
          });

        Blank()
          .layoutWeight(1);
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 90 })
      .backgroundColor(this.getThemePalette().pageBg);

      GlobalBottomNavBar({
        currentTab: 'profile',
        showCenterFab: false
      })
        .zIndex(9);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getThemePalette().pageBg);
  }
}
