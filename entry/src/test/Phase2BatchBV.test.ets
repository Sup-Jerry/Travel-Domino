import { describe, expect, it } from '@ohos/hypium';
import { DateUtil } from '../main/ets/common/utils/DateUtil';
import {
  CompanionControlPage
} from '../main/ets/pages/components/views/companion/CompanionControlPage';
import {
  CompanionExecutionWeatherCard
} from '../main/ets/pages/components/views/companion/CompanionExecutionWeatherCard';
import {
  CompanionFocusedCardHost
} from '../main/ets/pages/components/views/companion/CompanionFocusedCardHost';
import {
  CompanionHistoryPage
} from '../main/ets/pages/components/views/companion/CompanionHistoryPage';
import {
  shouldShowCompanionFilterOverlay,
  shouldShowCompanionHistoryOverlay,
  shouldShowCompanionSearchOverlay
} from '../main/ets/pages/components/views/companion/CompanionOverlayPages';
import {
  CompanionTimelineSection
} from '../main/ets/pages/components/views/companion/CompanionTimelineSection';
import {
  HistoryTimelineFilter,
  HistoryTimelineItem,
  PlaceCheckinSummary
} from '../main/ets/viewmodel/TimelineViewModel';

type PaletteLike = { [key: string]: string };

type HistoryPageHarness = {
  effectiveTheme: string;
  historyTimelineFilter: HistoryTimelineFilter;
  historyTimelineItems: HistoryTimelineItem[];
  historySummary: PlaceCheckinSummary | null;
  selectedHistoryTimelineItem: HistoryTimelineItem | null;
  getThemePalette: () => PaletteLike;
  isTimelineItemVisible: (item: HistoryTimelineItem) => boolean;
  getFilteredHistoryTimelineItems: () => HistoryTimelineItem[];
  getHistoryDayTitle: (groupKey: string) => string;
  getTimelineSkipReason: (item: HistoryTimelineItem) => string;
  getCurrentHistoryPlaceName: () => string;
  isNewerHistoryItem: (candidate: HistoryTimelineItem, current: HistoryTimelineItem) => boolean;
  getCurrentHistoryLatestItem: () => HistoryTimelineItem | null;
  getTimelineCardBgColorByIndex: (index: number) => string;
};

function getPrototypeMethod<T>(proto: Object, name: string): T {
  return Reflect.get(proto, name) as T;
}

function buildHistoryItem(overrides: Partial<HistoryTimelineItem> = {}): HistoryTimelineItem {
  return {
    id: 1,
    eventId: 1,
    placeName: '西湖',
    actionType: 'ARRIVE',
    plannedStart: 0,
    actualStart: 0,
    actualEnd: 0,
    stayMinutes: 0,
    deviationMinutes: 0,
    status: 0,
    groupDateKey: '2026-04-19',
    address: '',
    note: '',
    displayTs: 0,
    isAbnormal: false,
    ...overrides
  };
}

function buildHistorySummary(placeName: string): PlaceCheckinSummary {
  return {
    placeName: placeName,
    totalRecords: 1,
    completedRecords: 0,
    skippedRecords: 0,
    avgStayMinutes: 0,
    lastEndTime: 0,
    records: []
  };
}

const controlGetThemePalette = getPrototypeMethod<(this: Object) => PaletteLike>(
  CompanionControlPage.prototype as Object,
  'getThemePalette'
);
const controlGetCardTranslateX = getPrototypeMethod<(this: Object, phase: string) => number>(
  CompanionControlPage.prototype as Object,
  'getCardTranslateX'
);
const controlGetCardOpacity = getPrototypeMethod<(this: Object, phase: string) => number>(
  CompanionControlPage.prototype as Object,
  'getCardOpacity'
);
const controlGetCardScale = getPrototypeMethod<(this: Object, phase: string) => number>(
  CompanionControlPage.prototype as Object,
  'getCardScale'
);

const focusedGetThemePalette = getPrototypeMethod<(this: Object) => PaletteLike>(
  CompanionFocusedCardHost.prototype as Object,
  'getThemePalette'
);

const executionGetThemePalette = getPrototypeMethod<(this: Object) => PaletteLike>(
  CompanionExecutionWeatherCard.prototype as Object,
  'getThemePalette'
);

const timelineGetThemePalette = getPrototypeMethod<(this: Object) => PaletteLike>(
  CompanionTimelineSection.prototype as Object,
  'getThemePalette'
);

