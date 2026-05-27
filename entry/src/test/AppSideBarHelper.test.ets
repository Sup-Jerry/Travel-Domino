import { describe, it, expect } from '@ohos/hypium';
import { ThemeCenter } from '../main/ets/common/utils/ThemeCenter';
import {
  AppSideBar,
  AppNavKey,
  createAppSideBarRouteOptions,
  getAppSideBarRouteByKey,
  shouldAppSideBarNavigate
} from '../main/ets/pages/components/views/AppSideBar';

interface AppSideBarParamsTest {
  isSideBarShow?: boolean;
}

interface AppSideBarHostPrivateTest {
  __isSideBarShow: Object;
}

interface AppSideBarCtorParamsTest {
  isSideBarShow: Object;
}

interface AppSideBarPaletteTest {
  primary?: Object;
  textPrimary?: Object;
  divider?: Object;
  pageBg?: Object;
}

interface AppSideBarRouteOptionsTest {
  url: string;
}

interface AppSideBarRouterTest {
  replaceUrl(options: AppSideBarRouteOptionsTest): Promise<void>;
}

interface AppSideBarUiContextTest {
  getRouter(): AppSideBarRouterTest;
}

interface AppSideBarPrivateTest {
  isSideBarShow: boolean;
  effectiveTheme: string;
  current: AppNavKey;
  setInitiallyProvidedValue(params: AppSideBarParamsTest): void;
  updateStateVars(params: AppSideBarParamsTest): void;
  getUIContext: () => AppSideBarUiContextTest;
  getPalette(): AppSideBarPaletteTest;
  createRouteOptions(url: string): AppSideBarRouteOptionsTest;
  safeReplaceUrl(url: string): Promise<void>;
  handleNavClick(target: AppNavKey): void;
  initialRender(): void;
}

class AppSideBarRouterMockTest implements AppSideBarRouterTest {
  public urls: string[] = [];

  async replaceUrl(options: AppSideBarRouteOptionsTest): Promise<void> {
    this.urls.push(options.url);
  }
}

class AppSideBarUiContextMockTest implements AppSideBarUiContextTest {
  private readonly router: AppSideBarRouterTest;

  constructor(router: AppSideBarRouterTest) {
    this.router = router;
  }

  getRouter(): AppSideBarRouterTest {
    return this.router;
  }
}

@Component
struct AppSideBarHostTest {
  @State isSideBarShow: boolean = true;

  build() {
    AppSideBar({
      isSideBarShow: $isSideBarShow
    });
  }
}

