import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { PreferenceManager, AiDailyPoiRangeConfig } from '../common/utils/PreferenceManager';
import { AppStorageKeys } from '../common/constants/AppStorageKeys';
import { ThemeCenter, ThemeMode } from '../common/utils/ThemeCenter';
import { SettingSelectItem, SettingsSubPageHeader, SettingSwitchItem } from './components/views/SettingsItems';

export function resolveSettingsGeneralThemeModeText(themeMode: ThemeMode): string {
  if (themeMode === 'dark') {
    return '深色';
  }
  if (themeMode === 'light') {
    return '浅色';
  }
  return '跟随系统';
}

export function resolveSettingsGeneralIdleGapTriggerMinutes(input: string, currentValue: number): number {
  const raw = parseInt(input, 10);
  const next = isNaN(raw) ? currentValue : raw;
  return PreferenceManager.normalizeIdleGapTriggerMinutes(next);
}

export function resolveSettingsGeneralMinEventDuration(input: string, currentValue: number): number {
  const raw = parseInt(input, 10);
  const next = isNaN(raw) ? currentValue : raw;
  return PreferenceManager.normalizeMinEventDuration(next);
}

export function resolveSettingsGeneralAiPoiInput(rawInput: string, fallback: number): number {
  const raw = parseInt(rawInput, 10);
  const source = isNaN(raw) ? fallback : raw;
  return PreferenceManager.normalizeAiPoiCount(source, fallback);
}

export interface SettingsGeneralAiPoiInputState {
  defaultMinInput: string;
  defaultMaxInput: string;
  soldierMinInput: string;
  soldierMaxInput: string;
  leisureMinInput: string;
  leisureMaxInput: string;
}

interface SettingsGeneralAiPoiRangePair {
  min: number;
  max: number;
}

function buildSettingsGeneralAiPoiRangePair(
  minInput: string,
  maxInput: string,
  fallbackMin: number,
  fallbackMax: number
): SettingsGeneralAiPoiRangePair {
  const min = resolveSettingsGeneralAiPoiInput(minInput, fallbackMin);
  const max = resolveSettingsGeneralAiPoiInput(maxInput, fallbackMax);
  if (min > max) {
    const swapped: SettingsGeneralAiPoiRangePair = {
      min: max,
      max: min
    };
    return swapped;
  }
  const result: SettingsGeneralAiPoiRangePair = {
    min: min,
    max: max
  };
  return result;
}

export function buildSettingsGeneralAiPoiRangeConfig(
  inputState: SettingsGeneralAiPoiInputState,
  current: AiDailyPoiRangeConfig
): AiDailyPoiRangeConfig {
  const defaultRange = buildSettingsGeneralAiPoiRangePair(
    inputState.defaultMinInput,
    inputState.defaultMaxInput,
    current.defaultMin,
    current.defaultMax
  );
  const soldierRange = buildSettingsGeneralAiPoiRangePair(
    inputState.soldierMinInput,
    inputState.soldierMaxInput,
    current.soldierMin,
    current.soldierMax
  );
  const leisureRange = buildSettingsGeneralAiPoiRangePair(
    inputState.leisureMinInput,
    inputState.leisureMaxInput,
    current.leisureMin,
    current.leisureMax
  );
  return {
    defaultMin: defaultRange.min,
    defaultMax: defaultRange.max,
    soldierMin: soldierRange.min,
    soldierMax: soldierRange.max,
    leisureMin: leisureRange.min,
    leisureMax: leisureRange.max
  };
}

@Entry
@Component
struct SettingsGeneralPage {
  @State weatherFeatureEnabled: boolean = true;
  @State enableIdleGapDetection: boolean = true;
  @State idleGapTriggerMinutes: number = 45;
  @State idleGapTriggerInput: string = '45';
  @State minEventDuration: number = 30;
  @State minEventDurationInput: string = '30';
  @State aiDefaultMinInput: string = '4';
  @State aiDefaultMaxInput: string = '6';
  @State aiSoldierMinInput: string = '5';
  @State aiSoldierMaxInput: string = '8';
  @State aiLeisureMinInput: string = '3';
  @State aiLeisureMaxInput: string = '5';
  @State loading: boolean = true;
  @State themeMode: ThemeMode = 'system';
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  aboutToAppear(): void {
    void this.reload();
  }

