import { ThemeCenter } from '../../../common/utils/ThemeCenter';
import { NavigationHelper } from '../../../common/utils/NavigationHelper';


export function shouldShowSettingSwitchLoading(loading: boolean): boolean {
  return loading;
}

export function resolveSettingSelectValueText(valueText: string): string {
  return valueText || '';
}

export function getSettingsSubPageBackLabel(): string {
  return '\u8FD4\u56DE';
}

@Component
export struct SettingSwitchItem {
  @Prop title: string = '';
  @Prop desc: string = '';
  @Prop loading: boolean = false;
  @Prop textPrimary: ResourceColor = '#222';
  @Prop textSecondary: ResourceColor = '#888';
  @Prop cardBg: ResourceColor = Color.White;
  @Link checked: boolean;

  onToggle: (value: boolean) => void = () => {};

  build() {
    Row() {
      Column() {
        Text(this.title)
          .fontSize(16)
          .fontColor(this.textPrimary)
          .fontWeight(FontWeight.Medium);

        Text(this.desc)
          .fontSize(12)
          .fontColor(this.textSecondary)
          .margin({ top: 6 });
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1);

      if (shouldShowSettingSwitchLoading(this.loading)) {
        Text('加载中...')
          .fontSize(12)
          .fontColor('#AAA');
      } else {
        Toggle({ type: ToggleType.Switch, isOn: this.checked })
          .onChange((value: boolean) => {
            this.checked = value;
            this.onToggle(value);
          });
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.cardBg)
    .borderRadius(12);
  }
}

@Component
export struct SettingSelectItem {
  @Prop title: string = '';
  @Prop desc: string = '';
  @Prop valueText: string = '';
  @Prop textPrimary: ResourceColor = '#222';
  @Prop textSecondary: ResourceColor = '#888';
  @Prop cardBg: ResourceColor = Color.White;
  @Prop actionColor: ResourceColor = '#007DFF';

  onClickItem: () => void = () => {};

  build() {
    Row() {
      Column() {
        Text(this.title)
          .fontSize(16)
          .fontColor(this.textPrimary)
          .fontWeight(FontWeight.Medium);

        Text(this.desc)
          .fontSize(12)
          .fontColor(this.textSecondary)
          .margin({ top: 6 });
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1);

      Text(resolveSettingSelectValueText(this.valueText))
        .fontSize(13)
        .fontColor(this.actionColor);

      Text('>')
        .fontSize(14)
        .fontColor(this.textSecondary)
        .margin({ left: 8 });
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.cardBg)
    .borderRadius(12)
    .onClick(() => {
      this.onClickItem();
    });
  }
}

@Component
export struct SettingCategoryItem {
  @Prop title: string = '';
  @Prop desc: string = '';
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  onClickItem: () => void = () => {};

  private getPalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  build() {
    Row() {
      Column({ space: 4 }) {
        Text(this.title)
          .fontSize(17)
          .fontColor(this.getPalette().textPrimary)
          .fontWeight(FontWeight.Medium);

        Text(this.desc)
          .fontSize(12)
          .fontColor(this.getPalette().textSecondary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      Text('>')
        .fontSize(16)
        .fontColor(this.getPalette().textSecondary);
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.getPalette().cardBg)
    .borderRadius(12)
    .onClick(() => this.onClickItem());
  }
}

@Component
export struct SettingsSubPageHeader {
  @Prop title: string = '';
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  private getPalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  build() {
    Stack() {
      Text(this.title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getPalette().textPrimary)
        .align(Alignment.Center);

      Row() {
        Button(getSettingsSubPageBackLabel())
          .type(ButtonType.Capsule)
          .fontSize(14)
          .height(32)
          .padding({ left: 12, right: 12 })
          .backgroundColor(this.getPalette().primary)
          .fontColor(Color.White)
          .onClick(() => {
            void NavigationHelper.backOrFallbackToPlanList(this.getUIContext());
          });
      }
      .width('100%')
      .justifyContent(FlexAlign.Start);
    }
    .width('100%')
    .padding({ top: 14, left: 8, right: 16, bottom: 6 });
  }
}
