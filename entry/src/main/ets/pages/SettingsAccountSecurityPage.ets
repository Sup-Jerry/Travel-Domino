import { ThemeCenter } from '../common/utils/ThemeCenter';
import { SettingsSubPageHeader } from './components/views/SettingsItems';

@Entry
@Component
struct SettingsAccountSecurityPage {
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  build() {
    Column({ space: 12 }) {
      SettingsSubPageHeader({ title: '账号与安全' });

      Column({ space: 8 }) {
        Text('暂未开放')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getThemePalette().textPrimary);

        Text('账号与安全能力将在后续版本开放。')
          .fontSize(13)
          .fontColor(this.getThemePalette().textSecondary)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
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
