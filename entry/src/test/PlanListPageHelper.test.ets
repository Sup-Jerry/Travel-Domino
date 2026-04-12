import { describe, it, expect } from '@ohos/hypium';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import {
  canPlanListRepromptPermission,
  resolvePlanListShareCategory,
  resolvePlanListShareEndTime,
  resolvePlanListShareIcon,
  resolvePlanListShareStartTime
} from '../main/ets/pages/PlanListPage';

function buildShareEvent(): TravelPlanItem {
  const item = {} as TravelPlanItem;
  item.fixedStartTime = '09:30';
  item.computedStartTime = '10:00';
  item.priority = 0;
  item.lockStatus = 0;
  item.type = 'NORMAL';
  return item;
}

export default function planListPageHelperTest() {
  describe('unit_test_case_generator_autofill_PlanListPageHelper', () => {
    it('normal: plan_list_share_start_should_extract_valid_time', 0, () => {
      // Arrange
      const event = buildShareEvent();
      // Act
      const start = resolvePlanListShareStartTime(event);
      // Assert
      expect(start).assertEqual('09:30');
    });

    it('boundary: plan_list_reprompt_should_allow_when_cooldown_exactly_met', 0, () => {
      // Arrange
      const now = 2000;
      const lastPromptAt = 1000;
      const cooldownMs = 1000;
      // Act
      const allowed = canPlanListRepromptPermission(now, lastPromptAt, true, cooldownMs);
      // Assert
      expect(allowed).assertTrue();
    });

    it('invalid: plan_list_share_start_should_fallback_when_time_invalid', 0, () => {
      // Arrange
      const event = buildShareEvent();
      event.fixedStartTime = 'abc';
      event.computedStartTime = '';
      // Act
      const start = resolvePlanListShareStartTime(event);
      // Assert
      expect(start).assertEqual('--:--');
    });

    it('conflict: plan_list_share_icon_should_prioritize_star_over_anchor', 0, () => {
      // Arrange
      const event = buildShareEvent();
      event.priority = 1;
      event.lockStatus = 1;
      event.type = 'ANCHOR';
      // Act
      const icon = resolvePlanListShareIcon(event);
      // Assert
      expect(icon).assertEqual('⭐');
    });

    it('regression: td-20260412-plan_list_share_category_anchor_should_keep_fixed_label', 0, () => {
      // Arrange
      const event = buildShareEvent();
      event.type = 'ANCHOR';
      // Act
      const category = resolvePlanListShareCategory(event);
      // Assert
      expect(category).assertEqual('固定行程');
    });

    it('combined: plan_list_share_end_should_fallback_when_start_invalid_even_with_duration', 0, () => {
      // Arrange
      const event = buildShareEvent();
      event.fixedStartTime = '';
      event.computedStartTime = 'invalid';
      // Act
      const end = resolvePlanListShareEndTime(event, 90);
      // Assert
      expect(end).assertEqual('--:--');
    });
  });
}
