import { describe, it, expect } from '@ohos/hypium';
import {
  CompanionOverlayPages,
  shouldShowCompanionFilterOverlay,
  shouldShowCompanionHistoryOverlay,
  shouldShowCompanionSearchOverlay
} from '../main/ets/pages/components/views/companion/CompanionOverlayPages';
import { EventEntity } from '../main/ets/model/entity/EventEntity';

interface CompanionOverlayPagesParamsTest {
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

interface CompanionOverlayPagesPrivateTest {
  showHistoryPage: boolean;
  historyTimelineItems: Object[];
  historyTimelineFilter: string;
  historyViewMode: string;
  vm: Object | null;
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
  setInitiallyProvidedValue(params: CompanionOverlayPagesParamsTest): void;
  updateStateVars(params: CompanionOverlayPagesParamsTest): void;
  initialRender(): void;
}

function createOverlayEvent(id: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `event_${id}`;
  return event;
}

class OverlayPlaceholderTest {}

export default function companionOverlayPagesHelperTest() {
  describe('unit_test_case_generator_autofill_CompanionOverlayPagesHelper', () => {
    it('normal: history_overlay_should_follow_history_flag', 0, () => {
      // Arrange
      const show = true;

      // Act
      const visible = shouldShowCompanionHistoryOverlay(show);

      // Assert
      expect(visible).assertTrue();
    });

    it('boundary: search_overlay_should_support_false_flag', 0, () => {
      // Arrange
      const show = false;

      // Act
      const visible = shouldShowCompanionSearchOverlay(show);

      // Assert
      expect(visible).assertFalse();
    });

    it('invalid: filter_overlay_should_still_return_boolean_for_direct_input', 0, () => {
      // Arrange
      const show = true;

      // Act
      const visible = shouldShowCompanionFilterOverlay(show);

      // Assert
      expect(typeof visible === 'boolean').assertTrue();
    });

    it('conflict: overlay_flags_should_be_independent_across_panels', 0, () => {
      // Arrange
      const history = shouldShowCompanionHistoryOverlay(false);
      const search = shouldShowCompanionSearchOverlay(true);
      const filter = shouldShowCompanionFilterOverlay(false);

      // Act
      const matrix = !history && search && !filter;

      // Assert
      expect(matrix).assertTrue();
    });

    it('regression: overlay_helpers_should_preserve_identity_for_true_false', 0, () => {
      // Arrange
      const values: boolean[] = [true, false];

      // Act
      const mapped = values.map((v) => [
        shouldShowCompanionHistoryOverlay(v),
        shouldShowCompanionSearchOverlay(v),
        shouldShowCompanionFilterOverlay(v)
      ]);

      // Assert
      expect(mapped[0][0]).assertTrue();
      expect(mapped[1][2]).assertFalse();
    });

    it('combined: overlay_visibility_matrix_should_support_mixed_panel_states', 0, () => {
      // Arrange
      const history = shouldShowCompanionHistoryOverlay(true);
      const search = shouldShowCompanionSearchOverlay(false);
      const filter = shouldShowCompanionFilterOverlay(true);

      // Act
      const result = history && !search && filter;

      // Assert
      expect(result).assertTrue();
    });

    it('combined: overlay_instance_should_sync_props_and_keep_default_callbacks_stable', 0, () => {
      // Arrange
      const page = new CompanionOverlayPages(undefined, {} as LocalStorage) as Object as CompanionOverlayPagesPrivateTest;
      const initParams: CompanionOverlayPagesParamsTest = {
        showHistoryPage: true,
        historyTimelineItems: [new OverlayPlaceholderTest() as Object],
        historyTimelineFilter: 'all',
        historyViewMode: 'timeline',
        vm: null,
        showSearchPage: true,
        searchKeyword: 'museum',
        searchResults: [createOverlayEvent(1)],
        showFilterPage: true,
        companionFilterState: 'ACTIVE',
        safeTopInset: 4,
        safeBottomInset: 6
      };
      const nextParams: CompanionOverlayPagesParamsTest = {
        showHistoryPage: false,
        historyTimelineItems: [new OverlayPlaceholderTest() as Object, new OverlayPlaceholderTest() as Object],
        historyTimelineFilter: 'completed',
        historyViewMode: 'summary',
        selectedHistoryTimelineItem: new OverlayPlaceholderTest() as Object,
        showSearchPage: false,
        searchKeyword: 'station',
        searchResults: [createOverlayEvent(2), createOverlayEvent(3)],
        showFilterPage: false,
        companionFilterState: 'SKIPPED',
        safeTopInset: 14,
        safeBottomInset: 16
      };

      // Act
      page.onHistoryClose();
      page.onHistoryBack();
      page.onHistoryFilterChange('all');
      page.onHistoryItemClick(new OverlayPlaceholderTest() as Object);
      page.onSearchClose();
      page.onSearch('keyword');
      page.onSearchResultClick(createOverlayEvent(9));
      page.onFilterClose();
      page.onFilterSelect('ALL');
      page.setInitiallyProvidedValue(initParams);
      page.updateStateVars(nextParams);

      // Assert
      expect(page.showHistoryPage).assertFalse();
      expect(page.historyTimelineItems.length).assertEqual(2);
      expect(page.historyTimelineFilter).assertEqual('completed');
      expect(page.historyViewMode).assertEqual('summary');
      expect(page.showSearchPage).assertFalse();
      expect(page.searchKeyword).assertEqual('station');
      expect(page.searchResults.length).assertEqual(2);
      expect(page.showFilterPage).assertFalse();
      expect(page.companionFilterState).assertEqual('SKIPPED');
      expect(page.safeTopInset).assertEqual(14);
      expect(page.safeBottomInset).assertEqual(16);
    });

    it('normal: overlay_pages_initial_render_should_support_all_overlay_branches', 0, () => {
      // Arrange
      const page = new CompanionOverlayPages(undefined, {} as LocalStorage) as Object as CompanionOverlayPagesPrivateTest;
      page.setInitiallyProvidedValue({
        showHistoryPage: true,
        historyTimelineItems: [new OverlayPlaceholderTest() as Object],
        historyTimelineFilter: 'all',
        historyViewMode: 'timeline',
        historySummary: new OverlayPlaceholderTest() as Object,
        vm: null,
        selectedHistoryTimelineItem: new OverlayPlaceholderTest() as Object,
        showSearchPage: true,
        searchKeyword: 'museum',
        searchResults: [createOverlayEvent(1)],
        showFilterPage: true,
        companionFilterState: 'ACTIVE',
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

    it('boundary: overlay_pages_initial_render_should_support_hidden_overlay_branch', 0, () => {
      // Arrange
      const page = new CompanionOverlayPages(undefined, {} as LocalStorage) as Object as CompanionOverlayPagesPrivateTest;
      page.setInitiallyProvidedValue({
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
        showFilterPage: false,
        companionFilterState: 'ALL',
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

    it('combined: overlay_pages_initial_render_should_support_search_only_branch', 0, () => {
      // Arrange
      const page = new CompanionOverlayPages(undefined, {} as LocalStorage) as Object as CompanionOverlayPagesPrivateTest;
      const params: CompanionOverlayPagesParamsTest = {
        showHistoryPage: false,
        historyTimelineItems: [],
        historyTimelineFilter: 'all',
        historyViewMode: 'timeline',
        historySummary: null,
        vm: null,
        selectedHistoryTimelineItem: null,
        showSearchPage: true,
        searchKeyword: 'station',
        searchResults: [createOverlayEvent(7), createOverlayEvent(8)],
        showFilterPage: false,
        companionFilterState: 'ALL',
        safeTopInset: 6,
        safeBottomInset: 8
      };
      page.setInitiallyProvidedValue(params);
      page.updateStateVars(params);

      // Act
      let threw = false;
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(page.showSearchPage).assertTrue();
      expect(page.searchResults.length).assertEqual(2);
    });

    it('normal: overlay_pages_should_execute_overridden_callbacks_without_mutating_flags', 0, () => {
      // Arrange
      const page = new CompanionOverlayPages(undefined, {} as LocalStorage) as Object as CompanionOverlayPagesPrivateTest;
      let historyCloseCount = 0;
      let searchCount = 0;
      let filterCount = 0;
      const params: CompanionOverlayPagesParamsTest = {
        showHistoryPage: true,
        historyTimelineItems: [new OverlayPlaceholderTest() as Object],
        historyTimelineFilter: 'pending',
        historyViewMode: 'timeline',
        historySummary: null,
        vm: null,
        selectedHistoryTimelineItem: null,
        showSearchPage: false,
        searchKeyword: '',
        searchResults: [],
        showFilterPage: true,
        companionFilterState: 'PENDING',
        safeTopInset: 2,
        safeBottomInset: 4
      };
      page.setInitiallyProvidedValue(params);
      page.updateStateVars(params);
      page.onHistoryClose = (): void => {
        historyCloseCount += 1;
      };
      page.onSearch = (_keyword: string): void => {
        searchCount += 1;
      };
      page.onFilterSelect = (_state: string): void => {
        filterCount += 1;
      };

      // Act
      page.onHistoryClose();
      page.onSearch('museum');
      page.onFilterSelect('ACTIVE');

      // Assert
      expect(historyCloseCount).assertEqual(1);
      expect(searchCount).assertEqual(1);
      expect(filterCount).assertEqual(1);
      expect(page.showHistoryPage).assertTrue();
      expect(page.showFilterPage).assertTrue();
    });
  });
}
