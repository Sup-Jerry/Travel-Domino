import {
  HistoryTimelineFilter,
  HistoryTimelineItem,
  HistoryTimelineSummary,
  PlaceCheckinSummary,
  TimelineViewModel
} from '../../../../viewmodel/TimelineViewModel';
import { DateUtil } from '../../../../common/utils/DateUtil';
import { CompanionPresentationHelper } from '../CompanionPresentationHelper';
import { ThemeCenter } from '../../../../common/utils/ThemeCenter';

export type HistoryViewMode = 'timeline' | 'detail';

interface HistoryTimelineGroup {
  key: string;
  title: string;
  items: HistoryTimelineItem[];
}

@Component
export struct CompanionHistoryPage {
  @Prop showHistoryPage: boolean = false;
  @Prop historyTimelineSummary: HistoryTimelineSummary | null = null;
  @Prop historyTimelineItems: HistoryTimelineItem[] = [];
  @Prop historyTimelineFilter: HistoryTimelineFilter = 'all';
  @Prop historyViewMode: HistoryViewMode = 'timeline';
  @Prop historySummary: PlaceCheckinSummary | null = null;
  @Prop vm: TimelineViewModel | null = null;
  @Prop selectedHistoryTimelineItem: HistoryTimelineItem | null = null;
  @Prop safeTopInset: number = 0;
  @Prop safeBottomInset: number = 0;
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  onClose: () => void = () => {};
  onBack: () => void = () => {};
  onFilterChange: (filter: HistoryTimelineFilter) => void = (_filter: HistoryTimelineFilter) => {};
  onItemClick: (item: HistoryTimelineItem) => void = (_item: HistoryTimelineItem) => {};

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  private formatTs(ts: number): string {
    return CompanionPresentationHelper.formatTs(ts);
  }

  private getHistoryDayTitle(groupKey: string): string {
    if (groupKey === '未定') {
      return '未定';
    }
    const todayKey = DateUtil.formatLocalDate(Date.now());
    if (groupKey === todayKey) {
      return '今天';
    }
    const date = new Date(groupKey);
    return DateUtil.formatDate(date, 'MM月dd日');
  }

  private getNextHistoryTimelineFilter(): HistoryTimelineFilter {
    if (this.historyTimelineFilter === 'all') {
      return 'completed';
    }
    if (this.historyTimelineFilter === 'completed') {
      return 'skipped';
    }
    if (this.historyTimelineFilter === 'skipped') {
      return 'abnormal';
    }
    return 'all';
  }

  private getHistoryTimelineFilterLabel(): string {
    if (this.historyTimelineFilter === 'completed') {
      return '只看完成';
    }
    if (this.historyTimelineFilter === 'skipped') {
      return '只看跳过';
    }
    if (this.historyTimelineFilter === 'abnormal') {
      return '只看异常';
    }
    return '全部';
  }

  private isTimelineItemVisible(item: HistoryTimelineItem): boolean {
    if (this.historyTimelineFilter === 'all') {
      return true;
    }
    if (this.historyTimelineFilter === 'completed') {
      return item.actionType === 'ARRIVE' || item.actionType === 'LEAVE';
    }
    if (this.historyTimelineFilter === 'skipped') {
      return item.actionType === 'SKIP';
    }
    return item.isAbnormal || item.actionType === 'SKIP';
  }

  private getFilteredHistoryTimelineItems(): HistoryTimelineItem[] {
    return this.historyTimelineItems.filter((item: HistoryTimelineItem) => this.isTimelineItemVisible(item));
  }

