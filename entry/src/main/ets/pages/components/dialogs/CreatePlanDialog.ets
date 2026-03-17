// 文件路径: ets/pages/components/CreatePlanDialog.ets
import { ThemeCenter } from '../../../common/utils/ThemeCenter';
import { DomainConstants } from '../../../common/constants/DomainConstants';
import { PlanRepositoryImpl } from '../../../infrastructure/persistence/PlanRepositoryImpl';

@CustomDialog
export struct CreatePlanDialog {
  controller: CustomDialogController;
  onPlanCreated: (planId: number, title: string) => void = () => {};
  onCreatePlan: (title: string, startDate: number) => Promise<number> = async (_title: string, _startDate: number) => -1;

  @State title: string = '';
  // [Phase 2] 默认为今天
  @State selectedDate: Date = new Date();
  @State selectedStrategy: number = 0;
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  private getPalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  build() {
    Column() {
      Text('创建新计划')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getPalette().textPrimary)
        .margin({ bottom: 20 })

      // 1. 输入标题
      TextInput({ placeholder: '给计划起个名字 (如: 东京攻略)' })
        .backgroundColor(this.getPalette().cardBgSoft)
        .fontColor(this.getPalette().textPrimary)
        .placeholderColor(this.getPalette().textTertiary)
        .onChange((value: string) => {
          this.title = value;
        })
        .margin({ bottom: 15 })

      // 2. [Phase 2] 选择出发日期
      Row() {
        Text('出发日期')
          .fontSize(16)
          .fontColor(this.getPalette().textSecondary)

        Blank()

        // 显示当前选择的日期 (格式: YYYY/M/D)
        Text(`${this.selectedDate.getFullYear()}/${this.selectedDate.getMonth() + 1}/${this.selectedDate.getDate()}`)
          .fontSize(16)
          .fontColor(this.getPalette().textPrimary)
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .padding({ top: 10, bottom: 10 })
      .backgroundColor(this.getPalette().cardBgSoft)
      .border({ width: 1, color: this.getPalette().divider })
      .borderRadius(8)
      .margin({ bottom: 20 })
      .onClick(() => {
        // [Phase 2] 弹出日期选择器
        this.getUIContext().showDatePickerDialog({
          start: new Date(DomainConstants.DATE_PICKER_MIN),
          end: new Date(DomainConstants.DATE_PICKER_MAX),
          selected: this.selectedDate,
          onAccept: (value: DatePickerResult) => {
            // 更新 State，触发 UI 刷新
            this.selectedDate.setFullYear(value.year, value.month, value.day);
            // 强制刷新 (ArkUI有时监听不到 Date 内部变化)
            this.selectedDate = new Date(this.selectedDate);
          }
        })
      })

      // 策略选择
      Text('旅行策略（可选）')
        .fontSize(14)
        .fontColor(this.getPalette().textSecondary)
        .margin({ bottom: 8 })
        .alignSelf(ItemAlign.Start)

      Row() {
        Button() { Text('✨ 默认').fontSize(13) }
          .height(34)
          .backgroundColor(this.selectedStrategy === 0 ? this.getPalette().primary : this.getPalette().cardBgSoft)
          .fontColor(this.selectedStrategy === 0 ? Color.White : this.getPalette().textPrimary)
          .borderRadius(8)
          .layoutWeight(1)
          .onClick(() => { this.selectedStrategy = 0; })

        Button() { Text('⚡ 特种兵').fontSize(13) }
          .height(34)
          .backgroundColor(this.selectedStrategy === 1 ? this.getPalette().primary : this.getPalette().cardBgSoft)
          .fontColor(this.selectedStrategy === 1 ? Color.White : this.getPalette().textPrimary)
          .borderRadius(8)
          .layoutWeight(1)
          .margin({ left: 6 })
          .onClick(() => { this.selectedStrategy = 1; })

        Button() { Text('☕ 休闲').fontSize(13) }
          .height(34)
          .backgroundColor(this.selectedStrategy === 2 ? this.getPalette().primary : this.getPalette().cardBgSoft)
          .fontColor(this.selectedStrategy === 2 ? Color.White : this.getPalette().textPrimary)
          .borderRadius(8)
          .layoutWeight(1)
          .margin({ left: 6 })
          .onClick(() => { this.selectedStrategy = 2; })
      }
      .width('100%')
      .margin({ bottom: 20 })

      // 3. 按钮组
      Row() {
        Button('取消')
          .backgroundColor(this.getPalette().cardBgSoft)
          .fontColor(this.getPalette().textSecondary)
          .onClick(() => {
            this.controller.close();
          })
          .width('40%')

        Blank()

        Button('创建')
          .backgroundColor(this.getPalette().primary)
          .fontColor(Color.White)
          .onClick(async () => {
            if (this.title.length > 0) {
              const newPlanId = await this.onCreatePlan(this.title, this.selectedDate.getTime());
              if (newPlanId > 0) {
                // 如果选择了非默认策略，设置策略模式
                if (this.selectedStrategy > 0) {
                  await PlanRepositoryImpl.updateStrategyMode(newPlanId, this.selectedStrategy);
                }
                this.onPlanCreated(newPlanId, this.title);
                this.controller.close();
              }
            }
          })
          .width('40%')
      }
      .width('100%')
    }
    .padding(20)
    .backgroundColor(this.getPalette().cardBg)
    .borderRadius(16)
  }
}

