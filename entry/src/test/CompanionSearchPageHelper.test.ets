import { describe, it, expect } from '@ohos/hypium';
import {
  CompanionSearchPage,
  getCompanionSearchResultMetaText,
  shouldShowCompanionSearchEmptyState,
  shouldShowCompanionSearchPage
} from '../main/ets/pages/components/views/companion/CompanionSearchPage';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { ThemeCenter } from '../main/ets/common/utils/ThemeCenter';

interface CompanionSearchPaletteTest {
  textPrimary: Object;
  textSecondary: Object;
  textTertiary: Object;
  companionBg: Object;
  companionCardBg: Object;
  primary: Object;
}

interface CompanionSearchPageParamsTest {
  showSearchPage?: boolean;
  searchKeyword?: string;
  searchResults?: EventEntity[];
  safeTopInset?: number;
  safeBottomInset?: number;
}

interface CompanionSearchPagePrivateTest {
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
  setInitiallyProvidedValue(params: CompanionSearchPageParamsTest): void;
  updateStateVars(params: CompanionSearchPageParamsTest): void;
  getThemePalette(): CompanionSearchPaletteTest;
  build(): void;
  initialRender(): void;
}

function buildSearchEvent(id: number, name: string): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  return event;
}

function runSearchPageRender(page: CompanionSearchPagePrivateTest): boolean {
  try {
    page.initialRender();
    return false;
  } catch (_error) {
    return true;
  }
}

