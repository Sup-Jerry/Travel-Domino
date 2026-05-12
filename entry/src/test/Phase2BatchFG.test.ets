import { describe, expect, it } from '@ohos/hypium';
import {
  CompanionOverlayPages,
  shouldShowCompanionFilterOverlay,
  shouldShowCompanionHistoryOverlay,
  shouldShowCompanionSearchOverlay
} from '../main/ets/pages/components/views/companion/CompanionOverlayPages';
import {
  CompanionControlTopBar,
  getCompanionControlTopBarPaddingTop
} from '../main/ets/pages/components/views/companion/CompanionControlTopBar';
import { EventEntity } from '../main/ets/model/entity/EventEntity';

interface Phase2OverlayParamsFG {
  showHistoryPage?: boolean;
  historyTimelineSummary?: Object | null;
  historyTimelineItems?: Object[];
  historyTimelineFilter?: string;
  historyViewMode?: string;
  historySummary?: Object | null;
  vm?: Object | null;
  selectedHistoryTimelineItem?: Object | null;
  showSearchPage?: boolean;
  searchKeyword?: string;
  searchResults?: EventEntity[];
  showFilterPage?: boolean;
  companionFilterState?: string;
  safeTopInset?: number;
  safeBottomInset?: number;
}

interface Phase2OverlayPrivateFG {
  showHistoryPage: boolean;
  historyTimelineItems: Object[];
  historyTimelineFilter: string;
  historyViewMode: string;
  selectedHistoryTimelineItem: Object | null;
  showSearchPage: boolean;
  searchKeyword: string;
  searchResults: EventEntity[];
  showFilterPage: boolean;
  companionFilterState: string;
  safeTopInset: number;
  safeBottomInset: number;
  onHistoryClose: () => void;
  onHistoryBack: () => void;
  onHistoryFilterChange: (filter: string) => void;
  onHistoryItemClick: (item: Object) => void;
  onSearchClose: () => void;
  onSearch: (keyword: string) => void;
  onSearchResultClick: (item: EventEntity) => void;
  onFilterClose: () => void;
  onFilterSelect: (state: string) => void;
  setInitiallyProvidedValue(params: Phase2OverlayParamsFG): void;
  updateStateVars(params: Phase2OverlayParamsFG): void;
  initialRender(): void;
}

interface Phase2TopBarParamsFG {
  safeTopInset?: number;
  runtimeDescription?: string;
}

interface Phase2TopBarPrivateFG {
  safeTopInset: number;
  runtimeDescription: string;
  onExit: () => void;
  setInitiallyProvidedValue(params: Phase2TopBarParamsFG): void;
  updateStateVars(params: Phase2TopBarParamsFG): void;
  initialRender(): void;
}

class Phase2OverlayPlaceholderFG {}

function buildOverlayEventFG(id: number, name: string): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  return event;
}

