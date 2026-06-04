import { ThemeCenter } from '../../../common/utils/ThemeCenter';
import { DEFAULT_WEATHER_USER_PREFERENCE, WeatherUserPreference } from '../../../domain/services/WeatherModels';

export type PlanSettingsAction = 'rename' | 'reschedule' | 'share' | 'weather_preference';
type PlanSettingsVoidAction = () => void;
type PlanSettingsWeatherPreferenceAction = (preference: WeatherUserPreference) => void;

export function getPlanSettingsActions(): PlanSettingsAction[] {
  return ['rename', 'reschedule', 'share', 'weather_preference'];
}

export function isPlanSettingsActionSupported(action: string): boolean {
  return getPlanSettingsActions().indexOf(action as PlanSettingsAction) >= 0;
}

export function isWeatherPreferenceLevelValid(level: number): boolean {
  return Number.isInteger(level) && level >= 0 && level <= 2;
}

@CustomDialog
export struct PlanSettingsDialog {
  controller: CustomDialogController;
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  onRename: PlanSettingsVoidAction = () => {};
  onReschedule: PlanSettingsVoidAction = () => {};
  onShare: PlanSettingsVoidAction = () => {};
  onWeatherPreferenceChange: PlanSettingsWeatherPreferenceAction = (_preference: WeatherUserPreference) => {};
  weatherUserPreference: WeatherUserPreference = {
    heatSensitivity: DEFAULT_WEATHER_USER_PREFERENCE.heatSensitivity,
    rainSensitivity: DEFAULT_WEATHER_USER_PREFERENCE.rainSensitivity,
    weatherRiskTolerance: DEFAULT_WEATHER_USER_PREFERENCE.weatherRiskTolerance
  };

  @State weatherPreference: WeatherUserPreference = {
    heatSensitivity: DEFAULT_WEATHER_USER_PREFERENCE.heatSensitivity,
    rainSensitivity: DEFAULT_WEATHER_USER_PREFERENCE.rainSensitivity,
    weatherRiskTolerance: DEFAULT_WEATHER_USER_PREFERENCE.weatherRiskTolerance
  };

  private getPalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  aboutToAppear() {
    this.weatherPreference = {
      heatSensitivity: this.weatherUserPreference.heatSensitivity,
      rainSensitivity: this.weatherUserPreference.rainSensitivity,
      weatherRiskTolerance: this.weatherUserPreference.weatherRiskTolerance
    };
  }

  @Builder
  buildDimensionRow(label: string, options: string[], values: number[], getCurrent: () => number, onChange: (val: number) => void) {
    Row() {
      Text(label).fontSize(14).fontColor(this.getPalette().textSecondary).width(60);
      ForEach(options, (opt: string, idx: number) => {
        Button(opt)
          .height(36)
          .fontSize(13)
          .backgroundColor(getCurrent() === values[idx] ? this.getPalette().primary : this.getPalette().cardBgSoft)
          .fontColor(getCurrent() === values[idx] ? Color.White : this.getPalette().textPrimary)
          .borderRadius(6)
          .margin({ left: 8 })
          .padding({ left: 12, right: 12 })
          .onClick(() => onChange(values[idx]));
      }, (opt: string, idx: number) => `${label}-${idx}`);
    }.width('100%').margin({ top: 8 });
  }

