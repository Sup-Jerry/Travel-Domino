import { ThemeCenter } from '../../../common/utils/ThemeCenter';

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
  @State selectedStrategy: number = 0;

  private getPalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  aboutToAppear() {
    this.selectedStrategy = this.currentStrategyMode;
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









