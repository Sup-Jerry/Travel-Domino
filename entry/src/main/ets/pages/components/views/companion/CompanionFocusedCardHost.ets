import { EventEntity } from '../../../../model/entity/EventEntity';
import { ThemeCenter } from '../../../../common/utils/ThemeCenter';

type CardPhase = 'stable' | 'outgoing' | 'incoming';

@Component
export struct CompanionFocusedCardHost {
  @Prop canRenderSwitchCards: boolean = false;
  @Prop outgoingEvent: EventEntity | null = null;
  @Prop incomingEvent: EventEntity | null = null;
  @Prop stableEvent: EventEntity | null = null;
  @Prop runtimeState: string = 'IDLE';
  @Prop currentEventId: number = -1;
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  getEventStateLabel: (event: EventEntity) => string = (_event: EventEntity) => '--';
  getStateTagTextColor: (event: EventEntity) => ResourceColor = (_event: EventEntity) => '#666';
  getStateTagBackgroundColor: (event: EventEntity) => ResourceColor = (_event: EventEntity) => '#F5F5F5';
  getStateBorderColor: (event: EventEntity) => ResourceColor = (_event: EventEntity) => '#DDD';
  getMainCardTimeText: (event: EventEntity) => string = (_event: EventEntity) => '--:--';
  getPlannedRange: (event: EventEntity) => string = (_event: EventEntity) => '--';
  getEventState: (event: EventEntity) => string = (_event: EventEntity) => 'PENDING';
  canStartFocused: (event: EventEntity) => boolean = (_event: EventEntity) => false;
  canEndFocused: (event: EventEntity) => boolean = (_event: EventEntity) => false;
  getCardTranslateX: (phase: CardPhase) => number = (_phase: CardPhase) => 0;
  getCardOpacity: (phase: CardPhase) => number = (_phase: CardPhase) => 1;
  getCardScale: (phase: CardPhase) => number = (_phase: CardPhase) => 1;

  onNavigate: (event: EventEntity) => void = (_event: EventEntity) => {};
  onStart: (event: EventEntity) => Promise<void> | void = (_event: EventEntity) => {};
  onSkip: (event: EventEntity) => Promise<void> | void = (_event: EventEntity) => {};
  onEnd: (event: EventEntity) => Promise<void> | void = (_event: EventEntity) => {};
  onReopen: (event: EventEntity) => Promise<void> | void = (_event: EventEntity) => {};
  onAdjust: (event: EventEntity) => Promise<void> | void = (_event: EventEntity) => {};
  onSkipDisabledTap: () => void = () => {};
  onEnterImmersive: () => void = () => {};

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  @Builder
  private FocusedCardBody(event: EventEntity, phase: CardPhase) {
    Column({ space: 10 }) {
      Text(event.name)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getThemePalette().textPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });

      Row({ space: 8 }) {
        Text(this.getEventStateLabel(event))
          .fontSize(12)
          .fontColor(this.getStateTagTextColor(event))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(this.getStateTagBackgroundColor(event))
          .border({ width: 1, color: this.getStateBorderColor(event), radius: 10 })
          .borderRadius(10);
        Text(this.getMainCardTimeText(event))
          .fontSize(12)
          .fontColor(this.getThemePalette().textSecondary)
          .maxLines(1);
      }

      if (this.getEventState(event) !== 'PENDING') {
        Text(`计划 ${this.getPlannedRange(event)}`)
          .fontSize(12)
          .fontColor(this.getThemePalette().textTertiary)
          .maxLines(1);
      }

