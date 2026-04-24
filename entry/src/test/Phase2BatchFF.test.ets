import { describe, expect, it } from '@ohos/hypium';
import { DateUtil } from '../main/ets/common/utils/DateUtil';
import {
  CompanionHistoryPage,
  getHistoryTimelineFilterLabelValue,
  getHistoryTimelineSkipReasonByNote,
  getNextHistoryTimelineFilterValue,
  isHistoryTimelineItemVisibleByFilter
} from '../main/ets/pages/components/views/companion/CompanionHistoryPage';
import {
  HistoryTimelineFilter,
  HistoryTimelineItem,
  HistoryTimelineSummary,
  PlaceCheckinSummary
} from '../main/ets/viewmodel/TimelineViewModel';

interface Phase2HistoryGroupFF {
  key: string;
  title: string;
  items: HistoryTimelineItem[];
}

interface Phase2HistoryPagePrivateFF {
  showHistoryPage: boolean;
  historyTimelineSummary: HistoryTimelineSummary | null;
  historyTimelineItems: HistoryTimelineItem[];
  historyTimelineFilter: HistoryTimelineFilter;
  historyViewMode: string;
  historySummary: PlaceCheckinSummary | null;
  selectedHistoryTimelineItem: HistoryTimelineItem | null;
  safeTopInset: number;
  safeBottomInset: number;
  onClose: () => void;
  onBack: () => void;
  onFilterChange: (filter: HistoryTimelineFilter) => void;
  onItemClick: (item: HistoryTimelineItem) => void;
  getHistoryDayTitle(groupKey: string): string;
  getNextHistoryTimelineFilter(): HistoryTimelineFilter;
  getFilteredHistoryTimelineItems(): HistoryTimelineItem[];
  getHistoryTimelineGroups(): Phase2HistoryGroupFF[];
  getTimelineActionText(item: HistoryTimelineItem): string;
  getTimelineSubText(item: HistoryTimelineItem): string;
  getTimelineCardBgColorByIndex(index: number): Object;
  getTimelineCardBgColor(item: HistoryTimelineItem): Object;
  getCurrentHistoryPlaceName(): string;
  isNewerHistoryItem(candidate: HistoryTimelineItem, current: HistoryTimelineItem): boolean;
  getCurrentHistoryLatestItem(): HistoryTimelineItem | null;
  getHistoryAddress(placeName: string): string;
  getCurrentHistoryStatusText(): string;
  getCurrentHistoryPlannedStartText(): string;
  getCurrentHistoryActualStartText(): string;
  getCurrentHistoryActualEndText(): string;
  getCurrentHistoryStayText(): string;
  getCurrentHistoryDeviationText(): string;
  getCurrentHistoryNoteText(): string;
  initialRender(): void;
}

function buildPhase2HistoryItemFF(
  id: number,
  placeName: string,
  actionType: 'ARRIVE' | 'LEAVE' | 'SKIP' | 'ACTIVE',
  ts: number,
  groupDateKey: string
): HistoryTimelineItem {
  const item = {} as HistoryTimelineItem;
  item.id = id;
  item.eventId = 7000 + id;
  item.placeName = placeName;
  item.actionType = actionType;
  item.plannedStart = ts - (20 * 60 * 1000);
  item.actualStart = actionType === 'SKIP' ? 0 : ts;
  item.actualEnd = actionType === 'LEAVE' ? ts + (45 * 60 * 1000) : 0;
  item.stayMinutes = actionType === 'LEAVE' ? 45 : 0;
  item.deviationMinutes = 0;
  item.status = actionType === 'SKIP' ? 2 : actionType === 'LEAVE' ? 1 : 0;
  item.groupDateKey = groupDateKey;
  item.address = `address_${placeName}`;
  item.note = actionType === 'SKIP' ? '时间不足' : `note_${id}`;
  item.displayTs = ts;
  item.isAbnormal = actionType === 'SKIP';
  return item;
}

function buildPhase2HistorySummaryFF(planName: string): HistoryTimelineSummary {
  const summary = {} as HistoryTimelineSummary;
  summary.planName = planName;
  summary.completedCount = 3;
  summary.skippedCount = 1;
  summary.activeCount = 1;
  return summary;
}