  private safeShowToast(message: string): void {
    try {
      promptAction.openToast({ message: message });
    } catch (_error) {
    }
  }

  private getThemeModeText(): string {
    return resolveSettingsGeneralThemeModeText(this.themeMode);
  }

  private showThemeModeDialog(): void {
    this.getUIContext().showAlertDialog({
      title: '主题模式',
      message: '选择应用主题模式',
      buttons: [
        { value: '跟随系统', action: () => { void this.applyThemeMode('system'); } },
        { value: '浅色', action: () => { void this.applyThemeMode('light'); } },
        { value: '深色', action: () => { void this.applyThemeMode('dark'); } }
      ],
      autoCancel: true,
      alignment: DialogAlignment.Center
    });
  }

  private async applyThemeMode(mode: ThemeMode): Promise<void> {
    const pref = PreferenceManager.getInstance();
    await pref.setThemeMode(mode);
    this.themeMode = mode;
    const context = this.getUIContext().getHostContext() as common.Context;
    const effective = ThemeCenter.applyThemeMode(context, mode);
    this.effectiveTheme = effective;
    this.safeShowToast(`主题已切换为${this.getThemeModeText()}`);
  }

  private async reload(): Promise<void> {
    this.loading = true;
    try {
      const pref = PreferenceManager.getInstance();
      this.themeMode = ThemeCenter.normalizeThemeMode(await pref.getThemeMode());
      const context = this.getUIContext().getHostContext() as common.Context;
      this.effectiveTheme = ThemeCenter.applyThemeMode(context, this.themeMode);

      this.weatherFeatureEnabled = await pref.isWeatherFeatureEnabled();
      this.enableIdleGapDetection = await pref.getIdleGapDetectionEnabled();
      this.idleGapTriggerMinutes = await pref.getIdleGapTriggerMinutes();
      this.idleGapTriggerInput = `${this.idleGapTriggerMinutes}`;
      this.minEventDuration = await pref.getMinEventDuration();
      this.minEventDurationInput = `${this.minEventDuration}`;
      const aiRange = await pref.getAiDailyPoiRangeConfig();
      this.aiDefaultMinInput = `${aiRange.defaultMin}`;
      this.aiDefaultMaxInput = `${aiRange.defaultMax}`;
      this.aiSoldierMinInput = `${aiRange.soldierMin}`;
      this.aiSoldierMaxInput = `${aiRange.soldierMax}`;
      this.aiLeisureMinInput = `${aiRange.leisureMin}`;
      this.aiLeisureMaxInput = `${aiRange.leisureMax}`;
      AppStorage.setOrCreate(AppStorageKeys.MIN_EVENT_DURATION, this.minEventDuration);
    } finally {
      this.loading = false;
    }
  }

  private async onWeatherFeatureChanged(value: boolean): Promise<void> {
    const old = this.weatherFeatureEnabled;
    this.weatherFeatureEnabled = value;
    try {
      const pref = PreferenceManager.getInstance();
      await pref.setWeatherFeatureEnabled(value);
      this.weatherFeatureEnabled = await pref.isWeatherFeatureEnabled();
      this.safeShowToast(this.weatherFeatureEnabled ? '已开启天气功能' : '已关闭天气功能');
    } catch (_error) {
      this.weatherFeatureEnabled = old;
      this.safeShowToast('天气功能开关保存失败');
    }
  }