const historyGetThemePalette = getPrototypeMethod<(this: Object) => PaletteLike>(
  CompanionHistoryPage.prototype as Object,
  'getThemePalette'
);
const historyFormatTs = getPrototypeMethod<(this: Object, ts: number) => string>(
  CompanionHistoryPage.prototype as Object,
  'formatTs'
);
const historyGetDayTitle = getPrototypeMethod<(this: Object, groupKey: string) => string>(
  CompanionHistoryPage.prototype as Object,
  'getHistoryDayTitle'
);
const historyGetNextFilter = getPrototypeMethod<(this: Object) => HistoryTimelineFilter>(
  CompanionHistoryPage.prototype as Object,
  'getNextHistoryTimelineFilter'
);
const historyGetFilterLabel = getPrototypeMethod<(this: Object) => string>(
  CompanionHistoryPage.prototype as Object,
  'getHistoryTimelineFilterLabel'
);
const historyIsTimelineItemVisible = getPrototypeMethod<(this: Object, item: HistoryTimelineItem) => boolean>(
  CompanionHistoryPage.prototype as Object,
  'isTimelineItemVisible'
);
const historyGetFilteredItems = getPrototypeMethod<(this: Object) => HistoryTimelineItem[]>(
  CompanionHistoryPage.prototype as Object,
  'getFilteredHistoryTimelineItems'
);
const historyGetGroups = getPrototypeMethod<(this: Object) => Array<{ key: string; title: string; items: HistoryTimelineItem[] }>>(
  CompanionHistoryPage.prototype as Object,
  'getHistoryTimelineGroups'
);
const historyGetTimelineActionText = getPrototypeMethod<(this: Object, item: HistoryTimelineItem) => string>(
  CompanionHistoryPage.prototype as Object,
  'getTimelineActionText'
);
const historyGetTimelineSkipReason = getPrototypeMethod<(this: Object, item: HistoryTimelineItem) => string>(
  CompanionHistoryPage.prototype as Object,
  'getTimelineSkipReason'
);
const historyGetTimelineSubText = getPrototypeMethod<(this: Object, item: HistoryTimelineItem) => string>(
  CompanionHistoryPage.prototype as Object,
  'getTimelineSubText'
);
const historyGetTimelineSubTextColor = getPrototypeMethod<(this: Object, item: HistoryTimelineItem) => string>(
  CompanionHistoryPage.prototype as Object,
  'getTimelineSubTextColor'
);
const historyGetCardBgColorByIndex = getPrototypeMethod<(this: Object, index: number) => string>(
  CompanionHistoryPage.prototype as Object,
  'getTimelineCardBgColorByIndex'
);
const historyGetCardBgColor = getPrototypeMethod<(this: Object, item: HistoryTimelineItem) => string>(
  CompanionHistoryPage.prototype as Object,
  'getTimelineCardBgColor'
);
const historyGetCurrentPlaceName = getPrototypeMethod<(this: Object) => string>(
  CompanionHistoryPage.prototype as Object,
  'getCurrentHistoryPlaceName'
);
const historyIsNewerItem = getPrototypeMethod<(this: Object, candidate: HistoryTimelineItem, current: HistoryTimelineItem) => boolean>(
  CompanionHistoryPage.prototype as Object,
  'isNewerHistoryItem'
);
const historyGetCurrentLatestItem = getPrototypeMethod<(this: Object) => HistoryTimelineItem | null>(
  CompanionHistoryPage.prototype as Object,
  'getCurrentHistoryLatestItem'
);
const historyGetAddress = getPrototypeMethod<(this: Object, placeName: string) => string>(
  CompanionHistoryPage.prototype as Object,
  'getHistoryAddress'
);
const historyGetStatusText = getPrototypeMethod<(this: Object) => string>(
  CompanionHistoryPage.prototype as Object,
  'getCurrentHistoryStatusText'
);
const historyGetPlannedStartText = getPrototypeMethod<(this: Object) => string>(
  CompanionHistoryPage.prototype as Object,
  'getCurrentHistoryPlannedStartText'
);
const historyGetActualStartText = getPrototypeMethod<(this: Object) => string>(
  CompanionHistoryPage.prototype as Object,
  'getCurrentHistoryActualStartText'
);
const historyGetActualEndText = getPrototypeMethod<(this: Object) => string>(
  CompanionHistoryPage.prototype as Object,
  'getCurrentHistoryActualEndText'
);
const historyGetStayText = getPrototypeMethod<(this: Object) => string>(
  CompanionHistoryPage.prototype as Object,
  'getCurrentHistoryStayText'
);
const historyGetDeviationText = getPrototypeMethod<(this: Object) => string>(
  CompanionHistoryPage.prototype as Object,
  'getCurrentHistoryDeviationText'
);
const historyGetNoteText = getPrototypeMethod<(this: Object) => string>(
  CompanionHistoryPage.prototype as Object,
  'getCurrentHistoryNoteText'
);

