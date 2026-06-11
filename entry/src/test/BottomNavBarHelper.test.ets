import { describe, it, expect } from '@ohos/hypium';
import { ThemeCenter } from '../main/ets/common/utils/ThemeCenter';
import {
  AppNavTab,
  CompanionBottomActionBar,
  GlobalBottomNavBar,
  getBottomNavTargetRoute,
  isBottomNavTabPressed,
  isBottomNavVisualActive,
  PlanBottomActionBar,
  resolveBottomNavNavigateAction,
  resolveBottomNavPressedTab,
  resolveBottomNavTapPlan,
  resolveBottomNavVisualTab,
  shouldBottomNavTapNavigate
} from '../main/ets/pages/components/views/BottomNavBar';

interface BottomNavPaletteTest {
  textPrimary?: Object;
  textSecondary?: Object;
  textTertiary?: Object;
  primary?: Object;
  cardBg?: Object;
  divider?: Object;
  companionBg?: Object;
  border?: Object;
}

interface BottomNavRouteOptionsTest {
  url: string;
}

interface GlobalBottomNavRouterTest {
  replaceUrl(options: BottomNavRouteOptionsTest): Promise<void>;
}

interface GlobalBottomNavUIContextTest {
  animateTo(options: Object, action: () => void): void;
  getRouter(): GlobalBottomNavRouterTest;
}

class GlobalBottomNavRouterImplTest implements GlobalBottomNavRouterTest {
  private urls: string[];

  constructor(urls: string[]) {
    this.urls = urls;
  }

  async replaceUrl(options: BottomNavRouteOptionsTest): Promise<void> {
    this.urls.push(options.url);
  }
}

class GlobalBottomNavUIContextImplTest implements GlobalBottomNavUIContextTest {
  private router: GlobalBottomNavRouterTest;

  constructor(router: GlobalBottomNavRouterTest) {
    this.router = router;
  }

  animateTo(_options: Object, action: () => void): void {
    action();
  }

  getRouter(): GlobalBottomNavRouterTest {
    return this.router;
  }
}

class GlobalBottomNavRouterThrowingImplTest implements GlobalBottomNavRouterTest {
  async replaceUrl(_options: BottomNavRouteOptionsTest): Promise<void> {
    throw new Error('route_failed');
  }
}

class BottomNavTouchEventTest {
  type: TouchType = TouchType.Down;

  constructor(type: TouchType) {
    this.type = type;
  }
}

interface GlobalBottomNavBarParamsTest {
  currentTab?: AppNavTab;
  showCenterFab?: boolean;
  onCenterFabTap?: () => void;
  onSearchTap?: () => Promise<void>;
}

interface GlobalBottomNavBarPrivateTest {
  currentTab: AppNavTab;
  showCenterFab: boolean;
  effectiveTheme: string;
  pressedTab: AppNavTab | '';
  transitionTab: AppNavTab | '';
  navLocked: boolean;
  fabPressed: boolean;
  onCenterFabTap: () => void;
  onSearchTap: () => Promise<void>;
  setInitiallyProvidedValue(params: GlobalBottomNavBarParamsTest): void;
  updateStateVars(params: GlobalBottomNavBarParamsTest): void;
  getPalette(): BottomNavPaletteTest;
  createRouteOptions(url: string): BottomNavRouteOptionsTest;
  isVisualActive(tab: AppNavTab): boolean;
  isTabPressed(tab: AppNavTab): boolean;
  getUIContext: () => GlobalBottomNavUIContextTest;
  safeReplaceUrl(options: BottomNavRouteOptionsTest, routeLabel: string): Promise<void>;
  navigateTo(tab: AppNavTab): Promise<void>;
  setTabPressed(tab: AppNavTab, pressed: boolean): void;
  onTabTouch(tab: AppNavTab, event: BottomNavTouchEventTest): void;
  handleTabTap(tab: AppNavTab): void;
  initialRender(): void;
}

interface PlanBottomActionBarParamsTest {
  onFilter?: () => void;
  onAi?: () => void;
  onAdd?: () => void;
  aiEnabled?: boolean;
  addEnabled?: boolean;
}

