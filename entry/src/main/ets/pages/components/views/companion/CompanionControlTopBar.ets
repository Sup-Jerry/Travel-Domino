import { ThemeCenter } from '../../../../common/utils/ThemeCenter';

@Component
export struct CompanionControlTopBar {
  @Prop safeTopInset: number = 0;
  @Prop runtimeDescription: string = '';
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  onExit: () => void = () => {};

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  build() {
    Row() {
      Column({ space: 2 }) {
        Text('伴游控制')
          .fontSize(18)
          .fontColor(this.getThemePalette().textPrimary)
          .fontWeight(FontWeight.Bold);
        Text(this.runtimeDescription)
          .fontSize(11)
          .fontColor(this.getThemePalette().textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1);

      Text('退出伴游')
        .fontSize(13)
        .fontColor(this.getThemePalette().textSecondary)
        .onClick(() => {
          this.onExit();
        });
    }
    .width('100%')
    .padding({ top: this.safeTopInset + 10, left: 16, right: 16, bottom: 8 });
  }
}
