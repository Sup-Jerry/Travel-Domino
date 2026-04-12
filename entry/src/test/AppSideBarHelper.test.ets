import { describe, it, expect } from '@ohos/hypium';
import { AppNavKey, getAppSideBarRouteByKey, shouldAppSideBarNavigate } from '../main/ets/pages/components/views/AppSideBar';

export default function appSideBarHelperTest() {
  describe('unit_test_case_generator_autofill_AppSideBarHelper', () => {
    it('normal: app_sidebar_route_should_map_plans_to_plan_list', 0, () => {
      // Arrange
      const key: AppNavKey = 'plans';
      // Act
      const route = getAppSideBarRouteByKey(key);
      // Assert
      expect(route).assertEqual('pages/PlanListPage');
    });

    it('boundary: app_sidebar_route_should_map_settings_to_settings_page', 0, () => {
      // Arrange
      const key: AppNavKey = 'settings';
      // Act
      const route = getAppSideBarRouteByKey(key);
      // Assert
      expect(route).assertEqual('pages/SettingsPage');
    });

    it('invalid: app_sidebar_should_not_navigate_when_target_same_as_current', 0, () => {
      // Arrange
      const current: AppNavKey = 'trash';
      const target: AppNavKey = 'trash';
      // Act
      const shouldNavigate = shouldAppSideBarNavigate(current, target);
      // Assert
      expect(shouldNavigate).assertFalse();
    });

    it('conflict: app_sidebar_should_navigate_when_current_and_target_conflict', 0, () => {
      // Arrange
      const current: AppNavKey = 'archive';
      const target: AppNavKey = 'plans';
      // Act
      const shouldNavigate = shouldAppSideBarNavigate(current, target);
      // Assert
      expect(shouldNavigate).assertTrue();
    });

    it('regression: td-20260412-app-sidebar-route-map-should-stay-stable', 0, () => {
      // Arrange
      const keys: AppNavKey[] = ['archive', 'trash'];
      // Act
      const routes = keys.map((key: AppNavKey) => getAppSideBarRouteByKey(key));
      // Assert
      expect(routes[0]).assertEqual('pages/ArchivePage');
      expect(routes[1]).assertEqual('pages/TrashPage');
    });

    it('combined: app_sidebar_route_and_navigate_should_match_expected_behavior', 0, () => {
      // Arrange
      const current: AppNavKey = 'plans';
      const target: AppNavKey = 'settings';
      // Act
      const route = getAppSideBarRouteByKey(target);
      const shouldNavigate = shouldAppSideBarNavigate(current, target);
      // Assert
      expect(route).assertEqual('pages/SettingsPage');
      expect(shouldNavigate).assertTrue();
    });
  });
}
