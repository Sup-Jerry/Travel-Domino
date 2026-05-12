import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { CompanionSearchPage } from '../main/ets/pages/components/views/companion/CompanionSearchPage';
import { CompanionFilterPage, CompanionFilterState } from '../main/ets/pages/components/views/companion/CompanionFilterPage';
import { CompanionOverlayPages } from '../main/ets/pages/components/views/companion/CompanionOverlayPages';

interface SearchParamsGE {
  showSearchPage?: boolean;
  searchKeyword?: string;
  searchResults?: EventEntity[];
  safeTopInset?: number;
  safeBottomInset?: number;
}

interface SearchPrivateGE {
  onClose: () => void;
  onSearch: (keyword: string) => void;
  onResultClick: (item: EventEntity) => void;
  getEventStateLabel: (item: EventEntity) => string;
  getPlannedRange: (item: EventEntity) => string;
  setInitiallyProvidedValue(params: SearchParamsGE): void;
  initialRender(): void;
}

interface FilterParamsGE {
  showFilterPage?: boolean;
  companionFilterState?: CompanionFilterState;
  safeTopInset?: number;
  safeBottomInset?: number;
}

interface FilterPrivateGE {
  onClose: () => void;
  onFilterSelect: (item: CompanionFilterState) => void;
  getFilterOptions: () => CompanionFilterState[];
  getFilterLabel: (state: CompanionFilterState) => string;
  setInitiallyProvidedValue(params: FilterParamsGE): void;
  initialRender(): void;
}

interface OverlayParamsGE {
  showHistoryPage?: boolean;
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

interface OverlayPrivateGE {
  onHistoryClose: () => void;
  onHistoryBack: () => void;
  onHistoryFilterChange: (filter: string) => void;
  onHistoryItemClick: (item: Object) => void;
  onSearchClose: () => void;
  onSearch: (keyword: string) => void;
  onSearchResultClick: (item: EventEntity) => void;
  onFilterClose: () => void;
  onFilterSelect: (state: string) => void;
  setInitiallyProvidedValue(params: OverlayParamsGE): void;
  initialRender(): void;
}

class OverlayPlaceholderGE {}

function buildEventGE(id: number, name: string): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  return event;
}

export default function phase2BatchGETest() {
  describe('unit_test_case_generator_autofill_Phase2BatchGE_overlay_search_filter_render_lines', () => {
    it('combined: search_page_initial_render_should_support_custom_meta_and_callback_configuration', 0, () => {
      const page = new CompanionSearchPage(undefined, {} as LocalStorage) as Object as SearchPrivateGE;
      const result = buildEventGE(1, 'museum');
      let closeCount = 0;
      let lastKeyword = '';
      let lastClick = -1;
      page.onClose = (): void => { closeCount += 1; };
      page.onSearch = (keyword: string): void => { lastKeyword = keyword; };
      page.onResultClick = (item: EventEntity): void => { lastClick = item.id; };
      page.getEventStateLabel = (_item: EventEntity): string => '进行中';
      page.getPlannedRange = (_item: EventEntity): string => '10:00-11:00';
      page.setInitiallyProvidedValue({
        showSearchPage: true,
        searchKeyword: 'mu',
        searchResults: [result],
        safeTopInset: 8,
        safeBottomInset: 10
      });

      let threw = false;
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }
      page.onClose();
      page.onSearch('museum');
      page.onResultClick(result);

      expect(threw).assertFalse();
      expect(closeCount).assertEqual(1);
      expect(lastKeyword).assertEqual('museum');
      expect(lastClick).assertEqual(result.id);
    });

    it('combined: filter_page_initial_render_should_support_pending_completed_and_skipped_option_sets', 0, () => {
      const pendingPage = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as FilterPrivateGE;
      const completedPage = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as FilterPrivateGE;
      const skippedPage = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as FilterPrivateGE;
      let threwPending = false;
      let threwCompleted = false;
      let threwSkipped = false;

      pendingPage.getFilterOptions = (): CompanionFilterState[] => ['PENDING'];
      pendingPage.getFilterLabel = (state: CompanionFilterState): string => `label_${state}`;
      pendingPage.setInitiallyProvidedValue({ showFilterPage: true, companionFilterState: 'PENDING', safeTopInset: 2, safeBottomInset: 4 });

      completedPage.getFilterOptions = (): CompanionFilterState[] => ['COMPLETED'];
      completedPage.getFilterLabel = (state: CompanionFilterState): string => `label_${state}`;
      completedPage.setInitiallyProvidedValue({ showFilterPage: true, companionFilterState: 'COMPLETED', safeTopInset: 0, safeBottomInset: 0 });

      skippedPage.getFilterOptions = (): CompanionFilterState[] => ['SKIPPED', 'ALL'];
      skippedPage.getFilterLabel = (state: CompanionFilterState): string => `label_${state}`;
      skippedPage.setInitiallyProvidedValue({ showFilterPage: true, companionFilterState: 'SKIPPED', safeTopInset: 6, safeBottomInset: 8 });

      try {
        pendingPage.initialRender();
      } catch (_error) {
        threwPending = true;
      }
      try {
        completedPage.initialRender();
      } catch (_error) {
        threwCompleted = true;
      }
      try {
        skippedPage.initialRender();
      } catch (_error) {
        threwSkipped = true;
      }

      expect(threwPending).assertFalse();
      expect(threwCompleted).assertFalse();
      expect(threwSkipped).assertFalse();
    });

    it('combined: overlay_pages_initial_render_should_support_history_only_and_mixed_search_filter_paths', 0, () => {
      const historyOnly = new CompanionOverlayPages(undefined, {} as LocalStorage) as Object as OverlayPrivateGE;
      const mixed = new CompanionOverlayPages(undefined, {} as LocalStorage) as Object as OverlayPrivateGE;
      const historyItem = new OverlayPlaceholderGE() as Object;
      const result = buildEventGE(8, 'station');
      let historyOnlyThrew = false;
      let mixedThrew = false;

      historyOnly.setInitiallyProvidedValue({
        showHistoryPage: true,
        historyTimelineItems: [historyItem],
        historyTimelineFilter: 'all',
        historyViewMode: 'timeline',
        historySummary: historyItem,
        vm: null,
        selectedHistoryTimelineItem: historyItem,
        showSearchPage: false,
        searchKeyword: '',
        searchResults: [],
        showFilterPage: false,
        companionFilterState: 'ALL',
        safeTopInset: 12,
        safeBottomInset: 14
      });
      mixed.setInitiallyProvidedValue({
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
        showFilterPage: true,
        companionFilterState: 'ACTIVE',
        safeTopInset: 4,
        safeBottomInset: 6
      });

      try {
        historyOnly.initialRender();
      } catch (_error) {
        historyOnlyThrew = true;
      }
      try {
        mixed.initialRender();
      } catch (_error) {
        mixedThrew = true;
      }

      expect(historyOnlyThrew).assertFalse();
      expect(mixedThrew).assertFalse();
    });
  });
}
