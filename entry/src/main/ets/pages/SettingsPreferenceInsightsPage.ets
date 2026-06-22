import { promptAction } from '@kit.ArkUI';
import { PreferenceManager } from '../common/utils/PreferenceManager';
import { ThemeCenter } from '../common/utils/ThemeCenter';
import { WeatherUserPreference } from '../domain/services/WeatherModels';
import { DEFAULT_USER_PROFILE, UserStrategyProfile } from '../domain/strategy/UserStrategyProfile';
import { SettingsSubPageHeader } from './components/views/SettingsItems';

export interface ModeFrequencyView {
  modeCustom: number;
  modeDefault: number;
  modeSoldier: number;
  modeLeisure: number;
}

export interface ModeBarItem {
  label: string;
  count: number;
  color: string;
}

const RECOMMEND_SAMPLE_THRESHOLD = 3;

export function clampSettingsPreferenceInt(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) {
    return min;
  }
  const rounded = Math.round(value);
  if (rounded < min) {
    return min;
  }
  if (rounded > max) {
    return max;
  }
  return rounded;
}

export function parseSettingsPreferenceModeCount(raw: string, key: string): number {
  const pattern = new RegExp(`"${key}"\\s*:\\s*(\\d+)`);
  const match = raw.match(pattern);
  if (!match || match.length < 2) {
    return 0;
  }
  const value = Number(match[1]);
  if (!Number.isFinite(value) || value <= 0) {
    return 0;
  }
  return Math.floor(value);
}

export function parseSettingsPreferenceModeFrequency(raw: string): ModeFrequencyView {
  const safeRaw = raw || '';
  return {
    modeCustom: parseSettingsPreferenceModeCount(safeRaw, '-1'),
    modeDefault: parseSettingsPreferenceModeCount(safeRaw, '0'),
    modeSoldier: parseSettingsPreferenceModeCount(safeRaw, '1'),
    modeLeisure: parseSettingsPreferenceModeCount(safeRaw, '2')
  };
}

export function resolveSettingsPreferenceModeTotalCount(freq: ModeFrequencyView): number {
  const total = freq.modeCustom + freq.modeDefault + freq.modeSoldier + freq.modeLeisure;
  if (total <= 0) {
    return 0;
  }
  return total;
}

export function resolveSettingsPreferencePercentText(count: number, total: number): string {
  if (count <= 0 || total <= 0) {
    return '0%';
  }
  const percent = Math.round((count * 1000) / total) / 10;
  return `${percent}%`;
}

export function resolveSettingsPreferencePercentWidth(count: number, total: number): string {
  if (count <= 0 || total <= 0) {
    return '0%';
  }
  const percent = Math.round((count * 1000) / total) / 10;
  const visiblePercent = percent < 6 ? 6 : percent;
  return `${visiblePercent}%`;
}

export function resolveSettingsPreferenceConsistencyRateText(match: number, mismatch: number): string {
  const total = match + mismatch;
  if (total <= 0) {
    return '暂无比对数据';
  }
  const percent = Math.round((match * 1000) / total) / 10;
  return `${percent}%`;
}

export function resolveSettingsPreferenceWeatherLevelText(value: number): string {
  if (value <= 0) {
    return '低';
  }
  if (value >= 2) {
    return '高';
  }
  return '中';
}

export function resolveSettingsPreferenceDensityText(value: number): string {
  const level = clampSettingsPreferenceInt(value, 0, 2);
  if (level === 0) {
    return '低';
  }
  if (level === 2) {
    return '高';
  }
  return '中';
}

export function resolveSettingsPreferencePaceText(value: number): string {
  const level = clampSettingsPreferenceInt(value, 0, 2);
  if (level === 0) {
    return '松弛';
  }
  if (level === 2) {
    return '紧凑';
  }
  return '平衡';
}

