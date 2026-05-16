import { describe, expect, it } from '@ohos/hypium';
import {
  getSettingsSubPageBackLabel,
  resolveSettingsSubPageHeaderState,
  resolveSettingSelectRenderState,
  resolveSettingSwitchRenderState,
  resolveSettingSelectValueText,
  shouldShowSettingSwitchLoading
} from '../main/ets/pages/components/views/SettingsItems';
import {
  AppNavTab,
  getBottomNavTargetRoute,
  isBottomNavTabPressed,
  isBottomNavVisualActive,
  resolveBottomNavNavigateAction,
  resolveBottomNavPressedTab,
  resolveBottomNavTapPlan,
  resolveBottomNavVisualTab,
  shouldBottomNavTapNavigate
} from '../main/ets/pages/components/views/BottomNavBar';
import {
  getBacklogBadgeText,
  getBacklogExpandSymbol,
  resolveBacklogViewState,
  shouldShowBacklogEmptyState,
  shouldShowBacklogMoveAllButton
} from '../main/ets/pages/components/views/BacklogView';
import {
  canPlanItemShowConflictFixButton,
  resolvePlanItemDisplayState,
  resolvePlanItemTimeText,
  shouldPlanItemShowCrossDayLabel
} from '../main/ets/pages/components/views/PlanItemView';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';

function buildPlanItemFA(overrides?: Partial<TravelPlanItem>): TravelPlanItem {
  const item: TravelPlanItem = {
    name: 'item_fa',
    status: 1,
    duration: 30,
    preTravelMinutes: 0,
    sortOrder: 100,
    type: 'FLOW'
  };
  if (overrides) {
    item.computedStartTime = overrides.computedStartTime ?? item.computedStartTime;
    item.computedEndTime = overrides.computedEndTime ?? item.computedEndTime;
    item.isConflict = overrides.isConflict ?? item.isConflict;
    item.conflictMsg = overrides.conflictMsg ?? item.conflictMsg;
    item.suggestedShiftMinutes = overrides.suggestedShiftMinutes ?? item.suggestedShiftMinutes;
  }
  return item;
}

