import { GlobalBottomNavBar } from './components/views/BottomNavBar';
import { ThemeCenter } from '../common/utils/ThemeCenter';
import { SettingCategoryItem } from './components/views/SettingsItems';

export interface SettingsPageCategoryItem {
  title: string;
  desc: string;
  url: string;
}

export function buildSettingsPageCategoryItems(): SettingsPageCategoryItem[] {
  return [
    {
      title: '账号与安全',
      desc: '账号状态、登录保护与安全信息。',
      url: 'pages/SettingsAccountSecurityPage'
    },
    {
      title: '通知与提醒',
      desc: '管理归档/删除等提示弹窗。',
      url: 'pages/SettingsNotificationPage'
    },
    {
      title: '隐私与权限',
      desc: '路线服务与权限相关控制。',
      url: 'pages/SettingsPrivacyPage'
    },
    {
      title: '偏好画像',
      desc: '查看天气与 AI 学习到的个性化偏好。',
      url: 'pages/SettingsPreferenceInsightsPage'
    },
    {
      title: '通用与外观',
      desc: '主题、天气、时间与行程基础配置。',
      url: 'pages/SettingsGeneralPage'
    }
  ];
}

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
            ForEach(buildSettingsPageCategoryItems(), (item: SettingsPageCategoryItem) => {
              SettingCategoryItem({
                title: item.title,
                desc: item.desc,
                onClickItem: () => this.openPage(item.url)
              });
            }, (item: SettingsPageCategoryItem) => item.url);
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