export function resolveSettingsPreferencePreferenceText(value: number): string {
  const level = clampSettingsPreferenceInt(value, 0, 4);
  if (level === 1) {
    return '景点';
  }
  if (level === 2) {
    return '美食';
  }
  if (level === 3) {
    return '文化';
  }
  if (level === 4) {
    return '夜景';
  }
  return '均衡';
}

export function resolveSettingsPreferenceEnergyText(value: number): string {
  const level = clampSettingsPreferenceInt(value, 0, 2);
  if (level === 0) {
    return '轻松';
  }
  if (level === 2) {
    return '充沛';
  }
  return '中等';
}

export function resolveSettingsPreferenceStrategySummary(profile: UserStrategyProfile): string {
  if (profile.sampleCount < RECOMMEND_SAMPLE_THRESHOLD && profile.manualOverrideEnabled !== true) {
    return '样本不足，继续使用 AI 后会形成更稳定画像';
  }
  return `${resolveSettingsPreferenceDensityText(profile.avgDensity)}密度 · ${resolveSettingsPreferencePaceText(profile.avgPace)}节奏 · ` +
    `${resolveSettingsPreferencePreferenceText(profile.avgPreference)}偏好 · ${resolveSettingsPreferenceEnergyText(profile.avgEnergy)}体力`;
}

export function resolveSettingsPreferenceDominantModeText(freq: ModeFrequencyView, sampleCount: number): string {
  if (sampleCount <= 0) {
    return '暂无';
  }
  let maxMode: string = '默认';
  let maxCount = freq.modeDefault;
  if (freq.modeSoldier > maxCount) {
    maxMode = '特种兵';
    maxCount = freq.modeSoldier;
  }
  if (freq.modeLeisure > maxCount) {
    maxMode = '休闲';
    maxCount = freq.modeLeisure;
  }
  if (freq.modeCustom > maxCount) {
    maxMode = '自定义';
  }
  return maxMode;
}

export function buildSettingsPreferenceModeUsageItems(freq: ModeFrequencyView): ModeBarItem[] {
  return [
    { label: '默认', count: freq.modeDefault, color: '#5B8FF9' },
    { label: '特种兵', count: freq.modeSoldier, color: '#F6903D' },
    { label: '休闲', count: freq.modeLeisure, color: '#5AD8A6' },
    { label: '自定义', count: freq.modeCustom, color: '#9270CA' }
  ];
}

export function normalizeSettingsPreferenceCount(raw: number): number {
  if (!Number.isFinite(raw) || raw <= 0) {
    return 0;
  }
  return Math.floor(raw);
}

@Entry
@Component
struct SettingsPreferenceInsightsPage {
  @State loading: boolean = true;
  @State savingWeather: boolean = false;
  @State savingProfile: boolean = false;

  @State weatherFeatureEnabled: boolean = true;
  @State weatherPreference: WeatherUserPreference = {
    heatSensitivity: 1,
    rainSensitivity: 1,
    weatherRiskTolerance: 1
  };

  @State profile: UserStrategyProfile = {
    avgDensity: DEFAULT_USER_PROFILE.avgDensity,
    avgPace: DEFAULT_USER_PROFILE.avgPace,
    avgPreference: DEFAULT_USER_PROFILE.avgPreference,
    avgEnergy: DEFAULT_USER_PROFILE.avgEnergy,
    modeFrequency: DEFAULT_USER_PROFILE.modeFrequency,
    sampleCount: DEFAULT_USER_PROFILE.sampleCount,
    updatedAt: DEFAULT_USER_PROFILE.updatedAt,
    manualOverrideEnabled: DEFAULT_USER_PROFILE.manualOverrideEnabled,
    consistencyMatchCount: DEFAULT_USER_PROFILE.consistencyMatchCount,
    consistencyMismatchCount: DEFAULT_USER_PROFILE.consistencyMismatchCount,
    lastConsistencyCheckAt: DEFAULT_USER_PROFILE.lastConsistencyCheckAt
  };

