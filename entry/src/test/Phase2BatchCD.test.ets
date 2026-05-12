import { describe, expect, it } from '@ohos/hypium';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import {
  buildPlanListShareEventItems,
  canPlanListRepromptPermission,
  createPlanListPageForTest,
  resolvePlanListShareCategory,
  resolvePlanListShareEndTime,
  resolvePlanListShareIcon,
  resolvePlanListShareStartTime,
  sortPlanListShareEvents
} from '../main/ets/pages/PlanListPage';

interface PlanListPagePrivateCD {
  effectiveTheme: string;
  canRepromptPermission(now: number, lastPromptAt: number, hasPromptedBefore: boolean): boolean;
  convertToShareEvents(events: TravelPlanItem[]): Object[];
  sortEventsForShare(events: TravelPlanItem[]): TravelPlanItem[];
  getThemePalette(): Object;
}

interface ShareItemCD {
  name: string;
  dayOffset: number;
  startTime: string;
  endTime: string;
  duration: number;
  icon: string;
  location: string;
  category: string;
}

function buildPlanListEventCD(
  name: string,
  dayOffset: number,
  sortOrder: number,
  fixedStartTime: string,
  duration: number
): TravelPlanItem {
  const item = {} as TravelPlanItem;
  item.name = name;
  item.address = `${name}_addr`;
  item.duration = duration;
  item.dayOffset = dayOffset;
  item.sortOrder = sortOrder;
  item.fixedStartTime = fixedStartTime;
  item.computedStartTime = '';
  item.priority = 0;
  item.lockStatus = 0;
  item.type = 'NORMAL';
  return item;
}

function asShareItemCD(item: Object): ShareItemCD {
  return item as ShareItemCD;
}

export default function phase2BatchCDTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchCD_plan_list_extra', () => {
    it('normal: plan_list_share_events_should_use_computed_time_when_fixed_time_missing', 0, () => {
      // Arrange
      const event = buildPlanListEventCD('computed', 0, 1, '', 45);
      event.computedStartTime = '13:20';

      // Act
      const start = resolvePlanListShareStartTime(event);
      const end = resolvePlanListShareEndTime(event, 45);

      // Assert
      expect(start).assertEqual('13:20');
      expect(end).assertEqual('14:05');
    });

    it('boundary: plan_list_reprompt_should_allow_first_prompt_even_when_time_is_zero', 0, () => {
      // Arrange
      const now = 0;
      const lastPromptAt = 0;
      const hasPromptedBefore = false;

      // Act
      const allowed = canPlanListRepromptPermission(now, lastPromptAt, hasPromptedBefore, 600000);

      // Assert
      expect(allowed).assertTrue();
    });

    it('invalid: plan_list_share_events_should_fallback_for_non_numeric_duration_and_day', 0, () => {
      // Arrange
      const event = buildPlanListEventCD('bad', 0, 0, '08:00', 30);
      event.duration = 'bad' as Object as number;
      event.dayOffset = 'bad' as Object as number;

      // Act
      const items = buildPlanListShareEventItems([event]);

      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].duration).assertEqual(0.5);
      expect(items[0].dayOffset).assertEqual(0);
      expect(items[0].endTime).assertEqual('08:00');
    });

    it('conflict: plan_list_share_category_should_treat_lock_status_as_fixed_even_when_type_normal', 0, () => {
      // Arrange
      const event = buildPlanListEventCD('locked', 0, 0, '09:00', 60);
      event.lockStatus = 1;
      event.type = 'NORMAL';

      // Act
      const category = resolvePlanListShareCategory(event);
      const icon = resolvePlanListShareIcon(event);

      // Assert
      expect(category).assertEqual('固定行程');
      expect(icon.length > 0).assertTrue();
    });

    it('regression: td-20260422-plan_list_share_sort_should_keep_original_array_unchanged', 0, () => {
      // Arrange
      const first = buildPlanListEventCD('first', 2, 0, '10:00', 60);
      const second = buildPlanListEventCD('second', 0, 0, '08:00', 60);
      const source = [first, second];

      // Act
      const sorted = sortPlanListShareEvents(source);

      // Assert
      expect(sorted[0].name).assertEqual('second');
      expect(source[0].name).assertEqual('first');
      expect(source[1].name).assertEqual('second');
    });

    it('combined: plan_list_share_items_should_resolve_priority_anchor_and_sort_together', 0, () => {
      // Arrange
      const anchor = buildPlanListEventCD('anchor', 1, 5, '12:00', 30);
      anchor.type = 'ANCHOR';
      const priority = buildPlanListEventCD('priority', 0, 9, '09:00', 120);
      priority.priority = 1;
      const normal = buildPlanListEventCD('normal', 0, 1, '08:30', 30);

      // Act
      const items = buildPlanListShareEventItems([anchor, priority, normal]);

      // Assert
      expect(items[0].name).assertEqual('normal');
      expect(items[1].name).assertEqual('priority');
      expect(items[1].duration).assertEqual(2);
      expect(items[2].category).assertEqual('固定行程');
    });

    it('normal: plan_list_page_test_instance_should_delegate_sort_and_convert_helpers', 0, () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateCD;
      const first = buildPlanListEventCD('first', 1, 0, '10:00', 60);
      const second = buildPlanListEventCD('second', 0, 0, '08:00', 60);

      // Act
      const sorted = page.sortEventsForShare([first, second]);
      const converted = page.convertToShareEvents([first, second]);

      // Assert
      expect(sorted[0].name).assertEqual('second');
      expect(converted.length).assertEqual(2);
      expect(asShareItemCD(converted[0]).name).assertEqual('second');
    });

    it('boundary: plan_list_page_test_instance_should_apply_default_reprompt_cooldown', 0, () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateCD;
      const cooldownMs = 10 * 60 * 1000;

      // Act
      const beforeCooldown = page.canRepromptPermission(cooldownMs - 1, 0, true);
      const atCooldown = page.canRepromptPermission(cooldownMs, 0, true);

      // Assert
      expect(beforeCooldown).assertFalse();
      expect(atCooldown).assertTrue();
    });

    it('combined: plan_list_page_test_instance_should_return_palette_for_light_and_dark_modes', 0, () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateCD;

      // Act
      page.effectiveTheme = 'light';
      const lightPalette = page.getThemePalette();
      page.effectiveTheme = 'dark';
      const darkPalette = page.getThemePalette();

      // Assert
      expect(lightPalette !== undefined).assertTrue();
      expect(darkPalette !== undefined).assertTrue();
    });
  });
}
