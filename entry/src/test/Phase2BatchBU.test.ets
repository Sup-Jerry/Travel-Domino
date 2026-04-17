import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import {
  EventItemTimeRangeMeta,
  resolveEventItemActualRangeMeta,
  resolveEventItemCompanionOpacity,
  resolveEventItemCompanionStateLabel,
  resolveEventItemForecastRange,
  resolveEventItemPlanRange,
  resolveEventItemStartTimeDisplay,
  resolveEventItemThemeColor
} from '../main/ets/pages/components/views/EventItemView';
import {
  resolveCompanionBackAction,
  resolveCompanionDefaultFocusId,
  resolveCompanionSearchResults,
  resolveCompanionVisibleFocusId,
  resolveCompanionVisibleFocusPosition
} from '../main/ets/pages/components/views/CompanionView';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import { resolvePlanItemDisplayState } from '../main/ets/pages/components/views/PlanItemView';
import { resolveBacklogViewState } from '../main/ets/pages/components/views/BacklogView';
import {
  resolveSettingSelectRenderState,
  resolveSettingsSubPageHeaderState,
  resolveSettingSwitchRenderState
} from '../main/ets/pages/components/views/SettingsItems';
import {
  AppNavTab,
  resolveBottomNavNavigateAction,
  resolveBottomNavPressedTab,
  resolveBottomNavTapPlan
} from '../main/ets/pages/components/views/BottomNavBar';

function buildCompanionEventBU(
  id: number,
  name: string,
  address: string,
  actualStartTime: number,
  completionStatus: number
): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.address = address;
  event.status = 1;
  event.completion_status = completionStatus;
  event.actual_start_time = actualStartTime;
  event.actual_end_time = 0;
  return event;
}

function buildPlanItemBU(overrides?: Partial<TravelPlanItem>): TravelPlanItem {
  return {
    name: 'BU Item',
    status: 1,
    duration: 90,
    preTravelMinutes: 15,
    sortOrder: 100,
    type: 'FLOW',
    ...overrides
  };
}