  @State modeFrequency: ModeFrequencyView = {
    modeCustom: 0,
    modeDefault: 0,
    modeSoldier: 0,
    modeLeisure: 0
  };

  @State editHeatSensitivity: number = 1;
  @State editRainSensitivity: number = 1;
  @State editWeatherRiskTolerance: number = 1;

  @State editDensity: number = 1;
  @State editPace: number = 1;
  @State editPreference: number = 0;
  @State editEnergy: number = 1;

  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  aboutToAppear(): void {
    void this.reloadInsights();
  }

  private safeShowToast(message: string): void {
    try {
      promptAction.openToast({ message: message });
    } catch (_error) {
    }
  }

  private clampInt(value: number, min: number, max: number): number {
    return clampSettingsPreferenceInt(value, min, max);
  }

  private syncEditableState(): void {
    this.editHeatSensitivity = this.clampInt(this.weatherPreference.heatSensitivity, 0, 2);
    this.editRainSensitivity = this.clampInt(this.weatherPreference.rainSensitivity, 0, 2);
    this.editWeatherRiskTolerance = this.clampInt(this.weatherPreference.weatherRiskTolerance, 0, 2);

    this.editDensity = this.clampInt(this.profile.avgDensity, 0, 2);
    this.editPace = this.clampInt(this.profile.avgPace, 0, 2);
    this.editPreference = this.clampInt(this.profile.avgPreference, 0, 4);
    this.editEnergy = this.clampInt(this.profile.avgEnergy, 0, 2);
  }

  private async reloadInsights(): Promise<void> {
    this.loading = true;
    try {
      const pref = PreferenceManager.getInstance();
      this.weatherFeatureEnabled = await pref.isWeatherFeatureEnabled();
      this.weatherPreference = await pref.getWeatherUserPreference();
      this.profile = await pref.getUserStrategyProfile();
      this.modeFrequency = this.parseModeFrequency(this.profile.modeFrequency);
      this.syncEditableState();
    } catch (_error) {
      this.safeShowToast('偏好画像加载失败');
    } finally {
      this.loading = false;
    }
  }

  private async saveWeatherPreference(): Promise<void> {
    this.savingWeather = true;
    try {
      const pref = PreferenceManager.getInstance();
      const nextWeatherPreference: WeatherUserPreference = {
        heatSensitivity: this.clampInt(this.editHeatSensitivity, 0, 2) as 0 | 1 | 2,
        rainSensitivity: this.clampInt(this.editRainSensitivity, 0, 2) as 0 | 1 | 2,
        weatherRiskTolerance: this.clampInt(this.editWeatherRiskTolerance, 0, 2) as 0 | 1 | 2
      };
      await pref.setWeatherUserPreference(nextWeatherPreference);
      this.weatherPreference = await pref.getWeatherUserPreference();
      this.syncEditableState();
      this.safeShowToast('天气偏好已更新并立即生效');
    } catch (_error) {
      this.safeShowToast('天气偏好保存失败');
    } finally {
      this.savingWeather = false;
    }
  }

  private async saveAiProfile(): Promise<void> {
    this.savingProfile = true;
    try {
      const pref = PreferenceManager.getInstance();
      const now = Date.now();
      const nextProfile: UserStrategyProfile = {
        avgDensity: this.clampInt(this.editDensity, 0, 2),
        avgPace: this.clampInt(this.editPace, 0, 2),
        avgPreference: this.clampInt(this.editPreference, 0, 4),
        avgEnergy: this.clampInt(this.editEnergy, 0, 2),
        modeFrequency: this.profile.modeFrequency || DEFAULT_USER_PROFILE.modeFrequency,
        sampleCount: Math.max(0, this.clampInt(this.profile.sampleCount, 0, Number.MAX_SAFE_INTEGER)),
        updatedAt: now,
        manualOverrideEnabled: true,
        consistencyMatchCount: this.getMatchCount(),
        consistencyMismatchCount: this.getMismatchCount(),
        lastConsistencyCheckAt: this.profile.lastConsistencyCheckAt || 0
      };
      await pref.setUserStrategyProfile(nextProfile);
      this.profile = await pref.getUserStrategyProfile();
      this.modeFrequency = this.parseModeFrequency(this.profile.modeFrequency);
      this.syncEditableState();
      this.safeShowToast('AI画像已更新，后续将按新画像推荐并持续校正');
    } catch (_error) {
      this.safeShowToast('AI画像保存失败');
    } finally {
      this.savingProfile = false;
    }
  }

