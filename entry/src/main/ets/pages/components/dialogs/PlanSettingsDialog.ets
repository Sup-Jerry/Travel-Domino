import { ThemeCenter } from '../../../common/utils/ThemeCenter';
import { ComposableStrategy, DensityLevel, PaceLevel, PreferenceType, EnergyLevel } from '../../../domain/strategy/TravelStrategyDimensions';
import { StrategyService } from '../../../domain/strategy/StrategyService';
import { DEFAULT_WEATHER_USER_PREFERENCE, WeatherUserPreference } from '../../../domain/services/WeatherModels';

@CustomDialog
export struct PlanSettingsDialog {
  controller: CustomDialogController;
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  onRename: () => void = () => {};
  onReschedule: () => void = () => {};
  onAutoRouteChange: (enabled: boolean) => void = () => {};
  autoRouteEnabled: boolean = true;
  currentStrategyMode: number = 0;
  onStrategyChange: (mode: number) => void = (mode: number) => {};
  hasAiHistory: boolean = false;
  onRegenerateWithStrategy: (mode: number) => void = (mode: number) => {};
  onCustomStrategyChange: (strategy: ComposableStrategy) => void = (strategy: ComposableStrategy) => {};
  onRegenerateWithCustomStrategy: (strategy: ComposableStrategy) => void = (strategy: ComposableStrategy) => {};
  onWeatherPreferenceChange: (preference: WeatherUserPreference) => void = (_preference: WeatherUserPreference) => {};
  weatherUserPreference: WeatherUserPreference = {
    heatSensitivity: DEFAULT_WEATHER_USER_PREFERENCE.heatSensitivity,
    rainSensitivity: DEFAULT_WEATHER_USER_PREFERENCE.rainSensitivity,
    weatherRiskTolerance: DEFAULT_WEATHER_USER_PREFERENCE.weatherRiskTolerance
  };
  @State selectedStrategy: number = 0;
  @State useCustomStrategy: boolean = false;
  @State customStrategy: ComposableStrategy = {
    density: DensityLevel.MEDIUM,
    pace: PaceLevel.BALANCED,
    preference: PreferenceType.BALANCED,
    energy: EnergyLevel.MEDIUM
  };
  @State strategyExplanation: string = '';
  @State weatherPreference: WeatherUserPreference = {
    heatSensitivity: DEFAULT_WEATHER_USER_PREFERENCE.heatSensitivity,
    rainSensitivity: DEFAULT_WEATHER_USER_PREFERENCE.rainSensitivity,
    weatherRiskTolerance: DEFAULT_WEATHER_USER_PREFERENCE.weatherRiskTolerance
  };

  private getPalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  aboutToAppear() {
    this.selectedStrategy = this.currentStrategyMode;
    this.weatherPreference = {
      heatSensitivity: this.weatherUserPreference.heatSensitivity,
      rainSensitivity: this.weatherUserPreference.rainSensitivity,
      weatherRiskTolerance: this.weatherUserPreference.weatherRiskTolerance
    };
    this.loadStrategyExplanation();
  }

  private loadStrategyExplanation() {
    if (this.currentStrategyMode === -1) {
      this.strategyExplanation = StrategyService.buildComposableExplanation(this.customStrategy);
    } else {
      this.strategyExplanation = StrategyService.buildStrategyExplanation(this.currentStrategyMode);
    }
  }

  private getStrategyName(mode: number): string {
    if (mode === 1) return '⚡ 特种兵';
    if (mode === 2) return '☕ 休闲';
    return '✨ 默认';
  }

  private getStrategyDesc(mode: number): string {
    if (mode === 1) return '高密度景点覆盖，适合体力充沛的旅行者';
    if (mode === 2) return '低密度慢节奏，适合放松度假';
    return 'AI智能推荐，平衡节奏';
  }

