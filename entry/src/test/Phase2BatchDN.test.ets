import { describe, it, expect } from '@ohos/hypium';
import {
  buildSettingsPageCategoryItems,
  createSettingsPageForTest,
  SettingsPageCategoryItem
} from '../main/ets/pages/SettingsPage';

interface SettingsPaletteDN {
  textPrimary: Object;
  pageBg: Object;
  cardBg: Object;
}

interface SettingsPagePrivateDN {
  effectiveTheme: string;
  getThemePalette(): SettingsPaletteDN;
  openPage(url: string): void;
  initialRender(): void;
}

class RouterMockDN {
  public pushedUrls: string[] = [];

  pushUrl(options: RouteOptionsDN): void {
    this.pushedUrls.push(options.url);
  }
}

class RouteOptionsDN {
  url: string = '';
}

class UiContextMockDN {
  public readonly router: RouterMockDN = new RouterMockDN();

  getRouter(): RouterMockDN {
    return this.router;
  }
}

function createPageDN(uiContext: UiContextMockDN): SettingsPagePrivateDN {
  const page = createSettingsPageForTest() as SettingsPagePrivateDN;
  Reflect.set(page as Object, 'getUIContext', (): UiContextMockDN => uiContext);
  return page;
}

function findCategoryDN(title: string): SettingsPageCategoryItem | null {
  const items = buildSettingsPageCategoryItems();
  for (let i = 0; i < items.length; i += 1) {
    if (items[i].title === title) {
      return items[i];
    }
  }
  return null;
}

export default function phase2BatchDNTest() {
  describe('phase2BatchDNTest', () => {
    it('normal: settings_page_instance_should_push_requested_subpage_route', 0, () => {
      // Arrange
      const uiContext = new UiContextMockDN();
      const page = createPageDN(uiContext);

      // Act
      page.openPage('pages/SettingsGeneralPage');

      // Assert
      expect(uiContext.router.pushedUrls.length).assertEqual(1);
      expect(uiContext.router.pushedUrls[0]).assertEqual('pages/SettingsGeneralPage');
    });

    it('boundary: settings_page_palette_should_resolve_for_light_and_dark_theme', 0, () => {
      // Arrange
      const page = createPageDN(new UiContextMockDN());

      // Act
      page.effectiveTheme = 'light';
      const light = page.getThemePalette();
      page.effectiveTheme = 'dark';
      const dark = page.getThemePalette();

      // Assert
      expect(light.pageBg !== undefined).assertTrue();
      expect(dark.pageBg !== undefined).assertTrue();
    });

    it('invalid: settings_page_category_lookup_should_return_null_for_unknown_title', 0, () => {
      // Arrange
      const missingTitle = 'not-existing-dn';

      // Act
      const found = findCategoryDN(missingTitle);

      // Assert
      expect(found === null).assertTrue();
    });

    it('conflict: settings_page_instance_should_keep_multiple_route_clicks_in_order', 0, () => {
      // Arrange
      const uiContext = new UiContextMockDN();
      const page = createPageDN(uiContext);

      // Act
      page.openPage('pages/SettingsNotificationPage');
      page.openPage('pages/SettingsPrivacyPage');

      // Assert
      expect(uiContext.router.pushedUrls.length).assertEqual(2);
      expect(uiContext.router.pushedUrls[0]).assertEqual('pages/SettingsNotificationPage');
      expect(uiContext.router.pushedUrls[1]).assertEqual('pages/SettingsPrivacyPage');
    });

    it('regression: settings_page_initial_render_should_not_throw_with_default_category_matrix', 0, () => {
      // Arrange
      const page = createPageDN(new UiContextMockDN());
      page.effectiveTheme = 'dark';
      let threw = false;

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('combined: settings_page_category_routes_should_drive_instance_navigation', 0, () => {
      // Arrange
      const uiContext = new UiContextMockDN();
      const page = createPageDN(uiContext);
      const items = buildSettingsPageCategoryItems();

      // Act
      for (let i = 0; i < items.length; i += 1) {
        page.openPage(items[i].url);
      }

      // Assert
      expect(uiContext.router.pushedUrls.length).assertEqual(items.length);
      expect(uiContext.router.pushedUrls[0]).assertEqual(items[0].url);
      expect(uiContext.router.pushedUrls[items.length - 1]).assertEqual(items[items.length - 1].url);
    });
  });
}