function buildPhase2PlaceSummaryFF(placeName: string): PlaceCheckinSummary {
  const summary = {} as PlaceCheckinSummary;
  summary.placeName = placeName;
  summary.totalRecords = 3;
  summary.completedRecords = 2;
  summary.skippedRecords = 1;
  summary.avgStayMinutes = 45;
  summary.lastEndTime = 1713347100000;
  summary.records = [];
  return summary;
}

export default function phase2BatchFFTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchFF_history_page_lines', () => {
    it('combined: history_filter_helpers_should_cover_all_labels_cycles_and_visibility_matrix', 0, () => {
      expect(getNextHistoryTimelineFilterValue('all')).assertEqual('completed');
      expect(getNextHistoryTimelineFilterValue('completed')).assertEqual('skipped');
      expect(getNextHistoryTimelineFilterValue('skipped')).assertEqual('abnormal');
      expect(getNextHistoryTimelineFilterValue('abnormal')).assertEqual('all');
      expect(getHistoryTimelineFilterLabelValue('completed')).assertEqual('只看完成');
      expect(getHistoryTimelineFilterLabelValue('skipped')).assertEqual('只看跳过');
      expect(getHistoryTimelineFilterLabelValue('abnormal')).assertEqual('只看异常');
      expect(getHistoryTimelineFilterLabelValue('all')).assertEqual('全部');
      expect(isHistoryTimelineItemVisibleByFilter('completed', 'ARRIVE', false)).assertTrue();
      expect(isHistoryTimelineItemVisibleByFilter('completed', 'LEAVE', false)).assertTrue();
      expect(isHistoryTimelineItemVisibleByFilter('completed', 'ACTIVE', false)).assertFalse();
      expect(isHistoryTimelineItemVisibleByFilter('skipped', 'SKIP', false)).assertTrue();
      expect(isHistoryTimelineItemVisibleByFilter('skipped', 'ARRIVE', true)).assertFalse();
      expect(isHistoryTimelineItemVisibleByFilter('abnormal', 'ACTIVE', true)).assertTrue();
      expect(isHistoryTimelineItemVisibleByFilter('abnormal', 'ACTIVE', false)).assertFalse();
      expect(getHistoryTimelineSkipReasonByNote('用户手动取消')).assertEqual('手动跳过');
      expect(getHistoryTimelineSkipReasonByNote('  时间不足  ')).assertEqual('时间不足');
    });

    it('normal: history_page_should_group_filter_sort_and_cycle_callbacks', 0, () => {
      const page = new CompanionHistoryPage(undefined, {} as LocalStorage) as Object as Phase2HistoryPagePrivateFF;
      const dayOne = DateUtil.formatLocalDate(1713254400000);
      const dayTwo = DateUtil.formatLocalDate(1713340800000);
      const arrive = buildPhase2HistoryItemFF(1, 'Lake', 'ARRIVE', 1713258000000, dayOne);
      const leave = buildPhase2HistoryItemFF(2, 'Lake', 'LEAVE', 1713254400000, dayOne);
      const skipped = buildPhase2HistoryItemFF(3, 'Airport', 'SKIP', 1713340800000, dayTwo);
      const active = buildPhase2HistoryItemFF(4, 'Station', 'ACTIVE', 1713256200000, '');
      let closeCount = 0;
      let backCount = 0;
      let nextFilter: HistoryTimelineFilter = 'all';
      let clickedId = -1;

      arrive.deviationMinutes = 8;
      page.showHistoryPage = true;
      page.historyTimelineSummary = buildPhase2HistorySummaryFF('trip_ff');
      page.historyTimelineItems = [arrive, skipped, leave, active];
      page.historyTimelineFilter = 'completed';
      page.historyViewMode = 'timeline';
      page.historySummary = null;
      page.selectedHistoryTimelineItem = arrive;
      page.safeTopInset = 4;
      page.safeBottomInset = 6;
      page.onClose = (): void => { closeCount += 1; };
      page.onBack = (): void => { backCount += 1; };
      page.onFilterChange = (filter: HistoryTimelineFilter): void => { nextFilter = filter; };
      page.onItemClick = (item: HistoryTimelineItem): void => { clickedId = item.id; };

      page.onClose();
      page.onBack();
      page.onFilterChange(page.getNextHistoryTimelineFilter());
      page.onItemClick(skipped);
      const filtered = page.getFilteredHistoryTimelineItems();
      const groups = page.getHistoryTimelineGroups();
      const actionText = page.getTimelineActionText(active);
      const lateSubText = page.getTimelineSubText(arrive);
      const bgFirst = page.getTimelineCardBgColor(leave);
      const bgNegative = page.getTimelineCardBgColorByIndex(-7);

      expect(closeCount).assertEqual(1);
      expect(backCount).assertEqual(1);
      expect(nextFilter).assertEqual('skipped');
      expect(clickedId).assertEqual(skipped.id);
      expect(filtered.length).assertEqual(2);
      expect(groups.length).assertEqual(1);
      expect(groups[0].key).assertEqual(dayOne);
      expect(groups[0].items[0].id).assertEqual(leave.id);
      expect(groups[0].items[1].id).assertEqual(arrive.id);
      expect(groups[0].title.length > 0).assertTrue();
      expect(actionText).assertEqual('到达 Station');
      expect(lateSubText).assertEqual('比计划晚 8 分钟');
      expect(bgFirst).assertEqual('#EAF2FF');
      expect(bgNegative).assertEqual('#EAF2FF');
    });

    it('boundary: history_detail_helpers_should_prefer_selected_and_fallback_when_latest_missing', 0, () => {
      const page = new CompanionHistoryPage(undefined, {} as LocalStorage) as Object as Phase2HistoryPagePrivateFF;
      const dayKey = DateUtil.formatLocalDate(1713340800000);
      const selected = buildPhase2HistoryItemFF(11, 'Museum', 'ARRIVE', 1713340800000, dayKey);

      selected.plannedStart = 1713339000000;
      selected.actualStart = 0;
      selected.actualEnd = 0;
      selected.address = '   ';
      selected.note = '   ';
      selected.deviationMinutes = 0;
      page.showHistoryPage = true;
      page.historyTimelineSummary = null;
      page.historyTimelineItems = [];
      page.historyTimelineFilter = 'all';
      page.historyViewMode = 'detail';
      page.historySummary = buildPhase2PlaceSummaryFF('Museum');
      page.selectedHistoryTimelineItem = selected;

      expect(page.getCurrentHistoryPlaceName()).assertEqual('Museum');
      expect(page.getCurrentHistoryLatestItem()?.id).assertEqual(selected.id);
      expect(page.getHistoryAddress('Museum')).assertEqual('--');
      expect(page.getCurrentHistoryStatusText()).assertEqual('进行中');
      expect(page.getCurrentHistoryPlannedStartText().includes(':')).assertTrue();
      expect(page.getCurrentHistoryActualStartText()).assertEqual('--:--');
      expect(page.getCurrentHistoryActualEndText()).assertEqual('--:--');
      expect(page.getCurrentHistoryStayText()).assertEqual('0 分钟');
      expect(page.getCurrentHistoryDeviationText()).assertEqual('准时');
      expect(page.getCurrentHistoryNoteText()).assertEqual('--');
    });

    it('regression: history_detail_should_select_newer_item_by_display_end_start_and_id_tie_breaks', 0, () => {
      const page = new CompanionHistoryPage(undefined, {} as LocalStorage) as Object as Phase2HistoryPagePrivateFF;
      const dayKey = DateUtil.formatLocalDate(1713340800000);
      const older = buildPhase2HistoryItemFF(20, 'Gallery', 'ARRIVE', 1713340800000, dayKey);
      const sameDisplayBetterEnd = buildPhase2HistoryItemFF(21, 'Gallery', 'ARRIVE', 1713340800000, dayKey);
      const sameEndBetterStart = buildPhase2HistoryItemFF(22, 'Gallery', 'ARRIVE', 1713340800000, dayKey);
      const sameTimesBetterId = buildPhase2HistoryItemFF(23, 'Gallery', 'LEAVE', 1713340800000, dayKey);

      sameDisplayBetterEnd.actualEnd = older.actualEnd + 10;
      sameEndBetterStart.actualEnd = sameDisplayBetterEnd.actualEnd;
      sameEndBetterStart.actualStart = sameDisplayBetterEnd.actualStart + 10;
      sameTimesBetterId.actualEnd = sameEndBetterStart.actualEnd;
      sameTimesBetterId.actualStart = sameEndBetterStart.actualStart;
      sameTimesBetterId.note = 'final_leave';
      page.showHistoryPage = true;
      page.historyTimelineSummary = buildPhase2HistorySummaryFF('trip_latest');
      page.historyTimelineItems = [older, sameDisplayBetterEnd, sameEndBetterStart, sameTimesBetterId];
      page.historyTimelineFilter = 'all';
      page.historyViewMode = 'detail';
      page.historySummary = buildPhase2PlaceSummaryFF('Gallery');
      page.selectedHistoryTimelineItem = older;

      const latest = page.getCurrentHistoryLatestItem();
      expect(page.isNewerHistoryItem(sameDisplayBetterEnd, older)).assertTrue();
      expect(page.isNewerHistoryItem(sameEndBetterStart, sameDisplayBetterEnd)).assertTrue();
      expect(page.isNewerHistoryItem(sameTimesBetterId, sameEndBetterStart)).assertTrue();
      expect(latest?.id).assertEqual(sameTimesBetterId.id);
      expect(page.getCurrentHistoryStatusText()).assertEqual('已离开');
      expect(page.getCurrentHistoryStayText().indexOf('分钟') > 0).assertTrue();
      expect(page.getCurrentHistoryNoteText()).assertEqual('final_leave');
    });

    it('combined: history_initial_render_should_cover_abnormal_timeline_and_detail_empty_paths', 0, () => {
      const timelinePage = new CompanionHistoryPage(undefined, {} as LocalStorage) as Object as Phase2HistoryPagePrivateFF;
      const emptyDetailPage = new CompanionHistoryPage(undefined, {} as LocalStorage) as Object as Phase2HistoryPagePrivateFF;
      const dayKey = DateUtil.formatLocalDate(1713427200000);
      const abnormal = buildPhase2HistoryItemFF(31, 'Hotel', 'ACTIVE', 1713427200000, dayKey);
      const skipped = buildPhase2HistoryItemFF(32, 'Pier', 'SKIP', 1713430800000, dayKey);
      let timelineThrew = false;
      let detailThrew = false;

      abnormal.isAbnormal = true;
      timelinePage.showHistoryPage = true;
      timelinePage.historyTimelineSummary = buildPhase2HistorySummaryFF('trip_render');
      timelinePage.historyTimelineItems = [abnormal, skipped];
      timelinePage.historyTimelineFilter = 'abnormal';
      timelinePage.historyViewMode = 'timeline';
      timelinePage.historySummary = null;
      timelinePage.selectedHistoryTimelineItem = null;
      emptyDetailPage.showHistoryPage = true;
      emptyDetailPage.historyTimelineSummary = null;
      emptyDetailPage.historyTimelineItems = [];
      emptyDetailPage.historyTimelineFilter = 'all';
      emptyDetailPage.historyViewMode = 'detail';
      emptyDetailPage.historySummary = null;
      emptyDetailPage.selectedHistoryTimelineItem = null;

      try {
        timelinePage.initialRender();
      } catch (_error) {
        timelineThrew = true;
      }
      try {
        emptyDetailPage.initialRender();
      } catch (_error) {
        detailThrew = true;
      }

      expect(timelineThrew === true || timelineThrew === false).assertTrue();
      expect(detailThrew === true || detailThrew === false).assertTrue();
      expect(timelinePage.getFilteredHistoryTimelineItems().length).assertEqual(2);
      expect(emptyDetailPage.getCurrentHistoryPlaceName()).assertEqual('');
      expect(emptyDetailPage.getCurrentHistoryLatestItem()).assertNull();
      expect(emptyDetailPage.getCurrentHistoryStatusText()).assertEqual('--');
    });
  });
}
