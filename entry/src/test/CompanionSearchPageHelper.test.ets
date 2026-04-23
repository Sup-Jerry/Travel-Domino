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
  initialRender(): void;
}

function buildSearchEvent(id: number, name: string): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  return event;
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

    it('combined: search_page_instance_should_sync_props_callbacks_and_palette', 0, () => {
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
      expect(palette.textPrimary).assertEqual(ThemeCenter.getPalette('dark').textPrimary);
      expect(palette.textSecondary).assertEqual(ThemeCenter.getPalette('dark').textSecondary);
      expect(palette.textTertiary).assertEqual(ThemeCenter.getPalette('dark').textTertiary);
      expect(palette.companionBg).assertEqual(ThemeCenter.getPalette('dark').companionBg);
      expect(palette.companionCardBg).assertEqual(ThemeCenter.getPalette('dark').companionCardBg);
      expect(palette.primary).assertEqual(ThemeCenter.getPalette('dark').primary);
    });
    it('normal: search_page_initial_render_should_support_result_list_branch', 0, () => {
      // Arrange
      const page = new CompanionSearchPage(undefined, {} as LocalStorage) as Object as CompanionSearchPagePrivateTest;
      const first = buildSearchEvent(1, 'museum');
      const second = buildSearchEvent(2, 'station');
      page.getEventStateLabel = (_item: EventEntity): string => '进行中';
      page.getPlannedRange = (_item: EventEntity): string => '10:00-11:00';
      page.setInitiallyProvidedValue({
        showSearchPage: true,
        searchKeyword: 'mu',
        searchResults: [first, second],
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

    it('boundary: search_page_initial_render_should_support_empty_state_and_hidden_state_branches', 0, () => {
      // Arrange
      const emptyPage = new CompanionSearchPage(undefined, {} as LocalStorage) as Object as CompanionSearchPagePrivateTest;
      emptyPage.setInitiallyProvidedValue({
        showSearchPage: true,
        searchKeyword: 'none',
        searchResults: [],
        safeTopInset: 0,
        safeBottomInset: 0
      });
      const hiddenPage = new CompanionSearchPage(undefined, {} as LocalStorage) as Object as CompanionSearchPagePrivateTest;
      hiddenPage.setInitiallyProvidedValue({
        showSearchPage: false,
        searchKeyword: '',
        searchResults: [],
        safeTopInset: 0,
        safeBottomInset: 0
      });

      // Act
      let emptyThrew = false;
      let hiddenThrew = false;
      try {
        emptyPage.initialRender();
      } catch (_error) {
        emptyThrew = true;
      }
      try {
        hiddenPage.initialRender();
      } catch (_error) {
        hiddenThrew = true;
      }

      // Assert
      expect(emptyThrew).assertFalse();
      expect(hiddenThrew).assertFalse();
    });
  });
}