  @Builder
  buildDimensionRow(label: string, options: string[], values: number[], getCurrent: () => number, onChange: (val: number) => void) {
    Row() {
      Text(label).fontSize(14).fontColor(this.getPalette().textSecondary).width(60)
      ForEach(options, (opt: string, idx: number) => {
        Button(opt)
          .height(36)
          .fontSize(13)
          .backgroundColor(getCurrent() === values[idx] ? this.getPalette().primary : this.getPalette().cardBgSoft)
          .fontColor(getCurrent() === values[idx] ? Color.White : this.getPalette().textPrimary)
          .borderRadius(6)
          .margin({ left: 8 })
          .padding({ left: 12, right: 12 })
          .onClick(() => onChange(values[idx]))
      }, (opt: string, idx: number) => `${label}-${idx}`)
    }.width('100%').margin({ top: 8 })
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

      if (this.strategyExplanation) {
        Row() {
          Text('💡').fontSize(14).margin({ right: 6 })
          Text(this.strategyExplanation)
            .fontSize(12)
            .fontColor(this.getPalette().textSecondary)
            .layoutWeight(1)
        }
        .width('100%')
        .padding(12)
        .backgroundColor(this.getPalette().cardBgSoft)
        .borderRadius(8)
        .margin({ bottom: 12 })
      }

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
        Text('[A]')
          .fontSize(18)
          .fontColor(this.getPalette().primary)
          .margin({ right: 16 });

        Column() {
          Text('自动计算高德通勤时间')
            .fontSize(16)
            .fontColor(this.getPalette().textPrimary)
            .fontWeight(FontWeight.Medium);
          Text('进入计划或新增地点时，自动计算未锁定地点的通勤时间')
            .fontSize(12)
            .fontColor(this.getPalette().textSecondary)
            .margin({ top: 4 })
            .maxLines(2);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        Toggle({ type: ToggleType.Switch, isOn: this.autoRouteEnabled })
          .selectedColor(this.getPalette().primary)
          .onChange((value: boolean) => {
            this.onAutoRouteChange(value);
          });
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 });

      Divider().color(this.getPalette().divider).margin({ top: 8, bottom: 8 });