  private getHistoryTimelineGroups(): HistoryTimelineGroup[] {
    const source = this.getFilteredHistoryTimelineItems();
    const grouped: Record<string, HistoryTimelineItem[]> = {};
    source.forEach((item: HistoryTimelineItem) => {
      const key = item.groupDateKey || '未定';
      if (!grouped[key]) {
        grouped[key] = [];
      }
      grouped[key].push(item);
    });
    const keys = Object.keys(grouped).sort((a: string, b: string) => a.localeCompare(b));
    return keys.map((key: string): HistoryTimelineGroup => {
      const items = grouped[key];
      items.sort((a: HistoryTimelineItem, b: HistoryTimelineItem) => {
        if (a.displayTs !== b.displayTs) {
          return a.displayTs - b.displayTs;
        }
        return a.id - b.id;
      });
      return {
        key: key,
        title: this.getHistoryDayTitle(key),
        items: items
      };
    });
  }

  private getTimelineActionText(item: HistoryTimelineItem): string {
    if (item.actionType === 'ARRIVE') {
      return `到达 ${item.placeName}`;
    }
    if (item.actionType === 'LEAVE') {
      return `离开 ${item.placeName}`;
    }
    if (item.actionType === 'SKIP') {
      return `跳过 ${item.placeName}`;
    }
    return `到达 ${item.placeName}`;
  }

  private getTimelineSkipReason(item: HistoryTimelineItem): string {
    const note = (item.note || '').trim();
    if (note.includes('时间不足')) {
      return '时间不足';
    }
    return '手动跳过';
  }

  private getTimelineSubText(item: HistoryTimelineItem): string {
    if (item.actionType === 'LEAVE') {
      return `停留 ${item.stayMinutes} 分钟`;
    }
    if (item.actionType === 'SKIP') {
      return `原因：${this.getTimelineSkipReason(item)}`;
    }
    if (item.actionType === 'ACTIVE') {
      return '当前进行中';
    }
    if (item.deviationMinutes > 0) {
      return `比计划晚 ${item.deviationMinutes} 分钟`;
    }
    if (item.deviationMinutes < 0) {
      return `比计划早 ${Math.abs(item.deviationMinutes)} 分钟`;
    }
    return '与计划一致';
  }

  private getTimelineSubTextColor(item: HistoryTimelineItem): ResourceColor {
    if (item.actionType === 'SKIP') {
      return this.getThemePalette().statusSkipped;
    }
    if (item.actionType === 'ACTIVE') {
      return this.getThemePalette().success;
    }
    if (item.isAbnormal) {
      return this.getThemePalette().danger;
    }
    return this.getThemePalette().textSecondary;
  }

  private getTimelineCardBgColorByIndex(index: number): ResourceColor {
    const palette: string[] = ['#EAF2FF', '#EAF7EE', '#F7F2EA', '#F8EEF2'];
    const safeIndex = index >= 0 ? index : 0;
    return palette[safeIndex % palette.length];
  }

  private getTimelineCardBgColor(item: HistoryTimelineItem): ResourceColor {
    const visibleItems = this.getFilteredHistoryTimelineItems();
    const placeColorIndex = new Map<string, number>();
    let nextIndex = 0;
    for (let i = 0; i < visibleItems.length; i++) {
      const placeName = (visibleItems[i].placeName || '').trim();
      if (!placeColorIndex.has(placeName)) {
        placeColorIndex.set(placeName, nextIndex % 4);
        nextIndex += 1;
      }
    }
    const key = (item.placeName || '').trim();
    const idx = placeColorIndex.get(key) ?? 0;
    return this.getTimelineCardBgColorByIndex(idx);
  }

  private getTimelineDotColor(_item: HistoryTimelineItem): ResourceColor {
    return this.getThemePalette().primary;
  }

  private getCurrentHistoryPlaceName(): string {
    if (this.historySummary && (this.historySummary.placeName || '').trim().length > 0) {
      return this.historySummary.placeName.trim();
    }
    if (this.selectedHistoryTimelineItem && (this.selectedHistoryTimelineItem.placeName || '').trim().length > 0) {
      return this.selectedHistoryTimelineItem.placeName.trim();
    }
    return '';
  }

