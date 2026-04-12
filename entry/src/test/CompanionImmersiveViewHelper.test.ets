import { describe, it, expect } from '@ohos/hypium';
import {
  getImmersiveNextStationText,
  getImmersivePrimaryActionEnabled,
  getImmersivePrimaryActionLabel,
  shouldShowImmersivePrimaryAction
} from '../main/ets/pages/components/views/companion/CompanionImmersiveView';

export default function companionImmersiveViewHelperTest() {
  describe('unit_test_case_generator_autofill_CompanionImmersiveViewHelper', () => {
    it('normal: primary_action_should_show_when_pending', 0, () => {
      // Arrange
      const isPending = true;

      // Act
      const visible = shouldShowImmersivePrimaryAction(isPending, false, 'READY');

      // Assert
      expect(visible).assertTrue();
    });

    it('boundary: primary_action_should_show_when_runtime_paused_even_without_active_flags', 0, () => {
      // Arrange
      const runtimeState = 'PAUSED';

      // Act
      const visible = shouldShowImmersivePrimaryAction(false, false, runtimeState);

      // Assert
      expect(visible).assertTrue();
    });

    it('invalid: primary_action_enabled_should_be_false_when_guards_are_both_false', 0, () => {
      // Arrange
      const isPending = false;

      // Act
      const enabled = getImmersivePrimaryActionEnabled(isPending, false, false);

      // Assert
      expect(enabled).assertFalse();
    });

    it('conflict: pending_branch_should_prioritize_start_guard_over_end_guard', 0, () => {
      // Arrange
      const isPending = true;

      // Act
      const enabled = getImmersivePrimaryActionEnabled(isPending, true, false);
      const label = getImmersivePrimaryActionLabel(isPending);

      // Assert
      expect(enabled).assertTrue();
      expect(label).assertEqual('开始');
    });

    it('regression: next_station_text_should_keep_name_and_forecast_placeholder', 0, () => {
      // Arrange
      const name = '博物馆';
      const forecast = '--:--';

      // Act
      const text = getImmersiveNextStationText(name, forecast);

      // Assert
      expect(text.includes(name)).assertTrue();
      expect(text.includes(forecast)).assertTrue();
    });

    it('combined: action_visibility_and_label_should_match_pending_active_idle_matrix', 0, () => {
      // Arrange
      const idleVisible = shouldShowImmersivePrimaryAction(false, false, 'IDLE');
      const activeVisible = shouldShowImmersivePrimaryAction(false, true, 'ACTIVE');
      const endLabel = getImmersivePrimaryActionLabel(false);

      // Act
      const matrixPass = (!idleVisible) && activeVisible && endLabel === '结束';

      // Assert
      expect(matrixPass).assertTrue();
    });

    it('boundary: primary_action_should_hide_when_not_pending_not-active_and_not-paused', 0, () => {
      // Arrange
      const runtimeState = 'READY';

      // Act
      const visible = shouldShowImmersivePrimaryAction(false, false, runtimeState);

      // Assert
      expect(visible).assertFalse();
    });

    it('conflict: pending_enabled_should_ignore_end_guard_when_start_guard_is_false', 0, () => {
      // Arrange
      const isPending = true;

      // Act
      const enabled = getImmersivePrimaryActionEnabled(isPending, false, true);

      // Assert
      expect(enabled).assertFalse();
    });

    it('normal: end_enabled_should_follow_end_guard_when_not_pending', 0, () => {
      // Arrange
      const isPending = false;

      // Act
      const enabled = getImmersivePrimaryActionEnabled(isPending, false, true);
      const label = getImmersivePrimaryActionLabel(isPending);

      // Assert
      expect(enabled).assertTrue();
      expect(label).assertEqual('结束');
    });

    it('regression: next_station_text_should_keep_stable_prefix_and_brackets', 0, () => {
      // Arrange
      const name = '机场';
      const forecast = '09:30';

      // Act
      const text = getImmersiveNextStationText(name, forecast);

      // Assert
      expect(text).assertEqual('下一站：机场（09:30）');
    });
  });
}
