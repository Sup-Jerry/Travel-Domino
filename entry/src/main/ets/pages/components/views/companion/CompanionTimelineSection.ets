import { EventEntity } from '../../../../model/entity/EventEntity';
import { ThemeCenter } from '../../../../common/utils/ThemeCenter';

export function isCompanionTimelineFocused(itemId: number, focusedEventId: number): boolean {
  return itemId === focusedEventId;
}

export function getCompanionTimelineVisibleCount(timelineCount: number): number {
  return Math.max(1, timelineCount);
}

export function getCompanionTimelineFilterSummary(filterLabel: string, focusPosition: number, timelineCount: number): string {
  return `筛选 ${filterLabel}  ${focusPosition}/${getCompanionTimelineVisibleCount(timelineCount)}`;
}

export function shouldShowCompanionTimelineEmptyState(timelineCount: number): boolean {
  return timelineCount === 0;
}

@Component
export struct CompanionTimelineSection {
  @Prop focusedEventId: number = -1;
  @Prop filterLabel: string = '';
  @Prop focusPosition: number = 0;
  @Prop timelineCount: number = 0;
  @Prop events: EventEntity[] = [];
  timelineScroller: Scroller = new Scroller();
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  getStateDotColor: (event: EventEntity) => ResourceColor = (_event: EventEntity) => '#999';
  getEventStateLabel: (event: EventEntity) => string = (_event: EventEntity) => '--';
  getStateTagTextColor: (event: EventEntity) => ResourceColor = (_event: EventEntity) => '#666';
  getStateTagBackgroundColor: (event: EventEntity) => ResourceColor = (_event: EventEntity) => '#F5F5F5';
  getStateBorderColor: (event: EventEntity) => ResourceColor = (_event: EventEntity) => '#DDD';
  getTimelineSupplement: (event: EventEntity) => string = (_event: EventEntity) => '--';

  onItemTap: (event: EventEntity, index: number) => void = (_event: EventEntity, _index: number) => {};
  onScrollIndex: (start: number, end: number, center: number) => void = (_start: number, _end: number, _center: number) => {};
  onScrollStop: () => void = () => {};

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  @Builder
  private TimelineFocusItem(item: EventEntity, index: number) {
    Row({ space: 10 }) {
      Column({ space: 0 }) {
        Column()
          .width(10)
          .height(10)
          .borderRadius(5)
          .backgroundColor(isCompanionTimelineFocused(item.id, this.focusedEventId) ? this.getStateDotColor(item) : this.getThemePalette().textTertiary);
      }
      .width(16)
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Start);

      Column({ space: 4 }) {
        Text(item.name)
          .fontSize(isCompanionTimelineFocused(item.id, this.focusedEventId) ? 16 : 14)
          .fontWeight(isCompanionTimelineFocused(item.id, this.focusedEventId) ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(isCompanionTimelineFocused(item.id, this.focusedEventId) ? this.getThemePalette().textPrimary : this.getThemePalette().textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });

        Row({ space: 6 }) {
          Text(this.getEventStateLabel(item))
            .fontSize(10)
            .fontColor(this.getStateTagTextColor(item))
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor(this.getStateTagBackgroundColor(item))
            .border({ width: 1, color: this.getStateBorderColor(item), radius: 8 })
            .borderRadius(8);
          if (isCompanionTimelineFocused(item.id, this.focusedEventId)) {
            Text(this.getTimelineSupplement(item))
              .fontSize(11)
              .fontColor(this.getThemePalette().textTertiary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1);
          }
        }
        .width('100%');
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .padding({
      left: 12,
      right: 12,
      top: isCompanionTimelineFocused(item.id, this.focusedEventId) ? 12 : 10,
      bottom: isCompanionTimelineFocused(item.id, this.focusedEventId) ? 12 : 10
    })
    .backgroundColor(isCompanionTimelineFocused(item.id, this.focusedEventId) ? this.getThemePalette().companionCardBg : this.getThemePalette().companionBg)
    .border({ width: isCompanionTimelineFocused(item.id, this.focusedEventId) ? 1 : 0, color: this.getStateBorderColor(item), radius: 12 })
    .borderRadius(12)
    .shadow({
      radius: isCompanionTimelineFocused(item.id, this.focusedEventId) ? 10 : 0,
      color: isCompanionTimelineFocused(item.id, this.focusedEventId) ? '#22000000' : '#00000000',
      offsetY: isCompanionTimelineFocused(item.id, this.focusedEventId) ? 4 : 0
    })
    .scale({ x: isCompanionTimelineFocused(item.id, this.focusedEventId) ? 1 : 0.995, y: isCompanionTimelineFocused(item.id, this.focusedEventId) ? 1 : 0.995 })
    .onClick(() => {
      this.onItemTap(item, index);
    });
  }

  build() {
    Column({ space: 8 }) {
      Row() {
        Text('时间轴')
          .fontSize(13)
          .fontColor(this.getThemePalette().textSecondary);
        Blank();
        Text(getCompanionTimelineFilterSummary(this.filterLabel, this.focusPosition, this.timelineCount))
          .fontSize(11)
          .fontColor(this.getThemePalette().textTertiary);
      }
      .width('100%');

      if (shouldShowCompanionTimelineEmptyState(this.timelineCount)) {
        Column({ space: 6 }) {
          Text('当前筛选下无可见日程')
            .fontSize(13)
            .fontColor(this.getThemePalette().textSecondary);
          Text('点击筛选按钮可切换状态')
            .fontSize(11)
            .fontColor(this.getThemePalette().textTertiary);
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center);
      } else {
        List({ space: 8, scroller: this.timelineScroller }) {
          ForEach(this.events, (item: EventEntity, index: number) => {
            ListItem() {
              this.TimelineFocusItem(item, index);
            };
          }, (item: EventEntity) => item.id.toString());
          ListItem().height(8);
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .onScrollIndex((start: number, end: number, center: number) => {
          this.onScrollIndex(start, end, center);
        })
        .onScrollStop(() => {
          this.onScrollStop();
        });
      }
    }
    .width('100%')
    .layoutWeight(1);
  }
}
