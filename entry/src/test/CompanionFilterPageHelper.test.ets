import { describe, it, expect } from '@ohos/hypium';
import {
  CompanionFilterPage,
  CompanionFilterState,
  getCompanionFilterBorderType,
  getCompanionFilterBorderWidth,
  isCompanionFilterSelected,
  shouldShowCompanionFilterPage
} from '../main/ets/pages/components/views/companion/CompanionFilterPage';
import { ThemeCenter } from '../main/ets/common/utils/ThemeCenter';

interface CompanionFilterPagePaletteTest {
  textPrimary: Object;
  textSecondary: Object;
  companionBg: Object;
  primary: Object;
}

interface CompanionFilterPageParamsTest {
  showFilterPage?: boolean;
  companionFilterState?: CompanionFilterState;
  safeTopInset?: number;
  safeBottomInset?: number;
}

interface CompanionFilterPagePrivateTest {
  showFilterPage: boolean;
  companionFilterState: CompanionFilterState;
  safeTopInset: number;
  safeBottomInset: number;
  effectiveTheme: string;
  onClose: () => void;
  onFilterSelect: (item: CompanionFilterState) => void;
  getFilterOptions: () => CompanionFilterState[];
  getFilterLabel: (state: CompanionFilterState) => string;
  setInitiallyProvidedValue(params: CompanionFilterPageParamsTest): void;
  updateStateVars(params: CompanionFilterPageParamsTest): void;
  getThemePalette(): CompanionFilterPagePaletteTest;
  initialRender(): void;
}