  private isNewerHistoryItem(candidate: HistoryTimelineItem, current: HistoryTimelineItem): boolean {
    if (candidate.displayTs !== current.displayTs) {
      return candidate.displayTs > current.displayTs;
    }
    if (candidate.actualEnd !== current.actualEnd) {
      return candidate.actualEnd > current.actualEnd;
    }
    if (candidate.actualStart !== current.actualStart) {
      return candidate.actualStart > current.actualStart;
    }
    return candidate.id > current.id;
  }

  private getCurrentHistoryLatestItem(): HistoryTimelineItem | null {
    const placeName = this.getCurrentHistoryPlaceName();
    if (placeName.length === 0) {
      return null;
    }
    let latest: HistoryTimelineItem | null = null;
    this.historyTimelineItems.forEach((item: HistoryTimelineItem) => {
      if ((item.placeName || '').trim() !== placeName) {
        return;
      }
      if (!latest || this.isNewerHistoryItem(item, latest)) {
        latest = item;
      }
    });
    if (latest) {
      return latest;
    }
    if (this.selectedHistoryTimelineItem && (this.selectedHistoryTimelineItem.placeName || '').trim() === placeName) {
      return this.selectedHistoryTimelineItem;
    }
    return null;
  }

  private getHistoryAddress(_placeName: string): string {
    const latestItem = this.getCurrentHistoryLatestItem();
    if (!latestItem) {
      return '--';
    }
    const address = (latestItem.address || '').trim();
    return address.length > 0 ? address : '--';
  }

  private getCurrentHistoryStatusText(): string {
    const latestItem = this.getCurrentHistoryLatestItem();
    if (!latestItem) {
      return '--';
    }
    if (latestItem.actionType === 'SKIP' || latestItem.status === 2) {
      return '已跳过';
    }
    if (latestItem.actionType === 'ACTIVE') {
      return '进行中';
    }
    if (latestItem.actionType === 'LEAVE' || latestItem.status === 1 || latestItem.actualEnd > latestItem.actualStart) {
      return '已离开';
    }
    if (latestItem.actionType === 'ARRIVE' || latestItem.actualStart > 0) {
      return '进行中';
    }
    return '未开始';
  }

  private getCurrentHistoryPlannedStartText(): string {
    if (this.selectedHistoryTimelineItem && this.selectedHistoryTimelineItem.plannedStart > 0) {
      return CompanionPresentationHelper.formatTs(this.selectedHistoryTimelineItem.plannedStart);
    }
    const latestItem = this.getCurrentHistoryLatestItem();
    if (!latestItem || latestItem.plannedStart <= 0) {
      return '--:--';
    }
    return CompanionPresentationHelper.formatTs(latestItem.plannedStart);
  }

  private getCurrentHistoryActualStartText(): string {
    const latestItem = this.getCurrentHistoryLatestItem();
    if (!latestItem || latestItem.actualStart <= 0) {
      return '--:--';
    }
    return CompanionPresentationHelper.formatTs(latestItem.actualStart);
  }

  private getCurrentHistoryActualEndText(): string {
    const latestItem = this.getCurrentHistoryLatestItem();
    if (!latestItem || latestItem.actualEnd <= 0) {
      return '--:--';
    }
    return CompanionPresentationHelper.formatTs(latestItem.actualEnd);
  }

  private getCurrentHistoryStayText(): string {
    const latestItem = this.getCurrentHistoryLatestItem();
    if (!latestItem) {
      return '0 分钟';
    }
    if (latestItem.stayMinutes > 0) {
      return `${latestItem.stayMinutes} 分钟`;
    }
    if (latestItem.actualStart <= 0 || latestItem.actualEnd <= latestItem.actualStart) {
      return '0 分钟';
    }
    const stayMinutes = Math.round((latestItem.actualEnd - latestItem.actualStart) / 60000);
    return `${stayMinutes} 分钟`;
  }

