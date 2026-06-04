import { ThemeCenter } from '../../../common/utils/ThemeCenter';
import { NavigationHelper } from '../../../common/utils/NavigationHelper';

type SettingToggleAction = (value: boolean) => void;
type SettingClickAction = () => void;

function noopSettingToggle(_value: boolean): void {}

function noopSettingClick(): void {}

export function shouldShowSettingSwitchLoading(loading: boolean): boolean {
  return loading;
}

export function resolveSettingSelectValueText(valueText: string): string {
  return valueText || '';
}

export function getSettingsSubPageBackLabel(): string {
  return '\u8FD4\u56DE';
}

export interface SettingSwitchRenderState {
  showLoading: boolean;
  showToggle: boolean;
  loadingText: string;
}

export interface SettingSelectRenderState {
  valueText: string;
  trailingText: string;
}

export interface SettingsSubPageHeaderState {
  title: string;
  backLabel: string;
}

export function resolveSettingSwitchRenderState(loading: boolean): SettingSwitchRenderState {
  const showLoading = shouldShowSettingSwitchLoading(loading);
  return {
    showLoading: showLoading,
    showToggle: !showLoading,
    loadingText: showLoading ? '加载中...' : ''
  };
}

export function resolveSettingSelectRenderState(valueText: string): SettingSelectRenderState {
  return {
    valueText: resolveSettingSelectValueText(valueText),
    trailingText: '>'
  };
}

export function resolveSettingsSubPageHeaderState(title: string): SettingsSubPageHeaderState {
  return {
    title: title,
    backLabel: getSettingsSubPageBackLabel()
  };
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

  onToggle: SettingToggleAction = noopSettingToggle;

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

      if (resolveSettingSwitchRenderState(this.loading).showLoading) {
        Text(resolveSettingSwitchRenderState(this.loading).loadingText)
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

  onClickItem: SettingClickAction = noopSettingClick;

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

      Text(resolveSettingSelectRenderState(this.valueText).valueText)
        .fontSize(13)
        .fontColor(this.actionColor);

      Text(resolveSettingSelectRenderState(this.valueText).trailingText)
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

  onClickItem: SettingClickAction = noopSettingClick;

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
      Text(resolveSettingsSubPageHeaderState(this.title).title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getPalette().textPrimary)
        .align(Alignment.Center);

      Row() {
        Button(resolveSettingsSubPageHeaderState(this.title).backLabel)
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
