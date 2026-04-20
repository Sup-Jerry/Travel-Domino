import { describe, it, expect } from '@ohos/hypium';
import { ThemeCenter } from '../main/ets/common/utils/ThemeCenter';
import {
  CompanionControlTopBar,
  getCompanionControlTopBarPaddingTop
} from '../main/ets/pages/components/views/companion/CompanionControlTopBar';

interface CompanionControlTopBarThemePaletteTest {
  textPrimary: Object;
  textSecondary: Object;
}

interface CompanionControlTopBarParamsTest {
  safeTopInset?: number;
  runtimeDescription?: string;
}

interface CompanionControlTopBarPrivateTest {
  safeTopInset: number;
  runtimeDescription: string;
  effectiveTheme: string;
  onExit: () => void;
  setInitiallyProvidedValue(params: CompanionControlTopBarParamsTest): void;
  updateStateVars(params: CompanionControlTopBarParamsTest): void;
  getThemePalette(): CompanionControlTopBarThemePaletteTest;
  initialRender(): void;
}

export default function companionControlTopBarHelperTest() {
  describe('unit_test_case_generator_autofill_CompanionControlTopBarHelper', () => {
    it('normal: topbar_padding_should_add_base_offset', 0, () => {
      // Arrange
      const safeTopInset = 20;

      // Act
      const paddingTop = getCompanionControlTopBarPaddingTop(safeTopInset);

      // Assert
      expect(paddingTop).assertEqual(30);
    });

    it('boundary: topbar_padding_should_handle_zero_inset', 0, () => {
      // Arrange
      const safeTopInset = 0;

      // Act
      const paddingTop = getCompanionControlTopBarPaddingTop(safeTopInset);

      // Assert
      expect(paddingTop).assertEqual(10);
    });

    it('invalid: topbar_padding_should_keep_linear_rule_for_negative_input', 0, () => {
      // Arrange
      const safeTopInset = -3;

      // Act
      const paddingTop = getCompanionControlTopBarPaddingTop(safeTopInset);

      // Assert
      expect(paddingTop).assertEqual(7);
    });

    it('conflict: topbar_padding_should_remain_monotonic_when_input_increases', 0, () => {
      // Arrange
      const low = 4;
      const high = 9;

      // Act
      const lowPadding = getCompanionControlTopBarPaddingTop(low);
      const highPadding = getCompanionControlTopBarPaddingTop(high);

      // Assert
      expect(highPadding > lowPadding).assertTrue();
    });

    it('regression: topbar_padding_should_preserve_delta_equal_to_input_delta', 0, () => {
      // Arrange
      const first = 6;
      const second = 14;

      // Act
      const delta = getCompanionControlTopBarPaddingTop(second) - getCompanionControlTopBarPaddingTop(first);

      // Assert
      expect(delta).assertEqual(second - first);
    });

    it('combined: topbar_padding_matrix_should_match_multiple_inputs', 0, () => {
      // Arrange
      const inputs: number[] = [0, 8, 16];

      // Act
      const outputs = inputs.map((v) => getCompanionControlTopBarPaddingTop(v));

      // Assert
      expect(outputs[0]).assertEqual(10);
      expect(outputs[1]).assertEqual(18);
      expect(outputs[2]).assertEqual(26);
    });

    it('combined: topbar_instance_should_sync_props_and_theme_palette_without_runtime_build', 0, () => {
      // Arrange
      const page = new CompanionControlTopBar(undefined, {} as LocalStorage) as Object as CompanionControlTopBarPrivateTest;

      // Act
      page.onExit();
      page.setInitiallyProvidedValue({
        safeTopInset: 8,
        runtimeDescription: 'ready'
      });
      page.updateStateVars({
        safeTopInset: 18,
        runtimeDescription: 'paused'
      });
      page.effectiveTheme = 'dark';
      const palette = page.getThemePalette();

      // Assert
      expect(page.safeTopInset).assertEqual(18);
      expect(page.runtimeDescription).assertEqual('paused');
      expect(palette.textPrimary).assertEqual(ThemeCenter.getPalette('dark').textPrimary);
      expect(palette.textSecondary).assertEqual(ThemeCenter.getPalette('dark').textSecondary);
    });

    it('normal: topbar_initial_render_should_support_runtime_description_branch', 0, () => {
      // Arrange
      const page = new CompanionControlTopBar(undefined, {} as LocalStorage) as Object as CompanionControlTopBarPrivateTest;
      page.setInitiallyProvidedValue({
        safeTopInset: 12,
        runtimeDescription: '伴游运行中'
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
  });
}
