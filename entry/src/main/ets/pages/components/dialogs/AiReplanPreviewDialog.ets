import { ThemeCenter } from '../../../common/utils/ThemeCenter';
import { ComposableStrategy } from '../../../domain/strategy/TravelStrategyDimensions';
import { AiReplanPreviewItem, AiReplanPreviewResult } from '../../../domain/timeline/services/TimelineAiService';

export function getAiReplanItemTypeLabel(itemType: number): string {
  if (itemType === 1) return '缇庨';
  if (itemType === 2) return '浣忓';
  return '鏅偣';
}

export function getAiReplanStrategyLabel(mode: number): string {
  if (mode === 1) return '鐗圭鍏?';
  if (mode === 2) return '浼戦棽';
  if (mode === -1) return '鑷畾涔?';
  return '榛樿';
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

  onRegenerateAgain: (prompt: string, strategyMode: number, customStrategy?: ComposableStrategy) => void =
    (_prompt: string, _strategyMode: number, _customStrategy?: ComposableStrategy) => {};
  onApplyOverwrite: () => void = () => {};
  onApplyKeep: () => void = () => {};
  onCancel: () => void = () => {};

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
      Text('AI 閲嶆柊瑙勫垝棰勮')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getPalette().textPrimary)
        .margin({ bottom: 10 });

      Text(`鍏辩敓鎴?${this.preview.itemCount} 涓湴鐐癸紝绛栫暐锛?{this.buildStrategyLabel(this.preview.strategyMode)}`)
        .fontSize(13)
        .fontColor(this.getPalette().textSecondary)
        .margin({ bottom: 12 });

      Text(`鎻愮ず璇嶏細${this.preview.prompt}`)
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
              Text(`${this.buildItemTypeLabel(item.itemType)} 路 ${item.duration}鍒嗛挓`)
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
        Button('鍙栨秷')
          .height(40)
          .layoutWeight(1)
          .backgroundColor(this.getPalette().cardBg)
          .border({ width: 1, color: this.getPalette().border, radius: 12 })
          .fontColor(this.getPalette().textSecondary)
          .onClick(() => {
            this.onCancel();
            this.controller.close();
          });

        Button('閲嶆柊鐢熸垚')
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
        Button('淇濈暀')
          .height(42)
          .layoutWeight(1)
          .backgroundColor('#16A34A')
          .fontColor(Color.White)
          .onClick(() => {
            this.onApplyKeep();
            this.controller.close();
          });
        Button('瑕嗙洊')
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
