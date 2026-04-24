import { describe, it, expect } from '@ohos/hypium';
import {
  getSettingsSubPageBackLabel,
  resolveSettingSelectRenderState,
  resolveSettingSelectValueText,
  resolveSettingSwitchRenderState,
  resolveSettingsSubPageHeaderState,
  shouldShowSettingSwitchLoading
} from '../main/ets/pages/components/views/SettingsItems';

export default function phase2BatchGDTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchGD_settings_items_helpers', () => {
    it('boundary: settings_switch_render_state_should_flip_loading_and_toggle_flags', 0, () => {
      const loadingState = resolveSettingSwitchRenderState(true);
      const idleState = resolveSettingSwitchRenderState(false);

      expect(shouldShowSettingSwitchLoading(true)).assertTrue();
      expect(loadingState.showLoading).assertTrue();
      expect(loadingState.showToggle).assertFalse();
      expect(loadingState.loadingText.length > 0).assertTrue();
      expect(idleState.showLoading).assertFalse();
      expect(idleState.showToggle).assertTrue();
      expect(idleState.loadingText).assertEqual('');
    });

    it('boundary: settings_select_render_state_should_keep_blank_value_and_fixed_trailing_arrow', 0, () => {
      const blank = resolveSettingSelectRenderState('');
      const valued = resolveSettingSelectRenderState('manual');

      expect(resolveSettingSelectValueText('')).assertEqual('');
      expect(blank.valueText).assertEqual('');
      expect(blank.trailingText).assertEqual('>');
      expect(valued.valueText).assertEqual('manual');
      expect(valued.trailingText).assertEqual('>');
    });

    it('normal: settings_sub_page_header_state_should_echo_title_and_builtin_back_label', 0, () => {
      const state = resolveSettingsSubPageHeaderState('Security');

      expect(state.title).assertEqual('Security');
      expect(state.backLabel).assertEqual(getSettingsSubPageBackLabel());
      expect(getSettingsSubPageBackLabel()).assertEqual('\u8FD4\u56DE');
    });
  });
}