function createAppSideBarForTest(): AppSideBarPrivateTest {
  const host = new AppSideBarHostTest(undefined, {} as LocalStorage) as Object as AppSideBarHostPrivateTest;
  const params: AppSideBarCtorParamsTest = {
    isSideBarShow: host.__isSideBarShow
  };
  return new AppSideBar(host as Object, params as Object as LocalStorage) as Object as AppSideBarPrivateTest;
}

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

    it('boundary: app_sidebar_route_options_should_wrap_url_verbatim', 0, () => {
      // Arrange
      const url = 'pages/ArchivePage';
      // Act
      const options = createAppSideBarRouteOptions(url);
      // Assert
      expect(options.url).assertEqual(url);
    });

    it('combined: app_sidebar_route_options_should_keep_stable_urls_across_calls', 0, () => {
      // Arrange
      const route = getAppSideBarRouteByKey('trash');
      // Act
      const first = createAppSideBarRouteOptions(route);
      const second = createAppSideBarRouteOptions(route);
      // Assert
      expect(first.url).assertEqual('pages/TrashPage');
      expect(second.url).assertEqual(first.url);
    });

    it('normal: app_sidebar_instance_should_sync_link_state_and_palette', 0, () => {
      // Arrange
      const page = createAppSideBarForTest();
      page.setInitiallyProvidedValue({ isSideBarShow: true });
      page.updateStateVars({ isSideBarShow: true });

      // Act
      const initialShow = page.isSideBarShow;
      page.isSideBarShow = false;
      page.effectiveTheme = 'dark';
      page.current = 'archive';
      const palette = page.getPalette();
      const routeOptions = page.createRouteOptions(getAppSideBarRouteByKey('archive'));

      // Assert
      expect(initialShow).assertTrue();
      expect(page.isSideBarShow).assertFalse();
      expect(page.current).assertEqual('archive');
      expect(routeOptions.url).assertEqual('pages/ArchivePage');
      expect(palette.primary).assertEqual(ThemeCenter.getPalette('dark').primary);
      expect(palette.textPrimary).assertEqual(ThemeCenter.getPalette('dark').textPrimary);
      expect(palette.divider).assertEqual(ThemeCenter.getPalette('dark').divider);
      expect(palette.pageBg).assertEqual(ThemeCenter.getPalette('dark').pageBg);
    });

    it('boundary: app_sidebar_settings_state_should_keep_route_and_navigation_contract', 0, () => {
      // Arrange
      const page = createAppSideBarForTest();
      page.setInitiallyProvidedValue({ isSideBarShow: false });
      page.updateStateVars({ isSideBarShow: false });
      page.current = 'settings';
      page.effectiveTheme = 'light';

      // Act
      const route = getAppSideBarRouteByKey(page.current);
      const shouldNavigateSelf = shouldAppSideBarNavigate(page.current, 'settings');
      const shouldNavigateTrash = shouldAppSideBarNavigate(page.current, 'trash');
      const palette = page.getPalette();

      // Assert
      expect(route).assertEqual('pages/SettingsPage');
      expect(shouldNavigateSelf).assertFalse();
      expect(shouldNavigateTrash).assertTrue();
      expect(page.current).assertEqual('settings');
      expect(palette.primary).assertEqual(ThemeCenter.getPalette('light').primary);
    });

    it('regression: app_sidebar_safe_replace_url_should_delegate_to_ui_router', 0, async () => {
      // Arrange
      const page = createAppSideBarForTest();
      const router = new AppSideBarRouterMockTest();
      page.getUIContext = (): AppSideBarUiContextTest => new AppSideBarUiContextMockTest(router);

      // Act
      await page.safeReplaceUrl('pages/ArchivePage');

      // Assert
      expect(router.urls.length).assertEqual(1);
      expect(router.urls[0]).assertEqual('pages/ArchivePage');
    });

    it('combined: app_sidebar_initial_render_should_cover_nav_item_layout_branch', 0, () => {
      // Arrange
      const page = createAppSideBarForTest();
      let threw = false;
      page.current = 'trash';
      page.effectiveTheme = 'dark';

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(page.current).assertEqual('trash');
    });

    it('combined: app_sidebar_initial_render_should_support_plans_light_theme_branch', 0, () => {
      // Arrange
      const page = createAppSideBarForTest();
      let threw = false;
      page.current = 'plans';
      page.effectiveTheme = 'light';

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(page.current).assertEqual('plans');
    });

    it('boundary: app_sidebar_handle_nav_click_should_close_without_navigation_when_target_is_current', 0, async () => {
      // Arrange
      const page = createAppSideBarForTest();
      const router = new AppSideBarRouterMockTest();
      page.getUIContext = (): AppSideBarUiContextTest => new AppSideBarUiContextMockTest(router);
      page.isSideBarShow = true;
      page.current = 'plans';

      // Act
      page.handleNavClick('plans');
      await Promise.resolve();

      // Assert
      expect(page.isSideBarShow).assertFalse();
      expect(router.urls.length).assertEqual(0);
    });

    it('normal: app_sidebar_handle_nav_click_should_navigate_archive_when_target_differs', 0, async () => {
      // Arrange
      const page = createAppSideBarForTest();
      const router = new AppSideBarRouterMockTest();
      page.getUIContext = (): AppSideBarUiContextTest => new AppSideBarUiContextMockTest(router);
      page.isSideBarShow = true;
      page.current = 'plans';

      // Act
      page.handleNavClick('archive');
      await Promise.resolve();

      // Assert
      expect(page.isSideBarShow).assertFalse();
      expect(router.urls.length).assertEqual(1);
      expect(router.urls[0]).assertEqual('pages/ArchivePage');
    });

    it('combined: app_sidebar_handle_nav_click_should_cover_trash_and_settings_routes', 0, async () => {
      // Arrange
      const page = createAppSideBarForTest();
      const router = new AppSideBarRouterMockTest();
      page.getUIContext = (): AppSideBarUiContextTest => new AppSideBarUiContextMockTest(router);
      page.current = 'archive';

      // Act
      page.handleNavClick('trash');
      page.handleNavClick('settings');
      await Promise.resolve();

      // Assert
      expect(router.urls.length).assertEqual(2);
      expect(router.urls[0]).assertEqual('pages/TrashPage');
      expect(router.urls[1]).assertEqual('pages/SettingsPage');
    });
  });
}