function createHistoryPageHarness(overrides: Partial<HistoryPageHarness> = {}): HistoryPageHarness {
  return {
    effectiveTheme: 'light',
    historyTimelineFilter: 'all',
    historyTimelineItems: [],
    historySummary: null,
    selectedHistoryTimelineItem: null,
    getThemePalette(): PaletteLike {
      return historyGetThemePalette.call(this as Object);
    },
    isTimelineItemVisible(item: HistoryTimelineItem): boolean {
      return historyIsTimelineItemVisible.call(this as Object, item);
    },
    getFilteredHistoryTimelineItems(): HistoryTimelineItem[] {
      return historyGetFilteredItems.call(this as Object);
    },
    getHistoryDayTitle(groupKey: string): string {
      return historyGetDayTitle.call(this as Object, groupKey);
    },
    getTimelineSkipReason(item: HistoryTimelineItem): string {
      return historyGetTimelineSkipReason.call(this as Object, item);
    },
    getCurrentHistoryPlaceName(): string {
      return historyGetCurrentPlaceName.call(this as Object);
    },
    isNewerHistoryItem(candidate: HistoryTimelineItem, current: HistoryTimelineItem): boolean {
      return historyIsNewerItem.call(this as Object, candidate, current);
    },
    getCurrentHistoryLatestItem(): HistoryTimelineItem | null {
      return historyGetCurrentLatestItem.call(this as Object);
    },
    getTimelineCardBgColorByIndex(index: number): string {
      return historyGetCardBgColorByIndex.call(this as Object, index);
    },
    ...overrides
  };
}