  private parseModeFrequency(raw: string): ModeFrequencyView {
    return parseSettingsPreferenceModeFrequency(raw);
  }

  private parseModeCount(raw: string, key: string): number {
    return parseSettingsPreferenceModeCount(raw, key);
  }

  private getWeatherLevelText(value: number): string {
    return resolveSettingsPreferenceWeatherLevelText(value);
  }

  private getDensityText(value: number): string {
    return resolveSettingsPreferenceDensityText(value);
  }

  private getPaceText(value: number): string {
    return resolveSettingsPreferencePaceText(value);
  }

  private getPreferenceText(value: number): string {
    return resolveSettingsPreferencePreferenceText(value);
  }

  private getEnergyText(value: number): string {
    return resolveSettingsPreferenceEnergyText(value);
  }

  private getStrategySummary(): string {
    return resolveSettingsPreferenceStrategySummary(this.profile);
  }

  private getDominantModeText(): string {
    return resolveSettingsPreferenceDominantModeText(this.modeFrequency, this.profile.sampleCount);
  }

  private getModeUsageItems(): ModeBarItem[] {
    return buildSettingsPreferenceModeUsageItems(this.modeFrequency);
  }

  private getModeTotalCount(): number {
    return resolveSettingsPreferenceModeTotalCount(this.modeFrequency);
  }

  private getPercentText(count: number, total: number): string {
    return resolveSettingsPreferencePercentText(count, total);
  }

  private getPercentWidth(count: number, total: number): string {
    return resolveSettingsPreferencePercentWidth(count, total);
  }

  private formatUpdatedAt(timestamp: number): string {
    if (!Number.isFinite(timestamp) || timestamp <= 0) {
      return '暂无记录';
    }
    return new Date(timestamp).toLocaleString();
  }

  private getMatchCount(): number {
    return normalizeSettingsPreferenceCount(Number(this.profile.consistencyMatchCount || 0));
  }

  private getMismatchCount(): number {
    return normalizeSettingsPreferenceCount(Number(this.profile.consistencyMismatchCount || 0));
  }

  private getConsistencyRateText(): string {
    return resolveSettingsPreferenceConsistencyRateText(this.getMatchCount(), this.getMismatchCount());
  }

  @Builder
  private buildDimensionEditor(
    label: string,
    options: string[],
    values: number[],
    current: number,
    onChange: (value: number) => void
  ) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(this.getThemePalette().textSecondary)
        .width(72);

      Scroll() {
        Row() {
          ForEach(options, (opt: string, idx: number) => {
            Button(opt)
              .height(32)
              .fontSize(12)
              .backgroundColor(current === values[idx] ? this.getThemePalette().primary : this.getThemePalette().cardBgSoft)
              .fontColor(current === values[idx] ? Color.White : this.getThemePalette().textPrimary)
              .borderRadius(8)
              .margin({ left: idx === 0 ? 0 : 8 })
              .padding({ left: 12, right: 12 })
              .onClick(() => {
                onChange(values[idx]);
              });
          }, (opt: string, idx: number) => `${label}-${idx}`);
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .layoutWeight(1);
    }
    .width('100%')
    .margin({ top: 8 });
  }

  @Builder
  private buildWeatherReadonlyRow(label: string, value: number) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor(this.getThemePalette().textSecondary)
        .width(80);

