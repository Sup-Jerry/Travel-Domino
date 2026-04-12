import { describe, it, expect } from '@ohos/hypium';
import { buildSettingsPageCategoryItems } from '../main/ets/pages/SettingsPage';

export default function settingsPageHelperTest() {
  describe('unit_test_case_generator_autofill_SettingsPageHelper', () => {
    it('normal: settings_page_categories_should_include_five_entries', 0, () => {
      // Arrange
      // Act
      const items = buildSettingsPageCategoryItems();
      // Assert
      expect(items.length).assertEqual(5);
    });

    it('boundary: settings_page_categories_should_keep_unique_route_keys', 0, () => {
      // Arrange
      const items = buildSettingsPageCategoryItems();
      // Act
      const uniqueCount = new Set(items.map((item) => item.url)).size;
      // Assert
      expect(uniqueCount).assertEqual(items.length);
    });

    it('invalid: settings_page_categories_should_not_contain_empty_title_or_desc', 0, () => {
      // Arrange
      const items = buildSettingsPageCategoryItems();
      // Act
      const hasEmptyField = items.some((item) => item.title.length <= 0 || item.desc.length <= 0);
      // Assert
      expect(hasEmptyField).assertFalse();
    });

    it('conflict: settings_page_categories_should_keep_distinct_general_and_profile_routes', 0, () => {
      // Arrange
      const items = buildSettingsPageCategoryItems();
      // Act
      const general = items.find((item) => item.title === '通用与外观');
      const profile = items.find((item) => item.title === '偏好画像');
      // Assert
      expect(!!general).assertTrue();
      expect(!!profile).assertTrue();
      if (general && profile) {
        expect(general.url === profile.url).assertFalse();
      }
    });

    it('regression: td-20260412-settings_page_category_order_should_keep_account_first', 0, () => {
      // Arrange
      const items = buildSettingsPageCategoryItems();
      // Act
      const firstTitle = items[0]?.title ?? '';
      // Assert
      expect(firstTitle).assertEqual('账号与安全');
    });

    it('combined: settings_page_categories_should_cover_core_settings_subpages', 0, () => {
      // Arrange
      const requiredRoutes = [
        'pages/SettingsAccountSecurityPage',
        'pages/SettingsNotificationPage',
        'pages/SettingsPrivacyPage',
        'pages/SettingsPreferenceInsightsPage',
        'pages/SettingsGeneralPage'
      ];
      // Act
      const routes = buildSettingsPageCategoryItems().map((item) => item.url);
      const allCovered = requiredRoutes.every((route) => routes.indexOf(route) >= 0);
      // Assert
      expect(allCovered).assertTrue();
    });
  });
}