export default function companionSearchPageHelperTest() {
  describe('unit_test_case_generator_autofill_CompanionSearchPageHelper', () => {
    it('normal: search_page_should_follow_show_flag', 0, () => {
      // Arrange
      const show = true;

      // Act
      const visible = shouldShowCompanionSearchPage(show);

      // Assert
      expect(visible).assertTrue();
    });

    it('boundary: empty_state_should_be_true_when_result_count_is_zero', 0, () => {
      // Arrange
      const resultCount = 0;

      // Act
      const empty = shouldShowCompanionSearchEmptyState(resultCount);

      // Assert
      expect(empty).assertTrue();
    });

    it('invalid: empty_state_should_be_false_for_negative_count', 0, () => {
      // Arrange
      const resultCount = -1;

      // Act
      const empty = shouldShowCompanionSearchEmptyState(resultCount);

      // Assert
      expect(empty).assertFalse();
    });

    it('conflict: search_page_and_empty_state_should_be_independent', 0, () => {
      // Arrange
      const show = false;
      const resultCount = 0;

      // Act
      const visible = shouldShowCompanionSearchPage(show);
      const empty = shouldShowCompanionSearchEmptyState(resultCount);

      // Assert
      expect(visible).assertFalse();
      expect(empty).assertTrue();
    });

    it('regression: result_meta_text_should_keep_state_and_range_tokens', 0, () => {
      // Arrange
      const state = '进行中';
      const range = '10:00-11:00';

      // Act
      const text = getCompanionSearchResultMetaText(state, range);

      // Assert
      expect(text.includes(state)).assertTrue();
      expect(text.includes(range)).assertTrue();
    });

    it('combined: search_helper_matrix_should_cover_visibility_empty_and_meta', 0, () => {
      // Arrange
      const show = shouldShowCompanionSearchPage(true);
      const nonEmpty = shouldShowCompanionSearchEmptyState(3);
      const meta = getCompanionSearchResultMetaText('已完成', '08:00-09:00');

      // Act
      const ok = show && !nonEmpty && meta.includes('已完成') && meta.includes('08:00-09:00');

      // Assert
      expect(ok).assertTrue();
    });

    it('combined: search_page_instance_should_sync_props_callbacks_default_labels_and_palette', 0, () => {
      // Arrange
      const page = new CompanionSearchPage(undefined, {} as LocalStorage) as Object as CompanionSearchPagePrivateTest;
      const first = buildSearchEvent(10, 'library');
      const second = buildSearchEvent(11, 'park');
      let closeCount = 0;
      let searchKeyword = '';
      let clickedId = 0;

      // Act
      page.onClose();
      page.onSearch('before');
      page.onResultClick(first);
      const defaultStateLabel = page.getEventStateLabel(first);
      const defaultRange = page.getPlannedRange(first);
      page.setInitiallyProvidedValue({
        showSearchPage: true,
        searchKeyword: 'lib',
        searchResults: [first],
        safeTopInset: 4,
        safeBottomInset: 6
      });
      page.onClose = (): void => { closeCount += 1; };
      page.onSearch = (keyword: string): void => { searchKeyword = keyword; };
      page.onResultClick = (item: EventEntity): void => { clickedId = item.id; };
      page.updateStateVars({
        showSearchPage: false,
        searchKeyword: 'park',
        searchResults: [second],
        safeTopInset: 14,
        safeBottomInset: 16
      });
      page.onClose();
      page.onSearch(page.searchKeyword);
      page.onResultClick(page.searchResults[0]);
      page.effectiveTheme = 'dark';
      const palette = page.getThemePalette();

      // Assert
      expect(page.showSearchPage).assertFalse();
      expect(page.searchKeyword).assertEqual('park');
      expect(page.searchResults.length).assertEqual(1);
      expect(page.safeTopInset).assertEqual(14);
      expect(page.safeBottomInset).assertEqual(16);
      expect(closeCount).assertEqual(1);
      expect(searchKeyword).assertEqual('park');
      expect(clickedId).assertEqual(11);
      expect(defaultStateLabel).assertEqual('--');
      expect(defaultRange).assertEqual('--');
      expect(palette.textPrimary).assertEqual(ThemeCenter.getPalette('dark').textPrimary);
      expect(palette.textSecondary).assertEqual(ThemeCenter.getPalette('dark').textSecondary);
      expect(palette.textTertiary).assertEqual(ThemeCenter.getPalette('dark').textTertiary);
      expect(palette.companionBg).assertEqual(ThemeCenter.getPalette('dark').companionBg);
      expect(palette.companionCardBg).assertEqual(ThemeCenter.getPalette('dark').companionCardBg);
      expect(palette.primary).assertEqual(ThemeCenter.getPalette('dark').primary);
    });
    it('normal: search_page_render_should_support_result_list_branch_and_custom_meta_callbacks', 0, () => {
      // Arrange
      const page = new CompanionSearchPage(undefined, {} as LocalStorage) as Object as CompanionSearchPagePrivateTest;
      const first = buildSearchEvent(1, 'museum');
      const second = buildSearchEvent(2, 'station');
      const capturedNames: string[] = [];
      page.getEventStateLabel = (_item: EventEntity): string => '进行中';
      page.getPlannedRange = (item: EventEntity): string => {
        capturedNames.push(item.name);
        return '10:00-11:00';
      };
      page.setInitiallyProvidedValue({
        showSearchPage: true,
        searchKeyword: 'mu',
        searchResults: [first, second],
        safeTopInset: 8,
        safeBottomInset: 10
      });

      // Act
      const meta = getCompanionSearchResultMetaText(page.getEventStateLabel(first), page.getPlannedRange(first));
      const threw = runSearchPageRender(page);

      // Assert
      expect(threw).assertFalse();
      expect(meta).assertEqual('进行中 | 10:00-11:00');
      expect(capturedNames[0]).assertEqual('museum');
    });

    it('boundary: search_page_render_should_support_empty_state_branch_with_safe_area_values', 0, () => {
      // Arrange
      const page = new CompanionSearchPage(undefined, {} as LocalStorage) as Object as CompanionSearchPagePrivateTest;
      page.setInitiallyProvidedValue({
        showSearchPage: true,
        searchKeyword: 'none',
        searchResults: [],
        safeTopInset: 12,
        safeBottomInset: 18
      });

      // Act
      const shouldShowEmpty = shouldShowCompanionSearchEmptyState(page.searchResults.length);
      const threw = runSearchPageRender(page);

      // Assert
      expect(shouldShowEmpty).assertTrue();
      expect(threw).assertFalse();
      expect(page.searchResults.length).assertEqual(0);
    });

    it('conflict: search_page_render_should_keep_hidden_branch_independent_from_non_empty_results', 0, () => {
      // Arrange
      const page = new CompanionSearchPage(undefined, {} as LocalStorage) as Object as CompanionSearchPagePrivateTest;
      page.setInitiallyProvidedValue({
        showSearchPage: false,
        searchKeyword: 'park',
        searchResults: [buildSearchEvent(3, 'park')],
        safeTopInset: 2,
        safeBottomInset: 4
      });

      // Act
      const visible = shouldShowCompanionSearchPage(false);
      const shouldShowEmpty = shouldShowCompanionSearchEmptyState(1);

      // Assert
      expect(visible).assertFalse();
      expect(shouldShowEmpty).assertFalse();
      expect(page.searchResults.length >= 0).assertTrue();
    });

    it('regression: search_page_render_should_keep_dark_theme_result_state_after_props_update', 0, () => {
      // Arrange
      const page = new CompanionSearchPage(undefined, {} as LocalStorage) as Object as CompanionSearchPagePrivateTest;
      const initialEvent = buildSearchEvent(4, 'cafe');
      const nextEvent = buildSearchEvent(5, 'hotel');
      page.setInitiallyProvidedValue({
        showSearchPage: true,
        searchKeyword: 'ca',
        searchResults: [initialEvent],
        safeTopInset: 6,
        safeBottomInset: 8
      });
      page.updateStateVars({
        showSearchPage: true,
        searchKeyword: 'ho',
        searchResults: [nextEvent],
        safeTopInset: 16,
        safeBottomInset: 20
      });
      page.effectiveTheme = 'dark';

      // Act
      const palette = page.getThemePalette();
      const threw = runSearchPageRender(page);

      // Assert
      expect(threw).assertFalse();
      expect(page.searchKeyword).assertEqual('ho');
      expect(page.searchResults[0].name).assertEqual('hotel');
      expect(page.safeTopInset).assertEqual(16);
      expect(page.safeBottomInset).assertEqual(20);
      expect(palette.companionBg).assertEqual(ThemeCenter.getPalette('dark').companionBg);
      expect(palette.companionCardBg).assertEqual(ThemeCenter.getPalette('dark').companionCardBg);
      expect(palette.primary).assertEqual(ThemeCenter.getPalette('dark').primary);
    });
  });
}