  private getCurrentHistoryDeviationText(): string {
    const latestItem = this.getCurrentHistoryLatestItem();
    if (!latestItem) {
      return '--';
    }
    const delta = latestItem.deviationMinutes;
    if (delta > 0) {
      return `晚到 ${delta} 分钟`;
    }
    if (delta < 0) {
      return `早到 ${Math.abs(delta)} 分钟`;
    }
    return '准时';
  }

  private getCurrentHistoryNoteText(): string {
    const latestItem = this.getCurrentHistoryLatestItem();
    if (!latestItem) {
      return '--';
    }
    const note = (latestItem.note || '').trim();
    return note.length > 0 ? note : '--';
  }

  build() {
    if (this.showHistoryPage) {
      Column({ space: 12 }) {
        Row() {
          Text(this.historyViewMode === 'timeline' ? '本次计划打卡历史' : '打卡详情')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getThemePalette().textPrimary);
          Blank();
          if (this.historyViewMode === 'timeline') {
            Text(`筛选 ${this.getHistoryTimelineFilterLabel()}`)
              .fontSize(14)
              .fontColor(this.getThemePalette().textSecondary)
              .onClick(() => {
                this.onFilterChange(this.getNextHistoryTimelineFilter());
              });
          } else {
            Text('返回')
              .fontSize(14)
              .fontColor(this.getThemePalette().textSecondary)
              .onClick(() => {
                this.onBack();
              });
          }
          Text('关闭')
            .fontSize(14)
            .fontColor(this.getThemePalette().textSecondary)
            .margin({ left: 14 })
            .onClick(() => {
              this.onClose();
            });
        }
        .width('100%')
        .padding({ top: this.safeTopInset + 8, bottom: 6 });

        if (this.historyViewMode === 'timeline') {
          if (this.historyTimelineSummary) {
            Column({ space: 6 }) {
              Text(`计划：${this.historyTimelineSummary.planName}`)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.getThemePalette().textPrimary)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis });
              Text(`已完成 ${this.historyTimelineSummary.completedCount} / 跳过 ${this.historyTimelineSummary.skippedCount} / 进行中 ${this.historyTimelineSummary.activeCount}`)
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary);
            }
            .width('100%')
            .padding(12)
            .backgroundColor(this.getThemePalette().companionCardBg)
            .borderRadius(12);
          }

          if (this.getHistoryTimelineGroups().length === 0) {
            Column({ space: 8 }) {
              Text('暂无打卡记录')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.getThemePalette().textSecondary);
              Text('开始或结束一个地点后会生成时间线记录。')
                .fontSize(12)
                .fontColor(this.getThemePalette().textTertiary);
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center);
          } else {
            List({ space: 10 }) {
              ForEach(this.getHistoryTimelineGroups(), (group: HistoryTimelineGroup) => {
                ListItem() {
                  Column({ space: 8 }) {
                    Text(group.title)
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.getThemePalette().textSecondary);

                    Column({ space: 8 }) {
                      ForEach(group.items, (item: HistoryTimelineItem) => {
                        Row({ space: 10 }) {
                          Text(item.displayTs > 0 ? this.formatTs(item.displayTs) : '--:--')
                            .fontSize(12)
                            .fontColor(this.getThemePalette().textSecondary)
                            .width(52);

                          Text('●')
                            .fontSize(14)
                            .fontColor(this.getTimelineDotColor(item))
                            .width(14);

                          Column({ space: 4 }) {
                            Text(this.getTimelineActionText(item))
                              .fontSize(14)
                              .fontWeight(FontWeight.Medium)
                              .fontColor(this.getThemePalette().textPrimary)
                              .maxLines(1)
                              .textOverflow({ overflow: TextOverflow.Ellipsis });
                            Text(this.getTimelineSubText(item))
                              .fontSize(12)
                              .fontColor(this.getTimelineSubTextColor(item))
                              .maxLines(1)
                              .textOverflow({ overflow: TextOverflow.Ellipsis });
                          }
                          .layoutWeight(1)
                          .alignItems(HorizontalAlign.Start);
                        }
                        .width('100%')
                        .padding({ left: 10, right: 10, top: 8, bottom: 8 })
                        .backgroundColor(this.getTimelineCardBgColor(item))
                        .borderRadius(10)
                        .onClick(() => {
                          this.onItemClick(item);
                        });
                      }, (item: HistoryTimelineItem) => item.id.toString());
                    }
                    .width('100%');
                  }
                  .width('100%')
                  .padding({ left: 12, right: 12, top: 12, bottom: 12 })
                  .backgroundColor(this.getThemePalette().companionCardBg)
                  .borderRadius(12);
                };
              }, (group: HistoryTimelineGroup) => group.key);
            }
            .width('100%')
            .layoutWeight(1);

            Row({ space: 8 }) {
              Button('只看完成')
                .type(ButtonType.Capsule)
                .fontSize(12)
                .fontColor(this.historyTimelineFilter === 'completed'
                  ? this.getThemePalette().primary
                  : this.getThemePalette().textSecondary)
                .backgroundColor(this.getThemePalette().companionCardBg)
                .layoutWeight(1)
                .onClick(() => {
                  this.onFilterChange('completed');
                });
              Button('只看跳过')
                .type(ButtonType.Capsule)
                .fontSize(12)
                .fontColor(this.historyTimelineFilter === 'skipped'
                  ? this.getThemePalette().statusSkipped
                  : this.getThemePalette().textSecondary)
                .backgroundColor(this.getThemePalette().companionCardBg)
                .layoutWeight(1)
                .onClick(() => {
                  this.onFilterChange('skipped');
                });
              Button('只看异常')
                .type(ButtonType.Capsule)
                .fontSize(12)
                .fontColor(this.historyTimelineFilter === 'abnormal'
                  ? this.getThemePalette().danger
                  : this.getThemePalette().textSecondary)
                .backgroundColor(this.getThemePalette().companionCardBg)
                .layoutWeight(1)
                .onClick(() => {
                  this.onFilterChange('abnormal');
                });
            }
            .width('100%');
          }
        } else if (this.historySummary) {
          Column({ space: 10 }) {
            Column({ space: 4 }) {
              Text(this.historySummary.placeName)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.getThemePalette().textPrimary)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis });
              Text(`状态：${this.getCurrentHistoryStatusText()}`)
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary);
            }
            .width('100%')
            .padding(12)
            .backgroundColor(this.getThemePalette().companionCardBg)
            .borderRadius(12);

            Column({ space: 6 }) {
              Text(`计划开始：${this.getCurrentHistoryPlannedStartText()}`)
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary);
              Text(`实际到达：${this.getCurrentHistoryActualStartText()}`)
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary);
              Text(`实际离开：${this.getCurrentHistoryActualEndText()}`)
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary);
              Text(`实际停留：${this.getCurrentHistoryStayText()}`)
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary);
              Text(`执行偏差：${this.getCurrentHistoryDeviationText()}`)
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary);
            }
            .width('100%')
            .padding(12)
            .backgroundColor(this.getThemePalette().companionCardBg)
            .borderRadius(12);

            Column({ space: 6 }) {
              Text(`地址：${this.getHistoryAddress(this.historySummary.placeName)}`)
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis });
              Text(`备注：${this.getCurrentHistoryNoteText()}`)
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis });
            }
            .width('100%')
            .padding(12)
            .backgroundColor(this.getThemePalette().companionCardBg)
            .borderRadius(12);
          }
          .width('100%')
          .layoutWeight(1);
        } else {
          Column() {
            Text('暂无历史详情')
              .fontSize(14)
              .fontColor(this.getThemePalette().textSecondary);
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center);
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, bottom: this.safeBottomInset + 14 })
      .backgroundColor(this.getThemePalette().companionBg)
      .zIndex(9)
      .transition({
        type: TransitionType.All,
        opacity: 0,
        translate: { y: 18 },
        scale: { x: 0.985, y: 0.985 }
      });
    }
  }
}

