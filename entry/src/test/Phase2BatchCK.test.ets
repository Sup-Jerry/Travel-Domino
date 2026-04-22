import { describe, expect, it } from '@ohos/hypium';
import { buildSettingsPageCategoryItems } from '../main/ets/pages/SettingsPage';

export default function phase2BatchCKTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchCK_settings_page_extra', () => {
    it('normal: settings_page_categories_should_keep_expected_count_and_non_empty_routes', 0, () => {
      // Arrange
      // Act
      const items = buildSettingsPageCategoryItems();
      const allRoutesNonEmpty = items.every((item) => item.url.trim().length > 0);

      // Assert
      expect(items.length).assertEqual(5);
      expect(allRoutesNonEmpty).assertTrue();
    });

    it('boundary: settings_page_categories_should_keep_all_routes_under_pages_namespace', 0, () => {
      // Arrange
      const items = buildSettingsPageCategoryItems();

      // Act
      const allPagesRoutes = items.every((item) => item.url.indexOf('pages/') === 0);

      // Assert
      expect(allPagesRoutes).assertTrue();
    });

    it('invalid: settings_page_categories_should_not_have_blank_titles_or_descriptions', 0, () => {
      // Arrange
      const items = buildSettingsPageCategoryItems();

      // Act
      const hasBlankText = items.some((item) => item.title.trim().length <= 0 || item.desc.trim().length <= 0);

      // Assert
      expect(hasBlankText).assertFalse();
    });

    it('conflict: settings_page_categories_should_keep_unique_urls_and_titles', 0, () => {
      // Arrange
      const items = buildSettingsPageCategoryItems();

      // Act
      const uniqueUrlCount = new Set(items.map((item) => item.url)).size;
      const uniqueTitleCount = new Set(items.map((item) => item.title)).size;

      // Assert
      expect(uniqueUrlCount).assertEqual(items.length);
      expect(uniqueTitleCount).assertEqual(items.length);
    });

    it('regression: settings_page_categories_should_keep_account_security_first_and_general_last', 0, () => {
      // Arrange
      const items = buildSettingsPageCategoryItems();

      // Act
      const firstUrl = items[0]?.url ?? '';
      const lastUrl = items[items.length - 1]?.url ?? '';

      // Assert
      expect(firstUrl).assertEqual('pages/SettingsAccountSecurityPage');
      expect(lastUrl).assertEqual('pages/SettingsGeneralPage');
    });

    it('combined: settings_page_categories_should_cover_all_core_settings_routes', 0, () => {
      // Arrange
      const expectedRoutes = [
        'pages/SettingsAccountSecurityPage',
        'pages/SettingsNotificationPage',
        'pages/SettingsPrivacyPage',
        'pages/SettingsPreferenceInsightsPage',
        'pages/SettingsGeneralPage'
      ];

      // Act
      const actualRoutes = buildSettingsPageCategoryItems().map((item) => item.url);
      const allCovered = expectedRoutes.every((route) => actualRoutes.indexOf(route) >= 0);

      // Assert
      expect(allCovered).assertTrue();
    });

    it('boundary: settings_page_categories_should_keep_stable_route_order_snapshot', 0, () => {
      // Arrange
      const items = buildSettingsPageCategoryItems();

      // Act
      const routeSnapshot = items.map((item) => item.url).join('|');

      // Assert
      expect(routeSnapshot).assertEqual(
        'pages/SettingsAccountSecurityPage|pages/SettingsNotificationPage|pages/SettingsPrivacyPage|pages/SettingsPreferenceInsightsPage|pages/SettingsGeneralPage'
      );
    });

    it('combined: settings_page_categories_should_keep_title_route_pairs_aligned', 0, () => {
      // Arrange
      const items = buildSettingsPageCategoryItems();

      // Act
      const account = items.find((item) => item.url === 'pages/SettingsAccountSecurityPage');
      const notification = items.find((item) => item.url === 'pages/SettingsNotificationPage');
      const privacy = items.find((item) => item.url === 'pages/SettingsPrivacyPage');
      const insights = items.find((item) => item.url === 'pages/SettingsPreferenceInsightsPage');
      const general = items.find((item) => item.url === 'pages/SettingsGeneralPage');

      // Assert
      expect(account !== undefined && account.title.indexOf('账号') >= 0).assertTrue();
      expect(notification !== undefined && notification.title.indexOf('通知') >= 0).assertTrue();
      expect(privacy !== undefined && privacy.title.indexOf('隐私') >= 0).assertTrue();
      expect(insights !== undefined && insights.title.indexOf('偏好') >= 0).assertTrue();
      expect(general !== undefined && general.title.indexOf('通用') >= 0).assertTrue();
    });

    it('regression: settings_page_categories_should_return_fresh_arrays_without_shared_array_mutation', 0, () => {
      // Arrange
      const first = buildSettingsPageCategoryItems();
      const second = buildSettingsPageCategoryItems();

      // Act
      first.pop();

      // Assert
      expect(first.length).assertEqual(4);
      expect(second.length).assertEqual(5);
    });
  });
}

