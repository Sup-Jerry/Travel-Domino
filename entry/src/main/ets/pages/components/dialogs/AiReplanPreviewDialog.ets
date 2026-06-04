import { ThemeCenter } from '../../../common/utils/ThemeCenter';
import { ComposableStrategy } from '../../../domain/strategy/TravelStrategyDimensions';
import { AiReplanPreviewItem, AiReplanPreviewResult } from '../../../domain/timeline/services/TimelineAiService';

type AiReplanRegenerateAction = (prompt: string, strategyMode: number, customStrategy?: ComposableStrategy) => void;
type AiReplanVoidAction = () => void;

export function getAiReplanItemTypeLabel(itemType: number): string {
  if (itemType === 1) return '美食';
  if (itemType === 2) return '住宿';
  return '景点';
}

export function getAiReplanStrategyLabel(mode: number): string {
  if (mode === 1) return '特种兵';
  if (mode === 2) return '休闲';
  if (mode === -1) return '自定义';
  return '默认';
}

export function buildAiReplanPreviewSummary(preview: AiReplanPreviewResult): string {
  return `共生成 ${preview.itemCount} 个地点，策略：${getAiReplanStrategyLabel(preview.strategyMode)}`;
}


@CustomDialog
export struct AiReplanPreviewDialog {
  controller: CustomDialogController;
  preview: AiReplanPreviewResult = {
    prompt: '',
    strategyMode: 0,
    generatedAt: 0,
    itemCount: 0,
    items: []
  };
  effectiveTheme: string = 'light';

  onRegenerateAgain: AiReplanRegenerateAction =
    (_prompt: string, _strategyMode: number, _customStrategy?: ComposableStrategy) => {};
  onApplyOverwrite: AiReplanVoidAction = () => {};
  onApplyKeep: AiReplanVoidAction = () => {};
  onCancel: AiReplanVoidAction = () => {};

  private getPalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  private buildItemTypeLabel(itemType: number): string {
    return getAiReplanItemTypeLabel(itemType);
  }

  private buildStrategyLabel(mode: number): string {
    return getAiReplanStrategyLabel(mode);
  }

  build() {
    Column() {
      Text('AI 重新规划预览')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getPalette().textPrimary)
        .margin({ bottom: 10 });

      Text(buildAiReplanPreviewSummary(this.preview))
        .fontSize(13)
        .fontColor(this.getPalette().textSecondary)
        .margin({ bottom: 12 });

      Text(`提示词：${this.preview.prompt}`)
        .fontSize(12)
        .fontColor(this.getPalette().textTertiary)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ bottom: 12 });

      Scroll() {
        Column() {
          ForEach(this.preview.items, (item: AiReplanPreviewItem, index: number) => {
            Row() {
              Text(`${index + 1}. ${item.name}`)
                .fontSize(14)
                .fontColor(this.getPalette().textPrimary)
                .layoutWeight(1);
              Text(`${this.buildItemTypeLabel(item.itemType)} · ${item.duration}分钟`)
                .fontSize(12)
                .fontColor(this.getPalette().textSecondary);
            }
            .width('100%')
            .padding({ top: 10, bottom: 10, left: 10, right: 10 })
            .backgroundColor(this.getPalette().cardBgSoft)
            .borderRadius(8)
            .margin({ bottom: 8 });
          }, (_item: AiReplanPreviewItem, index: number) => `preview-${index}`);
        }
      }
      .height(260)
      .width('100%')
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Auto);

      Row() {
        Button('取消')
          .height(40)
          .layoutWeight(1)
          .backgroundColor(this.getPalette().cardBg)
          .border({ width: 1, color: this.getPalette().border, radius: 12 })
          .fontColor(this.getPalette().textSecondary)
          .onClick(() => {
            this.onCancel();
            this.controller.close();
          });

        Button('重新生成')
          .height(40)
          .layoutWeight(1)
          .margin({ left: 8 })
          .backgroundColor('#6B7280')
          .fontColor(Color.White)
          .onClick(() => {
            this.onRegenerateAgain(this.preview.prompt, this.preview.strategyMode, this.preview.customStrategy);
            this.controller.close();
          });
      }
      .width('100%')
      .margin({ top: 14 });

      Row() {
        Button('保留')
          .height(42)
          .layoutWeight(1)
          .backgroundColor('#16A34A')
          .fontColor(Color.White)
          .onClick(() => {
            this.onApplyKeep();
            this.controller.close();
          });
        Button('覆盖')
          .height(42)
          .layoutWeight(1)
          .margin({ left: 8 })
          .backgroundColor('#2563EB')
          .fontColor(Color.White)
          .onClick(() => {
            this.onApplyOverwrite();
            this.controller.close();
          });
      }
      .width('100%')
      .margin({ top: 10 });
    }
    .padding(18)
    .width('92%')
    .backgroundColor(this.getPalette().cardBg)
    .borderRadius(16);
  }
}