export default function companionFilterPageHelperTest() {
  describe('unit_test_case_generator_autofill_CompanionFilterPageHelper', () => {
    it('normal: filter_page_should_follow_show_flag', 0, () => {
      // Arrange
      const show = true;

      // Act
      const visible = shouldShowCompanionFilterPage(show);

      // Assert
      expect(visible).assertTrue();
    });

    it('boundary: border_width_should_be_one_for_selected_item', 0, () => {
      // Arrange
      const item: CompanionFilterState = 'ACTIVE';
      const current: CompanionFilterState = 'ACTIVE';

      // Act
      const width = getCompanionFilterBorderWidth(item, current);

      // Assert
      expect(width).assertEqual(1);
    });

    it('invalid: border_type_should_fallback_to_default_for_all', 0, () => {
      // Arrange
      const item: CompanionFilterState = 'ALL';

      // Act
      const borderType = getCompanionFilterBorderType(item);

      // Assert
      expect(borderType).assertEqual('default');
    });

    it('conflict: selected_state_should_be_false_when_item_and_current_mismatch', 0, () => {
      // Arrange
      const item: CompanionFilterState = 'PENDING';
      const current: CompanionFilterState = 'COMPLETED';

      // Act
      const selected = isCompanionFilterSelected(item, current);

      // Assert
      expect(selected).assertFalse();
    });

    it('regression: border_type_mapping_should_keep_pending_completed_skipped_semantics', 0, () => {
      // Arrange
      const pending: CompanionFilterState = 'PENDING';
      const completed: CompanionFilterState = 'COMPLETED';
      const skipped: CompanionFilterState = 'SKIPPED';

      // Act
      const pendingType = getCompanionFilterBorderType(pending);
      const completedType = getCompanionFilterBorderType(completed);
      const skippedType = getCompanionFilterBorderType(skipped);

      // Assert
      expect(pendingType).assertEqual('pending');
      expect(completedType).assertEqual('completed');
      expect(skippedType).assertEqual('skipped');
    });

    it('combined: width_and_selection_matrix_should_be_consistent_for_options', 0, () => {
      // Arrange
      const current: CompanionFilterState = 'SKIPPED';
      const options: CompanionFilterState[] = ['ALL', 'PENDING', 'ACTIVE', 'COMPLETED', 'SKIPPED'];

      // Act
      const selectedCount = options.filter((item) => isCompanionFilterSelected(item, current)).length;
      const selectedWidth = getCompanionFilterBorderWidth('SKIPPED', current);
      const unselectedWidth = getCompanionFilterBorderWidth('ACTIVE', current);

      // Assert
      expect(selectedCount).assertEqual(1);
      expect(selectedWidth).assertEqual(1);
      expect(unselectedWidth).assertEqual(0);
    });

    it('combined: filter_page_instance_should_sync_props_and_keep_default_callbacks_stable', 0, () => {
      // Arrange
      const page = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as CompanionFilterPagePrivateTest;

      // Act
      page.onClose();
      page.onFilterSelect('ALL');
      const options = page.getFilterOptions();
      const label = page.getFilterLabel('ALL');
      page.setInitiallyProvidedValue({
        showFilterPage: true,
        companionFilterState: 'ACTIVE',
        safeTopInset: 8,
        safeBottomInset: 10
      });
      page.updateStateVars({
        showFilterPage: false,
        companionFilterState: 'SKIPPED',
        safeTopInset: 18,
        safeBottomInset: 20
      });
      page.effectiveTheme = 'dark';
      const palette = page.getThemePalette();

      // Assert
      expect(options.length).assertEqual(5);
      expect(label).assertEqual('--');
      expect(page.showFilterPage).assertFalse();
      expect(page.companionFilterState).assertEqual('SKIPPED');
      expect(page.safeTopInset).assertEqual(18);
      expect(page.safeBottomInset).assertEqual(20);
      expect(palette.textPrimary).assertEqual(ThemeCenter.getPalette('dark').textPrimary);
      expect(palette.textSecondary).assertEqual(ThemeCenter.getPalette('dark').textSecondary);
      expect(palette.companionBg).assertEqual(ThemeCenter.getPalette('dark').companionBg);
      expect(palette.primary).assertEqual(ThemeCenter.getPalette('dark').primary);
    });

    it('normal: filter_page_initial_render_should_support_visible_selected_branch', 0, () => {
      // Arrange
      const page = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as CompanionFilterPagePrivateTest;
      page.getFilterOptions = (): CompanionFilterState[] => ['ALL', 'PENDING', 'ACTIVE'];
      page.getFilterLabel = (state: CompanionFilterState): string => `label_${state}`;
      page.setInitiallyProvidedValue({
        showFilterPage: true,
        companionFilterState: 'PENDING',
        safeTopInset: 6,
        safeBottomInset: 8
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

    it('boundary: filter_page_initial_render_should_support_hidden_branch', 0, () => {
      // Arrange
      const page = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as CompanionFilterPagePrivateTest;
      page.setInitiallyProvidedValue({
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

    it('regression: filter_page_initial_render_should_support_completed_and_skipped_border_branches', 0, () => {
      // Arrange
      const completedPage = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as CompanionFilterPagePrivateTest;
      completedPage.getFilterOptions = (): CompanionFilterState[] => ['COMPLETED', 'SKIPPED'];
      completedPage.getFilterLabel = (state: CompanionFilterState): string => `label_${state}`;
      completedPage.effectiveTheme = 'dark';
      completedPage.setInitiallyProvidedValue({
        showFilterPage: true,
        companionFilterState: 'COMPLETED',
        safeTopInset: 4,
        safeBottomInset: 6
      });
      const skippedPage = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as CompanionFilterPagePrivateTest;
      skippedPage.getFilterOptions = (): CompanionFilterState[] => ['SKIPPED', 'ALL'];
      skippedPage.getFilterLabel = (state: CompanionFilterState): string => `label_${state}`;
      skippedPage.setInitiallyProvidedValue({
        showFilterPage: true,
        companionFilterState: 'SKIPPED',
        safeTopInset: 2,
        safeBottomInset: 3
      });
      let completedThrew = false;
      let skippedThrew = false;

      // Act
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

      // Assert
      expect(completedThrew).assertFalse();
      expect(skippedThrew).assertFalse();
      expect(getCompanionFilterBorderType('COMPLETED')).assertEqual('completed');
      expect(getCompanionFilterBorderType('SKIPPED')).assertEqual('skipped');
      expect(!!completedPage.getThemePalette().primary).assertTrue();
    });

    it('combined: filter_page_should_cover_unselected_visible_matrix_for_active_state', 0, () => {
      // Arrange
      const page = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as CompanionFilterPagePrivateTest;
      page.getFilterOptions = (): CompanionFilterState[] => ['ALL', 'ACTIVE', 'PENDING', 'COMPLETED'];
      page.getFilterLabel = (state: CompanionFilterState): string => `matrix_${state}`;
      page.setInitiallyProvidedValue({
        showFilterPage: true,
        companionFilterState: 'ACTIVE',
        safeTopInset: 10,
        safeBottomInset: 12
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
      expect(isCompanionFilterSelected('ACTIVE', 'ACTIVE')).assertTrue();
      expect(getCompanionFilterBorderWidth('PENDING', 'ACTIVE')).assertEqual(0);
      expect(getCompanionFilterBorderWidth('ACTIVE', 'ACTIVE')).assertEqual(1);
    });

    it('boundary: filter_page_initial_render_should_support_pending_selected_light_theme_branch', 0, () => {
      // Arrange
      const page = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as CompanionFilterPagePrivateTest;
      page.effectiveTheme = 'light';
      page.getFilterOptions = (): CompanionFilterState[] => ['PENDING', 'ACTIVE', 'ALL'];
      page.getFilterLabel = (state: CompanionFilterState): string => `pending_${state}`;
      page.setInitiallyProvidedValue({
        showFilterPage: true,
        companionFilterState: 'PENDING',
        safeTopInset: 5,
        safeBottomInset: 7
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
      expect(getCompanionFilterBorderType('PENDING')).assertEqual('pending');
      expect(getCompanionFilterBorderWidth('PENDING', 'PENDING')).assertEqual(1);
      expect(page.getThemePalette().primary).assertEqual(ThemeCenter.getPalette('light').primary);
    });

    it('combined: filter_page_initial_render_should_support_default_border_branch_for_all_selection', 0, () => {
      // Arrange
      const page = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as CompanionFilterPagePrivateTest;
      page.effectiveTheme = 'dark';
      page.getFilterOptions = (): CompanionFilterState[] => ['ALL', 'PENDING', 'SKIPPED'];
      page.getFilterLabel = (state: CompanionFilterState): string => `all_${state}`;
      page.setInitiallyProvidedValue({
        showFilterPage: true,
        companionFilterState: 'ALL',
        safeTopInset: 1,
        safeBottomInset: 2
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
      expect(getCompanionFilterBorderType('ALL')).assertEqual('default');
      expect(getCompanionFilterBorderWidth('ALL', 'ALL')).assertEqual(1);
      expect(getCompanionFilterBorderWidth('SKIPPED', 'ALL')).assertEqual(0);
    });
  });
}
