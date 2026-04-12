import { EventEntity } from '../../model/entity/EventEntity';
import { EventItemView } from '../components/views/EventItemView';
import { DateGroup } from '../../viewmodel/TimelineViewModel';
import { ConflictActionStrategy } from './IndexEventHandlers';

export interface IndexTimelineTheme {
  pageBg: string;
  textPrimary: string;
  textSecondary: string;
  textTertiary: string;
  warning: string;
}

export function resolveIndexTimelineVisiblePlaceCount(placeCount: number): number {
  return Math.max(0, placeCount);
}

export function buildIndexTimelineHeaderText(text: string, placeCount: number): string {
  return `${text} 共${resolveIndexTimelineVisiblePlaceCount(placeCount)}个地点`;
}

export function shouldShowIndexTimelineGroupItems(isCollapsed: boolean): boolean {
  return !isCollapsed;
}

export function shouldEnableIndexTimelineItem(isArchived: boolean): boolean {
  return !isArchived;
}

export function shouldShowIndexTimelineGapHint(isArchived: boolean, gapsCount: number): boolean {
  return !isArchived && gapsCount > 0;
}

export function resolveIndexTimelineBottomSpacerHeight(isCompanionMode: boolean): number {
  return isCompanionMode ? 24 : 100;
}

@Component
export struct IndexTimelineView {
  @Prop groupedEvents: DateGroup[] = [];
  @Prop allEvents: EventEntity[] = [];
  @Prop isArchived: boolean = false;
  @Prop isCompanionMode: boolean = false;
  @Prop showWeather: boolean = false;
  @Prop isPageRefreshing: boolean = false;
  @Prop gapsCount: number = 0;
  @Prop theme: IndexTimelineTheme = {
    pageBg: '#F6F8FC',
    textPrimary: '#1F2937',
    textSecondary: '#5B6B82',
    textTertiary: '#8FA1B8',
    warning: '#C58A2A'
  };

  onIsDayCollapsed: (dayOffset: number) => boolean = (_dayOffset: number) => false;
  onToggleDay: (dayOffset: number) => void = (_dayOffset: number) => {};
  onRefresh: () => void = () => {};
  onMoveUp: (item: EventEntity) => void = (_item: EventEntity) => {};
  onMoveDown: (item: EventEntity) => void = (_item: EventEntity) => {};
  onMainContentClick: (item: EventEntity) => void = (_item: EventEntity) => {};
  onTimeClick: (item: EventEntity) => void = (_item: EventEntity) => {};
  onTravelModeChange: (item: EventEntity, mode: number) => void = (_item: EventEntity, _mode: number) => {};
  onManualTravelInput: (item: EventEntity, minutes: number) => void = (_item: EventEntity, _minutes: number) => {};
  onCommuteChange: (item: EventEntity, minutes: number) => void = (_item: EventEntity, _minutes: number) => {};
  onConflictAction: (item: EventEntity, strategy: ConflictActionStrategy, gapMinutes: number) => void =
    (_item: EventEntity, _strategy: ConflictActionStrategy, _gapMinutes: number) => {};
  onMoveToBacklog: (item: EventEntity) => void = (_item: EventEntity) => {};
  onDeleteEvent: (item: EventEntity) => void = (_item: EventEntity) => {};
  onOpenGapOptimize: () => void = () => {};

  @Builder
  private buildDateHeader(text: string, dayOffset: number, placeCount: number) {
    Row() {
      Text(this.onIsDayCollapsed(dayOffset) ? '▶' : '▼')
        .fontSize(12)
        .fontColor(this.theme.textTertiary)
        .margin({ right: 8 });

      Column()
        .width(4)
        .height(14)
        .backgroundColor(this.theme.warning)
        .margin({ right: 8 })
        .borderRadius(2);

      Text(buildIndexTimelineHeaderText(text, placeCount))
        .fontSize(16)
        .fontColor(this.theme.textPrimary)
        .fontWeight(FontWeight.Bold);
    }
    .width('100%')
    .padding({ top: 16, bottom: 8, left: 4 })
    .backgroundColor(this.theme.pageBg)
    .onClick(() => {
      this.getUIContext().animateTo({ duration: 220, curve: Curve.FastOutSlowIn }, () => {
        this.onToggleDay(dayOffset);
      });
    });
  }