      Row({ space: 8 }) {
        Button('导航')
          .layoutWeight(1)
          .height(42)
          .backgroundColor(this.getThemePalette().primary)
          .fontColor(Color.White)
          .onClick(() => this.onNavigate(event));

        if (this.getEventState(event) === 'PENDING') {
          Button('开始')
            .layoutWeight(1)
            .height(42)
            .enabled(this.canStartFocused(event))
            .backgroundColor(this.getThemePalette().success)
            .fontColor(Color.White)
            .onClick(async () => {
              await this.onStart(event);
            });
          Button('跳过')
            .layoutWeight(1)
            .height(42)
            .backgroundColor(this.getThemePalette().warning)
            .fontColor(Color.White)
            .onClick(async () => {
              await this.onSkip(event);
            });
        } else if (this.getEventState(event) === 'ACTIVE') {
          Button('结束')
            .layoutWeight(1)
            .height(42)
            .enabled(this.canEndFocused(event))
            .backgroundColor(this.getThemePalette().warning)
            .fontColor(Color.White)
            .onClick(async () => {
              await this.onEnd(event);
            });
        } else if (this.runtimeState === 'PAUSED' && this.currentEventId === event.id) {
          Button('结束')
            .layoutWeight(1)
            .height(42)
            .enabled(this.canEndFocused(event))
            .backgroundColor(this.getThemePalette().warning)
            .fontColor(Color.White)
            .onClick(async () => {
              await this.onEnd(event);
            });
        } else if (this.getEventState(event) === 'SKIPPED') {
          Button('重新开始')
            .layoutWeight(1)
            .height(42)
            .backgroundColor(this.getThemePalette().success)
            .fontColor(Color.White)
            .onClick(async () => {
              await this.onReopen(event);
            });
          Button('跳过')
            .layoutWeight(1)
            .height(42)
            .enabled(false)
            .backgroundColor(this.getThemePalette().cardBgSoft)
            .fontColor(this.getThemePalette().textTertiary)
            .onClick(() => {
              this.onSkipDisabledTap();
            });
        } else {
          Button('结束')
            .layoutWeight(1)
            .height(42)
            .enabled(false)
            .backgroundColor(this.getThemePalette().cardBgSoft)
            .fontColor(this.getThemePalette().textTertiary);
          Button('跳过')
            .layoutWeight(1)
            .height(42)
            .enabled(false)
            .backgroundColor(this.getThemePalette().cardBgSoft)
            .fontColor(this.getThemePalette().textTertiary);
        }
      }
      .width('100%');

      Button('补打卡')
        .type(ButtonType.Capsule)
        .fontSize(12)
        .fontColor(this.getThemePalette().textSecondary)
        .backgroundColor(this.getThemePalette().cardBgSoft)
        .onClick(async () => {
          await this.onAdjust(event);
        });

      Text('点击此卡片进入沉浸模式')
        .fontSize(11)
        .fontColor(this.getThemePalette().primary)
        .padding({ top: 2 });
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(16)
    .backgroundColor(this.getThemePalette().companionCardBg)
    .border({ width: 1, color: this.getStateBorderColor(event), radius: 16 })
    .shadow({ radius: 14, color: '#24000000', offsetY: 5 })
    .borderRadius(16)
    .translate({ x: this.getCardTranslateX(phase), y: 0 })
    .opacity(this.getCardOpacity(phase))
    .scale({
      x: this.getCardScale(phase),
      y: this.getCardScale(phase)
    })
    .onClick(() => {
      this.onEnterImmersive();
    });
  }

  build() {
    Stack() {
      if (this.canRenderSwitchCards && this.outgoingEvent && this.incomingEvent) {
        this.FocusedCardBody(this.outgoingEvent, 'outgoing');
        this.FocusedCardBody(this.incomingEvent, 'incoming');
      } else if (this.stableEvent) {
        this.FocusedCardBody(this.stableEvent, 'stable');
      } else {
        Column({ space: 8 }) {
          Text('暂无焦点任务')
            .fontSize(20)
            .fontColor(this.getThemePalette().textPrimary)
            .fontWeight(FontWeight.Bold);
          Text('点击时间轴条目以聚焦')
            .fontSize(12)
            .fontColor(this.getThemePalette().textSecondary);
        }
        .width('100%')
        .padding(16)
        .backgroundColor(this.getThemePalette().companionCardBg)
        .borderRadius(16);
      }
    }
    .width('100%');
  }
}
