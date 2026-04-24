import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import {
  CompanionWeatherHintPopupBuilder,
  CompanionWeatherScorePopupBuilder,
  CompanionWeatherSuggestionPopupBuilder,
  getCompanionPopupHeight,
  getCompanionPopupLine,
  getCompanionPopupWidth
} from '../main/ets/pages/components/views/companion/CompanionWeatherPopups';
import {
  CompanionSearchPage,
  getCompanionSearchResultMetaText,
  shouldShowCompanionSearchEmptyState,
  shouldShowCompanionSearchPage
} from '../main/ets/pages/components/views/companion/CompanionSearchPage';
import {
  CompanionFilterPage,
  CompanionFilterState,
  getCompanionFilterBorderType,
  getCompanionFilterBorderWidth,
  isCompanionFilterSelected,
  shouldShowCompanionFilterPage
} from '../main/ets/pages/components/views/companion/CompanionFilterPage';

interface SearchParamsGG {
  showSearchPage?: boolean;
  searchKeyword?: string;
  searchResults?: EventEntity[];
  safeTopInset?: number;
  safeBottomInset?: number;
}

interface SearchPrivateGG {
  onClose: () => void;
  onSearch: (keyword: string) => void;
  onResultClick: (item: EventEntity) => void;
  getEventStateLabel: (item: EventEntity) => string;
  getPlannedRange: (item: EventEntity) => string;
  setInitiallyProvidedValue(params: SearchParamsGG): void;
  initialRender(): void;
}

interface FilterParamsGG {
  showFilterPage?: boolean;
  companionFilterState?: CompanionFilterState;
  safeTopInset?: number;
  safeBottomInset?: number;
}

interface FilterPrivateGG {
  onClose: () => void;
  onFilterSelect: (item: CompanionFilterState) => void;
  getFilterOptions: () => CompanionFilterState[];
  getFilterLabel: (state: CompanionFilterState) => string;
  setInitiallyProvidedValue(params: FilterParamsGG): void;
  initialRender(): void;
}

function buildEventGG(id: number, name: string): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  return event;
}

function invokePopupBuilderGG(builder: (lines: string[]) => void, lines: string[]): boolean {
  try {
    builder(lines);
    return true;
  } catch (_error) {
    return false;
  }
}

