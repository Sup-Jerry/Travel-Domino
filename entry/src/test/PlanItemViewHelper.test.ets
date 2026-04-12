import { describe, it, expect } from '@ohos/hypium';
import {
  canPlanItemShowConflictFixButton,
  resolvePlanItemTimeText,
  shouldPlanItemShowCrossDayLabel
} from '../main/ets/pages/components/views/PlanItemView';

export default function planItemViewHelperTest() {
  describe('unit_test_case_generator_autofill_PlanItemViewHelper', () => {
    it('normal: plan_item_cross_day_should_detect_date_prefix_time', 0, () => {
      // Arrange
      const timeText = '03-10 09:00';
      // Act
      const crossDay = shouldPlanItemShowCrossDayLabel(timeText);
      // Assert
      expect(crossDay).assertTrue();
    });

    it('boundary: plan_item_time_text_should_fallback_when_empty', 0, () => {
      // Arrange
      const timeText = '';
      // Act
      const display = resolvePlanItemTimeText(timeText);
      // Assert
      expect(display).assertEqual('--:--');
    });

    it('invalid: plan_item_conflict_fix_button_should_hide_when_not_conflict', 0, () => {
      // Arrange
      const isConflict = false;
      const suggestedShiftMinutes = 20;
      // Act
      const visible = canPlanItemShowConflictFixButton(isConflict, suggestedShiftMinutes);
      // Assert
      expect(visible).assertFalse();
    });

    it('conflict: plan_item_conflict_fix_button_should_show_with_positive_shift', 0, () => {
      // Arrange
      const isConflict = true;
      const suggestedShiftMinutes = 15;
      // Act
      const visible = canPlanItemShowConflictFixButton(isConflict, suggestedShiftMinutes);
      // Assert
      expect(visible).assertTrue();
    });

    it('regression: td-20260412-plan-item-cross-day-plain-time-should-stay-false', 0, () => {
      // Arrange
      const timeText = '09:00';
      // Act
      const crossDay = shouldPlanItemShowCrossDayLabel(timeText);
      // Assert
      expect(crossDay).assertFalse();
    });

    it('combined: plan_item_conflict_fix_button_should_require_conflict_and_positive_shift', 0, () => {
      // Arrange
      const isConflict = true;
      const suggestedShiftMinutes = 0;
      // Act
      const visible = canPlanItemShowConflictFixButton(isConflict, suggestedShiftMinutes);
      const fallbackTime = resolvePlanItemTimeText('');
      // Assert
      expect(visible).assertFalse();
      expect(fallbackTime).assertEqual('--:--');
    });
  });
}