export default function phase2BatchFGTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchFG_overlay_topbar_lines', () => {
    it('combined: overlay_visibility_helpers_should_cover_true_false_matrix', 0, () => {
      expect(shouldShowCompanionHistoryOverlay(true)).assertTrue();
      expect(shouldShowCompanionHistoryOverlay(false)).assertFalse();
      expect(shouldShowCompanionSearchOverlay(true)).assertTrue();
      expect(shouldShowCompanionSearchOverlay(false)).assertFalse();
      expect(shouldShowCompanionFilterOverlay(true)).assertTrue();
      expect(shouldShowCompanionFilterOverlay(false)).assertFalse();
    });

    it('normal: overlay_page_should_sync_callbacks_and_state_for_mixed_panels', 0, () => {
      const page = new CompanionOverlayPages(undefined, {} as LocalStorage) as Object as Phase2OverlayPrivateFG;
      const historyItem = new Phase2OverlayPlaceholderFG() as Object;
      const result = buildOverlayEventFG(1, 'museum');
      let historyClosed = 0;
      let searchClosed = 0;
      let filterClosed = 0;
      let selectedFilter = '';
      let historyFilter = '';
      let searchKeyword = '';
      let clickedId = -1;

      page.onHistoryClose = (): void => { historyClosed += 1; };
      page.onSearchClose = (): void => { searchClosed += 1; };
      page.onFilterClose = (): void => { filterClosed += 1; };
      page.onHistoryFilterChange = (filter: string): void => { historyFilter = filter; };
      page.onFilterSelect = (state: string): void => { selectedFilter = state; };
      page.onSearch = (keyword: string): void => { searchKeyword = keyword; };
      page.onSearchResultClick = (item: EventEntity): void => { clickedId = item.id; };
      page.setInitiallyProvidedValue({
        showHistoryPage: true,
        historyTimelineItems: [historyItem],
        historyTimelineFilter: 'all',
        historyViewMode: 'timeline',
        selectedHistoryTimelineItem: historyItem,
        showSearchPage: true,
        searchKeyword: 'mu',
        searchResults: [result],
        showFilterPage: false,
        companionFilterState: 'ACTIVE',
        safeTopInset: 4,
        safeBottomInset: 6
      });
      page.updateStateVars({
        showHistoryPage: false,
        historyTimelineItems: [historyItem, historyItem],
        historyTimelineFilter: 'completed',
        historyViewMode: 'detail',
        selectedHistoryTimelineItem: historyItem,
        showSearchPage: true,
        searchKeyword: 'park',
        searchResults: [result],
        showFilterPage: true,
        companionFilterState: 'SKIPPED',
        safeTopInset: 14,
        safeBottomInset: 16
      });
      page.onHistoryClose();
      page.onSearchClose();
      page.onFilterClose();
      page.onHistoryFilterChange(page.historyTimelineFilter);
      page.onFilterSelect(page.companionFilterState);
      page.onSearch(page.searchKeyword);
      page.onSearchResultClick(page.searchResults[0]);

      expect(page.showHistoryPage).assertFalse();
      expect(page.historyTimelineItems.length).assertEqual(2);
      expect(page.historyTimelineFilter).assertEqual('completed');
      expect(page.historyViewMode).assertEqual('detail');
      expect(page.showSearchPage).assertTrue();
      expect(page.searchKeyword).assertEqual('park');
      expect(page.showFilterPage).assertTrue();
      expect(page.companionFilterState).assertEqual('SKIPPED');
      expect(page.safeTopInset).assertEqual(14);
      expect(page.safeBottomInset).assertEqual(16);
      expect(historyClosed).assertEqual(1);
      expect(searchClosed).assertEqual(1);
      expect(filterClosed).assertEqual(1);
      expect(historyFilter).assertEqual('completed');
      expect(selectedFilter).assertEqual('SKIPPED');
      expect(searchKeyword).assertEqual('park');
      expect(clickedId).assertEqual(1);
    });

    it('combined: overlay_initial_render_should_cover_single_panel_combinations', 0, () => {
      const historyOnly = new CompanionOverlayPages(undefined, {} as LocalStorage) as Object as Phase2OverlayPrivateFG;
      const searchOnly = new CompanionOverlayPages(undefined, {} as LocalStorage) as Object as Phase2OverlayPrivateFG;
      const filterOnly = new CompanionOverlayPages(undefined, {} as LocalStorage) as Object as Phase2OverlayPrivateFG;
      const placeholder = new Phase2OverlayPlaceholderFG() as Object;
      const result = buildOverlayEventFG(2, 'station');
      let historyThrew = false;
      let searchThrew = false;
      let filterThrew = false;

      historyOnly.setInitiallyProvidedValue({
        showHistoryPage: true,
        historyTimelineSummary: placeholder,
        historyTimelineItems: [placeholder],
        historyTimelineFilter: 'skipped',
        historyViewMode: 'timeline',
        historySummary: placeholder,
        vm: null,
        selectedHistoryTimelineItem: placeholder,
        showSearchPage: false,
        searchKeyword: '',
        searchResults: [],
        showFilterPage: false,
        companionFilterState: 'ALL',
        safeTopInset: 8,
        safeBottomInset: 10
      });
      searchOnly.setInitiallyProvidedValue({
        showHistoryPage: false,
        historyTimelineItems: [],
        historyTimelineFilter: 'all',
        historyViewMode: 'timeline',
        historySummary: null,
        vm: null,
        selectedHistoryTimelineItem: null,
        showSearchPage: true,
        searchKeyword: 'st',
        searchResults: [result],
        showFilterPage: false,
        companionFilterState: 'ALL',
        safeTopInset: 2,
        safeBottomInset: 4
      });
      filterOnly.setInitiallyProvidedValue({
        showHistoryPage: false,
        historyTimelineItems: [],
        historyTimelineFilter: 'all',
        historyViewMode: 'timeline',
        historySummary: null,
        vm: null,
        selectedHistoryTimelineItem: null,
        showSearchPage: false,
        searchKeyword: '',
        searchResults: [],
        showFilterPage: true,
        companionFilterState: 'ACTIVE',
        safeTopInset: 0,
        safeBottomInset: 0
      });

      try {
        historyOnly.initialRender();
      } catch (_error) {
        historyThrew = true;
      }
      try {
        searchOnly.initialRender();
      } catch (_error) {
        searchThrew = true;
      }
      try {
        filterOnly.initialRender();
      } catch (_error) {
        filterThrew = true;
      }

      expect(historyThrew).assertFalse();
      expect(searchThrew).assertFalse();
      expect(filterThrew).assertFalse();
    });

    it('boundary: topbar_should_update_padding_and_exit_callback_after_state_change', 0, () => {
      const topBar = new CompanionControlTopBar(undefined, {} as LocalStorage) as Object as Phase2TopBarPrivateFG;
      let exitCount = 0;

      topBar.setInitiallyProvidedValue({
        safeTopInset: -2,
        runtimeDescription: ''
      });
      topBar.onExit = (): void => { exitCount += 1; };
      topBar.updateStateVars({
        safeTopInset: 22,
        runtimeDescription: '准备中'
      });
      topBar.onExit();

      expect(getCompanionControlTopBarPaddingTop(-2)).assertEqual(8);
      expect(getCompanionControlTopBarPaddingTop(22)).assertEqual(32);
      expect(topBar.safeTopInset).assertEqual(22);
      expect(topBar.runtimeDescription).assertEqual('准备中');
      expect(exitCount).assertEqual(1);
    });

    it('normal: topbar_initial_render_should_support_blank_and_long_runtime_descriptions', 0, () => {
      const blankTopBar = new CompanionControlTopBar(undefined, {} as LocalStorage) as Object as Phase2TopBarPrivateFG;
      const longTopBar = new CompanionControlTopBar(undefined, {} as LocalStorage) as Object as Phase2TopBarPrivateFG;
      let blankThrew = false;
      let longThrew = false;

      blankTopBar.setInitiallyProvidedValue({
        safeTopInset: 0,
        runtimeDescription: ''
      });
      longTopBar.setInitiallyProvidedValue({
        safeTopInset: 12,
        runtimeDescription: '当前已切换到伴游控制模式，正在等待下一次用户动作与路线推进'
      });

      try {
        blankTopBar.initialRender();
      } catch (_error) {
        blankThrew = true;
      }
      try {
        longTopBar.initialRender();
      } catch (_error) {
        longThrew = true;
      }

      expect(blankThrew).assertFalse();
      expect(longThrew).assertFalse();
    });
  });
}