interface PlanBottomActionBarPrivateTest {
  aiEnabled: boolean;
  addEnabled: boolean;
  effectiveTheme: string;
  onFilter: () => void;
  onAi: () => void;
  onAdd: () => void;
  setInitiallyProvidedValue(params: PlanBottomActionBarParamsTest): void;
  updateStateVars(params: PlanBottomActionBarParamsTest): void;
  getPalette(): BottomNavPaletteTest;
  initialRender(): void;
}

interface CompanionBottomActionBarParamsTest {
  onHistory?: () => void;
  onImmersive?: () => void;
  onSearch?: () => void;
  onFilter?: () => void;
}

interface CompanionBottomActionBarPrivateTest {
  effectiveTheme: string;
  onHistory: () => void;
  onImmersive: () => void;
  onSearch: () => void;
  onFilter: () => void;
  setInitiallyProvidedValue(params: CompanionBottomActionBarParamsTest): void;
  updateStateVars(params: CompanionBottomActionBarParamsTest): void;
  getPalette(): BottomNavPaletteTest;
  initialRender(): void;
}

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

    it('normal: bottom_nav_visual_active_should_follow_transition_tab', 0, () => {
      // Arrange
      const tab: AppNavTab = 'archive';
      // Act
      const active = isBottomNavVisualActive(tab, 'home', 'archive');
      // Assert
      expect(active).assertTrue();
    });

    it('boundary: bottom_nav_visual_active_should_fallback_to_current_when_transition_empty', 0, () => {
      // Arrange
      const tab: AppNavTab = 'home';
      // Act
      const active = isBottomNavVisualActive(tab, 'home', '');
      // Assert
      expect(active).assertTrue();
    });

    it('regression: td-20260412-bottom-nav-pressed-check-should-stay-equality-only', 0, () => {
      // Arrange
      const tab: AppNavTab = 'trash';
      // Act
      const pressed = isBottomNavTabPressed(tab, 'trash');
      const notPressed = isBottomNavTabPressed(tab, 'search');
      // Assert
      expect(pressed).assertTrue();
      expect(notPressed).assertFalse();
    });

    it('combined: bottom_nav_action_resolution_should_cover_noop_search_route_and_press_states', 0, () => {
      // Arrange
      const current: AppNavTab = 'home';

      // Act
      const noopAction = resolveBottomNavNavigateAction(current, 'home');
      const searchAction = resolveBottomNavNavigateAction(current, 'search');
      const routeAction = resolveBottomNavNavigateAction(current, 'archive');
      const sameTabPlan = resolveBottomNavTapPlan(current, 'home', false);
      const lockedPlan = resolveBottomNavTapPlan(current, 'archive', true);
      const freePlan = resolveBottomNavTapPlan(current, 'archive', false);
      const pressed = resolveBottomNavPressedTab('archive', true);
      const released = resolveBottomNavPressedTab('archive', false);

      // Assert
      expect(noopAction.kind).assertEqual('noop');
      expect(searchAction.kind).assertEqual('search');
      expect(searchAction.route).assertEqual('pages/PlanSearchPage');
      expect(routeAction.kind).assertEqual('route');
      expect(routeAction.route).assertEqual('pages/ArchivePage');
      expect(sameTabPlan.shouldNavigate).assertFalse();
      expect(lockedPlan.shouldNavigate).assertFalse();
      expect(lockedPlan.nextNavLocked).assertTrue();
      expect(freePlan.shouldNavigate).assertTrue();
      expect(freePlan.nextTransitionTab).assertEqual('archive');
      expect(pressed).assertEqual('archive');
      expect(released).assertEqual('');
    });

    it('combined: plan_bottom_action_bar_instance_should_sync_callbacks_state_and_palette', 0, () => {
      // Arrange
      const page = new PlanBottomActionBar(undefined, {} as LocalStorage) as Object as PlanBottomActionBarPrivateTest;
      let filterCount = 0;
      let aiCount = 0;
      let addCount = 0;
      const initParams: PlanBottomActionBarParamsTest = {
        onFilter: () => { filterCount += 1; },
        onAi: () => { aiCount += 1; },
        onAdd: () => { addCount += 1; },
        aiEnabled: false,
        addEnabled: true
      };
      const nextParams: PlanBottomActionBarParamsTest = {
        aiEnabled: true,
        addEnabled: false
      };
      page.setInitiallyProvidedValue(initParams);
      page.updateStateVars(initParams);

      // Act
      const initAiEnabled = page.aiEnabled;
      const initAddEnabled = page.addEnabled;
      page.onFilter();
      page.onAi();
      page.onAdd();
      page.updateStateVars(nextParams);
      page.effectiveTheme = 'dark';
      const palette = page.getPalette();

      // Assert
      expect(filterCount).assertEqual(1);
      expect(aiCount).assertEqual(1);
      expect(addCount).assertEqual(1);
      expect(initAiEnabled).assertFalse();
      expect(initAddEnabled).assertTrue();
      expect(page.aiEnabled).assertTrue();
      expect(page.addEnabled).assertFalse();
      expect(palette.cardBg).assertEqual(ThemeCenter.getPalette('dark').cardBg);
      expect(palette.divider).assertEqual(ThemeCenter.getPalette('dark').divider);
      expect(palette.textPrimary).assertEqual(ThemeCenter.getPalette('dark').textPrimary);
    });

    it('combined: companion_bottom_action_bar_instance_should_keep_initial_callbacks_when_update_state_is_noop', 0, () => {
      // Arrange
      const page = new CompanionBottomActionBar(undefined, {} as LocalStorage) as Object as CompanionBottomActionBarPrivateTest;
      let historyCount = 0;
      let immersiveCount = 0;
      let searchCount = 0;
      let filterCount = 0;
      const initParams: CompanionBottomActionBarParamsTest = {
        onHistory: () => { historyCount += 1; },
        onImmersive: () => { immersiveCount += 1; },
        onSearch: () => { searchCount += 1; },
        onFilter: () => { filterCount += 1; }
      };
      const nextParams: CompanionBottomActionBarParamsTest = {
        onHistory: () => { historyCount += 10; }
      };
      page.setInitiallyProvidedValue(initParams);
      page.updateStateVars(initParams);

      // Act
      page.onHistory();
      page.onImmersive();
      page.onSearch();
      page.onFilter();
      page.updateStateVars(nextParams);
      page.onHistory();
      page.effectiveTheme = 'dark';
      const palette = page.getPalette();

      // Assert
      expect(historyCount).assertEqual(2);
      expect(immersiveCount).assertEqual(1);
      expect(searchCount).assertEqual(1);
      expect(filterCount).assertEqual(1);
      expect(palette.companionBg).assertEqual(ThemeCenter.getPalette('dark').companionBg);
      expect(palette.border).assertEqual(ThemeCenter.getPalette('dark').border);
      expect(palette.textSecondary).assertEqual(ThemeCenter.getPalette('dark').textSecondary);
    });

    it('combined: global_bottom_nav_bar_instance_should_sync_visual_state_palette_and_callbacks', 0, async () => {
      // Arrange
      const page = new GlobalBottomNavBar(undefined, {} as LocalStorage) as Object as GlobalBottomNavBarPrivateTest;
      let fabCount = 0;
      let searchCount = 0;
      const routedUrls: string[] = [];
      const initParams: GlobalBottomNavBarParamsTest = {
        currentTab: 'home',
        showCenterFab: true,
        onCenterFabTap: () => { fabCount += 1; },
        onSearchTap: async () => { searchCount += 1; }
      };
      const nextParams: GlobalBottomNavBarParamsTest = {
        currentTab: 'profile',
        showCenterFab: false
      };
      const fakeRouter = new GlobalBottomNavRouterImplTest(routedUrls);
      const fakeUiContext = new GlobalBottomNavUIContextImplTest(fakeRouter);

      // Act
      page.getUIContext = (): GlobalBottomNavUIContextTest => fakeUiContext;
      page.setInitiallyProvidedValue(initParams);
      page.updateStateVars(initParams);
      const initCurrentTab = page.currentTab;
      const initShowCenterFab = page.showCenterFab;
      page.transitionTab = 'archive';
      page.pressedTab = 'search';
      page.navLocked = true;
      page.fabPressed = true;
      page.effectiveTheme = 'dark';
      const archiveActive = page.isVisualActive('archive');
      const homeActive = page.isVisualActive('home');
      const searchPressed = page.isTabPressed('search');
      const homePressed = page.isTabPressed('home');
      const routeOptions = page.createRouteOptions('pages/PlanListPage');
      page.currentTab = initCurrentTab;
      page.showCenterFab = initShowCenterFab;
      await page.safeReplaceUrl(routeOptions, 'pages/PlanListPage');
      page.setTabPressed('archive', true);
      const archivePressed = page.isTabPressed('archive');
      page.setTabPressed('archive', false);
      const archiveReleased = page.isTabPressed('archive');
      page.onCenterFabTap();
      await page.onSearchTap();
      await page.navigateTo('archive');
      await page.navigateTo('search');
      page.handleTabTap('archive');
      await new Promise<void>((resolve: () => void): void => {
        setTimeout((): void => {
          resolve();
        }, 360);
      });
      page.updateStateVars(nextParams);
      const palette = page.getPalette();

      // Assert
      expect(initCurrentTab).assertEqual('home');
      expect(initShowCenterFab).assertTrue();
      expect(archiveActive).assertTrue();
      expect(homeActive).assertFalse();
      expect(searchPressed).assertTrue();
      expect(homePressed).assertFalse();
      expect(archivePressed).assertTrue();
      expect(archiveReleased).assertFalse();
      expect(routeOptions.url).assertEqual('pages/PlanListPage');
      expect(routedUrls[0]).assertEqual('pages/PlanListPage');
      expect(routedUrls.includes('pages/ArchivePage')).assertTrue();
      expect(fabCount).assertEqual(1);
      expect(searchCount).assertEqual(2);
      expect(page.currentTab).assertEqual('profile');
      expect(page.showCenterFab).assertFalse();
      expect(page.transitionTab).assertEqual('');
      expect(page.navLocked).assertTrue();
      expect(page.fabPressed).assertTrue();
      expect(palette.cardBg).assertEqual(ThemeCenter.getPalette('dark').cardBg);
      expect(palette.primary).assertEqual(ThemeCenter.getPalette('dark').primary);
      expect(palette.textSecondary).assertEqual(ThemeCenter.getPalette('dark').textSecondary);
    });

    it('normal: global_bottom_nav_bar_initial_render_should_support_center_fab_branch', 0, () => {
      // Arrange
      const page = new GlobalBottomNavBar(undefined, {} as LocalStorage) as Object as GlobalBottomNavBarPrivateTest;
      const routedUrls: string[] = [];
      const fakeRouter = new GlobalBottomNavRouterImplTest(routedUrls);
      const fakeUiContext = new GlobalBottomNavUIContextImplTest(fakeRouter);
      page.getUIContext = (): GlobalBottomNavUIContextTest => fakeUiContext;
      page.setInitiallyProvidedValue({
        currentTab: 'home',
        showCenterFab: true
      });

      // Act
      let threw = false;
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('normal: plan_bottom_action_bar_initial_render_should_support_enabled_states', 0, () => {
      // Arrange
      const page = new PlanBottomActionBar(undefined, {} as LocalStorage) as Object as PlanBottomActionBarPrivateTest;
      page.setInitiallyProvidedValue({
        aiEnabled: true,
        addEnabled: true
      });

      // Act
      let threw = false;
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('boundary: companion_bottom_action_bar_initial_render_should_support_default_actions', 0, () => {
      // Arrange
      const page = new CompanionBottomActionBar(undefined, {} as LocalStorage) as Object as CompanionBottomActionBarPrivateTest;

      // Act
      let threw = false;
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('boundary: bottom_nav_tap_plan_should_clear_transition_and_unlock_on_same_tab', 0, () => {
      // Arrange
      const current: AppNavTab = 'archive';
      const target: AppNavTab = 'archive';

      // Act
      const plan = resolveBottomNavTapPlan(current, target, true);

      // Assert
      expect(plan.shouldNavigate).assertFalse();
      expect(plan.nextTransitionTab).assertEqual('');
      expect(plan.nextNavLocked).assertFalse();
    });

    it('combined: bottom_nav_tap_plan_should_keep_lock_when_blocked_by_nav_locked', 0, () => {
      // Arrange
      const current: AppNavTab = 'home';
      const target: AppNavTab = 'trash';

      // Act
      const plan = resolveBottomNavTapPlan(current, target, true);

      // Assert
      expect(plan.shouldNavigate).assertFalse();
      expect(plan.nextTransitionTab).assertEqual('');
      expect(plan.nextNavLocked).assertTrue();
    });

    it('boundary: global_bottom_nav_on_tab_touch_should_press_and_release_tab', 0, () => {
      // Arrange
      const page = new GlobalBottomNavBar(undefined, {} as LocalStorage) as Object as GlobalBottomNavBarPrivateTest;
      const routedUrls: string[] = [];
      const fakeRouter = new GlobalBottomNavRouterImplTest(routedUrls);
      const fakeUiContext = new GlobalBottomNavUIContextImplTest(fakeRouter);
      page.getUIContext = (): GlobalBottomNavUIContextTest => fakeUiContext;

      // Act
      page.onTabTouch('trash', new BottomNavTouchEventTest(TouchType.Down));
      const pressed = page.pressedTab;
      page.onTabTouch('trash', new BottomNavTouchEventTest(TouchType.Up));
      const released = page.pressedTab;

      // Assert
      expect(pressed).assertEqual('trash');
      expect(released).assertEqual('');
    });

    it('boundary: global_bottom_nav_navigate_to_should_noop_for_current_tab', 0, async () => {
      // Arrange
      const page = new GlobalBottomNavBar(undefined, {} as LocalStorage) as Object as GlobalBottomNavBarPrivateTest;
      const routedUrls: string[] = [];
      const fakeRouter = new GlobalBottomNavRouterImplTest(routedUrls);
      const fakeUiContext = new GlobalBottomNavUIContextImplTest(fakeRouter);
      page.getUIContext = (): GlobalBottomNavUIContextTest => fakeUiContext;
      page.currentTab = 'home';
      let searchCount = 0;
      page.onSearchTap = async (): Promise<void> => {
        searchCount += 1;
      };

      // Act
      await page.navigateTo('home');

      // Assert
      expect(routedUrls.length).assertEqual(0);
      expect(searchCount).assertEqual(0);
    });

    it('combined: global_bottom_nav_on_tab_touch_should_release_pressed_tab_on_cancel', 0, () => {
      // Arrange
      const page = new GlobalBottomNavBar(undefined, {} as LocalStorage) as Object as GlobalBottomNavBarPrivateTest;
      const routedUrls: string[] = [];
      const fakeRouter = new GlobalBottomNavRouterImplTest(routedUrls);
      const fakeUiContext = new GlobalBottomNavUIContextImplTest(fakeRouter);
      page.getUIContext = (): GlobalBottomNavUIContextTest => fakeUiContext;

      // Act
      page.onTabTouch('archive', new BottomNavTouchEventTest(TouchType.Down));
      const pressed = page.pressedTab;
      page.onTabTouch('archive', new BottomNavTouchEventTest(TouchType.Cancel));
      const released = page.pressedTab;

      // Assert
      expect(pressed).assertEqual('archive');
      expect(released).assertEqual('');
    });

    it('invalid: global_bottom_nav_safe_replace_url_should_swallow_router_failure', 0, async (done: () => void) => {
      // Arrange
      const page = new GlobalBottomNavBar(undefined, {} as LocalStorage) as Object as GlobalBottomNavBarPrivateTest;
      const fakeRouter = new GlobalBottomNavRouterThrowingImplTest();
      const fakeUiContext = new GlobalBottomNavUIContextImplTest(fakeRouter);
      page.getUIContext = (): GlobalBottomNavUIContextTest => fakeUiContext;
      let threw = false;

      // Act
      try {
        await page.safeReplaceUrl(page.createRouteOptions('pages/ArchivePage'), 'pages/ArchivePage');
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      done();
    });

    it('boundary: global_bottom_nav_handle_tab_tap_should_clear_lock_for_same_tab', 0, () => {
      // Arrange
      const page = new GlobalBottomNavBar(undefined, {} as LocalStorage) as Object as GlobalBottomNavBarPrivateTest;
      page.currentTab = 'home';
      page.transitionTab = 'archive';
      page.navLocked = true;

      // Act
      page.handleTabTap('home');

      // Assert
      expect(page.transitionTab).assertEqual('');
      expect(page.navLocked).assertFalse();
    });

    it('boundary: global_bottom_nav_set_tab_pressed_should_noop_when_state_is_unchanged', 0, () => {
      // Arrange
      const page = new GlobalBottomNavBar(undefined, {} as LocalStorage) as Object as GlobalBottomNavBarPrivateTest;
      const routedUrls: string[] = [];
      const fakeRouter = new GlobalBottomNavRouterImplTest(routedUrls);
      const fakeUiContext = new GlobalBottomNavUIContextImplTest(fakeRouter);
      page.getUIContext = (): GlobalBottomNavUIContextTest => fakeUiContext;
      page.pressedTab = 'search';

      // Act
      page.setTabPressed('search', true);

      // Assert
      expect(page.pressedTab).assertEqual('search');
    });

    it('boundary: global_bottom_nav_on_tab_touch_should_ignore_unhandled_move_event', 0, () => {
      // Arrange
      const page = new GlobalBottomNavBar(undefined, {} as LocalStorage) as Object as GlobalBottomNavBarPrivateTest;
      const routedUrls: string[] = [];
      const fakeRouter = new GlobalBottomNavRouterImplTest(routedUrls);
      const fakeUiContext = new GlobalBottomNavUIContextImplTest(fakeRouter);
      page.getUIContext = (): GlobalBottomNavUIContextTest => fakeUiContext;
      page.pressedTab = 'archive';

      // Act
      page.onTabTouch('archive', new BottomNavTouchEventTest(TouchType.Move));

      // Assert
      expect(page.pressedTab).assertEqual('archive');
    });

    it('combined: global_bottom_nav_navigate_to_should_use_search_callback_without_router_replace', 0, async (done: () => void) => {
      // Arrange
      const page = new GlobalBottomNavBar(undefined, {} as LocalStorage) as Object as GlobalBottomNavBarPrivateTest;
      const routedUrls: string[] = [];
      const fakeRouter = new GlobalBottomNavRouterImplTest(routedUrls);
      const fakeUiContext = new GlobalBottomNavUIContextImplTest(fakeRouter);
      page.getUIContext = (): GlobalBottomNavUIContextTest => fakeUiContext;
      page.currentTab = 'home';
      let searchCount = 0;
      page.onSearchTap = async (): Promise<void> => {
        searchCount += 1;
      };

      // Act
      await page.navigateTo('search');

      // Assert
      expect(searchCount).assertEqual(1);
      expect(routedUrls.length).assertEqual(0);
      done();
    });

    it('combined: global_bottom_nav_handle_tab_tap_should_route_and_auto_unlock_after_delay', 0, async (done: () => void) => {
      // Arrange
      const page = new GlobalBottomNavBar(undefined, {} as LocalStorage) as Object as GlobalBottomNavBarPrivateTest;
      const routedUrls: string[] = [];
      const fakeRouter = new GlobalBottomNavRouterImplTest(routedUrls);
      const fakeUiContext = new GlobalBottomNavUIContextImplTest(fakeRouter);
      page.getUIContext = (): GlobalBottomNavUIContextTest => fakeUiContext;
      page.currentTab = 'home';
      page.navLocked = false;
      page.transitionTab = '';

      // Act
      page.handleTabTap('archive');
      const lockedDuringTransition = page.navLocked;
      const transitionDuringAnimation = page.transitionTab;
      await new Promise<void>((resolve: () => void) => {
        setTimeout(() => {
          resolve();
        }, 360);
      });

      // Assert
      expect(lockedDuringTransition).assertTrue();
      expect(transitionDuringAnimation).assertEqual('archive');
      expect(routedUrls.includes('pages/ArchivePage')).assertTrue();
      expect(page.transitionTab).assertEqual('');
      expect(page.navLocked).assertFalse();
      done();
    });

    it('combined: plan_bottom_action_bar_should_keep_disabled_actions_and_dark_palette_consistent', 0, () => {
      // Arrange
      const page = new PlanBottomActionBar(undefined, {} as LocalStorage) as Object as PlanBottomActionBarPrivateTest;
      page.effectiveTheme = 'dark';
      page.aiEnabled = false;
      page.addEnabled = false;

      // Act
      const palette = page.getPalette();

      // Assert
      expect(page.aiEnabled).assertFalse();
      expect(page.addEnabled).assertFalse();
      expect(palette.textTertiary).assertEqual(ThemeCenter.getPalette('dark').textTertiary);
    });
  });
}
