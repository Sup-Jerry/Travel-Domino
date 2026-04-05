import {
  AdvanceAdjustCandidate,
  AdvanceAdjustContext,
  AdvanceAdjustPreview,
  TimelineViewModel
} from '../../../viewmodel/TimelineViewModel';

@CustomDialog
export struct AdvanceAdjustDialog {
  controller: CustomDialogController;
  vm: TimelineViewModel = new TimelineViewModel();
  targetIndex: number = -1;
  targetName: string = '';
  onConfirm: (selectedIds: number[], targetStartTime: string) => void = () => {};
  onCancel: () => void = () => {};

  @State context: AdvanceAdjustContext | null = null;
  @State selectedIds: Set<number> = new Set();
  @State targetStartTime: string = '';
  @State preview: AdvanceAdjustPreview | null = null;

  aboutToAppear(): void {
    this.context = this.vm.compressionCoordinator.buildAdvanceAdjustContext(this.targetIndex);
    if (!this.context || this.context.candidates.length === 0) {
      this.preview = null;
      return;
    }
    this.context.candidates.forEach((item) => this.selectedIds.add(item.id));
    this.selectedIds = new Set(this.selectedIds);
    const first = this.context.candidates[0];
    const firstMinutes = this.timeToMinutes(first.currentStartTime);
    const defaultMinutes = Math.max(0, firstMinutes - 30);
    this.targetStartTime = this.minutesToTime(defaultMinutes);
    this.refreshPreview();
  }

  private timeToMinutes(time: string): number {
    const parts = time.split(':');
    if (parts.length < 2) {
      return 0;
    }
    const hour = Number.parseInt(parts[0], 10);
    const minute = Number.parseInt(parts[1], 10);
    if (!Number.isFinite(hour) || !Number.isFinite(minute)) {
      return 0;
    }
    return Math.max(0, Math.min(23, hour)) * 60 + Math.max(0, Math.min(59, minute));
  }

  private minutesToTime(minutes: number): string {
    const normalized = ((Math.floor(minutes) % (24 * 60)) + (24 * 60)) % (24 * 60);
    const h = Math.floor(normalized / 60);
    const m = normalized % 60;
    const hh = h < 10 ? `0${h}` : `${h}`;
    const mm = m < 10 ? `0${m}` : `${m}`;
    return `${hh}:${mm}`;
  }

  private refreshPreview(): void {
    if (!this.context) {
      this.preview = null;
      return;
    }
    this.preview = this.vm.compressionCoordinator.previewAdvanceAdjust(this.targetIndex, this.selectedIds, this.targetStartTime);
  }

  private toggleOne(id: number, checked: boolean): void {
    if (checked) {
      this.selectedIds.add(id);
    } else {
      this.selectedIds.delete(id);
    }
    this.selectedIds = new Set(this.selectedIds);
    this.refreshPreview();
  }

  build() {
    Column() {
      Text('鍓嶇Щ璋冩暣')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .width('100%')
      Text(`鐩爣鍐茬獊鐐癸細${this.targetName}`)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .margin({ top: 4, bottom: 10 })
      Text('请选择连续地点，并设置所选首地点的新开始时间')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .margin({ bottom: 12 })

      if (!this.context || this.context.candidates.length === 0) {
        Text('当前冲突前不存在可调整区间')
          .fontSize(13)
          .fontColor('#FF4D4F')
          .width('100%')
      } else {
        List({ space: 8 }) {
          ForEach(this.context.candidates, (item: AdvanceAdjustCandidate) => {
            ListItem() {
              Row() {
                Checkbox()
                  .select(this.selectedIds.has(item.id))
                  .onChange((checked: boolean) => this.toggleOne(item.id, checked))
                  .margin({ right: 8 })
                Column() {
                  Text(item.name)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                  Text(`${item.currentStartTime} - ${item.currentEndTime} 路 ${item.duration}m`)
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding(10)
              .backgroundColor('#FAFAFA')
              .borderRadius(10)
            }
          })
        }
        .layoutWeight(1)
        .width('100%')
        .edgeEffect(EdgeEffect.Spring)

        Row() {
          Text('新开始时间')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
          TextInput({ text: this.targetStartTime, placeholder: 'HH:mm' })
            .type(InputType.Normal)
            .width(120)
            .height(38)
            .margin({ left: 10 })
            .onChange((value: string) => {
              this.targetStartTime = value.trim();
              this.refreshPreview();
            })
        }
        .width('100%')
        .margin({ top: 10 })

        Column() {
          Text(`宸查€?${this.preview?.selectedCount ?? 0} 涓紝棰勮鍓嶇Щ ${this.preview?.shiftMinutes ?? 0} 鍒嗛挓`)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
          Text(`首地点：${this.preview?.firstNewStartTime ?? '-'}，末地点：${this.preview?.lastNewEndTime ?? '-'}`)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .margin({ top: 4 })
          if (!(this.preview?.valid ?? false)) {
            Text(this.preview?.message ?? '褰撳墠閫夋嫨鏃犳晥')
              .fontSize(12)
              .fontColor('#FF4D4F')
              .width('100%')
              .margin({ top: 4 })
          }
        }
        .width('100%')
        .margin({ top: 10 })
      }

      Row() {
        Button('鍙栨秷', { type: ButtonType.Capsule })
          .width('40%')
          .backgroundColor('#F2F4F7')
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => {
            this.controller.close();
            this.onCancel();
          })
        Button('纭鍓嶇Щ', { type: ButtonType.Capsule })
          .width('45%')
          .backgroundColor($r('app.color.accent_primary'))
          .fontColor(Color.White)
          .enabled(this.preview?.valid ?? false)
          .onClick(() => {
            if (!(this.preview?.valid ?? false)) {
              return;
            }
            this.controller.close();
            this.onConfirm(Array.from(this.selectedIds), this.targetStartTime);
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 12 })
    }
    .padding(16)
    .width('90%')
    .constraintSize({ maxHeight: '85%' })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
  }
}