  private async onIdleGapDetectionChanged(value: boolean): Promise<void> {
    const old = this.enableIdleGapDetection;
    this.enableIdleGapDetection = value;
    try {
      const pref = PreferenceManager.getInstance();
      await pref.setIdleGapDetectionEnabled(value);
      this.enableIdleGapDetection = await pref.getIdleGapDetectionEnabled();
      this.safeShowToast(this.enableIdleGapDetection ? '已开启空闲时间检测' : '已关闭空闲时间检测');
    } catch (_error) {
      this.enableIdleGapDetection = old;
      this.safeShowToast('空闲时间检测开关保存失败');
    }
  }

  private async saveIdleGapTriggerMinutes(): Promise<void> {
    const oldValue = this.idleGapTriggerMinutes;
    const nextValue = resolveSettingsGeneralIdleGapTriggerMinutes(this.idleGapTriggerInput, oldValue);

    this.idleGapTriggerMinutes = nextValue;
    this.idleGapTriggerInput = `${nextValue}`;

    try {
      const pref = PreferenceManager.getInstance();
      await pref.setIdleGapTriggerMinutes(nextValue);
      const stored = await pref.getIdleGapTriggerMinutes();
      this.idleGapTriggerMinutes = stored;
      this.idleGapTriggerInput = `${stored}`;
      this.safeShowToast(`空闲检测触发阈值已设置为 ${stored} 分钟`);
    } catch (_error) {
      this.idleGapTriggerMinutes = oldValue;
      this.idleGapTriggerInput = `${oldValue}`;
      this.safeShowToast('空闲检测触发阈值保存失败');
    }
  }

  private async saveMinEventDuration(): Promise<void> {
    const oldValue = this.minEventDuration;
    const nextValue = resolveSettingsGeneralMinEventDuration(this.minEventDurationInput, oldValue);

    this.minEventDuration = nextValue;
    this.minEventDurationInput = `${nextValue}`;

    try {
      const pref = PreferenceManager.getInstance();
      await pref.setMinEventDuration(nextValue);
      const stored = await pref.getMinEventDuration();
      this.minEventDuration = stored;
      this.minEventDurationInput = `${stored}`;
      AppStorage.setOrCreate(AppStorageKeys.MIN_EVENT_DURATION, stored);
      this.safeShowToast(`已设置最小时长 ${stored} 分钟`);
    } catch (_error) {
      this.minEventDuration = oldValue;
      this.minEventDurationInput = `${oldValue}`;
      this.safeShowToast('最小时长保存失败');
    }
  }

  private async saveAiDailyPoiRanges(): Promise<void> {
    try {
      const pref = PreferenceManager.getInstance();
      const current = await pref.getAiDailyPoiRangeConfig();
      const next = buildSettingsGeneralAiPoiRangeConfig({
        defaultMinInput: this.aiDefaultMinInput,
        defaultMaxInput: this.aiDefaultMaxInput,
        soldierMinInput: this.aiSoldierMinInput,
        soldierMaxInput: this.aiSoldierMaxInput,
        leisureMinInput: this.aiLeisureMinInput,
        leisureMaxInput: this.aiLeisureMaxInput
      }, current);
      await pref.setAiDailyPoiRangeConfig(next);
      const stored = await pref.getAiDailyPoiRangeConfig();
      this.aiDefaultMinInput = `${stored.defaultMin}`;
      this.aiDefaultMaxInput = `${stored.defaultMax}`;
      this.aiSoldierMinInput = `${stored.soldierMin}`;
      this.aiSoldierMaxInput = `${stored.soldierMax}`;
      this.aiLeisureMinInput = `${stored.leisureMin}`;
      this.aiLeisureMaxInput = `${stored.leisureMax}`;
      this.safeShowToast('AI 每日地点范围已保存并实时生效');
    } catch (_error) {
      this.safeShowToast('AI 每日地点范围保存失败');
    }
  }

