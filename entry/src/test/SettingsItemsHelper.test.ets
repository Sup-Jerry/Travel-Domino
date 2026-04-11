import { describe, it, expect } from '@ohos/hypium';
import {
  getSettingsSubPageBackLabel,
  resolveSettingSelectValueText,
  shouldShowSettingSwitchLoading
} from '../main/ets/pages/components/views/SettingsItems';

export default function settingsItemsHelperTest() {
  describe('unit_test_case_generator_autofill_SettingsItemsHelper', () => {
    it('normal: settings_switch_should_show_loading_when_flag_true', 0, () => {
      // Arrange
      const loading = true;
      // Act
      const showLoading = shouldShowSettingSwitchLoading(loading);
      // Assert
      expect(showLoading).assertTrue();
    });

    it('boundary: settings_select_value_should_fallback_to_empty_when_blank', 0, () => {
      // Arrange
      const valueText = '';
      // Act
      const resolved = resolveSettingSelectValueText(valueText);
      // Assert
      expect(resolved).assertEqual('');
    });

    it('invalid: settings_switch_should_hide_loading_when_flag_false', 0, () => {
      // Arrange
      const loading = false;
      // Act
      const showLoading = shouldShowSettingSwitchLoading(loading);
      // Assert
      expect(showLoading).assertFalse();
    });

    it('conflict: settings_select_value_should_keep_original_non_empty_text', 0, () => {
      // Arrange
      const valueText = '自动';
      // Act
      const resolved = resolveSettingSelectValueText(valueText);
      // Assert
      expect(resolved).assertEqual('自动');
    });

    it('regression: td-20260412-settings-back-label-should-stay-return', 0, () => {
      // Arrange
      // Act
      const label = getSettingsSubPageBackLabel();
      // Assert
      expect(label).assertEqual('\u8FD4\u56DE');
    });

    it('combined: settings_loading_and_value_resolution_should_be_independent', 0, () => {
      // Arrange
      const loading = true;
      const valueText = '手动';
      // Act
      const showLoading = shouldShowSettingSwitchLoading(loading);
      const resolved = resolveSettingSelectValueText(valueText);
      // Assert
      expect(showLoading).assertTrue();
      expect(resolved).assertEqual('手动');
    });
  });
}