  @Builder
  private swipeStartAction(item: EventEntity) {
    Button({ type: ButtonType.Normal }) {
      Text('删除')
        .fontSize(14)
        .fontColor(Color.White);
    }
    .width(60)
    .height('100%')
    .backgroundColor('#D32F2F')
    .onClick(() => this.onDeleteEvent(item));
  }

  @Builder
  private swipeEndAction(item: EventEntity) {
    Button({ type: ButtonType.Normal }) {
      Text('暂存')
        .fontSize(14)
        .fontColor(Color.White);
    }
    .width(60)
    .height('100%')
    .backgroundColor('#FF9800')
    .onClick(() => this.onMoveToBacklog(item));
  }

  build() {
    Refresh({ refreshing: this.isPageRefreshing }) {
      List({ space: 0 }) {
        ForEach(this.groupedEvents, (group: DateGroup) => {
          ListItemGroup({ header: this.buildDateHeader(group.dateHeader, group.dayOffset, group.events.length) }) {
            if (shouldShowIndexTimelineGroupItems(this.onIsDayCollapsed(group.dayOffset))) {
              ForEach(group.events, (item: EventEntity, dayIndex: number) => {
                ListItem() {
                  EventItemView({
                    event: item,
                    isCompanionMode: this.isCompanionMode,
                    showWeather: this.showWeather,
                    showTravelIndicator: dayIndex > 0,
                    index: this.allEvents.indexOf(item),
                    totalCount: this.allEvents.length,
                    onMoveUp: () => this.onMoveUp(item),
                    onMoveDown: () => this.onMoveDown(item),
                    onMainContentClick: () => this.onMainContentClick(item),
                    onTimeClick: () => this.onTimeClick(item),
                    onTravelModeChange: (mode: number) => this.onTravelModeChange(item, mode),
                    onManualTravelInput: (minutes: number) => this.onManualTravelInput(item, minutes),
                    onCommuteChange: (minutes: number) => this.onCommuteChange(item, minutes),
                    onConflictAction: (targetItem: EventEntity, strategy: ConflictActionStrategy, gapMinutes: number) => {
                      this.onConflictAction(targetItem, strategy, gapMinutes);
                    }
                  })
                    .enabled(shouldEnableIndexTimelineItem(this.isArchived));
                }
                .swipeAction(!shouldEnableIndexTimelineItem(this.isArchived) ? undefined : {
                  start: {
                    builder: () => {
                      this.swipeStartAction(item);
                    },
                    actionAreaDistance: 60
                  },
                  end: {
                    builder: () => {
                      this.swipeEndAction(item);
                    },
                    actionAreaDistance: 60
                  }
                });
              }, (item: EventEntity) => `${item.id}_${item.sort_order}_${item.status}`);
            }
          }
          .divider({ strokeWidth: 0 });
        }, (group: DateGroup) => `${group.dayOffset}_${group.actualDateMs}_${group.events.length}`);

        if (shouldShowIndexTimelineGapHint(this.isArchived, this.gapsCount)) {
          ListItem() {
            Row() {
              Text('→')
                .fontSize(14)
                .fontColor(this.theme.textTertiary);

              Text(`检测到 ${this.gapsCount} 处空闲时间，是否立即优化？`)
                .fontSize(13)
                .fontColor(this.theme.textSecondary)
                .layoutWeight(1);
            }
            .width('100%')
            .padding({ top: 12, bottom: 12, left: 16, right: 16 })
            .justifyContent(FlexAlign.Center)
            .onClick(() => this.onOpenGapOptimize());
          }
        }

        ListItem().height(resolveIndexTimelineBottomSpacerHeight(this.isCompanionMode));
      }
      .sticky(StickyStyle.Header);
    }
    .onRefreshing(() => this.onRefresh())
    .layoutWeight(1)
    .padding({
      top: 0,
      bottom: 0,
      left: 12,
      right: 12
    })
    .backgroundColor(this.theme.pageBg);
  }
}