export default function phase2BatchBVTest() {
  describe('phase2BatchBVTest', () => {
    it('normal: control_page_private_wrappers_should_follow_switch_state_and_dark_palette', 0, () => {
      // Arrange
      const page = {
        effectiveTheme: 'dark',
        isCardSwitching: true,
        cardSwitchProgress: 0.5
      };

      // Act
      const palette = controlGetThemePalette.call(page as Object);
      const translateX = controlGetCardTranslateX.call(page as Object, 'incoming');
      const opacity = controlGetCardOpacity.call(page as Object, 'incoming');
      const scale = controlGetCardScale.call(page as Object, 'incoming');

      // Assert
      expect(palette.companionCardBg).assertEqual('#1A2A42');
      expect(translateX).assertEqual(9);
      expect(opacity).assertEqual(0.5);
      expect(scale).assertEqual(0.996);
    });

    it('normal: focused_host_private_theme_palette_should_switch_by_effective_theme', 0, () => {
      // Arrange
      const darkHost = { effectiveTheme: 'dark' };
      const lightHost = { effectiveTheme: 'light' };

      // Act
      const darkPalette = focusedGetThemePalette.call(darkHost as Object);
      const lightPalette = focusedGetThemePalette.call(lightHost as Object);

      // Assert
      expect(darkPalette.primary).assertEqual('#66A3FF');
      expect(lightPalette.textPrimary).assertEqual('#1F2937');
    });

    it('normal: execution_weather_card_private_theme_palette_should_return_expected_light_and_dark_values', 0, () => {
      // Arrange
      const lightCard = { effectiveTheme: 'light' };
      const darkCard = { effectiveTheme: 'dark' };

      // Act
      const lightPalette = executionGetThemePalette.call(lightCard as Object);
      const darkPalette = executionGetThemePalette.call(darkCard as Object);

      // Assert
      expect(lightPalette.companionCardBg).assertEqual('#FFFFFF');
      expect(darkPalette.border).assertEqual('#2A3B56');
    });

    it('normal: timeline_section_private_theme_palette_should_return_dark_palette', 0, () => {
      // Arrange
      const section = { effectiveTheme: 'dark' };

      // Act
      const palette = timelineGetThemePalette.call(section as Object);

      // Assert
      expect(palette.companionBg).assertEqual('#121D2D');
      expect(palette.textSecondary).assertEqual('#C0CEE1');
    });

    it('normal: overlay_page_helpers_should_keep_three_overlay_flags_independent', 0, () => {
      // Arrange
      // Act
      const historyVisible = shouldShowCompanionHistoryOverlay(false);
      const searchVisible = shouldShowCompanionSearchOverlay(true);
      const filterVisible = shouldShowCompanionFilterOverlay(true);

      // Assert
      expect(historyVisible).assertFalse();
      expect(searchVisible).assertTrue();
      expect(filterVisible).assertTrue();
    });

    it('normal: history_page_private_format_and_day_title_should_cover_zero_today_fixed_and_undetermined', 0, () => {
      // Arrange
      const page = createHistoryPageHarness();
      const ts = new Date('2026-04-19T08:30:00+08:00').getTime();
      const todayKey = DateUtil.formatLocalDate(Date.now());
      const fixedKey = '2026-04-21';

      // Act
      const emptyText = historyFormatTs.call(page as Object, 0);
      const timeText = historyFormatTs.call(page as Object, ts);
      const undeterminedTitle = historyGetDayTitle.call(page as Object, '未定');
      const todayTitle = historyGetDayTitle.call(page as Object, todayKey);
      const fixedTitle = historyGetDayTitle.call(page as Object, fixedKey);

      // Assert
      expect(emptyText).assertEqual('--:--');
      expect(timeText).assertEqual(DateUtil.formatDate(new Date(ts), 'HH:mm'));
      expect(undeterminedTitle).assertEqual('未定');
      expect(todayTitle).assertEqual('今天');
      expect(fixedTitle).assertEqual(DateUtil.formatDate(new Date(fixedKey), 'MM月dd日'));
    });

    it('normal: history_page_private_filter_methods_should_follow_current_filter_state', 0, () => {
      // Arrange
      const page = createHistoryPageHarness({
        historyTimelineFilter: 'skipped'
      });

      // Act
      const nextFilter = historyGetNextFilter.call(page as Object);
      const label = historyGetFilterLabel.call(page as Object);

      // Assert
      expect(nextFilter).assertEqual('abnormal');
      expect(label).assertEqual('只看跳过');
    });

    it('normal: history_page_private_filtered_items_should_delegate_visibility_rule', 0, () => {
      // Arrange
      const arrive = buildHistoryItem({ id: 1, actionType: 'ARRIVE' });
      const skip = buildHistoryItem({ id: 2, actionType: 'SKIP' });
      const leave = buildHistoryItem({ id: 3, actionType: 'LEAVE' });
      const page = createHistoryPageHarness({
        historyTimelineFilter: 'completed',
        historyTimelineItems: [arrive, skip, leave]
      });

      // Act
      const skipVisible = historyIsTimelineItemVisible.call(page as Object, skip);
      const filtered = historyGetFilteredItems.call(page as Object);

      // Assert
      expect(skipVisible).assertFalse();
      expect(filtered.length).assertEqual(2);
      expect(filtered[0].id).assertEqual(1);
      expect(filtered[1].id).assertEqual(3);
    });

    it('normal: history_page_private_groups_should_sort_by_group_key_display_time_and_id', 0, () => {
      // Arrange
      const first = buildHistoryItem({
        id: 3,
        groupDateKey: '2026-04-21',
        displayTs: 200
      });
      const second = buildHistoryItem({
        id: 2,
        groupDateKey: '2026-04-21',
        displayTs: 100
      });
      const undetermined = buildHistoryItem({
        id: 4,
        placeName: '外滩',
        groupDateKey: '',
        displayTs: 300
      });
      const page = createHistoryPageHarness({
        historyTimelineItems: [first, second, undetermined]
      });

      // Act
      const groups = historyGetGroups.call(page as Object);

      // Assert
      expect(groups.length).assertEqual(2);
      expect(groups[0].key).assertEqual('2026-04-21');
      expect(groups[0].title).assertEqual(DateUtil.formatDate(new Date('2026-04-21'), 'MM月dd日'));
      expect(groups[0].items[0].id).assertEqual(2);
      expect(groups[0].items[1].id).assertEqual(3);
      expect(groups[1].key).assertEqual('未定');
      expect(groups[1].title).assertEqual('未定');
      expect(groups[1].items[0].id).assertEqual(4);
    });

    it('normal: history_page_private_action_text_and_skip_reason_should_cover_each_branch', 0, () => {
      // Arrange
      const arrive = buildHistoryItem({ actionType: 'ARRIVE' });
      const leave = buildHistoryItem({ actionType: 'LEAVE' });
      const skip = buildHistoryItem({ actionType: 'SKIP', note: '  因天气导致时间不足，选择跳过  ' });
      const active = buildHistoryItem({ actionType: 'ACTIVE' });
      const page = createHistoryPageHarness();

      // Act
      const arriveText = historyGetTimelineActionText.call(page as Object, arrive);
      const leaveText = historyGetTimelineActionText.call(page as Object, leave);
      const skipText = historyGetTimelineActionText.call(page as Object, skip);
      const activeText = historyGetTimelineActionText.call(page as Object, active);
      const reason = historyGetTimelineSkipReason.call(page as Object, skip);

      // Assert
      expect(arriveText).assertEqual('到达 西湖');
      expect(leaveText).assertEqual('离开 西湖');
      expect(skipText).assertEqual('跳过 西湖');
      expect(activeText).assertEqual('到达 西湖');
      expect(reason).assertEqual('时间不足');
    });

    it('normal: history_page_private_sub_text_should_cover_leave_skip_active_and_deviation_states', 0, () => {
      // Arrange
      const leave = buildHistoryItem({ actionType: 'LEAVE', stayMinutes: 45 });
      const skip = buildHistoryItem({ actionType: 'SKIP', note: '时间不足' });
      const active = buildHistoryItem({ actionType: 'ACTIVE' });
      const late = buildHistoryItem({ deviationMinutes: 12 });
      const early = buildHistoryItem({ deviationMinutes: -8 });
      const onTime = buildHistoryItem({ deviationMinutes: 0 });
      const page = createHistoryPageHarness();

      // Act
      const leaveText = historyGetTimelineSubText.call(page as Object, leave);
      const skipText = historyGetTimelineSubText.call(page as Object, skip);
      const activeText = historyGetTimelineSubText.call(page as Object, active);
      const lateText = historyGetTimelineSubText.call(page as Object, late);
      const earlyText = historyGetTimelineSubText.call(page as Object, early);
      const onTimeText = historyGetTimelineSubText.call(page as Object, onTime);

      // Assert
      expect(leaveText).assertEqual('停留 45 分钟');
      expect(skipText).assertEqual('原因：时间不足');
      expect(activeText).assertEqual('当前进行中');
      expect(lateText).assertEqual('比计划晚 12 分钟');
      expect(earlyText).assertEqual('比计划早 8 分钟');
      expect(onTimeText).assertEqual('与计划一致');
    });

    it('normal: history_page_private_sub_text_color_and_index_palette_should_follow_light_theme_rules', 0, () => {
      // Arrange
      const skip = buildHistoryItem({ actionType: 'SKIP' });
      const active = buildHistoryItem({ actionType: 'ACTIVE' });
      const abnormal = buildHistoryItem({ isAbnormal: true });
      const normal = buildHistoryItem();
      const page = createHistoryPageHarness();

      // Act
      const skipColor = historyGetTimelineSubTextColor.call(page as Object, skip);
      const activeColor = historyGetTimelineSubTextColor.call(page as Object, active);
      const abnormalColor = historyGetTimelineSubTextColor.call(page as Object, abnormal);
      const normalColor = historyGetTimelineSubTextColor.call(page as Object, normal);
      const negativeIndexColor = historyGetCardBgColorByIndex.call(page as Object, -1);
      const wrappedIndexColor = historyGetCardBgColorByIndex.call(page as Object, 5);

      // Assert
      expect(skipColor).assertEqual('#C79A53');
      expect(activeColor).assertEqual('#2D7C5C');
      expect(abnormalColor).assertEqual('#B95B72');
      expect(normalColor).assertEqual('#5B6B82');
      expect(negativeIndexColor).assertEqual('#EAF2FF');
      expect(wrappedIndexColor).assertEqual('#EAF7EE');
    });

    it('normal: history_page_private_card_bg_color_should_keep_same_place_on_same_palette_slot', 0, () => {
      // Arrange
      const firstWestLake = buildHistoryItem({ id: 1, placeName: ' 西湖 ' });
      const bund = buildHistoryItem({ id: 2, placeName: '外滩' });
      const secondWestLake = buildHistoryItem({ id: 3, placeName: '西湖' });
      const page = createHistoryPageHarness({
        historyTimelineItems: [firstWestLake, bund, secondWestLake]
      });

      // Act
      const firstWestLakeColor = historyGetCardBgColor.call(page as Object, firstWestLake);
      const bundColor = historyGetCardBgColor.call(page as Object, bund);
      const secondWestLakeColor = historyGetCardBgColor.call(page as Object, secondWestLake);

      // Assert
      expect(firstWestLakeColor).assertEqual('#EAF2FF');
      expect(bundColor).assertEqual('#EAF7EE');
      expect(secondWestLakeColor).assertEqual('#EAF2FF');
    });

    it('normal: history_page_private_current_place_name_should_prefer_summary_then_selected_item', 0, () => {
      // Arrange
      const selected = buildHistoryItem({ placeName: ' 外滩 ' });
      const summaryFirstPage = createHistoryPageHarness({
        historySummary: buildHistorySummary(' 西湖 '),
        selectedHistoryTimelineItem: selected
      });
      const selectedOnlyPage = createHistoryPageHarness({
        selectedHistoryTimelineItem: selected
      });
      const emptyPage = createHistoryPageHarness({
        historySummary: buildHistorySummary('  ')
      });

      // Act
      const summaryFirst = historyGetCurrentPlaceName.call(summaryFirstPage as Object);
      const selectedOnly = historyGetCurrentPlaceName.call(selectedOnlyPage as Object);
      const emptyValue = historyGetCurrentPlaceName.call(emptyPage as Object);

      // Assert
      expect(summaryFirst).assertEqual('西湖');
      expect(selectedOnly).assertEqual('外滩');
      expect(emptyValue).assertEqual('');
    });

    it('normal: history_page_private_newer_item_and_latest_item_should_follow_display_end_start_and_fallback_rules', 0, () => {
      // Arrange
      const older = buildHistoryItem({
        id: 1,
        placeName: '西湖',
        displayTs: 100,
        actualStart: 200,
        actualEnd: 300
      });
      const newer = buildHistoryItem({
        id: 2,
        placeName: '西湖',
        displayTs: 100,
        actualStart: 200,
        actualEnd: 500
      });
      const selectedFallback = buildHistoryItem({
        id: 9,
        placeName: '灵隐寺'
      });
      const latestPage = createHistoryPageHarness({
        historySummary: buildHistorySummary('西湖'),
        historyTimelineItems: [older, newer]
      });
      const fallbackPage = createHistoryPageHarness({
        historySummary: buildHistorySummary('灵隐寺'),
        historyTimelineItems: [older, newer],
        selectedHistoryTimelineItem: selectedFallback
      });
      const emptyPage = createHistoryPageHarness();

      // Act
      const newerByActualEnd = historyIsNewerItem.call(latestPage as Object, newer, older);
      const latestItem = historyGetCurrentLatestItem.call(latestPage as Object);
      const fallbackItem = historyGetCurrentLatestItem.call(fallbackPage as Object);
      const emptyLatest = historyGetCurrentLatestItem.call(emptyPage as Object);

      // Assert
      expect(newerByActualEnd).assertTrue();
      expect((latestItem as HistoryTimelineItem).id).assertEqual(2);
      expect((fallbackItem as HistoryTimelineItem).id).assertEqual(9);
      expect(emptyLatest === null).assertTrue();
    });

    it('normal: history_page_private_address_and_status_text_should_follow_latest_item_state', 0, () => {
      // Arrange
      const skipped = buildHistoryItem({
        placeName: '西湖',
        actionType: 'SKIP',
        address: ' 杭州市西湖区龙井路 '
      });
      const active = buildHistoryItem({
        placeName: '外滩',
        actionType: 'ACTIVE'
      });
      const left = buildHistoryItem({
        placeName: '豫园',
        actionType: 'LEAVE',
        actualStart: 100,
        actualEnd: 200
      });
      const notStarted = buildHistoryItem({
        placeName: '南京路',
        actionType: 'OTHER' as HistoryTimelineItem['actionType']
      });
      const skippedPage = createHistoryPageHarness({
        historySummary: buildHistorySummary('西湖'),
        historyTimelineItems: [skipped]
      });
      const activePage = createHistoryPageHarness({
        historySummary: buildHistorySummary('外滩'),
        historyTimelineItems: [active]
      });
      const leftPage = createHistoryPageHarness({
        historySummary: buildHistorySummary('豫园'),
        historyTimelineItems: [left]
      });
      const notStartedPage = createHistoryPageHarness({
        historySummary: buildHistorySummary('南京路'),
        historyTimelineItems: [notStarted]
      });

      // Act
      const address = historyGetAddress.call(skippedPage as Object, '西湖');
      const skippedStatus = historyGetStatusText.call(skippedPage as Object);
      const activeStatus = historyGetStatusText.call(activePage as Object);
      const leftStatus = historyGetStatusText.call(leftPage as Object);
      const notStartedStatus = historyGetStatusText.call(notStartedPage as Object);

      // Assert
      expect(address).assertEqual('杭州市西湖区龙井路');
      expect(skippedStatus).assertEqual('已跳过');
      expect(activeStatus).assertEqual('进行中');
      expect(leftStatus).assertEqual('已离开');
      expect(notStartedStatus).assertEqual('未开始');
    });

    it('normal: history_page_private_time_texts_should_follow_selected_priority_latest_fallback_and_placeholder', 0, () => {
      // Arrange
      const selected = buildHistoryItem({
        placeName: '西湖',
        plannedStart: new Date('2026-04-19T08:00:00+08:00').getTime()
      });
      const latest = buildHistoryItem({
        placeName: '西湖',
        plannedStart: new Date('2026-04-19T09:00:00+08:00').getTime(),
        actualStart: new Date('2026-04-19T09:05:00+08:00').getTime(),
        actualEnd: new Date('2026-04-19T10:15:00+08:00').getTime()
      });
      const page = createHistoryPageHarness({
        historySummary: buildHistorySummary('西湖'),
        historyTimelineItems: [latest],
        selectedHistoryTimelineItem: selected
      });
      const emptyPage = createHistoryPageHarness();

      // Act
      const plannedStartText = historyGetPlannedStartText.call(page as Object);
      const actualStartText = historyGetActualStartText.call(page as Object);
      const actualEndText = historyGetActualEndText.call(page as Object);
      const emptyPlannedStartText = historyGetPlannedStartText.call(emptyPage as Object);
      const emptyActualStartText = historyGetActualStartText.call(emptyPage as Object);
      const emptyActualEndText = historyGetActualEndText.call(emptyPage as Object);

      // Assert
      expect(plannedStartText).assertEqual(DateUtil.formatDate(new Date(selected.plannedStart), 'HH:mm'));
      expect(actualStartText).assertEqual(DateUtil.formatDate(new Date(latest.actualStart), 'HH:mm'));
      expect(actualEndText).assertEqual(DateUtil.formatDate(new Date(latest.actualEnd), 'HH:mm'));
      expect(emptyPlannedStartText).assertEqual('--:--');
      expect(emptyActualStartText).assertEqual('--:--');
      expect(emptyActualEndText).assertEqual('--:--');
    });

    it('normal: history_page_private_stay_deviation_and_note_text_should_cover_computed_and_placeholder_values', 0, () => {
      // Arrange
      const latest = buildHistoryItem({
        placeName: '西湖',
        actualStart: new Date('2026-04-19T09:00:00+08:00').getTime(),
        actualEnd: new Date('2026-04-19T09:35:00+08:00').getTime(),
        deviationMinutes: -6,
        note: '  记得带伞  '
      });
      const page = createHistoryPageHarness({
        historySummary: buildHistorySummary('西湖'),
        historyTimelineItems: [latest]
      });
      const emptyPage = createHistoryPageHarness();

      // Act
      const stayText = historyGetStayText.call(page as Object);
      const deviationText = historyGetDeviationText.call(page as Object);
      const noteText = historyGetNoteText.call(page as Object);
      const emptyStayText = historyGetStayText.call(emptyPage as Object);
      const emptyDeviationText = historyGetDeviationText.call(emptyPage as Object);
      const emptyNoteText = historyGetNoteText.call(emptyPage as Object);

      // Assert
      expect(stayText).assertEqual('35 分钟');
      expect(deviationText).assertEqual('早到 6 分钟');
      expect(noteText).assertEqual('记得带伞');
      expect(emptyStayText).assertEqual('0 分钟');
      expect(emptyDeviationText).assertEqual('--');
      expect(emptyNoteText).assertEqual('--');
    });
  });
}