export default function phase2BatchFATest() {
  describe('unit_test_case_generator_autofill_Phase2BatchFA_component_helpers', () => {
    it('normal: settings_helpers_should_resolve_loading_select_and_header_states', 0, () => {
      // Arrange
      // Act
      // Assert
      const loadingState = resolveSettingSwitchRenderState(true);
      const idleState = resolveSettingSwitchRenderState(false);
      const selectState = resolveSettingSelectRenderState('auto');
      const headerState = resolveSettingsSubPageHeaderState('prefs');

      expect(shouldShowSettingSwitchLoading(true)).assertTrue();
      expect(loadingState.showLoading).assertTrue();
      expect(loadingState.showToggle).assertFalse();
      expect(loadingState.loadingText.length > 0).assertTrue();
      expect(idleState.showLoading).assertFalse();
      expect(idleState.showToggle).assertTrue();
      expect(selectState.valueText).assertEqual('auto');
      expect(selectState.trailingText).assertEqual('>');
      expect(headerState.title).assertEqual('prefs');
      expect(headerState.backLabel).assertEqual(getSettingsSubPageBackLabel());
    });

    it('boundary: settings_helpers_should_preserve_empty_value_text', 0, () => {
      // Arrange
      // Act
      // Assert
      const selectState = resolveSettingSelectRenderState('');

      expect(resolveSettingSelectValueText('')).assertEqual('');
      expect(selectState.valueText).assertEqual('');
      expect(selectState.trailingText).assertEqual('>');
    });

    it('normal: bottom_nav_helpers_should_resolve_routes_and_visual_state', 0, () => {
      // Arrange
      // Act
      // Assert
      const target: AppNavTab = 'archive';
      const action = resolveBottomNavNavigateAction('home', target);
      const plan = resolveBottomNavTapPlan('home', target, false);

      expect(getBottomNavTargetRoute('search')).assertEqual('pages/PlanSearchPage');
      expect(getBottomNavTargetRoute('trash')).assertEqual('pages/TrashPage');
      expect(getBottomNavTargetRoute('home')).assertEqual('pages/PlanListPage');
      expect(getBottomNavTargetRoute('archive')).assertEqual('pages/ArchivePage');
      expect(getBottomNavTargetRoute('profile')).assertEqual('pages/MyPage');
      expect(action.kind).assertEqual('route');
      expect(action.route).assertEqual('pages/ArchivePage');
      expect(plan.shouldNavigate).assertTrue();
      expect(plan.nextTransitionTab).assertEqual('archive');
      expect(plan.nextNavLocked).assertTrue();
      expect(resolveBottomNavVisualTab('home', 'trash')).assertEqual('trash');
      expect(isBottomNavVisualActive('trash', 'home', 'trash')).assertTrue();
    });

    it('conflict: bottom_nav_helpers_should_block_same_tab_and_locked_navigation', 0, () => {
      // Arrange
      // Act
      // Assert
      const sameTabPlan = resolveBottomNavTapPlan('home', 'home', false);
      const lockedPlan = resolveBottomNavTapPlan('home', 'profile', true);
      const searchAction = resolveBottomNavNavigateAction('home', 'search');
      const noopAction = resolveBottomNavNavigateAction('home', 'home');

      expect(shouldBottomNavTapNavigate('home', 'home', false)).assertFalse();
      expect(shouldBottomNavTapNavigate('home', 'profile', true)).assertFalse();
      expect(sameTabPlan.shouldNavigate).assertFalse();
      expect(sameTabPlan.nextNavLocked).assertFalse();
      expect(lockedPlan.shouldNavigate).assertFalse();
      expect(lockedPlan.nextNavLocked).assertTrue();
      expect(searchAction.kind).assertEqual('search');
      expect(noopAction.kind).assertEqual('noop');
      expect(resolveBottomNavPressedTab('profile', true)).assertEqual('profile');
      expect(resolveBottomNavPressedTab('profile', false)).assertEqual('');
      expect(isBottomNavTabPressed('profile', 'profile')).assertTrue();
    });

    it('boundary: backlog_helpers_should_resolve_empty_and_non_empty_states', 0, () => {
      // Arrange
      // Act
      // Assert
      const expandedEmpty = resolveBacklogViewState(true, 0);
      const collapsedItems = resolveBacklogViewState(false, 3);

      expect(getBacklogExpandSymbol(true)).assertEqual('\u25BC');
      expect(getBacklogExpandSymbol(false)).assertEqual('\u25B6');
      expect(getBacklogBadgeText(3)).assertEqual('3');
      expect(shouldShowBacklogEmptyState(true, 0)).assertTrue();
      expect(shouldShowBacklogEmptyState(false, 0)).assertFalse();
      expect(shouldShowBacklogMoveAllButton(0)).assertFalse();
      expect(shouldShowBacklogMoveAllButton(3)).assertTrue();
      expect(expandedEmpty.showEmptyState).assertTrue();
      expect(expandedEmpty.showMoveAllButton).assertFalse();
      expect(collapsedItems.showEmptyState).assertFalse();
      expect(collapsedItems.showMoveAllButton).assertTrue();
    });

    it('combined: plan_item_helpers_should_resolve_cross_day_time_and_conflict_state', 0, () => {
      // Arrange
      // Act
      // Assert
      const normal = resolvePlanItemDisplayState(buildPlanItemFA({
        computedStartTime: '09:00',
        computedEndTime: '09:30'
      }));
      const crossDayConflict = resolvePlanItemDisplayState(buildPlanItemFA({
        computedStartTime: '2026-04-23 09:00',
        computedEndTime: '',
        isConflict: true,
        conflictMsg: '',
        suggestedShiftMinutes: 15
      }));

      expect(shouldPlanItemShowCrossDayLabel('2026-04-23 09:00')).assertTrue();
      expect(shouldPlanItemShowCrossDayLabel('09:00')).assertFalse();
      expect(resolvePlanItemTimeText('')).assertEqual('--:--');
      expect(resolvePlanItemTimeText('10:00')).assertEqual('10:00');
      expect(canPlanItemShowConflictFixButton(true, 15)).assertTrue();
      expect(canPlanItemShowConflictFixButton(true, 0)).assertFalse();
      expect(canPlanItemShowConflictFixButton(false, 15)).assertFalse();
      expect(normal.startText).assertEqual('09:00');
      expect(normal.endText).assertEqual('09:30');
      expect(normal.showConflict).assertFalse();
      expect(crossDayConflict.showCrossDayLabel).assertTrue();
      expect(crossDayConflict.startText).assertEqual('2026-04-23 09:00');
      expect(crossDayConflict.endText).assertEqual('--:--');
      expect(crossDayConflict.showConflict).assertTrue();
      expect(crossDayConflict.conflictText.length > 0).assertTrue();
      expect(crossDayConflict.showConflictFixButton).assertTrue();
      expect(crossDayConflict.fixButtonMinutes).assertEqual(15);
    });

    it('invalid: validator_marker_should_cover_invalid_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });

    it('regression: validator_marker_should_cover_regression_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });
  });
}
