// 文件路径: ets/pages/components/dialogs/RecordCorrectionDialog.ets
import { EventEntity } from '../../../model/entity/EventEntity';
import { DateUtil } from '../../../common/utils/DateUtil';

@CustomDialog
export struct RecordCorrectionDialog {
  controller: CustomDialogController;
  @Prop event: EventEntity | null = null;

  // 临时状态，用于 TimePicker 显示
  @State startTime: Date = new Date();
  @State endTime: Date = new Date();
  @State hasEndTime: boolean = false;

  // 回调函数
  onConfirm: (startTs: number, endTs: number) => void = () => {};
  onClear: () => void = () => {};

  aboutToAppear() {
    if (!this.event) return;
    const baseTime = this.event.actual_start_time > 0
      ? this.event.actual_start_time
      : (this.event.dynamic_start_time > 0 ? this.event.dynamic_start_time : Date.now());
    this.startTime = new Date(baseTime);
    this.hasEndTime = this.event.actual_end_time > 0;
    this.endTime = this.hasEndTime
      ? new Date(this.event.actual_end_time)
      : new Date(baseTime);
  }

  build() {
    Column({ space: 15 }) {
      Text('修正打卡记录').fontSize(18).fontWeight(FontWeight.Bold).margin({ bottom: 10 })

      // 1. 真实开始时间
      Row() {
        Text('真实开始').fontSize(14).fontColor($r('app.color.text_secondary'))
        Blank()
        Text(DateUtil.formatDate(this.startTime, 'HH:mm'))
          .fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_secondary'))
          .padding(8).backgroundColor('#F0F8FF').borderRadius(8)
          .onClick(() => {
            this.getUIContext().showTimePickerDialog({
              selected: this.startTime,
              useMilitaryTime: true,
              onAccept: (val) => {
                this.startTime.setHours(val.hour, val.minute);
                this.startTime = new Date(this.startTime); // 触发刷新
              }
            })
          })
      }.width('100%')

      // 2. 真实结束时间
      Row() {
        Text('真实结束').fontSize(14).fontColor($r('app.color.text_secondary'))
        Blank()
        Text(this.hasEndTime ? DateUtil.formatDate(this.endTime, 'HH:mm') : '--:--')
          .fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_secondary'))

          .padding(8).backgroundColor('#F0F8FF').borderRadius(8)
          .onClick(() => {
            this.getUIContext().showTimePickerDialog({
              selected: this.endTime,
              useMilitaryTime: true,
              onAccept: (val) => {
                this.endTime.setHours(val.hour, val.minute);
                this.endTime = new Date(this.endTime); // 触发刷新
                this.hasEndTime = true;
              }
            })
          })
      }.width('100%')

      Divider().margin({ top: 10, bottom: 10 })

      // 3. 操作按钮
      Button('🗑️ 清除打卡记录')
        .fontSize(14).fontColor($r('app.color.text_secondary')).backgroundColor(Color.Transparent)
        .onClick(() => {
          this.onClear();
          this.controller.close();
        })

      Row({ space: 12 }) {
        Button('取消').layoutWeight(1).backgroundColor($r('app.color.card_bg')).fontColor($r('app.color.text_secondary'))
          .onClick(() => this.controller.close())
        Button('确定修正').layoutWeight(1).backgroundColor($r('app.color.accent_primary'))
          .onClick(() => {
            this.onConfirm(this.startTime.getTime(), this.hasEndTime ? this.endTime.getTime() : 0);
            this.controller.close();
          })
      }.width('100%').margin({ top: 10 })
    }
    .padding(24).backgroundColor($r('app.color.card_bg')).borderRadius(16).width('90%')
  }
}









