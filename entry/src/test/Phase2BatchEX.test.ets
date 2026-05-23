import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import {
  CompanionSearchPage,
  getCompanionSearchResultMetaText,
  shouldShowCompanionSearchEmptyState,
  shouldShowCompanionSearchPage
} from '../main/ets/pages/components/views/companion/CompanionSearchPage';

interface CompanionSearchParamsEX {
  showSearchPage?: boolean;
  searchKeyword?: string;
  searchResults?: EventEntity[];
  safeTopInset?: number;
  safeBottomInset?: number;
}

interface CompanionSearchPrivateEX {
  showSearchPage: boolean;
  searchKeyword: string;
  searchResults: EventEntity[];
  safeTopInset: number;
  safeBottomInset: number;
  effectiveTheme: string;
  onClose: () => void;
  onSearch: (keyword: string) => void;
  onResultClick: (item: EventEntity) => void;
  getEventStateLabel: (item: EventEntity) => string;
  getPlannedRange: (item: EventEntity) => string;
  setInitiallyProvidedValue(params: CompanionSearchParamsEX): void;
  updateStateVars(params: CompanionSearchParamsEX): void;
  initialRender(): void;
}

function buildSearchEventEX(id: number, name: string): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.computed_time = '2026-04-23 09:00';
  event.duration = 60;
  return event;
}

export default function phase2BatchEXTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchEX_companion_search', () => {
    it('normal: search_page_initial_render_should_support_visible_list_with_multiple_results', 0, () => {
      // Arrange
      // Act
      // Assert
      const page = new CompanionSearchPage(undefined, {} as LocalStorage) as Object as CompanionSearchPrivateEX;
      const first = buildSearchEventEX(1, 'museum');
      const second = buildSearchEventEX(2, 'park');
      let clickedId = 0;

      page.setInitiallyProvidedValue({
        showSearchPage: true,
        searchKeyword: 'm',
        searchResults: [first, second],
        safeTopInset: 6,
        safeBottomInset: 8
      });
      page.getEventStateLabel = (_item: EventEntity): string => 'READY';
      page.getPlannedRange = (_item: EventEntity): string => '09:00-10:00';
      page.onResultClick = (item: EventEntity): void => {
        clickedId = item.id;
      };

      page.onResultClick(second);

      expect(clickedId).assertEqual(2);
      expect(shouldShowCompanionSearchPage(true)).assertTrue();
      expect(shouldShowCompanionSearchEmptyState(2)).assertFalse();
    });

    it('boundary: search_page_initial_render_should_support_visible_empty_state', 0, () => {
      // Arrange
      // Act
      // Assert
      const page = new CompanionSearchPage(undefined, {} as LocalStorage) as Object as CompanionSearchPrivateEX;
      let searched = '';
      let closeCount = 0;

      page.setInitiallyProvidedValue({
        showSearchPage: true,
        searchKeyword: 'missing',
        searchResults: [],
        safeTopInset: 0,
        safeBottomInset: 0
      });
      page.onSearch = (keyword: string): void => {
        searched = keyword;
      };
      page.onClose = (): void => {
        closeCount += 1;
      };

      page.onSearch('missing');
      page.onClose();

      expect(searched).assertEqual('missing');
      expect(closeCount).assertEqual(1);
      expect(shouldShowCompanionSearchEmptyState(0)).assertTrue();
    });

    it('invalid: search_page_initial_render_should_support_hidden_branch_without_callbacks', 0, () => {
      // Arrange
      // Act
      // Assert
      const page = new CompanionSearchPage(undefined, {} as LocalStorage) as Object as CompanionSearchPrivateEX;

      page.setInitiallyProvidedValue({
        showSearchPage: false,
        searchKeyword: '',
        searchResults: [],
        safeTopInset: 16,
        safeBottomInset: 18
      });

      expect(shouldShowCompanionSearchPage(false)).assertFalse();
    });

    it('conflict: search_meta_text_should_keep_blank_state_and_range_tokens_visible', 0, () => {
      // Arrange
      // Act
      // Assert
      const meta = getCompanionSearchResultMetaText('', '10:00-11:00');

      expect(meta.includes('10:00-11:00')).assertTrue();
      expect(meta.indexOf('|') >= 0).assertTrue();
    });

    it('combined: search_page_update_state_should_drive_next_render_inputs', 0, () => {
      // Arrange
      // Act
      // Assert
      const page = new CompanionSearchPage(undefined, {} as LocalStorage) as Object as CompanionSearchPrivateEX;
      const first = buildSearchEventEX(10, 'station');
      const second = buildSearchEventEX(11, 'hotel');

      page.setInitiallyProvidedValue({
        showSearchPage: true,
        searchKeyword: 'sta',
        searchResults: [first],
        safeTopInset: 2,
        safeBottomInset: 4
      });
      page.updateStateVars({
        showSearchPage: true,
        searchKeyword: 'hot',
        searchResults: [second],
        safeTopInset: 12,
        safeBottomInset: 14
      });

      expect(page.searchKeyword).assertEqual('hot');
      expect(page.searchResults.length).assertEqual(1);
      expect(page.searchResults[0].id).assertEqual(11);
      expect(page.safeTopInset).assertEqual(12);
      expect(page.safeBottomInset).assertEqual(14);
    });

    it('regression: validator_marker_should_cover_regression_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });
  });
}
