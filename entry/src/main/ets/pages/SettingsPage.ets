import { GlobalBottomNavBar } from './components/views/BottomNavBar';
import { ThemeCenter } from '../common/utils/ThemeCenter';
import { SettingCategoryItem } from './components/views/SettingsItems';

@Entry
@Component
struct SettingsPage {
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  private openPage(url: string): void {
    this.getUIContext().getRouter().pushUrl({ url: url });
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        Row() {
          Text('设置')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getThemePalette().textPrimary)
            .margin({ top: 12 });
        }
        .width('100%')
        .padding({ left: 16, top: 10, bottom: 10, right: 16 })
        .backgroundColor(this.getThemePalette().cardBg);

        Scroll() {
          Column({ space: 10 }) {
            SettingCategoryItem({
              title: '账号与安全',
              desc: '账号状态、登录保护与安全信息。',
              onClickItem: () => this.openPage('pages/SettingsAccountSecurityPage')
            });

            SettingCategoryItem({
              title: '通知与提醒',
              desc: '管理归档/删除等提示弹窗。',
              onClickItem: () => this.openPage('pages/SettingsNotificationPage')
            });

            SettingCategoryItem({
              title: '隐私与权限',
              desc: '路线服务与权限相关控制。',
              onClickItem: () => this.openPage('pages/SettingsPrivacyPage')
            });

            SettingCategoryItem({
              title: '通用与外观',
              desc: '主题、天气、时间与行程基础配置。',
              onClickItem: () => this.openPage('pages/SettingsGeneralPage')
            });
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 16, right: 16, top: 16, bottom: 90 });
        }
        .scrollBar(BarState.Off)
        .layoutWeight(1);
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
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