      Row() {
        Text('[S]')
          .fontSize(18)
          .fontColor(this.getPalette().primary)
          .margin({ right: 16 });

        Column() {
          Text('旅行策略')
            .fontSize(16)
            .fontColor(this.getPalette().textPrimary)
            .fontWeight(FontWeight.Medium);
          Text(this.getStrategyDesc(this.selectedStrategy))
            .fontSize(12)
            .fontColor(this.getPalette().textSecondary)
            .margin({ top: 4 })
            .maxLines(2);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%')
      .padding({ top: 12, bottom: 8 });

      Row() {
        Button() { Text('✨ 默认').fontSize(14) }
          .height(36)
          .backgroundColor(this.selectedStrategy === 0 ? this.getPalette().primary : this.getPalette().cardBgSoft)
          .fontColor(this.selectedStrategy === 0 ? Color.White : this.getPalette().textPrimary)
          .borderRadius(8)
          .layoutWeight(1)
          .onClick(() => {
            if (this.selectedStrategy !== 0) {
              this.selectedStrategy = 0;
              this.useCustomStrategy = false;
              this.strategyExplanation = StrategyService.buildStrategyExplanation(0);
              this.onStrategyChange(0);
            }
          })
          .gesture(
            LongPressGesture({ repeat: false })
              .onAction(() => {
                if (this.hasAiHistory && this.selectedStrategy !== 0) {
                  this.onRegenerateWithStrategy(0);
                  this.controller.close();
                }
              })
          )

        Button() { Text('⚡ 特种兵').fontSize(14) }
          .height(36)
          .backgroundColor(this.selectedStrategy === 1 ? this.getPalette().primary : this.getPalette().cardBgSoft)
          .fontColor(this.selectedStrategy === 1 ? Color.White : this.getPalette().textPrimary)
          .borderRadius(8)
          .layoutWeight(1)
          .margin({ left: 8 })
          .onClick(() => {
            if (this.selectedStrategy !== 1) {
              this.selectedStrategy = 1;
              this.useCustomStrategy = false;
              this.strategyExplanation = StrategyService.buildStrategyExplanation(1);
              this.onStrategyChange(1);
            }
          })
          .gesture(
            LongPressGesture({ repeat: false })
              .onAction(() => {
                if (this.hasAiHistory && this.selectedStrategy !== 1) {
                  this.onRegenerateWithStrategy(1);
                  this.controller.close();
                }
              })
          )

        Button() { Text('☕ 休闲').fontSize(14) }
          .height(36)
          .backgroundColor(this.selectedStrategy === 2 ? this.getPalette().primary : this.getPalette().cardBgSoft)
          .fontColor(this.selectedStrategy === 2 ? Color.White : this.getPalette().textPrimary)
          .borderRadius(8)
          .layoutWeight(1)
          .margin({ left: 8 })
          .onClick(() => {
            if (this.selectedStrategy !== 2) {
              this.selectedStrategy = 2;
              this.useCustomStrategy = false;
              this.strategyExplanation = StrategyService.buildStrategyExplanation(2);
              this.onStrategyChange(2);
            }
          })
          .gesture(
            LongPressGesture({ repeat: false })
              .onAction(() => {
                if (this.hasAiHistory && this.selectedStrategy !== 2) {
                  this.onRegenerateWithStrategy(2);
                  this.controller.close();
                }
              })
          )

        Button() { Text('🎨 自定义').fontSize(14) }
          .height(36)
          .backgroundColor(this.useCustomStrategy ? this.getPalette().primary : this.getPalette().cardBgSoft)
          .fontColor(this.useCustomStrategy ? Color.White : this.getPalette().textPrimary)
          .borderRadius(8)
          .layoutWeight(1)
          .margin({ left: 8 })
          .onClick(() => {
            this.useCustomStrategy = true;
          })
      }
      .width('100%')
      .padding({ bottom: 12 })

      if (this.hasAiHistory) {
        Text('💡 长按策略按钮可直接切换并重新生成')
          .fontSize(11)
          .fontColor(this.getPalette().textTertiary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 8 })
      }

      if (this.useCustomStrategy) {
        Column() {
          this.buildDimensionRow('密度', ['低', '中', '高'], [0, 1, 2], () => this.customStrategy.density, (val) => {
            this.customStrategy = {
              density: val,
              pace: this.customStrategy.pace,
              preference: this.customStrategy.preference,
              energy: this.customStrategy.energy
            };
          })
          this.buildDimensionRow('节奏', ['松弛', '平衡', '紧凑'], [0, 1, 2], () => this.customStrategy.pace, (val) => {
            this.customStrategy = {
              density: this.customStrategy.density,
              pace: val,
              preference: this.customStrategy.preference,
              energy: this.customStrategy.energy
            };
          })
          this.buildDimensionRow('偏好', ['均衡', '景点', '美食', '文化', '夜景'], [0, 1, 2, 3, 4], () => this.customStrategy.preference, (val) => {
            this.customStrategy = {
              density: this.customStrategy.density,
              pace: this.customStrategy.pace,
              preference: val,
              energy: this.customStrategy.energy
            };
          })
          this.buildDimensionRow('体力', ['轻松', '中等', '充沛'], [0, 1, 2], () => this.customStrategy.energy, (val) => {
            this.customStrategy = {
              density: this.customStrategy.density,
              pace: this.customStrategy.pace,
              preference: this.customStrategy.preference,
              energy: val
            };
          })

          Button('应用自定义策略')
            .type(ButtonType.Normal)
            .backgroundColor(this.getPalette().primary)
            .fontColor(Color.White)
            .width('100%')
            .height(44)
            .borderRadius(8)
            .margin({ top: 16 })
            .onClick(() => {
              this.strategyExplanation = StrategyService.buildComposableExplanation(this.customStrategy);
              this.onCustomStrategyChange(this.customStrategy);
            })
            .gesture(
              LongPressGesture({ repeat: false })
                .onAction(() => {
                  if (this.hasAiHistory) {
                    this.onRegenerateWithCustomStrategy(this.customStrategy);
                    this.controller.close();
                  }
                })
            )

          if (this.hasAiHistory) {
            Text('💡 长按可直接重新生成')
              .fontSize(11)
              .fontColor(this.getPalette().textTertiary)
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 8 })
          }
        }
        .width('100%')
        .padding(12)
        .backgroundColor(this.getPalette().cardBgSoft)
        .borderRadius(8)
        .margin({ top: 12 })
      }

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













