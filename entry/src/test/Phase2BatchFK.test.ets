import { describe, expect, it } from '@ohos/hypium';
import {
  buildPlanListShareEventItems,
  resolvePlanListShareCategory,
  resolvePlanListShareEndTime,
  resolvePlanListShareIcon,
  resolvePlanListShareStartTime,
  sortPlanListShareEvents
} from '../main/ets/pages/PlanListPage';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';

function buildShareEventFK(overrides?: Partial<TravelPlanItem>): TravelPlanItem {
  const item: TravelPlanItem = {
    name: 'museum',
    status: 1,
    duration: 90,
    preTravelMinutes: 0,
    sortOrder: 100,
    dayOffset: 0,
    fixedStartTime: '09:00',
    address: 'West Lake',
    priority: 0,
    lockStatus: 0,
    type: 'FLOW'
  };
  if (overrides) {
    item.name = overrides.name ?? item.name;
    item.status = overrides.status ?? item.status;
    item.duration = overrides.duration ?? item.duration;
    item.preTravelMinutes = overrides.preTravelMinutes ?? item.preTravelMinutes;
    item.sortOrder = overrides.sortOrder ?? item.sortOrder;
    item.dayOffset = overrides.dayOffset ?? item.dayOffset;
    item.fixedStartTime = overrides.fixedStartTime ?? item.fixedStartTime;
    item.computedStartTime = overrides.computedStartTime ?? item.computedStartTime;
    item.address = overrides.address ?? item.address;
    item.priority = overrides.priority ?? item.priority;
    item.lockStatus = overrides.lockStatus ?? item.lockStatus;
    item.type = overrides.type ?? item.type;
  }
  return item;
}

export default function phase2BatchFKTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchFK_plan_list_share_helpers', () => {
    it('normal: share_time_helpers_should_resolve_start_and_end_from_valid_time_fields', 0, () => {
      const fixed = buildShareEventFK({ fixedStartTime: '09:30' });
      const computed = buildShareEventFK({ fixedStartTime: '', computedStartTime: '2026-04-23 10:15' });

      expect(resolvePlanListShareStartTime(fixed)).assertEqual('09:30');
      expect(resolvePlanListShareStartTime(computed)).assertEqual('10:15');
      expect(resolvePlanListShareEndTime(fixed, 90)).assertEqual('11:00');
      expect(resolvePlanListShareEndTime(computed, 45)).assertEqual('11:00');
    });

    it('boundary: share_time_helpers_should_fallback_when_time_or_duration_is_invalid', 0, () => {
      const invalid = buildShareEventFK({ fixedStartTime: '', computedStartTime: '' });
      const badFormat = buildShareEventFK({ fixedStartTime: 'bad' });

      expect(resolvePlanListShareStartTime(invalid)).assertEqual('--:--');
      expect(resolvePlanListShareStartTime(badFormat)).assertEqual('--:--');
      expect(resolvePlanListShareEndTime(invalid, 30)).assertEqual('--:--');
      expect(resolvePlanListShareEndTime(badFormat, 30)).assertEqual('--:--');
    });

    it('normal: share_icon_and_category_helpers_should_cover_priority_anchor_and_flow_branches', 0, () => {
      const priorityIcon = resolvePlanListShareIcon(buildShareEventFK({ priority: 1 }));
      const lockedIcon = resolvePlanListShareIcon(buildShareEventFK({ priority: 0, lockStatus: 1 }));
      const anchorIcon = resolvePlanListShareIcon(buildShareEventFK({ priority: 0, lockStatus: 0, type: 'ANCHOR' }));
      const flowIcon = resolvePlanListShareIcon(buildShareEventFK({ priority: 0, lockStatus: 0, type: 'FLOW' }));
      const lockedCategory = resolvePlanListShareCategory(buildShareEventFK({ lockStatus: 1 }));
      const anchorCategory = resolvePlanListShareCategory(buildShareEventFK({ type: 'ANCHOR' }));
      const flowCategory = resolvePlanListShareCategory(buildShareEventFK({ lockStatus: 0, type: 'FLOW' }));

      expect(priorityIcon.length > 0).assertTrue();
      expect(lockedIcon.length > 0).assertTrue();
      expect(anchorIcon.length > 0).assertTrue();
      expect(flowIcon.length > 0).assertTrue();
      expect(lockedIcon === anchorIcon).assertTrue();
      expect(priorityIcon === flowIcon).assertFalse();
      expect(lockedIcon === flowIcon).assertFalse();
      expect(lockedCategory === anchorCategory).assertTrue();
      expect(flowCategory.length > 0).assertTrue();
      expect(lockedCategory === flowCategory).assertFalse();
    });

    it('combined: share_sort_and_build_helpers_should_normalize_name_location_duration_and_order', 0, () => {
      const lateDay = buildShareEventFK({
        name: '  hotel  ',
        dayOffset: 2,
        sortOrder: 50,
        duration: 0,
        address: '  ',
        fixedStartTime: '18:00'
      });
      const early = buildShareEventFK({
        name: '  ',
        dayOffset: 0,
        sortOrder: 20,
        duration: 125,
        address: '',
        fixedStartTime: '08:00',
        type: 'ANCHOR',
        lockStatus: 1
      });
      const middle = buildShareEventFK({
        name: 'park',
        dayOffset: 0,
        sortOrder: 10,
        duration: 30,
        address: 'Green Park',
        fixedStartTime: '07:00',
        priority: 1
      });

      const sorted = sortPlanListShareEvents([lateDay, early, middle]);
      const built = buildPlanListShareEventItems([lateDay, early, middle]);
      const priorityIcon = resolvePlanListShareIcon(middle);
      const anchorCategory = resolvePlanListShareCategory(early);

      expect(sorted[0].sortOrder).assertEqual(10);
      expect(sorted[1].sortOrder).assertEqual(20);
      expect(sorted[2].dayOffset).assertEqual(2);
      expect(built.length).assertEqual(3);
      expect(built[0].name).assertEqual('park');
      expect(built[0].icon).assertEqual(priorityIcon);
      expect(built[1].name.length > 0).assertTrue();
      expect(built[1].location.length > 0).assertTrue();
      expect(built[1].category).assertEqual(anchorCategory);
      expect(built[1].duration).assertEqual(2.1);
      expect(built[2].name).assertEqual('hotel');
      expect(built[2].duration).assertEqual(0.5);
      expect(built[2].dayOffset).assertEqual(2);
    });
  });
}
