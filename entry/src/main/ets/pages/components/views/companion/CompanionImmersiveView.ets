import { EventEntity } from '../../../../model/entity/EventEntity';
import { CompanionContext } from '../../../../viewmodel/TimelineViewModel';
import { ThemeCenter } from '../../../../common/utils/ThemeCenter';

export type ImmersiveSwipePhase = 'start' | 'update' | 'end';

@Component
export struct CompanionImmersiveView {
  @Prop context: CompanionContext;
  @Prop immersiveText: string = '';
  @Prop immersiveDragOffsetY: number = 0;
  @Prop safeTopInset: number = 0;
  @Prop safeBottomInset: number = 0;
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  getRuntimeLabel: () => string = () => '--';
  getPlannedRange: (event: EventEntity) => string = (_event: EventEntity) => '--';
  getForecastStartText: (event: EventEntity) => string = (_event: EventEntity) => '--';
  isCurrentEventPending: () => boolean = () => false;
  isCurrentEventActive: () => boolean = () => false;
  canStartFocused: (event: EventEntity) => boolean = (_event: EventEntity) => false;
  canEndFocused: (event: EventEntity) => boolean = (_event: EventEntity) => false;

  onStartEvent: (event: EventEntity) => Promise<void> | void = (_event: EventEntity) => {};
  onEndEvent: (event: EventEntity) => Promise<void> | void = (_event: EventEntity) => {};
  onNavigate: (event?: EventEntity) => void = (_event?: EventEntity) => {};
  onSwipeGesture: (phase: ImmersiveSwipePhase, event?: GestureEvent) => void =
    (_phase: ImmersiveSwipePhase, _event?: GestureEvent) => {};

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  build() {
    Column({ space: 18 }) {
      Blank().layoutWeight(1);

      if (this.context.currentEvent) {
        Text(this.context.currentEvent.name)
          .fontSize(42)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getThemePalette().textPrimary)
          .maxLines(2)
          .textAlign(TextAlign.Center)
          .textOverflow({ overflow: TextOverflow.Ellipsis });

        Text(`${this.getRuntimeLabel()} | ${this.getPlannedRange(this.context.currentEvent)}`)
          .fontSize(14)
          .fontColor(this.getThemePalette().textSecondary)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor(this.getThemePalette().cardBgSoft)
          .borderRadius(16);

        Row({ space: 10 }) {
          if (this.isCurrentEventPending()) {
            Button('开始')
              .layoutWeight(2)
              .height(50)
              .enabled(this.canStartFocused(this.context.currentEvent))
              .backgroundColor(this.getThemePalette().success)
              .fontColor(Color.White)
              .onClick(async () => {
                const current = this.context.currentEvent;
                if (!current) {
                  return;
                }
                await this.onStartEvent(current);
              });
          } else if (this.isCurrentEventActive() || this.context.runtimeState === 'PAUSED') {
            Button('结束')
              .layoutWeight(2)
              .height(50)
              .enabled(this.canEndFocused(this.context.currentEvent))
              .backgroundColor(this.getThemePalette().warning)
              .fontColor(Color.White)
              .onClick(async () => {
                const current = this.context.currentEvent;
                if (!current) {
                  return;
                }
                await this.onEndEvent(current);
              });
          }
          Button('导航')
            .layoutWeight(1)
            .height(50)
            .backgroundColor(this.getThemePalette().primary)
            .fontColor(Color.White)
            .onClick(() => this.onNavigate(this.context.currentEvent || undefined));
        }
        .width('78%');
      } else {
        Text('当前暂无进行中的地点')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getThemePalette().textPrimary);
        Text(this.immersiveText)
          .fontSize(16)
          .fontColor(this.getThemePalette().textSecondary)
          .textAlign(TextAlign.Center)
          .padding({ left: 28, right: 28 });
        if (this.context.nextEvent) {
          Text(`下一站：${this.context.nextEvent.name}（${this.getForecastStartText(this.context.nextEvent)}）`)
            .fontSize(14)
            .fontColor(this.getThemePalette().textSecondary)
            .textAlign(TextAlign.Center)
            .padding({ left: 28, right: 28 });
        }
      }

      Text('上滑进入控制页')
        .fontSize(12)
        .fontColor(this.getThemePalette().textTertiary)
        .margin({ top: 10 });

      Blank().layoutWeight(1);
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: this.safeTopInset + 12, bottom: this.safeBottomInset + 12 })
    .backgroundColor(this.getThemePalette().immersiveBg)
    .translate({ y: this.immersiveDragOffsetY })
    .priorityGesture(
      PanGesture({ direction: PanDirection.Vertical, distance: 64 })
        .onActionStart((event: GestureEvent) => {
          this.onSwipeGesture('start', event);
        })
        .onActionUpdate((event: GestureEvent) => {
          this.onSwipeGesture('update', event);
        })
        .onActionEnd((event: GestureEvent) => {
          this.onSwipeGesture('end', event);
        })
    );
  }
}
