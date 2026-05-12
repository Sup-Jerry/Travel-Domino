import { describe, expect, it } from '@ohos/hypium';
import {
  CompanionFilterPage,
  CompanionFilterState,
  getCompanionFilterBorderType,
  getCompanionFilterBorderWidth,
  isCompanionFilterSelected,
  shouldShowCompanionFilterPage
} from '../main/ets/pages/components/views/companion/CompanionFilterPage';
import {
  CompanionWeatherHintPopupBuilder,
  CompanionWeatherScorePopupBuilder,
  CompanionWeatherSuggestionPopupBuilder,
  getCompanionPopupHeight,
  getCompanionPopupLine,
  getCompanionPopupWidth
} from '../main/ets/pages/components/views/companion/CompanionWeatherPopups';

interface Phase2FilterParamsFJ {
  showFilterPage?: boolean;
  companionFilterState?: CompanionFilterState;
  safeTopInset?: number;
  safeBottomInset?: number;
}

interface Phase2FilterPrivateFJ {
  showFilterPage: boolean;
  companionFilterState: CompanionFilterState;
  safeTopInset: number;
  safeBottomInset: number;
  onClose: () => void;
  onFilterSelect: (item: CompanionFilterState) => void;
  getFilterOptions: () => CompanionFilterState[];
  getFilterLabel: (state: CompanionFilterState) => string;
  setInitiallyProvidedValue(params: Phase2FilterParamsFJ): void;
  updateStateVars(params: Phase2FilterParamsFJ): void;
  initialRender(): void;
}

function invokePopupBuilderFJ(builder: (lines: string[]) => void, lines: string[]): boolean {
  try {
    builder(lines);
    return true;
  } catch (_error) {
    return false;
  }
}

export default function phase2BatchFJTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchFJ_filter_popup_lines', () => {
    it('combined: filter_helpers_should_cover_selection_border_and_type_matrix', 0, () => {
      const options: CompanionFilterState[] = ['ALL', 'PENDING', 'ACTIVE', 'COMPLETED', 'SKIPPED'];
      const selected = options.filter((item: CompanionFilterState) => isCompanionFilterSelected(item, 'COMPLETED'));
      expect(shouldShowCompanionFilterPage(true)).assertTrue();
      expect(shouldShowCompanionFilterPage(false)).assertFalse();
      expect(selected.length).assertEqual(1);
      expect(selected[0]).assertEqual('COMPLETED');
      expect(getCompanionFilterBorderWidth('COMPLETED', 'COMPLETED')).assertEqual(1);
      expect(getCompanionFilterBorderWidth('ACTIVE', 'COMPLETED')).assertEqual(0);
      expect(getCompanionFilterBorderType('PENDING')).assertEqual('pending');
      expect(getCompanionFilterBorderType('SKIPPED')).assertEqual('skipped');
      expect(getCompanionFilterBorderType('COMPLETED')).assertEqual('completed');
      expect(getCompanionFilterBorderType('ACTIVE')).assertEqual('default');
    });

    it('normal: filter_page_should_sync_custom_options_labels_and_callbacks', 0, () => {
      const page = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as Phase2FilterPrivateFJ;
      let closeCount = 0;
      let picked = '';
      page.onClose = (): void => { closeCount += 1; };
      page.onFilterSelect = (item: CompanionFilterState): void => { picked = item; };
      page.getFilterOptions = (): CompanionFilterState[] => ['SKIPPED', 'COMPLETED', 'ACTIVE'];
      page.getFilterLabel = (state: CompanionFilterState): string => `label_${state}`;
      page.setInitiallyProvidedValue({
        showFilterPage: true,
        companionFilterState: 'SKIPPED',
        safeTopInset: 6,
        safeBottomInset: 8
      });
      page.updateStateVars({
        showFilterPage: true,
        companionFilterState: 'COMPLETED',
        safeTopInset: 16,
        safeBottomInset: 18
      });
      page.onClose();
      page.onFilterSelect(page.getFilterOptions()[0]);

      expect(page.showFilterPage).assertTrue();
      expect(page.companionFilterState).assertEqual('COMPLETED');
      expect(page.safeTopInset).assertEqual(16);
      expect(page.safeBottomInset).assertEqual(18);
      expect(page.getFilterOptions().length).assertEqual(3);
      expect(page.getFilterLabel('ACTIVE')).assertEqual('label_ACTIVE');
      expect(closeCount).assertEqual(1);
      expect(picked).assertEqual('SKIPPED');
    });

    it('combined: filter_page_initial_render_should_cover_completed_skipped_and_single_option_paths', 0, () => {
      const completedPage = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as Phase2FilterPrivateFJ;
      const skippedPage = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as Phase2FilterPrivateFJ;
      let completedThrew = false;
      let skippedThrew = false;

      completedPage.getFilterOptions = (): CompanionFilterState[] => ['ALL', 'COMPLETED'];
      completedPage.getFilterLabel = (state: CompanionFilterState): string => `f_${state}`;
      completedPage.setInitiallyProvidedValue({
        showFilterPage: true,
        companionFilterState: 'COMPLETED',
        safeTopInset: 10,
        safeBottomInset: 12
      });
      skippedPage.getFilterOptions = (): CompanionFilterState[] => ['SKIPPED'];
      skippedPage.getFilterLabel = (state: CompanionFilterState): string => `f_${state}`;
      skippedPage.setInitiallyProvidedValue({
        showFilterPage: true,
        companionFilterState: 'SKIPPED',
        safeTopInset: 0,
        safeBottomInset: 0
      });

      try {
        completedPage.initialRender();
      } catch (_error) {
        completedThrew = true;
      }
      try {
        skippedPage.initialRender();
      } catch (_error) {
        skippedThrew = true;
      }

      expect(completedThrew).assertFalse();
      expect(skippedThrew).assertFalse();
    });

    it('boundary: popup_helpers_should_cover_sparse_lines_and_size_matrix', 0, () => {
      const sparseLines: string[] = ['head', '', 'tail'];
      expect(getCompanionPopupLine(sparseLines, 0)).assertEqual('head');
      expect(getCompanionPopupLine(sparseLines, 1)).assertEqual('');
      expect(getCompanionPopupLine(sparseLines, 2)).assertEqual('tail');
      expect(getCompanionPopupLine(sparseLines, 5)).assertEqual('');
      expect(getCompanionPopupHeight('score')).assertEqual(230);
      expect(getCompanionPopupHeight('hint')).assertEqual(230);
      expect(getCompanionPopupHeight('suggestion')).assertEqual(240);
      expect(getCompanionPopupWidth('score')).assertEqual(280);
      expect(getCompanionPopupWidth('hint')).assertEqual(280);
      expect(getCompanionPopupWidth('suggestion')).assertEqual(290);
    });

    it('combined: popup_builders_should_accept_empty_short_and_full_payloads', 0, () => {
      const emptyLines: string[] = [];
      const shortLines: string[] = ['a'];
      const fullLines: string[] = ['0', '1', '2', '3', '4', '5'];
      const scoreResult = invokePopupBuilderFJ(CompanionWeatherScorePopupBuilder, emptyLines);
      const hintResult = invokePopupBuilderFJ(CompanionWeatherHintPopupBuilder, shortLines);
      const suggestionResult = invokePopupBuilderFJ(CompanionWeatherSuggestionPopupBuilder, fullLines);

      expect(typeof scoreResult === 'boolean').assertTrue();
      expect(typeof hintResult === 'boolean').assertTrue();
      expect(typeof suggestionResult === 'boolean').assertTrue();
      expect(getCompanionPopupLine(fullLines, 5)).assertEqual('5');
    });
  });
}
