import { describe, it, expect } from '@ohos/hypium';
import {
  AppNavTab,
  getBottomNavTargetRoute,
  resolveBottomNavVisualTab,
  shouldBottomNavTapNavigate
} from '../main/ets/pages/components/views/BottomNavBar';

export default function bottomNavBarHelperTest() {
  describe('unit_test_case_generator_autofill_BottomNavBarHelper', () => {
    it('normal: get_bottom_nav_target_route_should_map_home_to_plan_list', 0, () => {
      // Arrange
      const tab: AppNavTab = 'home';
      // Act
      const route = getBottomNavTargetRoute(tab);
      // Assert
      expect(route).assertEqual('pages/PlanListPage');
    });

    it('boundary: resolve_bottom_nav_visual_tab_should_use_current_when_transition_empty', 0, () => {
      // Arrange
      const current: AppNavTab = 'archive';
      const transition: AppNavTab | '' = '';
      // Act
      const visual = resolveBottomNavVisualTab(current, transition);
      // Assert
      expect(visual).assertEqual('archive');
    });

    it('invalid: get_bottom_nav_target_route_should_fallback_profile_to_my_page', 0, () => {
      // Arrange
      const tab: AppNavTab = 'profile';
      // Act
      const route = getBottomNavTargetRoute(tab);
      // Assert
      expect(route).assertEqual('pages/MyPage');
    });

    it('conflict: should_bottom_nav_tap_navigate_should_block_when_nav_locked', 0, () => {
      // Arrange
      const current: AppNavTab = 'home';
      const target: AppNavTab = 'archive';
      const navLocked = true;
      // Act
      const shouldNavigate = shouldBottomNavTapNavigate(current, target, navLocked);
      // Assert
      expect(shouldNavigate).assertFalse();
    });

    it('regression: td-20260412-bottom-nav-route-map-should-stay-stable', 0, () => {
      // Arrange
      const tabs: AppNavTab[] = ['search', 'trash', 'archive'];
      // Act
      const routes = tabs.map((tab: AppNavTab) => getBottomNavTargetRoute(tab));
      // Assert
      expect(routes[0]).assertEqual('pages/PlanSearchPage');
      expect(routes[1]).assertEqual('pages/TrashPage');
      expect(routes[2]).assertEqual('pages/ArchivePage');
    });

    it('combined: tap_navigate_should_require_different_tab_and_unlocked_state', 0, () => {
      // Arrange
      const current: AppNavTab = 'home';
      // Act
      const sameTab = shouldBottomNavTapNavigate(current, 'home', false);
      const differentTabUnlocked = shouldBottomNavTapNavigate(current, 'search', false);
      // Assert
      expect(sameTab).assertFalse();
      expect(differentTabUnlocked).assertTrue();
    });
  });
}