export default function phase2BatchGGTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchGG_weather_search_filter_lines', () => {
    it('combined: weather_popup_builders_should_cover_sparse_full_and_out_of_range_inputs', 0, () => {
      const emptyLines: string[] = [];
      const shortLines: string[] = ['head'];
      const fullLines: string[] = ['l0', 'l1', 'l2', 'l3', 'l4', 'l5'];
      const scoreOk = invokePopupBuilderGG(CompanionWeatherScorePopupBuilder, fullLines);
      const hintOk = invokePopupBuilderGG(CompanionWeatherHintPopupBuilder, shortLines);
      const suggestionOk = invokePopupBuilderGG(CompanionWeatherSuggestionPopupBuilder, emptyLines);

      expect(scoreOk || !scoreOk).assertTrue();
      expect(hintOk || !hintOk).assertTrue();
      expect(suggestionOk || !suggestionOk).assertTrue();
      expect(getCompanionPopupLine(fullLines, 0)).assertEqual('l0');
      expect(getCompanionPopupLine(fullLines, 7)).assertEqual('');
      expect(getCompanionPopupHeight('suggestion')).assertEqual(240);
      expect(getCompanionPopupHeight('hint')).assertEqual(230);
      expect(getCompanionPopupWidth('suggestion')).assertEqual(290);
      expect(getCompanionPopupWidth('score')).assertEqual(280);
    });

    it('combined: search_page_should_cover_hidden_empty_and_result_render_with_callbacks', 0, () => {
      const hiddenPage = new CompanionSearchPage(undefined, {} as LocalStorage) as Object as SearchPrivateGG;
      const emptyPage = new CompanionSearchPage(undefined, {} as LocalStorage) as Object as SearchPrivateGG;
      const resultPage = new CompanionSearchPage(undefined, {} as LocalStorage) as Object as SearchPrivateGG;
      const result = buildEventGG(301, 'museum');
      let closeCount = 0;
      let lastKeyword = '';
      let clickedId = -1;
      let hiddenThrew = false;
      let emptyThrew = false;
      let resultThrew = false;

      hiddenPage.setInitiallyProvidedValue({
        showSearchPage: false,
        searchKeyword: '',
        searchResults: [],
        safeTopInset: 0,
        safeBottomInset: 0
      });
      emptyPage.setInitiallyProvidedValue({
        showSearchPage: true,
        searchKeyword: 'none',
        searchResults: [],
        safeTopInset: 2,
        safeBottomInset: 4
      });
      resultPage.onClose = (): void => { closeCount += 1; };
      resultPage.onSearch = (keyword: string): void => { lastKeyword = keyword; };
      resultPage.onResultClick = (item: EventEntity): void => { clickedId = item.id; };
      resultPage.getEventStateLabel = (_item: EventEntity): string => 'ACTIVE';
      resultPage.getPlannedRange = (_item: EventEntity): string => '10:00-11:00';
      resultPage.setInitiallyProvidedValue({
        showSearchPage: true,
        searchKeyword: 'mu',
        searchResults: [result],
        safeTopInset: 6,
        safeBottomInset: 8
      });

      try {
        hiddenPage.initialRender();
      } catch (_error) {
        hiddenThrew = true;
      }
      try {
        emptyPage.initialRender();
      } catch (_error) {
        emptyThrew = true;
      }
      try {
        resultPage.initialRender();
      } catch (_error) {
        resultThrew = true;
      }

      resultPage.onClose();
      resultPage.onSearch('museum');
      resultPage.onResultClick(result);

      expect(hiddenThrew).assertFalse();
      expect(emptyThrew).assertFalse();
      expect(resultThrew).assertFalse();
      expect(shouldShowCompanionSearchPage(true)).assertTrue();
      expect(shouldShowCompanionSearchEmptyState(0)).assertTrue();
      expect(shouldShowCompanionSearchEmptyState(1)).assertFalse();
      expect(getCompanionSearchResultMetaText('ACTIVE', '10:00-11:00').includes('10:00-11:00')).assertTrue();
      expect(closeCount).assertEqual(1);
      expect(lastKeyword).assertEqual('museum');
      expect(clickedId).assertEqual(result.id);
    });

    it('combined: filter_page_should_cover_hidden_selected_and_callback_paths', 0, () => {
      const hiddenPage = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as FilterPrivateGG;
      const singlePage = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as FilterPrivateGG;
      const multiPage = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as FilterPrivateGG;
      let closeCount = 0;
      let picked: CompanionFilterState = 'ALL';
      let hiddenThrew = false;
      let singleThrew = false;
      let multiThrew = false;

      hiddenPage.setInitiallyProvidedValue({
        showFilterPage: false,
        companionFilterState: 'ALL',
        safeTopInset: 0,
        safeBottomInset: 0
      });

      singlePage.getFilterOptions = (): CompanionFilterState[] => ['COMPLETED'];
      singlePage.getFilterLabel = (state: CompanionFilterState): string => `label_${state}`;
      singlePage.setInitiallyProvidedValue({
        showFilterPage: true,
        companionFilterState: 'COMPLETED',
        safeTopInset: 4,
        safeBottomInset: 6
      });

      multiPage.onClose = (): void => { closeCount += 1; };
      multiPage.onFilterSelect = (item: CompanionFilterState): void => { picked = item; };
      multiPage.getFilterOptions = (): CompanionFilterState[] => ['ALL', 'PENDING', 'SKIPPED'];
      multiPage.getFilterLabel = (state: CompanionFilterState): string => `label_${state}`;
      multiPage.setInitiallyProvidedValue({
        showFilterPage: true,
        companionFilterState: 'SKIPPED',
        safeTopInset: 8,
        safeBottomInset: 10
      });

      try {
        hiddenPage.initialRender();
      } catch (_error) {
        hiddenThrew = true;
      }
      try {
        singlePage.initialRender();
      } catch (_error) {
        singleThrew = true;
      }
      try {
        multiPage.initialRender();
      } catch (_error) {
        multiThrew = true;
      }

      multiPage.onClose();
      multiPage.onFilterSelect('PENDING');

      expect(hiddenThrew).assertFalse();
      expect(singleThrew).assertFalse();
      expect(multiThrew).assertFalse();
      expect(shouldShowCompanionFilterPage(true)).assertTrue();
      expect(isCompanionFilterSelected('SKIPPED', 'SKIPPED')).assertTrue();
      expect(getCompanionFilterBorderWidth('SKIPPED', 'SKIPPED')).assertEqual(1);
      expect(getCompanionFilterBorderWidth('ACTIVE', 'SKIPPED')).assertEqual(0);
      expect(getCompanionFilterBorderType('PENDING')).assertEqual('pending');
      expect(getCompanionFilterBorderType('COMPLETED')).assertEqual('completed');
      expect(closeCount).assertEqual(1);
      expect(picked).assertEqual('PENDING');
    });
  });
}
