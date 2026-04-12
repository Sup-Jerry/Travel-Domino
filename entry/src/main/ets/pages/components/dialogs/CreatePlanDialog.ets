// 文件路径: ets/pages/components/CreatePlanDialog.ets
import { ThemeCenter } from '../../../common/utils/ThemeCenter';
import { DomainConstants } from '../../../common/constants/DomainConstants';

export function formatCreatePlanDateText(selectedDate: Date): string {
  return `${selectedDate.getFullYear()}/${selectedDate.getMonth() + 1}/${selectedDate.getDate()}`;
}

export function canCreatePlanWithTitle(title: string): boolean {
  return title.trim().length > 0;
}

@CustomDialog
export struct CreatePlanDialog {
  controller: CustomDialogController;
  onPlanCreated: (planId: number, title: string) => void = () => {};
  onCreatePlan: (title: string, startDate: number) => Promise<number> = async (_title: string, _startDate: number) => -1;

  @State title: string = '';
  // [Phase 2] 默认为今天
  @State selectedDate: Date = new Date();
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
        Text(formatCreatePlanDateText(this.selectedDate))
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
            if (canCreatePlanWithTitle(this.title)) {
              const newPlanId = await this.onCreatePlan(this.title, this.selectedDate.getTime());
              if (newPlanId > 0) {
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

