import { describe, it, expect } from '@ohos/hypium';
import {
  canPlanItemShowConflictFixButton,
  resolvePlanItemTimeText,
  shouldPlanItemShowCrossDayLabel
} from '../main/ets/pages/components/views/PlanItemView';

export default function planItemViewTimeAndConflictEdgeTest() {
  describe('unit_test_case_generator_autofill_PlanItemViewTimeAndConflictEdge', () => {
    it('normal: plan_item_should_detect_cross_day_when_date_prefix_exists', 0, () => {
      // Arrange
      const timeText = '04-12 09:30';

      // Act
      const crossDay = shouldPlanItemShowCrossDayLabel(timeText);

      // Assert
      expect(crossDay).assertTrue();
    });

    it('boundary: plan_item_should_not_detect_cross_day_for_plain_hhmm', 0, () => {
      // Arrange
      const timeText = '09:30';

      // Act
      const crossDay = shouldPlanItemShowCrossDayLabel(timeText);

      // Assert
      expect(crossDay).assertFalse();
    });

    it('invalid: plan_item_time_text_should_fallback_for_empty_input', 0, () => {
      // Arrange
      const timeText = '';

      // Act
      const display = resolvePlanItemTimeText(timeText);

      // Assert
      expect(display).assertEqual('--:--');
    });

    it('conflict: plan_item_fix_button_should_require_conflict_and_positive_shift', 0, () => {
      // Arrange
      // Act
      const hideWhenNoConflict = canPlanItemShowConflictFixButton(false, 20);
      const hideWhenZeroShift = canPlanItemShowConflictFixButton(true, 0);
      const showWhenBothMet = canPlanItemShowConflictFixButton(true, 20);

      // Assert
      expect(hideWhenNoConflict).assertFalse();
      expect(hideWhenZeroShift).assertFalse();
      expect(showWhenBothMet).assertTrue();
    });

    it('regression: td-20260412-plan-item-time-placeholder-should-stay-stable', 0, () => {
      // Arrange
      const placeholder = '--:--';

      // Act
      const display = resolvePlanItemTimeText(placeholder);

      // Assert
      expect(display).assertEqual('--:--');
    });

    it('combined: plan_item_cross_day_and_fix_button_should_follow_independent_rules', 0, () => {
      // Arrange
      const timeText = '05-01 10:00';

      // Act
      const crossDay = shouldPlanItemShowCrossDayLabel(timeText);
      const display = resolvePlanItemTimeText(timeText);
      const canFix = canPlanItemShowConflictFixButton(true, 5);

      // Assert
      expect(crossDay).assertTrue();
      expect(display).assertEqual('05-01 10:00');
      expect(canFix).assertTrue();
    });
  });
}

