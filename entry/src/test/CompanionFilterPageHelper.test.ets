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
  build(): void;
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

    it('boundary: filter_page_initial_render_should_skip_option_rendering_when_page_hidden', 0, () => {
      // Arrange
      const page = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as CompanionFilterPagePrivateTest;
      let optionReadCount = 0;
      page.getFilterOptions = (): CompanionFilterState[] => {
        optionReadCount += 1;
        return ['ALL', 'ACTIVE'];
      };
      page.setInitiallyProvidedValue({
        showFilterPage: false,
        companionFilterState: 'ACTIVE',
        safeTopInset: 3,
        safeBottomInset: 5
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
      expect(optionReadCount).assertEqual(0);
      expect(shouldShowCompanionFilterPage(page.showFilterPage)).assertFalse();
    });

    it('regression: filter_page_initial_render_should_support_visible_active_selected_with_completed_and_skipped_unselected', 0, () => {
      // Arrange
      const page = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as CompanionFilterPagePrivateTest;
      page.effectiveTheme = 'dark';
      page.getFilterOptions = (): CompanionFilterState[] => ['ACTIVE', 'COMPLETED', 'SKIPPED'];
      page.getFilterLabel = (state: CompanionFilterState): string => `build_${state}`;
      page.setInitiallyProvidedValue({
        showFilterPage: true,
        companionFilterState: 'ACTIVE',
        safeTopInset: 9,
        safeBottomInset: 11
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
      expect(isCompanionFilterSelected('ACTIVE', 'ACTIVE')).assertTrue();
      expect(getCompanionFilterBorderWidth('ACTIVE', 'ACTIVE')).assertEqual(1);
      expect(getCompanionFilterBorderWidth('COMPLETED', 'ACTIVE')).assertEqual(0);
      expect(getCompanionFilterBorderWidth('SKIPPED', 'ACTIVE')).assertEqual(0);
      expect(getCompanionFilterBorderType('ACTIVE')).assertEqual('default');
      expect(getCompanionFilterBorderType('COMPLETED')).assertEqual('completed');
      expect(getCompanionFilterBorderType('SKIPPED')).assertEqual('skipped');
      expect(page.getThemePalette().textPrimary).assertEqual(ThemeCenter.getPalette('dark').textPrimary);
    });

    it('combined: filter_page_initial_render_should_support_visible_completed_selected_with_all_and_pending_unselected', 0, () => {
      // Arrange
      const page = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as CompanionFilterPagePrivateTest;
      page.effectiveTheme = 'light';
      page.getFilterOptions = (): CompanionFilterState[] => ['ALL', 'PENDING', 'COMPLETED'];
      page.getFilterLabel = (state: CompanionFilterState): string => `visible_${state}`;
      page.setInitiallyProvidedValue({
        showFilterPage: true,
        companionFilterState: 'COMPLETED',
        safeTopInset: 12,
        safeBottomInset: 16
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
      expect(shouldShowCompanionFilterPage(true)).assertTrue();
      expect(isCompanionFilterSelected('COMPLETED', 'COMPLETED')).assertTrue();
      expect(isCompanionFilterSelected('ALL', 'COMPLETED')).assertFalse();
      expect(isCompanionFilterSelected('PENDING', 'COMPLETED')).assertFalse();
      expect(getCompanionFilterBorderType('ALL')).assertEqual('default');
      expect(getCompanionFilterBorderType('PENDING')).assertEqual('pending');
      expect(getCompanionFilterBorderType('COMPLETED')).assertEqual('completed');
      expect(getCompanionFilterBorderWidth('COMPLETED', 'COMPLETED')).assertEqual(1);
      expect(getCompanionFilterBorderWidth('ALL', 'COMPLETED')).assertEqual(0);
    });

    it('regression: filter_page_initial_render_should_support_visible_pending_selected_with_default_light_palette', 0, () => {
      // Arrange
      const page = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as CompanionFilterPagePrivateTest;
      page.getFilterOptions = (): CompanionFilterState[] => ['ALL', 'PENDING', 'SKIPPED'];
      page.setInitiallyProvidedValue({
        showFilterPage: true,
        companionFilterState: 'PENDING',
        safeTopInset: 0,
        safeBottomInset: 0
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
      expect(isCompanionFilterSelected('PENDING', 'PENDING')).assertTrue();
      expect(isCompanionFilterSelected('SKIPPED', 'PENDING')).assertFalse();
      expect(getCompanionFilterBorderType('PENDING')).assertEqual('pending');
      expect(getCompanionFilterBorderType('SKIPPED')).assertEqual('skipped');
      expect(page.getThemePalette().textPrimary).assertEqual(ThemeCenter.getPalette('light').textPrimary);
    });

    it('combined: filter_page_should_keep_default_label_and_width_matrix_consistent_for_all_and_pending', 0, () => {
      // Arrange
      const page = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as CompanionFilterPagePrivateTest;

      // Act
      const allLabel = page.getFilterLabel('ALL');
      const pendingLabel = page.getFilterLabel('PENDING');
      const allWidth = getCompanionFilterBorderWidth('ALL', 'PENDING');
      const pendingWidth = getCompanionFilterBorderWidth('PENDING', 'PENDING');

      // Assert
      expect(allLabel).assertEqual('--');
      expect(pendingLabel).assertEqual('--');
      expect(allWidth).assertEqual(0);
      expect(pendingWidth).assertEqual(1);
    });

    it('boundary: filter_page_initial_render_should_support_visible_all_selected_with_zero_safe_insets', 0, () => {
      // Arrange
      const page = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as CompanionFilterPagePrivateTest;
      page.getFilterOptions = (): CompanionFilterState[] => ['ALL', 'ACTIVE'];
      page.getFilterLabel = (state: CompanionFilterState): string => `all_mode_${state}`;
      page.setInitiallyProvidedValue({
        showFilterPage: true,
        companionFilterState: 'ALL',
        safeTopInset: 0,
        safeBottomInset: 0
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
      expect(isCompanionFilterSelected('ALL', 'ALL')).assertTrue();
      expect(getCompanionFilterBorderWidth('ALL', 'ALL')).assertEqual(1);
      expect(getCompanionFilterBorderType('ALL')).assertEqual('default');
    });

    it('combined: filter_page_should_keep_completed_and_skipped_unselected_matrix_consistent_under_pending_state', 0, () => {
      // Arrange
      const current: CompanionFilterState = 'PENDING';

      // Act
      const completedSelected = isCompanionFilterSelected('COMPLETED', current);
      const skippedSelected = isCompanionFilterSelected('SKIPPED', current);
      const completedWidth = getCompanionFilterBorderWidth('COMPLETED', current);
      const skippedWidth = getCompanionFilterBorderWidth('SKIPPED', current);

      // Assert
      expect(completedSelected).assertFalse();
      expect(skippedSelected).assertFalse();
      expect(completedWidth).assertEqual(0);
      expect(skippedWidth).assertEqual(0);
    });

    it('boundary: filter_page_should_keep_active_unselected_when_current_is_all', 0, () => {
      // Arrange
      const current: CompanionFilterState = 'ALL';

      // Act
      const activeSelected = isCompanionFilterSelected('ACTIVE', current);
      const activeWidth = getCompanionFilterBorderWidth('ACTIVE', current);

      // Assert
      expect(activeSelected).assertFalse();
      expect(activeWidth).assertEqual(0);
    });

    it('combined: filter_page_initial_render_should_support_visible_skipped_selected_with_pending_and_all_unselected', 0, () => {
      // Arrange
      const page = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as CompanionFilterPagePrivateTest;
      page.effectiveTheme = 'dark';
      page.getFilterOptions = (): CompanionFilterState[] => ['PENDING', 'ALL', 'SKIPPED'];
      page.getFilterLabel = (state: CompanionFilterState): string => `skipped_${state}`;
      page.setInitiallyProvidedValue({
        showFilterPage: true,
        companionFilterState: 'SKIPPED',
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
      expect(isCompanionFilterSelected('SKIPPED', 'SKIPPED')).assertTrue();
      expect(isCompanionFilterSelected('PENDING', 'SKIPPED')).assertFalse();
      expect(getCompanionFilterBorderType('SKIPPED')).assertEqual('skipped');
      expect(getCompanionFilterBorderWidth('SKIPPED', 'SKIPPED')).assertEqual(1);
      expect(page.getThemePalette().textSecondary).assertEqual(ThemeCenter.getPalette('dark').textSecondary);
    });

    it('regression: filter_page_should_keep_completed_border_semantics_under_pending_state', 0, () => {
      // Arrange
      const current: CompanionFilterState = 'PENDING';

      // Act
      const completedSelected = isCompanionFilterSelected('COMPLETED', current);
      const completedWidth = getCompanionFilterBorderWidth('COMPLETED', current);
      const completedType = getCompanionFilterBorderType('COMPLETED');

      // Assert
      expect(completedSelected).assertFalse();
      expect(completedWidth).assertEqual(0);
      expect(completedType).assertEqual('completed');
    });

    it('boundary: filter_page_initial_render_should_support_full_option_matrix_with_active_selected', 0, () => {
      // Arrange
      const page = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as CompanionFilterPagePrivateTest;
      page.effectiveTheme = 'dark';
      page.getFilterOptions = (): CompanionFilterState[] => ['ALL', 'PENDING', 'ACTIVE', 'COMPLETED', 'SKIPPED'];
      page.getFilterLabel = (state: CompanionFilterState): string => `full_${state}`;
      page.setInitiallyProvidedValue({
        showFilterPage: true,
        companionFilterState: 'ACTIVE',
        safeTopInset: 0,
        safeBottomInset: 0
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
      expect(getCompanionFilterBorderWidth('COMPLETED', 'ACTIVE')).assertEqual(0);
      expect(getCompanionFilterBorderType('SKIPPED')).assertEqual('skipped');
    });

    it('combined: filter_page_callbacks_should_keep_visible_completed_state_and_explicit_selection_consistent', 0, () => {
      // Arrange
      const page = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as CompanionFilterPagePrivateTest;
      let selectedState: CompanionFilterState = 'ALL';
      let closeCount = 0;
      page.effectiveTheme = 'dark';
      page.onClose = (): void => {
        closeCount += 1;
      };
      page.onFilterSelect = (item: CompanionFilterState): void => {
        selectedState = item;
      };
      page.setInitiallyProvidedValue({
        showFilterPage: true,
        companionFilterState: 'COMPLETED',
        safeTopInset: 6,
        safeBottomInset: 9
      });

      // Act
      page.onClose();
      page.onFilterSelect('ACTIVE');

      // Assert
      expect(closeCount).assertEqual(1);
      expect(selectedState).assertEqual('ACTIVE');
      expect(getCompanionFilterBorderWidth('COMPLETED', 'COMPLETED')).assertEqual(1);
      expect(getCompanionFilterBorderType('COMPLETED')).assertEqual('completed');
      expect(page.getThemePalette().companionBg).assertEqual(ThemeCenter.getPalette('dark').companionBg);
    });

    it('boundary: filter_page_hidden_state_should_keep_options_lazy_and_selection_semantics_stable', 0, () => {
      // Arrange
      const page = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as CompanionFilterPagePrivateTest;
      page.setInitiallyProvidedValue({
        showFilterPage: false,
        companionFilterState: 'SKIPPED',
        safeTopInset: 1,
        safeBottomInset: 2
      });

      // Act
      const options = page.getFilterOptions();

      // Assert
      expect(shouldShowCompanionFilterPage(page.showFilterPage)).assertFalse();
      expect(options.length).assertEqual(5);
      expect(getCompanionFilterBorderWidth('SKIPPED', 'SKIPPED')).assertEqual(1);
      expect(getCompanionFilterBorderWidth('ACTIVE', 'SKIPPED')).assertEqual(0);
    });

    it('combined: filter_page_initial_render_should_cover_all_unselected_pending_completed_and_skipped_visual_branches', 0, () => {
      // Arrange
      const page = new CompanionFilterPage(undefined, {} as LocalStorage) as Object as CompanionFilterPagePrivateTest;
      page.effectiveTheme = 'dark';
      page.getFilterOptions = (): CompanionFilterState[] => ['PENDING', 'COMPLETED', 'SKIPPED'];
      page.getFilterLabel = (state: CompanionFilterState): string => `branch_${state}`;
      page.setInitiallyProvidedValue({
        showFilterPage: true,
        companionFilterState: 'ACTIVE',
        safeTopInset: 3,
        safeBottomInset: 4
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
      expect(isCompanionFilterSelected('PENDING', page.companionFilterState)).assertFalse();
      expect(getCompanionFilterBorderType('PENDING')).assertEqual('pending');
      expect(getCompanionFilterBorderType('COMPLETED')).assertEqual('completed');
      expect(getCompanionFilterBorderType('SKIPPED')).assertEqual('skipped');
    });
  });
}