  build() {
    Scroll() {
      Column({ space: 10 }) {
        SettingsSubPageHeader({ title: '通用与外观' });

        SettingSelectItem({
          title: '主题模式',
          desc: '支持浅色、深色与跟随系统。',
          valueText: this.getThemeModeText(),
          textPrimary: this.getThemePalette().textPrimary,
          textSecondary: this.getThemePalette().textSecondary,
          cardBg: this.getThemePalette().cardBg,
          actionColor: this.getThemePalette().primary,
          onClickItem: () => this.showThemeModeDialog()
        });

        SettingSwitchItem({
          title: '启用天气功能',
          desc: '关闭后隐藏天气展示、刷新与提醒能力。',
          loading: this.loading,
          checked: this.weatherFeatureEnabled,
          textPrimary: this.getThemePalette().textPrimary,
          textSecondary: this.getThemePalette().textSecondary,
          cardBg: this.getThemePalette().cardBg,
          onToggle: async (value: boolean) => {
            await this.onWeatherFeatureChanged(value);
          }
        });

        SettingSwitchItem({
          title: '启用空闲时间检测',
          desc: '关闭后不再触发空闲时间优化提示。',
          loading: this.loading,
          checked: this.enableIdleGapDetection,
          textPrimary: this.getThemePalette().textPrimary,
          textSecondary: this.getThemePalette().textSecondary,
          cardBg: this.getThemePalette().cardBg,
          onToggle: async (value: boolean) => {
            await this.onIdleGapDetectionChanged(value);
          }
        });

      Row() {
        TextInput({ text: this.idleGapTriggerInput, placeholder: '空闲阈值(分钟)' })
          .type(InputType.Number)
          .fontSize(14)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(40)
          .backgroundColor(this.getThemePalette().cardBgSoft)
          .borderRadius(8)
          .enabled(this.enableIdleGapDetection)
          .onChange((value: string) => {
            this.idleGapTriggerInput = value;
          });

        Button('保存')
          .height(40)
          .margin({ left: 10 })
          .padding({ left: 14, right: 14 })
          .borderRadius(8)
          .backgroundColor(this.getThemePalette().primary)
          .fontColor(Color.White)
          .enabled(this.enableIdleGapDetection)
          .opacity(this.enableIdleGapDetection ? 1 : 0.5)
          .onClick(async () => {
            await this.saveIdleGapTriggerMinutes();
          });
      }
      .width('100%')
      .padding(12)
      .backgroundColor(this.getThemePalette().cardBg)
      .borderRadius(12);

      Column({ space: 8 }) {
        Text('压缩方案最小时长')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getThemePalette().textPrimary)
          .width('100%');

        Text('用于约束智能压缩时单个地点可被压缩到的最小时长。')
          .fontSize(12)
          .fontColor(this.getThemePalette().textSecondary)
          .width('100%');

        Row() {
          TextInput({ text: this.minEventDurationInput, placeholder: '压缩最小时长(分钟)' })
            .type(InputType.Number)
            .fontSize(14)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(40)
            .backgroundColor(this.getThemePalette().cardBgSoft)
            .borderRadius(8)
            .onChange((value: string) => {
              this.minEventDurationInput = value;
            });

          Button('保存')
            .height(40)
            .margin({ left: 10 })
            .padding({ left: 14, right: 14 })
            .borderRadius(8)
            .backgroundColor(this.getThemePalette().primary)
            .fontColor(Color.White)
            .onClick(async () => {
              await this.saveMinEventDuration();
            });
        }
        .width('100%');
      }
      .width('100%')
      .padding(12)
      .backgroundColor(this.getThemePalette().cardBg)
      .borderRadius(12);

      Column({ space: 8 }) {
        Text('AI 每日地点范围')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getThemePalette().textPrimary)
          .width('100%');

        Text('按策略设置 AI 每天生成地点数区间，保存后对新一轮生成实时生效。')
          .fontSize(12)
          .fontColor(this.getThemePalette().textSecondary)
          .width('100%');

        Row({ space: 8 }) {
          Text('默认')
            .width(48)
            .fontSize(13)
            .fontColor(this.getThemePalette().textSecondary);
          TextInput({ text: this.aiDefaultMinInput, placeholder: '最小' })
            .type(InputType.Number)
            .fontSize(13)
            .textAlign(TextAlign.Center)
            .width(72)
            .height(36)
            .backgroundColor(this.getThemePalette().cardBgSoft)
            .borderRadius(8)
            .onChange((value: string) => {
              this.aiDefaultMinInput = value;
            });
          Text('-').fontSize(13).fontColor(this.getThemePalette().textSecondary);
          TextInput({ text: this.aiDefaultMaxInput, placeholder: '最大' })
            .type(InputType.Number)
            .fontSize(13)
            .textAlign(TextAlign.Center)
            .width(72)
            .height(36)
            .backgroundColor(this.getThemePalette().cardBgSoft)
            .borderRadius(8)
            .onChange((value: string) => {
              this.aiDefaultMaxInput = value;
            });
        }
        .width('100%');

        Row({ space: 8 }) {
          Text('特种兵')
            .width(48)
            .fontSize(13)
            .fontColor(this.getThemePalette().textSecondary);
          TextInput({ text: this.aiSoldierMinInput, placeholder: '最小' })
            .type(InputType.Number)
            .fontSize(13)
            .textAlign(TextAlign.Center)
            .width(72)
            .height(36)
            .backgroundColor(this.getThemePalette().cardBgSoft)
            .borderRadius(8)
            .onChange((value: string) => {
              this.aiSoldierMinInput = value;
            });
          Text('-').fontSize(13).fontColor(this.getThemePalette().textSecondary);
          TextInput({ text: this.aiSoldierMaxInput, placeholder: '最大' })
            .type(InputType.Number)
            .fontSize(13)
            .textAlign(TextAlign.Center)
            .width(72)
            .height(36)
            .backgroundColor(this.getThemePalette().cardBgSoft)
            .borderRadius(8)
            .onChange((value: string) => {
              this.aiSoldierMaxInput = value;
            });
        }
        .width('100%');

        Row({ space: 8 }) {
          Text('休闲')
            .width(48)
            .fontSize(13)
            .fontColor(this.getThemePalette().textSecondary);
          TextInput({ text: this.aiLeisureMinInput, placeholder: '最小' })
            .type(InputType.Number)
            .fontSize(13)
            .textAlign(TextAlign.Center)
            .width(72)
            .height(36)
            .backgroundColor(this.getThemePalette().cardBgSoft)
            .borderRadius(8)
            .onChange((value: string) => {
              this.aiLeisureMinInput = value;
            });
          Text('-').fontSize(13).fontColor(this.getThemePalette().textSecondary);
          TextInput({ text: this.aiLeisureMaxInput, placeholder: '最大' })
            .type(InputType.Number)
            .fontSize(13)
            .textAlign(TextAlign.Center)
            .width(72)
            .height(36)
            .backgroundColor(this.getThemePalette().cardBgSoft)
            .borderRadius(8)
            .onChange((value: string) => {
              this.aiLeisureMaxInput = value;
            });
        }
        .width('100%');

        Button('保存 AI 范围')
          .width('100%')
          .height(36)
          .margin({ top: 8 })
          .borderRadius(10)
          .backgroundColor(this.getThemePalette().primary)
          .fontColor(Color.White)
          .onClick(async () => {
            await this.saveAiDailyPoiRanges();
          });
      }
      .width('100%')
      .padding(12)
      .backgroundColor(this.getThemePalette().cardBg)
      .borderRadius(12);

        Column() {
          Text('这里是通用设置页，适合放应用级开关与外观配置。')
            .fontSize(13)
            .fontColor(this.getThemePalette().textSecondary)
            .width('100%');
        }
        .width('100%')
        .padding(16)
        .backgroundColor(this.getThemePalette().cardBg)
        .borderRadius(12);
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 10, bottom: 24 });
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
    .backgroundColor(this.getThemePalette().pageBg);
  }
}