      Text(this.getWeatherLevelText(value))
        .fontSize(13)
        .fontColor(this.getThemePalette().textPrimary)
        .fontWeight(FontWeight.Medium);
    }
    .width('100%')
    .margin({ top: 6 });
  }

  build() {
    Column({ space: 10 }) {
      SettingsSubPageHeader({ title: '偏好画像' });

      Scroll() {
        Column({ space: 10 }) {
          Row() {
            Column({ space: 4 }) {
              Text('个性化学习概览')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.getThemePalette().textPrimary)
                .width('100%');

              Text('可手动修正画像；后续系统会继续记录与你实际操作的一致性。')
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary)
                .width('100%');
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start);

            Button(this.loading ? '加载中...' : '刷新')
              .height(32)
              .fontSize(13)
              .padding({ left: 12, right: 12 })
              .borderRadius(16)
              .backgroundColor(this.getThemePalette().primary)
              .fontColor(Color.White)
              .enabled(!this.loading)
              .onClick(() => {
                void this.reloadInsights();
              });
          }
          .width('100%')
          .padding(12)
          .backgroundColor(this.getThemePalette().cardBg)
          .borderRadius(12);

          Column({ space: 6 }) {
            Text('天气偏好')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getThemePalette().textPrimary)
              .width('100%');

            Text(this.weatherFeatureEnabled ? '天气功能已开启，修改后会立即参与天气风险评估。' : '天气功能已关闭，修改后待开启时生效。')
              .fontSize(12)
              .fontColor(this.getThemePalette().textSecondary)
              .width('100%');

            this.buildWeatherReadonlyRow('当前怕热', this.weatherPreference.heatSensitivity);
            this.buildWeatherReadonlyRow('当前怕雨', this.weatherPreference.rainSensitivity);
            this.buildWeatherReadonlyRow('当前容忍', this.weatherPreference.weatherRiskTolerance);

            this.buildDimensionEditor('怕热', ['低', '中', '高'], [0, 1, 2], this.editHeatSensitivity, (value: number) => {
              this.editHeatSensitivity = value;
            });

            this.buildDimensionEditor('怕雨', ['低', '中', '高'], [0, 1, 2], this.editRainSensitivity, (value: number) => {
              this.editRainSensitivity = value;
            });

            this.buildDimensionEditor('容忍', ['低', '中', '高'], [0, 1, 2], this.editWeatherRiskTolerance, (value: number) => {
              this.editWeatherRiskTolerance = value;
            });

            Button(this.savingWeather ? '保存中...' : '保存天气偏好')
              .width('100%')
              .height(36)
              .margin({ top: 8 })
              .borderRadius(10)
              .backgroundColor(this.getThemePalette().primary)
              .fontColor(Color.White)
              .enabled(!this.savingWeather)
              .onClick(() => {
                void this.saveWeatherPreference();
              });
          }
          .width('100%')
          .padding(12)
          .backgroundColor(this.getThemePalette().cardBg)
          .borderRadius(12);

          Column({ space: 6 }) {
            Text('AI 策略画像')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getThemePalette().textPrimary)
              .width('100%');

            Text(`学习样本：${this.profile.sampleCount} 次`)
              .fontSize(13)
              .fontColor(this.getThemePalette().textSecondary)
              .width('100%');

            Text(`主导模式：${this.getDominantModeText()}`)
              .fontSize(13)
              .fontColor(this.getThemePalette().textSecondary)
              .width('100%');

            Text(`画像摘要：${this.getStrategySummary()}`)
              .fontSize(13)
              .fontColor(this.getThemePalette().textSecondary)
              .width('100%');

            Text(`手动画像：${this.profile.manualOverrideEnabled === true ? '已启用' : '未启用'}`)
              .fontSize(13)
              .fontColor(this.getThemePalette().textSecondary)
              .width('100%');

            this.buildDimensionEditor('密度', ['低', '中', '高'], [0, 1, 2], this.editDensity, (value: number) => {
              this.editDensity = value;
            });

            this.buildDimensionEditor('节奏', ['松弛', '平衡', '紧凑'], [0, 1, 2], this.editPace, (value: number) => {
              this.editPace = value;
            });

            this.buildDimensionEditor('偏好', ['均衡', '景点', '美食', '文化', '夜景'], [0, 1, 2, 3, 4], this.editPreference, (value: number) => {
              this.editPreference = value;
            });

            this.buildDimensionEditor('体力', ['低', '中', '高'], [0, 1, 2], this.editEnergy, (value: number) => {
              this.editEnergy = value;
            });

            Button(this.savingProfile ? '保存中...' : '保存 AI 画像')
              .width('100%')
              .height(36)
              .margin({ top: 8 })
              .borderRadius(10)
              .backgroundColor(this.getThemePalette().primary)
              .fontColor(Color.White)
              .enabled(!this.savingProfile)
              .onClick(() => {
                void this.saveAiProfile();
              });

            Text(`最近更新：${this.formatUpdatedAt(this.profile.updatedAt)}`)
              .fontSize(12)
              .fontColor(this.getThemePalette().textTertiary)
              .width('100%')
              .margin({ top: 4 });
          }
          .width('100%')
          .padding(12)
          .backgroundColor(this.getThemePalette().cardBg)
          .borderRadius(12);

          Column({ space: 6 }) {
            Text('画像一致性统计')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getThemePalette().textPrimary)
              .width('100%');

            Text(`一致次数：${this.getMatchCount()}  次`)
              .fontSize(13)
              .fontColor(this.getThemePalette().textSecondary)
              .width('100%');

            Text(`不一致次数：${this.getMismatchCount()}  次`)
              .fontSize(13)
              .fontColor(this.getThemePalette().textSecondary)
              .width('100%');

            Text(`一致率：${this.getConsistencyRateText()}`)
              .fontSize(13)
              .fontColor(this.getThemePalette().textSecondary)
              .width('100%');

            Text('当后续实际操作与画像不一致时，系统会自动按操作结果修正画像。')
              .fontSize(12)
              .fontColor(this.getThemePalette().textTertiary)
              .width('100%');
          }
          .width('100%')
          .padding(12)
          .backgroundColor(this.getThemePalette().cardBg)
          .borderRadius(12);

          Column({ space: 8 }) {
            Text('AI 模式使用分布')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getThemePalette().textPrimary)
              .width('100%');

            ForEach(this.getModeUsageItems(), (item: ModeBarItem) => {
              Column({ space: 4 }) {
                Row() {
                  Text(item.label)
                    .fontSize(13)
                    .fontColor(this.getThemePalette().textSecondary);

                  Blank().layoutWeight(1);

                  Text(`${item.count} 次 · ${this.getPercentText(item.count, this.getModeTotalCount())}`)
                    .fontSize(12)
                    .fontColor(this.getThemePalette().textTertiary);
                }
                .width('100%');

                Stack({ alignContent: Alignment.Start }) {
                  Row()
                    .width('100%')
                    .height(8)
                    .borderRadius(6)
                    .backgroundColor(this.getThemePalette().divider);

                  Row()
                    .width(this.getPercentWidth(item.count, this.getModeTotalCount()))
                    .height(8)
                    .borderRadius(6)
                    .backgroundColor(item.color);
                }
                .width('100%')
                .height(8);
              }
              .width('100%')
              .padding({ top: 2, bottom: 2 });
            }, (item: ModeBarItem) => item.label);
          }
          .width('100%')
          .padding(12)
          .backgroundColor(this.getThemePalette().cardBg)
          .borderRadius(12);
        }
        .width('100%')
        .padding({ bottom: 20 });
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .width('100%');
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, bottom: 20 })
    .backgroundColor(this.getThemePalette().pageBg);
  }
}

export function createSettingsPreferenceInsightsPageForTest(): Object {
  return new SettingsPreferenceInsightsPage(undefined, {} as LocalStorage);
}
