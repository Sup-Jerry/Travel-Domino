import { promptAction } from '@kit.ArkUI';
import {
  CompressionMode,
  CompressionPlan,
  CompressionSelectionCandidate,
  CompressionSelectionContext,
  TimelineViewModel
} from '../../../viewmodel/TimelineViewModel';

@CustomDialog
export struct ConflictCompressDialog {
  controller: CustomDialogController;
  vm: TimelineViewModel = new TimelineViewModel();

  targetIndex: number = -1;
  targetTime: string = '09:00';
  targetName: string = '';
  initialMode: CompressionMode = 'RATIO';
  initialSelectedIds: number[] = [];
  forcedGapMinutes: number = 0;

  onConfirm: (selectedIds: number[], mode: CompressionMode) => void = () => {};
  onCancel: () => void = () => {};

  @State mode: CompressionMode = 'RATIO';
  @State context: CompressionSelectionContext | null = null;
  @State selectedIds: Set<number> = new Set();
  @State previewPlan: CompressionPlan | null = null;

  private safeShowToast(message: string, duration?: number): void {
    try {
      if (typeof duration === 'number') {
        promptAction.openToast({ message: message, duration: duration });
      } else {
        promptAction.openToast({ message: message });
      }
    } catch (_error) {
    }
  }

  aboutToAppear() {
    this.mode = this.initialMode;
    this.context = this.vm.compressionCoordinator.buildCompressionSelectionContext(
      this.targetIndex,
      this.targetTime,
      this.forcedGapMinutes
    );
    if (!this.context) {
      this.previewPlan = null;
      return;
    }

    const selectable = this.getSelectableCandidates();
    if (this.initialSelectedIds.length > 0) {
      const selectableSet = new Set<number>(selectable.map((item) => item.id));
      this.initialSelectedIds.forEach((id) => {
        if (selectableSet.has(id)) {
          this.selectedIds.add(id);
        }
      });
      if (this.selectedIds.size === 0) {
        selectable.forEach((item) => this.selectedIds.add(item.id));
      }
    } else {
      selectable.forEach((item) => this.selectedIds.add(item.id));
    }
    this.selectedIds = new Set(this.selectedIds);
    this.refreshPreview();
  }

  private refreshPreview(): void {
    if (!this.context) {
      this.previewPlan = null;
      return;
    }
    this.previewPlan = this.vm.compressionCoordinator.calculateCompressionPlanBySelection(
      this.targetIndex,
      this.targetTime,
      this.selectedIds,
      this.mode,
      this.forcedGapMinutes
    );
  }

  private getSelectableCandidates(): CompressionSelectionCandidate[] {
    if (!this.context) {
      return [];
    }
    return this.context.candidates.filter((item) => item.selectable);
  }

  private isAllSelected(): boolean {
    const selectable = this.getSelectableCandidates();
    return selectable.length > 0 && this.selectedIds.size === selectable.length;
  }

  private toggleSelectAll(next: boolean): void {
    if (next) {
      const selectable = this.getSelectableCandidates();
      selectable.forEach((item) => this.selectedIds.add(item.id));
    } else {
      this.selectedIds.clear();
    }
    this.selectedIds = new Set(this.selectedIds);
    this.refreshPreview();
  }

  private toggleOne(candidate: CompressionSelectionCandidate, checked: boolean): void {
    if (!candidate.selectable) {
      return;
    }
    if (checked) {
      this.selectedIds.add(candidate.id);
    } else {
      this.selectedIds.delete(candidate.id);
    }
    this.selectedIds = new Set(this.selectedIds);
    this.refreshPreview();
  }

  private getPreviewNewDuration(candidate: CompressionSelectionCandidate): number {
    if (!this.previewPlan) {
      return candidate.oldVal;
    }
    const match = this.previewPlan.affectedItems.find((item) => item.index === candidate.index);
    return match ? match.newVal : candidate.oldVal;
  }

  private getPreviewReduced(candidate: CompressionSelectionCandidate): number {
    return candidate.oldVal - this.getPreviewNewDuration(candidate);
  }

