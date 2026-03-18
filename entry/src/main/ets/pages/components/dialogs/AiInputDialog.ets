// 文件路径: ets/pages/components/AiInputDialog.ets
import { promptAction } from '@kit.ArkUI';
import { ThemeCenter } from '../../../common/utils/ThemeCenter';
import { ComposableStrategy, DensityLevel, PaceLevel, PreferenceType, EnergyLevel } from '../../../domain/strategy/TravelStrategyDimensions';

@CustomDialog
export struct AiInputDialog {
  controller: CustomDialogController
  onConfirm: (text: string, strategy: number, customStrategy?: ComposableStrategy) => void = (text: string, strategy: number, customStrategy?: ComposableStrategy) => {}
  onRegenerate: () => void = () => {}
  hasAiHistory: boolean = false
  @State inputText: string = ''
  @State isLoading: boolean = false
  @State selectedStrategy: number = 0
  @State useCustomStrategy: boolean = false
  @State customStrategy: ComposableStrategy = {
    density: DensityLevel.MEDIUM,
    pace: PaceLevel.BALANCED,
    preference: PreferenceType.BALANCED,
    energy: EnergyLevel.MEDIUM
  }
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light'

  private getPalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  private getStrategyExplanation(mode: number): string {
    if (mode === 1) {
      return '特种兵模式：优先提高每日覆盖率与景点数量，适合体力充沛、追求高效打卡的旅行者';
    }
    if (mode === 2) {
      return '休闲模式：优先降低日内移动强度与景点密度，适合放松度假、慢节奏体验的旅行者';
    }
    return '';
  }