export default function phase2BatchBUTest() {
  describe('phase2BatchBUTest', () => {
    it('normal: event_item_logic_helpers_should_cover_time_color_and_companion_paths', 0, () => {
      // Arrange
      const actualStart = new Date(2026, 3, 17, 9, 0, 0, 0).getTime();
      const actualEnd = new Date(2026, 3, 17, 10, 30, 0, 0).getTime();

      // Act
      const themeColor = resolveEventItemThemeColor(0, 0, '茶馆', 'dark', '#123456');
      const startText = resolveEventItemStartTimeDisplay('', '08:40');
      const planRange = resolveEventItemPlanRange('', '08:40', 90);
      const forecastRange = resolveEventItemForecastRange(0, 0, planRange);
      const actualRange: EventItemTimeRangeMeta = resolveEventItemActualRangeMeta(
        actualStart,
        actualEnd,
        0,
        0,
        90,
        planRange
      );
      const opacity = resolveEventItemCompanionOpacity(true, 8, 99, EventEntity.STATE_COMPLETED, 0);
      const stateLabel = resolveEventItemCompanionStateLabel(EventEntity.STATE_PENDING, 0, 8, 8);

      // Assert
      expect(themeColor).assertEqual('#FFB85C');
      expect(startText).assertEqual('08:40');
      expect(planRange).assertEqual('08:40-10:10');
      expect(forecastRange).assertEqual('08:40-10:10');
      expect(actualRange.text).assertEqual('09:00-10:30');
      expect(actualRange.isEstimated).assertFalse();
      expect(opacity).assertEqual(0.45);
      expect(stateLabel).assertEqual('READY');
    });

    it('boundary: event_item_logic_helpers_should_fallback_to_dynamic_and_default_states', 0, () => {
      // Arrange
      const dynamicStart = new Date(2026, 3, 17, 14, 15, 0, 0).getTime();
      const dynamicEnd = new Date(2026, 3, 17, 15, 45, 0, 0).getTime();

      // Act
      const themeColor = resolveEventItemThemeColor(0, 0, '未知地点', 'light', '#2468AC');
      const planRange = resolveEventItemPlanRange('', '', 45);
      const forecastRange = resolveEventItemForecastRange(dynamicStart, dynamicEnd, planRange);
      const actualRange = resolveEventItemActualRangeMeta(0, 0, dynamicStart, dynamicEnd, 45, planRange);
      const opacity = resolveEventItemCompanionOpacity(true, 5, 7, EventEntity.STATE_SKIPPED, 0);
      const stateLabel = resolveEventItemCompanionStateLabel(EventEntity.STATE_SKIPPED, 0, 5, 7);

      // Assert
      expect(themeColor).assertEqual('#2468AC');
      expect(planRange).assertEqual('--:-----:--');
      expect(forecastRange).assertEqual('14:15-15:45');
      expect(actualRange.text).assertEqual('14:15-15:45');
      expect(actualRange.isEstimated).assertTrue();
      expect(opacity).assertEqual(0.3);
      expect(stateLabel).assertEqual('SKIPPED');
    });

    it('normal: companion_logic_helpers_should_prioritize_active_focus_and_trim_search_keyword', 0, () => {
      // Arrange
      const pending = buildCompanionEventBU(1, '故宫', '北京东城', 0, EventEntity.STATE_PENDING);
      const active = buildCompanionEventBU(2, '景山公园', '北京东城', Date.now(), EventEntity.STATE_PENDING);
      const completed = buildCompanionEventBU(3, '后海', '北京西城', 0, EventEntity.STATE_COMPLETED);
      const schedule = [pending, active, completed];
      const searchMap = new Map<number, string>();
      searchMap.set(1, '故宫|北京东城');
      searchMap.set(2, '景山公园|北京东城');
      searchMap.set(3, '后海|北京西城');
      const visibleIndexById = new Map<number, number>();
      visibleIndexById.set(2, 0);
      visibleIndexById.set(3, 1);

      // Act
      const focusId = resolveCompanionDefaultFocusId(schedule, 1, 3);
      const results = resolveCompanionSearchResults(schedule, '  东城 ', searchMap);
      const visibleFocusId = resolveCompanionVisibleFocusId([active, completed], 2);
      const focusPosition = resolveCompanionVisibleFocusPosition(3, visibleIndexById);
      const backAction = resolveCompanionBackAction(false, false, false, 'control');

      // Assert
      expect(focusId).assertEqual(2);
      expect(results.length).assertEqual(2);
      expect(results[0].id).assertEqual(1);
      expect(results[1].id).assertEqual(2);
      expect(visibleFocusId).assertEqual(2);
      expect(focusPosition).assertEqual(2);
      expect(backAction).assertEqual('control_to_immersive');
    });

    it('boundary: companion_logic_helpers_should_limit_blank_search_and_fallback_focus_to_first_visible', 0, () => {
      // Arrange
      const schedule: EventEntity[] = [];
      for (let i = 0; i < 24; i++) {
        schedule.push(buildCompanionEventBU(i + 1, `地点${i + 1}`, `地址${i + 1}`, 0, EventEntity.STATE_PENDING));
      }

      // Act
      const blankResults = resolveCompanionSearchResults(schedule, '   ');
      const focusId = resolveCompanionDefaultFocusId(schedule, -1, -1);
      const visibleFocusId = resolveCompanionVisibleFocusId([schedule[4], schedule[5]], 999);
      const focusPosition = resolveCompanionVisibleFocusPosition(999, new Map<number, number>());
      const backAction = resolveCompanionBackAction(true, false, false, 'immersive');

      // Assert
      expect(blankResults.length).assertEqual(20);
      expect(focusId).assertEqual(1);
      expect(visibleFocusId).assertEqual(5);
      expect(focusPosition).assertEqual(0);
      expect(backAction).assertEqual('close_overlay');
    });

    it('normal: plan_backlog_settings_and_bottom_nav_view_states_should_keep_multi_field_outputs_stable', 0, () => {
      // Arrange
      const item = buildPlanItemBU({
        computedStartTime: '04-17 09:00',
        computedEndTime: '',
        isConflict: true,
        conflictMsg: '',
        suggestedShiftMinutes: 25
      });
      const currentTab: AppNavTab = 'home';

      // Act
      const planState = resolvePlanItemDisplayState(item);
      const backlogState = resolveBacklogViewState(true, 0);
      const switchState = resolveSettingSwitchRenderState(true);
      const selectState = resolveSettingSelectRenderState('');
      const headerState = resolveSettingsSubPageHeaderState('高级设置');
      const tapPlan = resolveBottomNavTapPlan(currentTab, 'archive', false);
      const navigateAction = resolveBottomNavNavigateAction(currentTab, 'archive');
      const pressedTab = resolveBottomNavPressedTab('archive', true);

      // Assert
      expect(planState.showCrossDayLabel).assertTrue();
      expect(planState.startText).assertEqual('04-17 09:00');
      expect(planState.endText).assertEqual('--:--');
      expect(planState.showConflictFixButton).assertTrue();
      expect(planState.conflictText).assertEqual('时间冲突');
      expect(backlogState.expandSymbol).assertEqual('\u25BC');
      expect(backlogState.showEmptyState).assertTrue();
      expect(backlogState.showMoveAllButton).assertFalse();
      expect(switchState.showLoading).assertTrue();
      expect(switchState.showToggle).assertFalse();
      expect(switchState.loadingText).assertEqual('加载中...');
      expect(selectState.valueText).assertEqual('');
      expect(selectState.trailingText).assertEqual('>');
      expect(headerState.backLabel).assertEqual('返回');
      expect(headerState.title).assertEqual('高级设置');
      expect(tapPlan.shouldNavigate).assertTrue();
      expect(tapPlan.nextTransitionTab).assertEqual('archive');
      expect(tapPlan.nextNavLocked).assertTrue();
      expect(navigateAction.kind).assertEqual('route');
      expect(navigateAction.route).assertEqual('pages/ArchivePage');
      expect(pressedTab).assertEqual('archive');
    });

    it('boundary: plan_backlog_settings_and_bottom_nav_view_states_should_keep_fallbacks_when_noop_or_locked', 0, () => {
      // Arrange
      const item = buildPlanItemBU({
        computedStartTime: '',
        computedEndTime: '10:30',
        isConflict: false,
        suggestedShiftMinutes: 0
      });
      const currentTab: AppNavTab = 'trash';

      // Act
      const planState = resolvePlanItemDisplayState(item);
      const backlogState = resolveBacklogViewState(false, 3);
      const switchState = resolveSettingSwitchRenderState(false);
      const selectState = resolveSettingSelectRenderState('自动');
      const headerState = resolveSettingsSubPageHeaderState('');
      const sameTabPlan = resolveBottomNavTapPlan(currentTab, 'trash', false);
      const lockedPlan = resolveBottomNavTapPlan(currentTab, 'archive', true);
      const searchAction = resolveBottomNavNavigateAction(currentTab, 'search');
      const noopAction = resolveBottomNavNavigateAction(currentTab, 'trash');
      const releasedTab = resolveBottomNavPressedTab('archive', false);

      // Assert
      expect(planState.showCrossDayLabel).assertFalse();
      expect(planState.startText).assertEqual('--:--');
      expect(planState.endText).assertEqual('10:30');
      expect(planState.showConflict).assertFalse();
      expect(planState.showConflictFixButton).assertFalse();
      expect(backlogState.expandSymbol).assertEqual('\u25B6');
      expect(backlogState.badgeText).assertEqual('3');
      expect(backlogState.showMoveAllButton).assertTrue();
      expect(backlogState.showEmptyState).assertFalse();
      expect(switchState.showLoading).assertFalse();
      expect(switchState.showToggle).assertTrue();
      expect(switchState.loadingText).assertEqual('');
      expect(selectState.valueText).assertEqual('自动');
      expect(headerState.backLabel).assertEqual('返回');
      expect(sameTabPlan.shouldNavigate).assertFalse();
      expect(sameTabPlan.nextNavLocked).assertFalse();
      expect(lockedPlan.shouldNavigate).assertFalse();
      expect(lockedPlan.nextNavLocked).assertTrue();
      expect(searchAction.kind).assertEqual('search');
      expect(searchAction.route).assertEqual('pages/PlanSearchPage');
      expect(noopAction.kind).assertEqual('noop');
      expect(releasedTab).assertEqual('');
    });
  });
}
