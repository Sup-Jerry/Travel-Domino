import { TravelPlanItem } from '../../../model/interface/IStandardEvent';


type PlanItemNumberAction = (value: number) => void;

export function shouldPlanItemShowCrossDayLabel(computedStartTime: string): boolean {
  return (computedStartTime || '').indexOf('-') >= 0;
}

export function resolvePlanItemTimeText(timeText: string): string {
  return (timeText && timeText.length > 0) ? timeText : '--:--';
}

export function canPlanItemShowConflictFixButton(isConflict: boolean, suggestedShiftMinutes: number): boolean {
  return !!isConflict && (suggestedShiftMinutes || 0) > 0;
}

export interface PlanItemDisplayState {
  showCrossDayLabel: boolean;
  startText: string;
  endText: string;
  showConflict: boolean;
  conflictText: string;
  showConflictFixButton: boolean;
  fixButtonMinutes: number;
}

export function resolvePlanItemDisplayState(item: TravelPlanItem): PlanItemDisplayState {
  const rawStartTime = item.computedStartTime || '';
  const showCrossDayLabel = shouldPlanItemShowCrossDayLabel(rawStartTime);
  const fixButtonMinutes = item.suggestedShiftMinutes || 0;
  const showConflict = !!item.isConflict;
  return {
    showCrossDayLabel: showCrossDayLabel,
    startText: showCrossDayLabel ? rawStartTime : resolvePlanItemTimeText(rawStartTime),
    endText: resolvePlanItemTimeText(item.computedEndTime || ''),
    showConflict: showConflict,
    conflictText: item.conflictMsg || '时间冲突',
    showConflictFixButton: canPlanItemShowConflictFixButton(showConflict, fixButtonMinutes),
    fixButtonMinutes: fixButtonMinutes
  };
}

@Component
export struct PlanItemView {
  @ObjectLink item: TravelPlanItem;
  @Prop index: number;

  // 回调函数
  onDurationChange: PlanItemNumberAction = () => {};
  onCommuteChange: PlanItemNumberAction = () => {};

  // [新增] 修复冲突回调
  onFixConflict: PlanItemNumberAction = () => {};

  private getDisplayState(): PlanItemDisplayState {
    return resolvePlanItemDisplayState(this.item);
  }

  build() {
    Row() {
      // 1. 左侧：时间轴
      Column() {
        if (this.getDisplayState().showCrossDayLabel) {
          // 跨天显示日期 (简易版样式)
          Text(this.getDisplayState().startText).fontSize(10).fontColor('#666666')
        } else {
          Text(this.getDisplayState().startText).fontSize(14).fontWeight(FontWeight.Bold)
        }
        // 连接线 (这里简化显示，实际可以用 Line 组件)
        Text('|').fontSize(10).fontColor('#CCCCCC').margin({ top: 2, bottom: 2 })
        Text(this.getDisplayState().endText).fontSize(12).fontColor('#999999')
      }
      .width(50)
      .alignItems(HorizontalAlign.End)
      .margin({ right: 12 })

      // 2. 右侧：卡片内容
      Column() {
        Row() {
          Text(this.item.name)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)

          // 时长
          Text(`${this.item.duration} min`)
            .fontSize(12)
            .fontColor('#007DFF')
            .backgroundColor('#E6F2FF')
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(4)
            .onClick(() => {
              // 模拟修改时长：简单点，每次+10分钟用于测试
              this.onDurationChange(this.item.duration + 30);
            })
        }
        .width('100%')
        .margin({ bottom: 8 })

        // 详情/备注
        if (this.item.note) {
          Text(this.item.note).fontSize(12).fontColor('#999999').margin({ bottom: 8 })
        }

        // --- 🚨 [核心新增] 冲突报警区域 ---
        if (this.getDisplayState().showConflict) {
          Column() {
            // 红色警告文案
            Text(`⚠️ ${this.getDisplayState().conflictText}`)
              .fontSize(12)
              .fontColor(Color.Red)
              .margin({ bottom: 4 })

            // 修复按钮 (仅当有建议时间时显示)
            if (this.getDisplayState().showConflictFixButton) {
              Button(`一键推迟 ${this.getDisplayState().fixButtonMinutes} 分钟`)
                .fontSize(12)
                .height(28)
                .backgroundColor('#FF5252') // 警示红
                .fontColor(Color.White)
                .onClick(() => {
                  // 触发修复
                  this.onFixConflict(this.getDisplayState().fixButtonMinutes);
                })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(8)
          .backgroundColor('#FFF0F0') // 淡红背景
          .borderRadius(8)
        }
        // ------------------------------------

      }
      .layoutWeight(1)
      .padding(12)
      .backgroundColor(Color.White)
      .borderRadius(12)
      .shadow({ radius: 4, color: '#1A000000', offsetY: 2 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }
}








