import { describe, it, expect } from '@ohos/hypium';
import {
  canPlanItemShowConflictFixButton,
  resolvePlanItemDisplayState,
  resolvePlanItemTimeText,
  shouldPlanItemShowCrossDayLabel
} from '../main/ets/pages/components/views/PlanItemView';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';

function buildPlanItemViewTestItem(): TravelPlanItem {
  return {
    name: '博物馆',
    status: 1,
    duration: 60,
    preTravelMinutes: 10,
    sortOrder: 100,
    type: 'FLOW',
    computedStartTime: '09:00',
    computedEndTime: '10:00'
  };
}

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

    it('normal: plan_item_display_state_should_use_plain_start_and_end_time', 0, () => {
      // Arrange
      const item = buildPlanItemViewTestItem();

      // Act
      const state = resolvePlanItemDisplayState(item);

      // Assert
      expect(state.showCrossDayLabel).assertFalse();
      expect(state.startText).assertEqual('09:00');
      expect(state.endText).assertEqual('10:00');
      expect(state.showConflict).assertFalse();
      expect(state.showConflictFixButton).assertFalse();
    });

    it('boundary: plan_item_display_state_should_fallback_empty_times', 0, () => {
      // Arrange
      const item = buildPlanItemViewTestItem();
      item.computedStartTime = '';
      item.computedEndTime = '';

      // Act
      const state = resolvePlanItemDisplayState(item);

      // Assert
      expect(state.startText).assertEqual('--:--');
      expect(state.endText).assertEqual('--:--');
      expect(state.fixButtonMinutes).assertEqual(0);
    });

    it('conflict: plan_item_display_state_should_show_default_conflict_text_and_fix_button', 0, () => {
      // Arrange
      const item = buildPlanItemViewTestItem();
      item.isConflict = true;
      item.suggestedShiftMinutes = 25;

      // Act
      const state = resolvePlanItemDisplayState(item);

      // Assert
      expect(state.showConflict).assertTrue();
      expect(state.conflictText).assertEqual('时间冲突');
      expect(state.showConflictFixButton).assertTrue();
      expect(state.fixButtonMinutes).assertEqual(25);
    });

    it('regression: td-20260422-plan-item-display_state_should_keep_cross_day_start_label', 0, () => {
      // Arrange
      const item = buildPlanItemViewTestItem();
      item.computedStartTime = '04-22 23:30';
      item.computedEndTime = '00:10';
      item.conflictMsg = '刚性地点冲突';
      item.isConflict = true;
      item.suggestedShiftMinutes = 0;

      // Act
      const state = resolvePlanItemDisplayState(item);

      // Assert
      expect(state.showCrossDayLabel).assertTrue();
      expect(state.startText).assertEqual('04-22 23:30');
      expect(state.endText).assertEqual('00:10');
      expect(state.conflictText).assertEqual('刚性地点冲突');
      expect(state.showConflictFixButton).assertFalse();
    });
  });
}