  build() {
    Column() {
      Row()
        .width(40)
        .height(4)
        .backgroundColor(this.getPalette().divider)
        .borderRadius(2)
        .margin({ top: 12, bottom: 20 });

      Text('计划设置')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getPalette().textPrimary)
        .margin({ bottom: 24 });

      Row() {
        Text('[R]')
          .fontSize(18)
          .fontColor(this.getPalette().primary)
          .margin({ right: 16 });

        Column() {
          Text('修改计划名称')
            .fontSize(16)
            .fontColor(this.getPalette().textPrimary)
            .fontWeight(FontWeight.Medium);
          Text('为本次行程设置更清晰的名称')
            .fontSize(12)
            .fontColor(this.getPalette().textSecondary)
            .margin({ top: 4 });
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        Text('>')
          .fontSize(16)
          .fontColor(this.getPalette().textTertiary);
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.controller.close();
        this.onRename();
      });

      Divider().color(this.getPalette().divider).margin({ top: 8, bottom: 8 });

      Row() {
        Text('[D]')
          .fontSize(18)
          .fontColor(this.getPalette().primary)
          .margin({ right: 16 });

        Column() {
          Text('调整出发时间')
            .fontSize(16)
            .fontColor(this.getPalette().textPrimary)
            .fontWeight(FontWeight.Medium);
          Text('整体平移计划内所有日程')
            .fontSize(12)
            .fontColor(this.getPalette().textSecondary)
            .margin({ top: 4 });
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        Text('>')
          .fontSize(16)
          .fontColor(this.getPalette().textTertiary);
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })
      .onClick(() => {
        this.controller.close();
        this.onReschedule();
      });

      Divider().color(this.getPalette().divider).margin({ top: 8, bottom: 8 });

      Row() {
        Text('[S]')
          .fontSize(18)
          .fontColor(this.getPalette().primary)
          .margin({ right: 16 });

        Column() {
          Text('分享计划')
            .fontSize(16)
            .fontColor(this.getPalette().textPrimary)
            .fontWeight(FontWeight.Medium);
          Text('导出分享数据并生成分享图')
            .fontSize(12)
            .fontColor(this.getPalette().textSecondary)
            .margin({ top: 4 });
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        Text('>')
          .fontSize(16)
          .fontColor(this.getPalette().textTertiary);
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })
      .onClick(() => {
        this.controller.close();
        this.onShare();
      });

      Divider().color(this.getPalette().divider).margin({ top: 12, bottom: 8 });

      Row() {
        Text('[W]')
          .fontSize(18)
          .fontColor(this.getPalette().primary)
          .margin({ right: 16 });

        Column() {
          Text('天气偏好')
            .fontSize(16)
            .fontColor(this.getPalette().textPrimary)
            .fontWeight(FontWeight.Medium);
          Text('影响天气风险评分与替代建议优先级')
            .fontSize(12)
            .fontColor(this.getPalette().textSecondary)
            .margin({ top: 4 });
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%')
      .padding({ top: 12, bottom: 6 });

      this.buildDimensionRow('怕热', ['低', '中', '高'], [0, 1, 2], () => this.weatherPreference.heatSensitivity, (val) => {
        this.weatherPreference = {
          heatSensitivity: val as 0 | 1 | 2,
          rainSensitivity: this.weatherPreference.rainSensitivity,
          weatherRiskTolerance: this.weatherPreference.weatherRiskTolerance
        };
        this.onWeatherPreferenceChange(this.weatherPreference);
      });
      this.buildDimensionRow('怕雨', ['低', '中', '高'], [0, 1, 2], () => this.weatherPreference.rainSensitivity, (val) => {
        this.weatherPreference = {
          heatSensitivity: this.weatherPreference.heatSensitivity,
          rainSensitivity: val as 0 | 1 | 2,
          weatherRiskTolerance: this.weatherPreference.weatherRiskTolerance
        };
        this.onWeatherPreferenceChange(this.weatherPreference);
      });
      this.buildDimensionRow('容忍', ['低', '中', '高'], [0, 1, 2], () => this.weatherPreference.weatherRiskTolerance, (val) => {
        this.weatherPreference = {
          heatSensitivity: this.weatherPreference.heatSensitivity,
          rainSensitivity: this.weatherPreference.rainSensitivity,
          weatherRiskTolerance: val as 0 | 1 | 2
        };
        this.onWeatherPreferenceChange(this.weatherPreference);
      });

      Button('取消')
        .type(ButtonType.Normal)
        .backgroundColor(this.getPalette().cardBgSoft)
        .fontColor(this.getPalette().textSecondary)
        .width('100%')
        .height(48)
        .borderRadius(12)
        .margin({ top: 32 })
        .onClick(() => {
          this.controller.close();
        });
    }
    .width('100%')
    .padding({ left: 20, right: 20, bottom: 20 })
    .backgroundColor(this.getPalette().cardBg)
    .borderRadius({ topLeft: 24, topRight: 24 });
  }
}
