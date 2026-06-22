import { EventEntity } from '../../../../model/entity/EventEntity';
import { CompanionContext } from '../../../../viewmodel/TimelineViewModel';
import { ThemeCenter } from '../../../../common/utils/ThemeCenter';

export type ImmersiveSwipePhase = 'start' | 'update' | 'end';

export function shouldShowImmersivePrimaryAction(
  isPending: boolean,
  isActive: boolean,
  runtimeState: string
): boolean {
  return isPending || isActive || runtimeState === 'PAUSED';
}

export function getImmersivePrimaryActionLabel(isPending: boolean): string {
  return isPending ? '开始' : '结束';
}

export function getImmersivePrimaryActionEnabled(
  isPending: boolean,
  canStartFocused: boolean,
  canEndFocused: boolean
): boolean {
  return isPending ? canStartFocused : canEndFocused;
}

export function getImmersiveNextStationText(name: string, forecastStart: string): string {
  return `下一站：${name}（${forecastStart}）`;
}

export interface ImmersiveCurrentRenderSections {
  currentEvents: EventEntity[];
  idleSlots: number[];
}

export function resolveImmersiveCurrentRenderSections(
  currentEvent: EventEntity | null
): ImmersiveCurrentRenderSections {
  if (currentEvent) {
    return { currentEvents: [currentEvent], idleSlots: [] };
  }
  return { currentEvents: [], idleSlots: [1] };
}

export function resolveImmersivePrimaryActionSlots(visible: boolean): number[] {
  return visible ? [1] : [];
}

export function resolveImmersiveNextRenderEvents(nextEvent: EventEntity | null): EventEntity[] {
  return nextEvent ? [nextEvent] : [];
}

type ImmersiveTextGetter = () => string;
type ImmersiveEventTextGetter = (event: EventEntity) => string;
type ImmersiveStateGetter = () => boolean;
type ImmersiveEventStateGetter = (event: EventEntity) => boolean;
type ImmersiveEventAsyncCallback = (event: EventEntity) => Promise<void> | void;
type ImmersiveNavigateCallback = (event?: EventEntity) => void;
type ImmersiveSwipeCallback = (phase: ImmersiveSwipePhase, event?: GestureEvent) => void;

function defaultImmersiveText(): string {
  return '--';
}

function defaultImmersiveEventText(_event: EventEntity): string {
  return '--';
}

function defaultImmersiveState(): boolean {
  return false;
}

function defaultImmersiveEventState(_event: EventEntity): boolean {
  return false;
}

function noopImmersiveEvent(_event: EventEntity): void {}

function noopImmersiveNavigate(_event?: EventEntity): void {}

function noopImmersiveSwipe(_phase: ImmersiveSwipePhase, _event?: GestureEvent): void {}

@Component
export struct CompanionImmersiveView {
  @Prop context: CompanionContext;
  @Prop immersiveText: string = '';
  @Prop immersiveDragOffsetY: number = 0;
  @Prop safeTopInset: number = 0;
  @Prop safeBottomInset: number = 0;
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  getRuntimeLabel: ImmersiveTextGetter = defaultImmersiveText;
  getPlannedRange: ImmersiveEventTextGetter = defaultImmersiveEventText;
  getForecastStartText: ImmersiveEventTextGetter = defaultImmersiveEventText;
  isCurrentEventPending: ImmersiveStateGetter = defaultImmersiveState;
  isCurrentEventActive: ImmersiveStateGetter = defaultImmersiveState;
  canStartFocused: ImmersiveEventStateGetter = defaultImmersiveEventState;
  canEndFocused: ImmersiveEventStateGetter = defaultImmersiveEventState;

  onStartEvent: ImmersiveEventAsyncCallback = noopImmersiveEvent;
  onEndEvent: ImmersiveEventAsyncCallback = noopImmersiveEvent;
  onNavigate: ImmersiveNavigateCallback = noopImmersiveNavigate;
  onSwipeGesture: ImmersiveSwipeCallback = noopImmersiveSwipe;

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  private hasCurrentEvent(): boolean {
    return !!this.context.currentEvent;
  }

