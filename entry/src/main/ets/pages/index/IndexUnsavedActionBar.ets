export interface IndexUnsavedActionTheme {
  textPrimary: string;
  textSecondary: string;
  divider: string;
  primary: string;
  cardBg: string;
}

export function getDefaultIndexUnsavedActionTheme(): IndexUnsavedActionTheme {
  return {
    textPrimary: '#1F2937',
    textSecondary: '#5B6B82',
    divider: '#E7EDF5',
    primary: '#2F7DFF',
    cardBg: '#FFFFFF'
  };
}

export function shouldShowIndexUnsavedActionBar(isVisible: boolean): boolean {
  return isVisible;
}

@Component
export struct IndexUnsavedActionBar {
  @Prop isVisible: boolean = false;
  @Prop marginBottom: number = 96;
  @Prop theme: IndexUnsavedActionTheme = getDefaultIndexUnsavedActionTheme();

  onUndo: () => void = () => {};
  onSave: () => void = () => {};

  build() {
    if (shouldShowIndexUnsavedActionBar(this.isVisible)) {
      Row() {
        Row() {
          Text('✨').fontSize(16).margin({ right: 6 });
          Text('已自动优化行程时间')
            .fontSize(14)
            .fontColor(this.theme.textPrimary)
            .fontWeight(FontWeight.Medium);
        }
        .layoutWeight(1);

        Row() {
          Text('撤销')
            .fontSize(14)
            .fontColor(this.theme.textSecondary)
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .onClick(() => this.onUndo());

          Line()
            .width(1)
            .height(14)
            .backgroundColor(this.theme.divider)
            .margin({ left: 4, right: 4 });

          Text('保存')
            .fontSize(14)
            .fontColor(this.theme.primary)
            .fontWeight(FontWeight.Bold)
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .onClick(() => this.onSave());
        }
      }
      .width('90%')
      .height(56)
      .padding({ left: 16, right: 8 })
      .backgroundColor(this.theme.cardBg)
      .borderRadius(28)
      .shadow({ radius: 20, color: '#1A000000', offsetY: 8 })
      .margin({ bottom: this.marginBottom })
      .transition({ type: TransitionType.All, opacity: 0, translate: { y: 20 } });
    }
  }
}