  private getRemainingGap(): number {
    return this.previewPlan?.remainingGapMinutes ?? 0;
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text('压缩前序地点')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
          Text(`目标：${this.targetName} ${this.targetTime}`)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Text('✕')
          .fontSize(20)
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => {
            this.controller.close();
            this.onCancel();
          })
      }
      .width('100%')
      .margin({ bottom: 12 })

      if (!this.context) {
        Text('当前上下文无法计算压缩候选，请返回重试。')
          .fontSize(14)
          .fontColor('#FF4D4F')
          .width('100%')
      } else {
        Text(`需压缩 ${this.context.neededGapMinutes} 分钟；可压缩上限 ${this.previewPlan?.capacityMinutes ?? 0} 分钟`)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .margin({ bottom: 12 })

        Row() {
          Text('均分模式')
            .fontSize(14)
            .fontColor(this.mode === 'EQUAL' ? Color.White : '#666')
            .backgroundColor(this.mode === 'EQUAL' ? '#007DFF' : Color.Transparent)
            .borderRadius(16)
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .onClick(() => {
              this.mode = 'EQUAL';
              this.refreshPreview();
            })
          Text('按比例模式')
            .fontSize(14)
            .fontColor(this.mode === 'RATIO' ? Color.White : '#666')
            .backgroundColor(this.mode === 'RATIO' ? '#007DFF' : Color.Transparent)
            .borderRadius(16)
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .margin({ left: 8 })
            .onClick(() => {
              this.mode = 'RATIO';
              this.refreshPreview();
            })
        }
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(20)
        .padding(4)
        .margin({ bottom: 12 })

        Row() {
          Checkbox()
            .select(this.isAllSelected())
            .enabled(this.getSelectableCandidates().length > 0)
            .onChange((checked: boolean) => this.toggleSelectAll(checked))
          Text(`全选可压缩地点 (${this.selectedIds.size}/${this.getSelectableCandidates().length})`)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .margin({ left: 8 })
        }
        .width('100%')
        .margin({ bottom: 8 })

        List({ space: 8 }) {
          ForEach(this.context.candidates, (candidate: CompressionSelectionCandidate) => {
            ListItem() {
              Row() {
                Checkbox()
                  .select(this.selectedIds.has(candidate.id))
                  .enabled(candidate.selectable)
                  .onChange((checked: boolean) => this.toggleOne(candidate, checked))
                  .margin({ right: 10 })

                Column() {
                  Row() {
                    Text(candidate.name)
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                    if (candidate.isRigid) {
                      Text('刚性')
                        .fontSize(10)
                        .fontColor(Color.White)
                        .backgroundColor('#FF9800')
                        .padding({ left: 4, right: 4 })
                        .borderRadius(4)
                        .margin({ left: 6 })
                    }
                  }
                  .width('100%')

                  Text(`${candidate.oldVal}m -> ${this.getPreviewNewDuration(candidate)}m  (压缩 ${this.getPreviewReduced(candidate)}m)`)
                    .fontSize(12)
                    .fontColor(candidate.selectable ? '#666' : '#999')
                    .margin({ top: 4 })

                  if (!candidate.selectable && candidate.disabledReason) {
                    Text(candidate.disabledReason)
                      .fontSize(11)
                      .fontColor('#FF4D4F')
                      .margin({ top: 2 })
                  }
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                .opacity(candidate.selectable ? 1 : 0.55)
              }
              .width('100%')
              .padding(12)
              .backgroundColor('#FAFAFA')
              .borderRadius(10)
            }
          })
        }
        .layoutWeight(1)
        .width('100%')
        .edgeEffect(EdgeEffect.Spring)

        if (this.previewPlan?.status === 'OVERLOAD' && this.getRemainingGap() > 0) {
          Text(`仍冲突 ${this.getRemainingGap()} 分钟，建议最早开始 ${this.previewPlan?.suggestedTime ?? this.targetTime}`)
            .fontSize(12)
            .fontColor('#FF4D4F')
            .width('100%')
            .margin({ top: 10 })
        }

        Row() {
          Button('取消', { type: ButtonType.Capsule })
            .width('40%')
            .backgroundColor('#F2F4F7')
            .fontColor($r('app.color.text_secondary'))
            .onClick(() => {
              this.controller.close();
              this.onCancel();
            })

          Button('确认压缩', { type: ButtonType.Capsule })
            .width('45%')
            .backgroundColor($r('app.color.accent_primary'))
            .fontColor(Color.White)
            .onClick(() => {
              if (this.selectedIds.size === 0) {
                this.safeShowToast('请先选择至少一个可压缩地点', 2000);
                return;
              }
              this.controller.close();
              this.onConfirm(Array.from(this.selectedIds), this.mode);
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 12 })
      }
    }
    .padding(16)
    .width('90%')
    .constraintSize({ maxHeight: '82%' })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
  }
}