  private shouldRenderPrimaryAction(): boolean {
    return shouldShowImmersivePrimaryAction(
      this.isCurrentEventPending(),
      this.isCurrentEventActive(),
      this.context.runtimeState
    );
  }

  private getPrimaryActionBackgroundColor(): ResourceColor {
    return this.isCurrentEventPending() ? this.getThemePalette().success : this.getThemePalette().warning;
  }

  private hasNextEvent(): boolean {
    return !!this.context.nextEvent;
  }

  private async handlePrimaryActionClick(): Promise<void> {
    const current = this.context.currentEvent;
    if (!current) {
      return;
    }
    if (this.isCurrentEventPending()) {
      await this.onStartEvent(current);
      return;
    }
    await this.onEndEvent(current);
  }

  private handleNavigateClick(): void {
    this.onNavigate(this.context.currentEvent || undefined);
  }

  private handleSwipeStart(event: GestureEvent): void {
    this.onSwipeGesture('start', event);
  }

  private handleSwipeUpdate(event: GestureEvent): void {
    this.onSwipeGesture('update', event);
  }

  private handleSwipeEnd(event: GestureEvent): void {
    this.onSwipeGesture('end', event);
  }

  build() {
    Column({ space: 18 }) {
      Blank().layoutWeight(1);

      ForEach(resolveImmersiveCurrentRenderSections(this.context.currentEvent).currentEvents, (current: EventEntity) => {
        Text(current.name)
          .fontSize(42)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getThemePalette().textPrimary)
          .maxLines(2)
          .textAlign(TextAlign.Center)
          .textOverflow({ overflow: TextOverflow.Ellipsis });

        Text(`${this.getRuntimeLabel()} | ${this.getPlannedRange(current)}`)
          .fontSize(14)
          .fontColor(this.getThemePalette().textSecondary)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor(this.getThemePalette().cardBgSoft)
          .borderRadius(16);

        Row({ space: 10 }) {
          ForEach(resolveImmersivePrimaryActionSlots(this.shouldRenderPrimaryAction()), (_slot: number) => {
            Button(getImmersivePrimaryActionLabel(this.isCurrentEventPending()))
              .layoutWeight(2)
              .height(50)
              .enabled(
                getImmersivePrimaryActionEnabled(
                  this.isCurrentEventPending(),
                  this.canStartFocused(current),
                  this.canEndFocused(current)
                )
              )
              .backgroundColor(this.getPrimaryActionBackgroundColor())
              .fontColor(Color.White)
              .onClick(async () => this.handlePrimaryActionClick());
          });
          Button('导航')
            .layoutWeight(1)
            .height(50)
            .backgroundColor(this.getThemePalette().primary)
            .fontColor(Color.White)
            .onClick(() => this.handleNavigateClick());
        }
        .width('78%');
      });

      ForEach(resolveImmersiveCurrentRenderSections(this.context.currentEvent).idleSlots, (_slot: number) => {
        Text('当前暂无进行中的地点')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getThemePalette().textPrimary);
        Text(this.immersiveText)
          .fontSize(16)
          .fontColor(this.getThemePalette().textSecondary)
          .textAlign(TextAlign.Center)
          .padding({ left: 28, right: 28 });

        ForEach(resolveImmersiveNextRenderEvents(this.context.nextEvent), (next: EventEntity) => {
          Text(
            getImmersiveNextStationText(
              next.name,
              this.getForecastStartText(next)
            )
          )
            .fontSize(14)
            .fontColor(this.getThemePalette().textSecondary)
            .textAlign(TextAlign.Center)
            .padding({ left: 28, right: 28 });
        });
      });

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
        .onActionStart((event: GestureEvent) => this.handleSwipeStart(event))
        .onActionUpdate((event: GestureEvent) => this.handleSwipeUpdate(event))
        .onActionEnd((event: GestureEvent) => this.handleSwipeEnd(event))
    );
  }
}