  private getLoadingText(): string {
    if (this.selectedStrategy === 1) {
      return '正在生成行程（预计30-60秒）';
    } else if (this.selectedStrategy === 2) {
      return '正在生成行程（预计20-40秒）';
    }
    return '正在生成行程（预计30-50秒）';
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
    Scroll() {
      Column() {
        Text('AI 灵感助手 ✨')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getPalette().textPrimary)
          .margin({ bottom: 16, top: 8 })

      TextArea({ placeholder: '例如：帮我规划一个西安两日游，想看兵马俑和吃面...' })
        .height(120)
        .backgroundColor(this.getPalette().cardBgSoft)
        .fontColor(this.getPalette().textPrimary)
        .placeholderColor(this.getPalette().textTertiary)
        .borderRadius(8)
        .onChange((value) => {
          this.inputText = value;
        })

      Row() {
        Text('旅行节奏')
          .fontSize(14)
          .fontColor(this.getPalette().textSecondary)
          .margin({ right: 12 })

        Scroll() {
          Row() {
            Button() {
              Row() {
                Text('✨ 默认').fontSize(14)
              }
            }
            .height(36)
            .backgroundColor(this.selectedStrategy === 0 ? this.getPalette().primary : this.getPalette().cardBgSoft)
            .fontColor(this.selectedStrategy === 0 ? Color.White : this.getPalette().textPrimary)
            .borderRadius(8)
            .onClick(() => { this.selectedStrategy = 0; })

            Button() {
              Row() {
                Text('⚡ 特种兵').fontSize(14)
              }
            }
            .height(36)
            .backgroundColor(this.selectedStrategy === 1 ? this.getPalette().primary : this.getPalette().cardBgSoft)
            .fontColor(this.selectedStrategy === 1 ? Color.White : this.getPalette().textPrimary)
            .borderRadius(8)
            .margin({ left: 8 })
            .onClick(() => { this.selectedStrategy = 1; })

            Button() {
              Row() {
                Text('☕ 休闲').fontSize(14)
              }
            }
            .height(36)
            .backgroundColor(this.selectedStrategy === 2 ? this.getPalette().primary : this.getPalette().cardBgSoft)
            .fontColor(this.selectedStrategy === 2 ? Color.White : this.getPalette().textPrimary)
            .borderRadius(8)
            .margin({ left: 8 })
            .onClick(() => { this.selectedStrategy = 2; this.useCustomStrategy = false; })

            Button() {
              Row() {
                Text('🎨 自定义').fontSize(14)
              }
            }
            .height(36)
            .backgroundColor(this.useCustomStrategy ? this.getPalette().primary : this.getPalette().cardBgSoft)
            .fontColor(this.useCustomStrategy ? Color.White : this.getPalette().textPrimary)
            .borderRadius(8)
            .margin({ left: 8 })
            .onClick(() => { this.useCustomStrategy = true; })
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .margin({ top: 16 })

      if (this.selectedStrategy > 0) {
        Row() {
          Text('💡')
            .fontSize(14)
            .margin({ right: 6 })
          Text(this.getStrategyExplanation(this.selectedStrategy))
            .fontSize(12)
            .fontColor(this.getPalette().textSecondary)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 8, left: 8, right: 8 })
        .backgroundColor(this.getPalette().cardBgSoft)
        .borderRadius(8)
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

          // 偏好行 - 分2行显示
          Column() {
            Row() {
              Text('偏好').fontSize(14).fontColor(this.getPalette().textSecondary).width(60)
              Button('均衡')
                .height(36).fontSize(13)
                .backgroundColor(this.customStrategy.preference === 0 ? this.getPalette().primary : this.getPalette().cardBgSoft)
                .fontColor(this.customStrategy.preference === 0 ? Color.White : this.getPalette().textPrimary)
                .borderRadius(6).margin({ left: 8 }).padding({ left: 12, right: 12 })
                .onClick(() => {
                  this.customStrategy = {
                    density: this.customStrategy.density,
                    pace: this.customStrategy.pace,
                    preference: 0,
                    energy: this.customStrategy.energy
                  };
                })
              Button('景点')
                .height(36).fontSize(13)
                .backgroundColor(this.customStrategy.preference === 1 ? this.getPalette().primary : this.getPalette().cardBgSoft)
                .fontColor(this.customStrategy.preference === 1 ? Color.White : this.getPalette().textPrimary)
                .borderRadius(6).margin({ left: 8 }).padding({ left: 12, right: 12 })
                .onClick(() => {
                  this.customStrategy = {
                    density: this.customStrategy.density,
                    pace: this.customStrategy.pace,
                    preference: 1,
                    energy: this.customStrategy.energy
                  };
                })
              Button('美食')
                .height(36).fontSize(13)
                .backgroundColor(this.customStrategy.preference === 2 ? this.getPalette().primary : this.getPalette().cardBgSoft)
                .fontColor(this.customStrategy.preference === 2 ? Color.White : this.getPalette().textPrimary)
                .borderRadius(6).margin({ left: 8 }).padding({ left: 12, right: 12 })
                .onClick(() => {
                  this.customStrategy = {
                    density: this.customStrategy.density,
                    pace: this.customStrategy.pace,
                    preference: 2,
                    energy: this.customStrategy.energy
                  };
                })
            }.width('100%')

            Row() {
              Button('文化')
                .height(36).fontSize(13)
                .backgroundColor(this.customStrategy.preference === 3 ? this.getPalette().primary : this.getPalette().cardBgSoft)
                .fontColor(this.customStrategy.preference === 3 ? Color.White : this.getPalette().textPrimary)
                .borderRadius(6).padding({ left: 12, right: 12 })
                .onClick(() => {
                  this.customStrategy = {
                    density: this.customStrategy.density,
                    pace: this.customStrategy.pace,
                    preference: 3,
                    energy: this.customStrategy.energy
                  };
                })
              Button('夜景')
                .height(36).fontSize(13)
                .backgroundColor(this.customStrategy.preference === 4 ? this.getPalette().primary : this.getPalette().cardBgSoft)
                .fontColor(this.customStrategy.preference === 4 ? Color.White : this.getPalette().textPrimary)
                .borderRadius(6).margin({ left: 8 }).padding({ left: 12, right: 12 })
                .onClick(() => {
                  this.customStrategy = {
                    density: this.customStrategy.density,
                    pace: this.customStrategy.pace,
                    preference: 4,
                    energy: this.customStrategy.energy
                  };
                })
            }.width('100%').margin({ top: 8, left: 68 })
          }.width('100%').margin({ top: 8 })

          this.buildDimensionRow('体力', ['低', '中', '高'], [0, 1, 2], () => this.customStrategy.energy, (val) => {
            this.customStrategy = {
              density: this.customStrategy.density,
              pace: this.customStrategy.pace,
              preference: this.customStrategy.preference,
              energy: val
            };
          })
        }
        .width('100%')
        .padding(12)
        .backgroundColor(this.getPalette().cardBgSoft)
        .borderRadius(8)
        .margin({ top: 8 })
      }

      if (this.isLoading) {
        Column() {
          Row() {
            LoadingProgress().width(24).height(24).margin({ right: 8 })
            Text(this.getLoadingText()).fontSize(14).fontColor(this.getPalette().textSecondary)
          }
          Text('请勿退出，生成中...')
            .fontSize(12)
            .fontColor(this.getPalette().textTertiary)
            .margin({ top: 8 })
        }
        .margin({ top: 20 })
      } else {
        Row() {
          Button('取消')
            .height(42)
            .backgroundColor(this.getPalette().cardBg)
            .border({ width: 1, color: this.getPalette().border, radius: 12 })
            .borderRadius(12)
            .fontColor(this.getPalette().textSecondary)
            .onClick(() => {
              this.controller.close();
            })
            .layoutWeight(1)

          if (this.hasAiHistory) {
            Button('AI重新规划')
              .height(42)
              .backgroundColor(this.getPalette().primary)
              .fontColor(Color.White)
              .borderRadius(12)
              .margin({ left: 8 })
              .layoutWeight(1)
              .onClick(() => {
                promptAction.openToast({ message: '正在重新规划行程...' });
                this.onRegenerate();
                this.controller.close();
              });
          }

          Button('生成')
            .height(42)
            .backgroundColor(this.getPalette().primary)
            .fontColor(Color.White)
            .borderRadius(12)
            .margin({ left: 8 })
            .enabled(this.inputText.trim().length > 0)
            .onClick(() => {
              if (this.inputText.trim().length > 0) {
                this.isLoading = true;
                const strategy = this.useCustomStrategy ? -1 : this.selectedStrategy;
                const custom = this.useCustomStrategy ? this.customStrategy : undefined;
                this.onConfirm(this.inputText, strategy, custom);
              } else {
                promptAction.openToast({ message: '请输入需求' });
              }
            })
            .layoutWeight(1)
        }
        .justifyContent(FlexAlign.SpaceBetween)
        .width('100%')
        .margin({ top: 24 })
      }
    }
    .padding(20)
    .backgroundColor(this.getPalette().cardBg)
    .borderRadius(16)
  }
  .scrollable(ScrollDirection.Vertical)
  .scrollBar(BarState.Auto)
  .edgeEffect(EdgeEffect.Spring)
  .friction(0.6)
  .width(360)
  .constraintSize({ maxWidth: '90%' })
  }
}









