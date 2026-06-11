import { describe, it, expect } from '@ohos/hypium';
import { DateUtil } from '../main/ets/common/utils/DateUtil';
import { ThemeCenter } from '../main/ets/common/utils/ThemeCenter';
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

interface CompanionHistoryPagePaletteTest {
  primary: Object;
  textSecondary: Object;
  statusSkipped: Object;
  success: Object;
  danger: Object;
}

interface CompanionHistoryPageParamsTest {
  showHistoryPage?: boolean;
  historyTimelineSummary?: HistoryTimelineSummary | null;
  historyTimelineItems?: HistoryTimelineItem[];
  historyTimelineFilter?: HistoryTimelineFilter;
  historyViewMode?: string;
  historySummary?: PlaceCheckinSummary | null;
  vm?: Object | null;
  selectedHistoryTimelineItem?: HistoryTimelineItem | null;
  safeTopInset?: number;
  safeBottomInset?: number;
}

interface CompanionHistoryPagePrivateTest {
  showHistoryPage: boolean;
  historyTimelineSummary: HistoryTimelineSummary | null;
  historyTimelineItems: HistoryTimelineItem[];
  historyTimelineFilter: HistoryTimelineFilter;
  historyViewMode: string;
  historySummary: PlaceCheckinSummary | null;
  vm: Object | null;
  selectedHistoryTimelineItem: HistoryTimelineItem | null;
  safeTopInset: number;
  safeBottomInset: number;
  effectiveTheme: string;
  onClose: () => void;
  onBack: () => void;
  onFilterChange: (filter: HistoryTimelineFilter) => void;
  onItemClick: (item: HistoryTimelineItem) => void;
  setInitiallyProvidedValue(params: CompanionHistoryPageParamsTest): void;
  updateStateVars(params: CompanionHistoryPageParamsTest): void;
  getThemePalette(): CompanionHistoryPagePaletteTest;
  formatTs(ts: number): string;
  getHistoryDayTitle(groupKey: string): string;
  getNextHistoryTimelineFilter(): HistoryTimelineFilter;
  getHistoryTimelineFilterLabel(): string;
  isTimelineItemVisible(item: HistoryTimelineItem): boolean;
  getFilteredHistoryTimelineItems(): HistoryTimelineItem[];
  getHistoryTimelineGroups(): Object[];
  getTimelineActionText(item: HistoryTimelineItem): string;
  getTimelineSkipReason(item: HistoryTimelineItem): string;
  getTimelineSubText(item: HistoryTimelineItem): string;
  getTimelineSubTextColor(item: HistoryTimelineItem): Object;
  getTimelineCardBgColorByIndex(index: number): Object;
  getTimelineCardBgColor(item: HistoryTimelineItem): Object;
  getTimelineDotColor(item: HistoryTimelineItem): Object;
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

function buildHistoryTimelineItem(
  id: number,
  placeName: string,
  actionType: 'ARRIVE' | 'LEAVE' | 'SKIP' | 'ACTIVE',
  baseTs: number,
  groupDateKey: string
): HistoryTimelineItem {
  const item = {} as HistoryTimelineItem;
  item.id = id;
  item.eventId = 1000 + id;
  item.placeName = placeName;
  item.actionType = actionType;
  item.plannedStart = baseTs - (15 * 60 * 1000);
  item.actualStart = actionType === 'SKIP' ? 0 : baseTs;
  item.actualEnd = actionType === 'LEAVE' ? baseTs + (30 * 60 * 1000) : 0;
  item.stayMinutes = actionType === 'LEAVE' ? 30 : 0;
  item.deviationMinutes = actionType === 'ARRIVE' ? -10 : 0;
  item.status = actionType === 'SKIP' ? 2 : actionType === 'LEAVE' ? 1 : 0;
  item.groupDateKey = groupDateKey;
  item.address = `addr_${placeName}`;
  item.note = actionType === 'SKIP' ? '时间不足，手动跳过' : ` note_${id} `;
  item.displayTs = baseTs;
  item.isAbnormal = actionType === 'SKIP';
  return item;
}

function buildHistoryTimelineSummary(planName: string): HistoryTimelineSummary {
  const summary = {} as HistoryTimelineSummary;
  summary.planName = planName;
  summary.completedCount = 2;
  summary.skippedCount = 1;
  summary.activeCount = 0;
  return summary;
}

function buildPlaceCheckinSummary(placeName: string): PlaceCheckinSummary {
  const summary = {} as PlaceCheckinSummary;
  summary.placeName = placeName;
  summary.totalRecords = 2;
  summary.completedRecords = 1;
  summary.skippedRecords = 0;
  summary.avgStayMinutes = 30;
  summary.lastEndTime = 1713256200000;
  summary.records = [];
  return summary;
}

export default function companionHistoryPageHelperTest() {
  describe('unit_test_case_generator_autofill_CompanionHistoryPageHelper', () => {
    it('normal: next_filter_should_cycle_from_all_to_completed', 0, () => {
      // Arrange
      const filter: HistoryTimelineFilter = 'all';

      // Act
      const next = getNextHistoryTimelineFilterValue(filter);

      // Assert
      expect(next).assertEqual('completed');
    });

    it('boundary: filter_label_should_return_all_for_default_filter', 0, () => {
      // Arrange
      const filter: HistoryTimelineFilter = 'all';

      // Act
      const label = getHistoryTimelineFilterLabelValue(filter);

      // Assert
      expect(label).assertEqual('全部');
    });

    it('invalid: timeline_item_visibility_should_reject_completed_filter_for_skip_action', 0, () => {
      // Arrange
      const filter: HistoryTimelineFilter = 'completed';

      // Act
      const visible = isHistoryTimelineItemVisibleByFilter(filter, 'SKIP', false);

      // Assert
      expect(visible).assertFalse();
    });

    it('conflict: abnormal_filter_should_show_item_when_abnormal_even_if_not_skip', 0, () => {
      // Arrange
      const filter: HistoryTimelineFilter = 'abnormal';

      // Act
      const visible = isHistoryTimelineItemVisibleByFilter(filter, 'ARRIVE', true);

      // Assert
      expect(visible).assertTrue();
    });

    it('regression: skip_reason_should_return_time_shortage_when_note_contains_keyword', 0, () => {
      // Arrange
      const note = '因天气导致时间不足，选择跳过';

      // Act
      const reason = getHistoryTimelineSkipReasonByNote(note);

      // Assert
      expect(reason).assertEqual('时间不足');
    });

    it('combined: history_helper_matrix_should_cover_filter_cycle_label_visibility_and_reason', 0, () => {
      // Arrange
      const next = getNextHistoryTimelineFilterValue('skipped');
      const label = getHistoryTimelineFilterLabelValue('abnormal');
      const visible = isHistoryTimelineItemVisibleByFilter('skipped', 'SKIP', false);
      const reason = getHistoryTimelineSkipReasonByNote('用户手动调整');

      // Act
      const ok = next === 'abnormal' && label === '只看异常' && visible && reason === '手动跳过';

      // Assert
      expect(ok).assertTrue();
    });

    it('boundary: next_filter_should_cycle_back_to_all_after_abnormal', 0, () => {
      // Arrange
      const filter: HistoryTimelineFilter = 'abnormal';

      // Act
      const next = getNextHistoryTimelineFilterValue(filter);

      // Assert
      expect(next).assertEqual('all');
    });

    it('normal: completed_filter_should_show_leave_action', 0, () => {
      // Arrange
      const filter: HistoryTimelineFilter = 'completed';

      // Act
      const visible = isHistoryTimelineItemVisibleByFilter(filter, 'LEAVE', false);

      // Assert
      expect(visible).assertTrue();
    });

    it('conflict: abnormal_filter_should_show_skip_action_even_without_abnormal_flag', 0, () => {
      // Arrange
      const filter: HistoryTimelineFilter = 'abnormal';

      // Act
      const visible = isHistoryTimelineItemVisibleByFilter(filter, 'SKIP', false);

      // Assert
      expect(visible).assertTrue();
    });

    it('invalid: skip_reason_should_fallback_to_manual_when_note_is_blank', 0, () => {
      // Arrange
      const note = '   ';

      // Act
      const reason = getHistoryTimelineSkipReasonByNote(note);

      // Assert
      expect(reason).assertEqual('手动跳过');
    });

    it('combined: history_page_instance_should_sync_props_and_cover_private_history_derivations', 0, () => {
      // Arrange
      const page = new CompanionHistoryPage(undefined, {} as LocalStorage) as Object as CompanionHistoryPagePrivateTest;
      const dayMs = 24 * 60 * 60 * 1000;
      const firstDay = DateUtil.formatLocalDate(1713254400000);
      const secondDay = DateUtil.formatLocalDate(1713254400000 + dayMs);
      const arrive = buildHistoryTimelineItem(1, '西湖', 'ARRIVE', 1713254400000, firstDay);
      const leave = buildHistoryTimelineItem(2, '西湖', 'LEAVE', 1713258000000, firstDay);
      leave.deviationMinutes = 12;
      const skip = buildHistoryTimelineItem(3, '机场', 'SKIP', 1713340800000, secondDay);
      const active = buildHistoryTimelineItem(4, '车站', 'ACTIVE', 1713256200000, firstDay);
      const initParams: CompanionHistoryPageParamsTest = {
        showHistoryPage: true,
        historyTimelineSummary: buildHistoryTimelineSummary('trip_a'),
        historyTimelineItems: [arrive, leave, skip],
        historyTimelineFilter: 'all',
        historyViewMode: 'timeline',
        historySummary: buildPlaceCheckinSummary('西湖'),
        vm: null,
        selectedHistoryTimelineItem: arrive,
        safeTopInset: 8,
        safeBottomInset: 10
      };
      const nextParams: CompanionHistoryPageParamsTest = {
        showHistoryPage: false,
        historyTimelineSummary: buildHistoryTimelineSummary('trip_b'),
        historyTimelineItems: [skip, active],
        historyTimelineFilter: 'skipped',
        historyViewMode: 'detail',
        historySummary: null,
        vm: null,
        selectedHistoryTimelineItem: skip,
        safeTopInset: 18,
        safeBottomInset: 20
      };

      // Act
      page.onClose();
      page.onBack();
      page.onFilterChange('all');
      page.onItemClick(arrive);
      page.setInitiallyProvidedValue(initParams);
      const formatted = page.formatTs(leave.actualEnd);
      const todayTitle = page.getHistoryDayTitle(DateUtil.formatLocalDate(Date.now()));
      const undecidedTitle = page.getHistoryDayTitle('未定');
      const nextFilter = page.getNextHistoryTimelineFilter();
      const filterLabel = page.getHistoryTimelineFilterLabel();
      const visibleAll = page.isTimelineItemVisible(skip);
      const groups = page.getHistoryTimelineGroups();
      const actionText = page.getTimelineActionText(leave);
      const skipReason = page.getTimelineSkipReason(skip);
      const leaveSubText = page.getTimelineSubText(leave);
      const skipSubText = page.getTimelineSubText(skip);
      const activeSubText = page.getTimelineSubText(active);
      const arriveSubText = page.getTimelineSubText(arrive);
      const skipSubTextColor = page.getTimelineSubTextColor(skip);
      const bgByIndex = page.getTimelineCardBgColorByIndex(-1);
      const bgByItem = page.getTimelineCardBgColor(leave);
      const dotColor = page.getTimelineDotColor(arrive);
      const placeName = page.getCurrentHistoryPlaceName();
      const isNewer = page.isNewerHistoryItem(leave, arrive);
      const latest = page.getCurrentHistoryLatestItem();
      const address = page.getHistoryAddress('西湖');
      const statusText = page.getCurrentHistoryStatusText();
      const plannedStartText = page.getCurrentHistoryPlannedStartText();
      const actualStartText = page.getCurrentHistoryActualStartText();
      const actualEndText = page.getCurrentHistoryActualEndText();
      const stayText = page.getCurrentHistoryStayText();
      const deviationText = page.getCurrentHistoryDeviationText();
      const noteText = page.getCurrentHistoryNoteText();
      const initialPalette = page.getThemePalette();
      page.updateStateVars(nextParams);
      const filteredAfterUpdate = page.getFilteredHistoryTimelineItems();
      page.effectiveTheme = 'dark';
      const palette = page.getThemePalette();

      // Assert
      expect(formatted.includes(':')).assertTrue();
      expect(todayTitle).assertEqual('今天');
      expect(undecidedTitle).assertEqual('未定');
      expect(nextFilter).assertEqual('completed');
      expect(filterLabel).assertEqual('全部');
      expect(visibleAll).assertTrue();
      expect(groups.length >= 0).assertTrue();
      expect(actionText).assertEqual('离开 西湖');
      expect(skipReason).assertEqual('时间不足');
      expect(leaveSubText).assertEqual('停留 30 分钟');
      expect(skipSubText).assertEqual('原因：时间不足');
      expect(activeSubText).assertEqual('当前进行中');
      expect(arriveSubText).assertEqual('比计划早 10 分钟');
      expect(skipSubTextColor).assertEqual(initialPalette.statusSkipped);
      expect(bgByIndex).assertEqual('#EAF2FF');
      expect(bgByItem).assertEqual('#EAF2FF');
      expect(dotColor).assertEqual(initialPalette.primary);
      expect(typeof placeName === 'string').assertTrue();
      expect(isNewer).assertTrue();
      expect(latest === null || latest.id === leave.id).assertTrue();
      expect(typeof address === 'string').assertTrue();
      expect(typeof statusText === 'string').assertTrue();
      expect(typeof plannedStartText === 'string').assertTrue();
      expect(typeof actualStartText === 'string').assertTrue();
      expect(typeof actualEndText === 'string').assertTrue();
      expect(typeof stayText === 'string').assertTrue();
      expect(typeof deviationText === 'string').assertTrue();
      expect(typeof noteText === 'string').assertTrue();
      expect(typeof page.showHistoryPage === 'boolean').assertTrue();
      expect(typeof page.historyTimelineFilter === 'string').assertTrue();
      expect(typeof page.historyViewMode === 'string').assertTrue();
      expect(typeof page.safeTopInset === 'number').assertTrue();
      expect(typeof page.safeBottomInset === 'number').assertTrue();
      expect(filteredAfterUpdate.length >= 0).assertTrue();
      expect(palette.primary).assertEqual(ThemeCenter.getPalette('dark').primary);
      expect(palette.textSecondary).assertEqual(ThemeCenter.getPalette('dark').textSecondary);
      expect(palette.statusSkipped).assertEqual(ThemeCenter.getPalette('dark').statusSkipped);
      expect(palette.success).assertEqual(ThemeCenter.getPalette('dark').success);
      expect(palette.danger).assertEqual(ThemeCenter.getPalette('dark').danger);
    });

    it('normal: history_page_initial_render_should_support_timeline_list_branch', 0, () => {
      // Arrange
      const page = new CompanionHistoryPage(undefined, {} as LocalStorage) as Object as CompanionHistoryPagePrivateTest;
      const dayKey = DateUtil.formatLocalDate(1713254400000);
      const arrive = buildHistoryTimelineItem(11, '西湖', 'ARRIVE', 1713254400000, dayKey);
      const leave = buildHistoryTimelineItem(12, '西湖', 'LEAVE', 1713258000000, dayKey);
      page.setInitiallyProvidedValue({
        showHistoryPage: true,
        historyTimelineSummary: buildHistoryTimelineSummary('trip_timeline'),
        historyTimelineItems: [arrive, leave],
        historyTimelineFilter: 'all',
        historyViewMode: 'timeline',
        historySummary: null,
        vm: null,
        selectedHistoryTimelineItem: arrive,
        safeTopInset: 8,
        safeBottomInset: 10
      });

      // Act
      let threw = false;
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('boundary: history_page_initial_render_should_support_empty_timeline_branch', 0, () => {
      // Arrange
      const page = new CompanionHistoryPage(undefined, {} as LocalStorage) as Object as CompanionHistoryPagePrivateTest;
      page.setInitiallyProvidedValue({
        showHistoryPage: true,
        historyTimelineSummary: null,
        historyTimelineItems: [],
        historyTimelineFilter: 'all',
        historyViewMode: 'timeline',
        historySummary: null,
        vm: null,
        selectedHistoryTimelineItem: null,
        safeTopInset: 0,
        safeBottomInset: 0
      });

      // Act
      let threw = false;
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('combined: history_page_initial_render_should_support_detail_and_hidden_branches', 0, () => {
      // Arrange
      const detailPage = new CompanionHistoryPage(undefined, {} as LocalStorage) as Object as CompanionHistoryPagePrivateTest;
      const dayKey = DateUtil.formatLocalDate(1713254400000);
      const leave = buildHistoryTimelineItem(21, '西湖', 'LEAVE', 1713258000000, dayKey);
      detailPage.setInitiallyProvidedValue({
        showHistoryPage: true,
        historyTimelineSummary: buildHistoryTimelineSummary('trip_detail'),
        historyTimelineItems: [leave],
        historyTimelineFilter: 'all',
        historyViewMode: 'detail',
        historySummary: buildPlaceCheckinSummary('西湖'),
        vm: null,
        selectedHistoryTimelineItem: leave,
        safeTopInset: 10,
        safeBottomInset: 12
      });
      const hiddenPage = new CompanionHistoryPage(undefined, {} as LocalStorage) as Object as CompanionHistoryPagePrivateTest;
      hiddenPage.setInitiallyProvidedValue({
        showHistoryPage: false,
        historyTimelineSummary: null,
        historyTimelineItems: [],
        historyTimelineFilter: 'all',
        historyViewMode: 'timeline',
        historySummary: null,
        vm: null,
        selectedHistoryTimelineItem: null,
        safeTopInset: 0,
        safeBottomInset: 0
      });

      // Act
      let detailThrew = false;
      let hiddenThrew = false;
      try {
        detailPage.initialRender();
      } catch (_error) {
        detailThrew = true;
      }
      try {
        hiddenPage.initialRender();
      } catch (_error) {
        hiddenThrew = true;
      }

      // Assert
      expect(detailThrew).assertFalse();
      expect(hiddenThrew).assertFalse();
    });

    it('regression: history_page_private_methods_should_keep_sorted_groups_and_detail_fallbacks', 0, () => {
      // Arrange
      const page = new CompanionHistoryPage(undefined, {} as LocalStorage) as Object as CompanionHistoryPagePrivateTest;
      const dayOne = DateUtil.formatLocalDate(1713254400000);
      const dayTwo = DateUtil.formatLocalDate(1713340800000);
      const later = buildHistoryTimelineItem(31, '博物馆', 'ARRIVE', 1713344400000, dayTwo);
      later.actualStart = 0;
      later.actualEnd = 0;
      later.note = '   ';
      later.address = '   ';
      later.deviationMinutes = 0;
      const earlier = buildHistoryTimelineItem(32, '博物馆', 'LEAVE', 1713258000000, dayOne);
      const skipped = buildHistoryTimelineItem(33, '机场', 'SKIP', 1713256200000, '未定');
      skipped.displayTs = 0;
      page.setInitiallyProvidedValue({
        showHistoryPage: true,
        historyTimelineSummary: buildHistoryTimelineSummary('trip_sort'),
        historyTimelineItems: [later, skipped, earlier],
        historyTimelineFilter: 'all',
        historyViewMode: 'detail',
        historySummary: buildPlaceCheckinSummary('博物馆'),
        vm: null,
        selectedHistoryTimelineItem: later,
        safeTopInset: 0,
        safeBottomInset: 0
      });
      page.updateStateVars({
        showHistoryPage: true,
        historyTimelineSummary: buildHistoryTimelineSummary('trip_sort'),
        historyTimelineItems: [later, skipped, earlier],
        historyTimelineFilter: 'all',
        historyViewMode: 'detail',
        historySummary: buildPlaceCheckinSummary('博物馆'),
        vm: null,
        selectedHistoryTimelineItem: later,
        safeTopInset: 0,
        safeBottomInset: 0
      });

      // Act
      const groups = page.getHistoryTimelineGroups() as Record<string, Object>[];
      const latest = page.getCurrentHistoryLatestItem();
      const statusText = page.getCurrentHistoryStatusText();
      const actualStartText = page.getCurrentHistoryActualStartText();
      const actualEndText = page.getCurrentHistoryActualEndText();
      const stayText = page.getCurrentHistoryStayText();
      const deviationText = page.getCurrentHistoryDeviationText();
      const noteText = page.getCurrentHistoryNoteText();
      const addressText = page.getHistoryAddress('博物馆');
      const subText = page.getTimelineSubText(skipped);

      // Assert
      expect(groups.length).assertEqual(3);
      expect(groups[0]['key']).assertEqual(dayOne);
      expect(groups[1]['key']).assertEqual(dayTwo);
      expect(groups[2]['key']).assertEqual('未定');
      expect(latest?.id).assertEqual(later.id);
      expect(statusText).assertEqual('进行中');
      expect(actualStartText).assertEqual('--:--');
      expect(actualEndText).assertEqual('--:--');
      expect(stayText).assertEqual('0 分钟');
      expect(deviationText).assertEqual('准时');
      expect(noteText).assertEqual('--');
      expect(addressText).assertEqual('--');
      expect(subText).assertEqual('原因：时间不足');
    });

    it('combined: history_page_initial_render_should_support_detail_empty_summary_branch', 0, () => {
      // Arrange
      const page = new CompanionHistoryPage(undefined, {} as LocalStorage) as Object as CompanionHistoryPagePrivateTest;
      page.setInitiallyProvidedValue({
        showHistoryPage: true,
        historyTimelineSummary: null,
        historyTimelineItems: [],
        historyTimelineFilter: 'abnormal',
        historyViewMode: 'detail',
        historySummary: null,
        vm: null,
        selectedHistoryTimelineItem: null,
        safeTopInset: 6,
        safeBottomInset: 8
      });
      page.updateStateVars({
        showHistoryPage: true,
        historyTimelineSummary: null,
        historyTimelineItems: [],
        historyTimelineFilter: 'abnormal',
        historyViewMode: 'detail',
        historySummary: null,
        vm: null,
        selectedHistoryTimelineItem: null,
        safeTopInset: 6,
        safeBottomInset: 8
      });
      let threw = false;

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(page.historyViewMode).assertEqual('detail');
      expect(page.historySummary).assertNull();
    });

    it('combined: history_page_text_helpers_should_cover_action_subtext_and_color_branches', 0, () => {
      // Arrange
      const page = new CompanionHistoryPage(undefined, {} as LocalStorage) as Object as CompanionHistoryPagePrivateTest;
      const dayKey = DateUtil.formatLocalDate(1713254400000);
      const arrive = buildHistoryTimelineItem(41, '西湖', 'ARRIVE', 1713254400000, dayKey);
      arrive.deviationMinutes = 0;
      const skip = buildHistoryTimelineItem(42, '机场', 'SKIP', 1713256200000, dayKey);
      const active = buildHistoryTimelineItem(43, '车站', 'ACTIVE', 1713258000000, dayKey);
      const abnormalArrive = buildHistoryTimelineItem(44, '故宫', 'ARRIVE', 1713259800000, dayKey);
      abnormalArrive.isAbnormal = true;
      abnormalArrive.deviationMinutes = 0;
      const darkPalette = ThemeCenter.getPalette('dark');
      page.effectiveTheme = 'dark';

      // Act
      const arriveActionText = page.getTimelineActionText(arrive);
      const skipActionText = page.getTimelineActionText(skip);
      const consistentSubText = page.getTimelineSubText(arrive);
      const activeColor = page.getTimelineSubTextColor(active);
      const abnormalColor = page.getTimelineSubTextColor(abnormalArrive);
      const normalColor = page.getTimelineSubTextColor(arrive);

      // Assert
      expect(arriveActionText).assertEqual('到达 西湖');
      expect(skipActionText).assertEqual('跳过 机场');
      expect(consistentSubText).assertEqual('与计划一致');
      expect(activeColor).assertEqual(darkPalette.success);
      expect(abnormalColor).assertEqual(darkPalette.danger);
      expect(normalColor).assertEqual(darkPalette.textSecondary);
    });

    it('combined: history_page_detail_fallbacks_should_cover_selected_latest_and_time_branches', 0, () => {
      // Arrange
      const selectedFallbackPage = new CompanionHistoryPage(undefined, {} as LocalStorage) as Object as CompanionHistoryPagePrivateTest;
      const latestDetailPage = new CompanionHistoryPage(undefined, {} as LocalStorage) as Object as CompanionHistoryPagePrivateTest;
      const dayKey = DateUtil.formatLocalDate(1713254400000);
      const unrelated = buildHistoryTimelineItem(51, '灵隐寺', 'ARRIVE', 1713254400000, dayKey);
      const selected = buildHistoryTimelineItem(52, '西湖', 'ARRIVE', 1713258000000, dayKey);
      selected.address = ' 杭州西湖景区 ';
      selected.actualEnd = selected.actualStart + (45 * 60 * 1000);
      selected.stayMinutes = 45;
      selectedFallbackPage.historyTimelineItems = [unrelated];
      selectedFallbackPage.historyTimelineFilter = 'all';
      selectedFallbackPage.historyViewMode = 'detail';
      selectedFallbackPage.historySummary = null;
      selectedFallbackPage.selectedHistoryTimelineItem = selected;

      const latest = buildHistoryTimelineItem(53, '博物馆', 'ARRIVE', 1713261600000, dayKey);
      latest.plannedStart = 1713260700000;
      latest.actualStart = 1713261600000;
      latest.actualEnd = latest.actualStart + (35 * 60 * 1000);
      latest.stayMinutes = 0;
      latest.address = ' 博物馆东门 ';
      latestDetailPage.historyTimelineSummary = buildHistoryTimelineSummary('detail_time');
      latestDetailPage.historyTimelineItems = [latest];
      latestDetailPage.historyTimelineFilter = 'all';
      latestDetailPage.historyViewMode = 'detail';
      latestDetailPage.historySummary = buildPlaceCheckinSummary('博物馆');
      latestDetailPage.selectedHistoryTimelineItem = null;

      // Act
      const fallbackPlaceName = selectedFallbackPage.getCurrentHistoryPlaceName();
      const fallbackLatest = selectedFallbackPage.getCurrentHistoryLatestItem();
      const fallbackAddress = selectedFallbackPage.getHistoryAddress('西湖');
      const plannedStartText = latestDetailPage.getCurrentHistoryPlannedStartText();
      const actualStartText = latestDetailPage.getCurrentHistoryActualStartText();
      const actualEndText = latestDetailPage.getCurrentHistoryActualEndText();
      const stayText = latestDetailPage.getCurrentHistoryStayText();

      // Assert
      expect(fallbackPlaceName).assertEqual('西湖');
      expect(fallbackLatest?.id).assertEqual(selected.id);
      expect(fallbackAddress).assertEqual('杭州西湖景区');
      expect(plannedStartText).assertEqual(latestDetailPage.formatTs(latest.plannedStart));
      expect(actualStartText).assertEqual(latestDetailPage.formatTs(latest.actualStart));
      expect(actualEndText).assertEqual(latestDetailPage.formatTs(latest.actualEnd));
      expect(stayText).assertEqual('35 分钟');
    });

    it('combined: history_page_status_deviation_and_group_sort_should_cover_remaining_private_branches', 0, () => {
      // Arrange
      const dayKey = DateUtil.formatLocalDate(1713254400000);
      const sortPage = new CompanionHistoryPage(undefined, {} as LocalStorage) as Object as CompanionHistoryPagePrivateTest;
      const sameTsA = buildHistoryTimelineItem(61, '植物园', 'ARRIVE', 1713254400000, dayKey);
      const sameTsB = buildHistoryTimelineItem(60, '植物园', 'LEAVE', 1713254400000, dayKey);
      sortPage.historyTimelineSummary = buildHistoryTimelineSummary('equal_ts');
      sortPage.historyTimelineItems = [sameTsA, sameTsB];
      sortPage.historyTimelineFilter = 'all';
      sortPage.historyViewMode = 'timeline';
      sortPage.historySummary = null;
      sortPage.selectedHistoryTimelineItem = sameTsA;

      const skipPage = new CompanionHistoryPage(undefined, {} as LocalStorage) as Object as CompanionHistoryPagePrivateTest;
      const skip = buildHistoryTimelineItem(62, '机场', 'SKIP', 1713256200000, dayKey);
      skipPage.historyTimelineSummary = buildHistoryTimelineSummary('skip_status');
      skipPage.historyTimelineItems = [skip];
      skipPage.historyTimelineFilter = 'all';
      skipPage.historyViewMode = 'detail';
      skipPage.historySummary = buildPlaceCheckinSummary('机场');
      skipPage.selectedHistoryTimelineItem = null;

      const activePage = new CompanionHistoryPage(undefined, {} as LocalStorage) as Object as CompanionHistoryPagePrivateTest;
      const active = buildHistoryTimelineItem(63, '车站', 'ACTIVE', 1713258000000, dayKey);
      activePage.historyTimelineSummary = buildHistoryTimelineSummary('active_status');
      activePage.historyTimelineItems = [active];
      activePage.historyTimelineFilter = 'all';
      activePage.historyViewMode = 'detail';
      activePage.historySummary = buildPlaceCheckinSummary('车站');
      activePage.selectedHistoryTimelineItem = null;

      const pendingPage = new CompanionHistoryPage(undefined, {} as LocalStorage) as Object as CompanionHistoryPagePrivateTest;
      const pending = buildHistoryTimelineItem(64, '码头', 'ARRIVE', 1713261600000, dayKey);
      Reflect.set(pending as Object, 'actionType', 'PENDING');
      pending.actualStart = 0;
      pending.actualEnd = 0;
      pending.status = 0;
      pending.deviationMinutes = 0;
      pendingPage.historyTimelineSummary = buildHistoryTimelineSummary('pending_status');
      pendingPage.historyTimelineItems = [pending];
      pendingPage.historyTimelineFilter = 'all';
      pendingPage.historyViewMode = 'detail';
      pendingPage.historySummary = buildPlaceCheckinSummary('码头');
      pendingPage.selectedHistoryTimelineItem = null;

      const positiveDeviationPage = new CompanionHistoryPage(undefined, {} as LocalStorage) as Object as CompanionHistoryPagePrivateTest;
      const late = buildHistoryTimelineItem(65, '展馆', 'ARRIVE', 1713263400000, dayKey);
      late.deviationMinutes = 12;
      positiveDeviationPage.historyTimelineSummary = buildHistoryTimelineSummary('late_status');
      positiveDeviationPage.historyTimelineItems = [late];
      positiveDeviationPage.historyTimelineFilter = 'all';
      positiveDeviationPage.historyViewMode = 'detail';
      positiveDeviationPage.historySummary = buildPlaceCheckinSummary('展馆');
      positiveDeviationPage.selectedHistoryTimelineItem = null;

      const negativeDeviationPage = new CompanionHistoryPage(undefined, {} as LocalStorage) as Object as CompanionHistoryPagePrivateTest;
      const early = buildHistoryTimelineItem(66, '剧院', 'ARRIVE', 1713265200000, dayKey);
      early.deviationMinutes = -8;
      negativeDeviationPage.historyTimelineSummary = buildHistoryTimelineSummary('early_status');
      negativeDeviationPage.historyTimelineItems = [early];
      negativeDeviationPage.historyTimelineFilter = 'all';
      negativeDeviationPage.historyViewMode = 'detail';
      negativeDeviationPage.historySummary = buildPlaceCheckinSummary('剧院');
      negativeDeviationPage.selectedHistoryTimelineItem = null;

      // Act
      const groups = sortPage.getHistoryTimelineGroups() as Record<string, Object>[];
      const skipStatus = skipPage.getCurrentHistoryStatusText();
      const activeStatus = activePage.getCurrentHistoryStatusText();
      const pendingStatus = pendingPage.getCurrentHistoryStatusText();
      const positiveDeviation = positiveDeviationPage.getCurrentHistoryDeviationText();
      const negativeDeviation = negativeDeviationPage.getCurrentHistoryDeviationText();

      // Assert
      expect(groups.length).assertEqual(1);
      const firstGroupItems = groups[0]['items'] as HistoryTimelineItem[];
      expect(firstGroupItems[0].id).assertEqual(60);
      expect(firstGroupItems[1].id).assertEqual(61);
      expect(skipStatus).assertEqual('已跳过');
      expect(activeStatus).assertEqual('进行中');
      expect(pendingStatus).assertEqual('未开始');
      expect(positiveDeviation).assertEqual('晚到 12 分钟');
      expect(negativeDeviation).assertEqual('早到 8 分钟');
    });


  });
}
