import { describe, it, expect } from '@ohos/hypium';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import {
  buildPlanListShareEventItems,
  canPlanListRepromptPermission,
  resolvePlanListShareCategory,
  resolvePlanListShareEndTime,
  resolvePlanListShareIcon,
  resolvePlanListShareStartTime,
  sortPlanListShareEvents
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

  describe('unit_test_case_generator_autofill_PlanListPageHelperBranches', () => {
    it('normal: plan_list_share_events_should_sort_by_day_offset_then_sort_order', 0, () => {
      // Arrange
      const first = buildShareEvent();
      first.name = 'first';
      first.dayOffset = 2;
      first.sortOrder = 1;
      const second = buildShareEvent();
      second.name = 'second';
      second.dayOffset = 1;
      second.sortOrder = 5;
      const third = buildShareEvent();
      third.name = 'third';
      third.dayOffset = 1;
      third.sortOrder = 1;
      // Act
      const sorted = sortPlanListShareEvents([first, second, third]);
      // Assert
      expect(sorted[0].name).assertEqual('third');
      expect(sorted[1].name).assertEqual('second');
      expect(sorted[2].name).assertEqual('first');
    });

    it('boundary: plan_list_share_item_should_floor_duration_to_single_decimal_hour', 0, () => {
      // Arrange
      const event = buildShareEvent();
      event.duration = 66;
      // Act
      const items = buildPlanListShareEventItems([event]);
      // Assert
      expect(items[0].duration).assertEqual(1.1);
    });

    it('invalid: plan_list_share_item_should_fallback_name_and_location_when_blank', 0, () => {
      // Arrange
      const event = buildShareEvent();
      event.name = '  ';
      event.address = ' ';
      event.duration = 0;
      // Act
      const items = buildPlanListShareEventItems([event]);
      // Assert
      expect(items[0].name).assertEqual('未命名地点');
      expect(items[0].location).assertEqual('待补充地点');
      expect(items[0].duration).assertEqual(0.5);
    });

    it('conflict: plan_list_share_icon_should_still_prefer_star_when_anchor_and_priority_conflict', 0, () => {
      // Arrange
      const event = buildShareEvent();
      event.priority = 1;
      event.lockStatus = 1;
      event.type = 'ANCHOR';
      // Act
      const items = buildPlanListShareEventItems([event]);
      // Assert
      expect(items[0].icon).assertEqual('⭐');
    });

    it('regression: td-20260418-plan_list_share_item_should_clamp_negative_day_offset_to_zero', 0, () => {
      // Arrange
      const event = buildShareEvent();
      event.dayOffset = -9;
      // Act
      const items = buildPlanListShareEventItems([event]);
      // Assert
      expect(items[0].dayOffset).assertEqual(0);
    });

    it('combined: plan_list_share_items_should_apply_sort_and_time_resolution_together', 0, () => {
      // Arrange
      const early = buildShareEvent();
      early.name = 'early';
      early.dayOffset = 0;
      early.sortOrder = 1;
      early.fixedStartTime = '08:00';
      early.duration = 30;
      const late = buildShareEvent();
      late.name = 'late';
      late.dayOffset = 0;
      late.sortOrder = 2;
      late.fixedStartTime = '09:30';
      late.duration = 90;
      // Act
      const items = buildPlanListShareEventItems([late, early]);
      // Assert
      expect(items[0].name).assertEqual('early');
      expect(items[0].startTime).assertEqual('08:00');
      expect(items[0].endTime).assertEqual('08:30');
      expect(items[1].name).assertEqual('late');
      expect(items[1].endTime).assertEqual('11:00');
    });
  });
}
