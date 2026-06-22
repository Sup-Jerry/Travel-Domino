import { describe, it, expect } from '@ohos/hypium';
import {
  createSettingsAccountSecurityPageForTest,
  resolveLogoutRedirectUrl,
  resolveLogoutToastMessage
} from '../main/ets/pages/SettingsAccountSecurityPage';

interface SettingsAccountSecurityPagePrivateTest {
  effectiveTheme: string;
  getThemePalette(): Object;
  doLogout(): Promise<void>;
  handleLogoutClick(): void;
  initialRender(): void;
  getUIContext(): SettingsAccountSecurityUiContextTest;
}

interface SettingsAccountSecurityRouterOptionsTest {
  url: string;
}

interface SettingsAccountSecurityRouterTest {
  replaceUrl(options: SettingsAccountSecurityRouterOptionsTest): Promise<void>;
}

interface SettingsAccountSecurityUiContextTest {
  getHostContext(): Object;
  getRouter(): SettingsAccountSecurityRouterTest;
}

interface SettingsAccountSecurityAuthFacadeTest {
  bindContext(context: Object): void;
  logout(): Promise<void>;
}

class SettingsAccountSecurityRouterMockTest implements SettingsAccountSecurityRouterTest {
  public urls: string[] = [];

  async replaceUrl(options: SettingsAccountSecurityRouterOptionsTest): Promise<void> {
    this.urls.push(options.url);
  }
}

class SettingsAccountSecurityHostContextMockTest {
}

class SettingsAccountSecurityUiContextMockTest implements SettingsAccountSecurityUiContextTest {
  private readonly router: SettingsAccountSecurityRouterTest;

  constructor(router: SettingsAccountSecurityRouterTest) {
    this.router = router;
  }

  getHostContext(): Object {
    return new SettingsAccountSecurityHostContextMockTest();
  }

  getRouter(): SettingsAccountSecurityRouterTest {
    return this.router;
  }
}

class SettingsAccountSecurityAuthFacadeMockTest implements SettingsAccountSecurityAuthFacadeTest {
  public bindCount: number = 0;
  public logoutCount: number = 0;
  public shouldFailLogout: boolean = false;

  bindContext(_context: Object): void {
    this.bindCount += 1;
  }

  async logout(): Promise<void> {
    this.logoutCount += 1;
    if (this.shouldFailLogout) {
      throw new Error('logout_failed_for_test');
    }
  }
}

function createSettingsAccountSecurityPrivateForTest(
  authFacade: SettingsAccountSecurityAuthFacadeMockTest,
  router: SettingsAccountSecurityRouterMockTest
): SettingsAccountSecurityPagePrivateTest {
  const page = createSettingsAccountSecurityPageForTest() as SettingsAccountSecurityPagePrivateTest;
  const uiContext = new SettingsAccountSecurityUiContextMockTest(router);
  Reflect.set(page as Object, 'authFacade', authFacade);
  Reflect.set(page as Object, 'getUIContext', (): SettingsAccountSecurityUiContextTest => uiContext);
  return page;
}

export default function settingsAccountSecurityPageHelperTest() {
  describe('unit_test_case_generator_autofill_SettingsAccountSecurityPageHelper', () => {
    it('normal: settings_account_security_logout_success_toast_should_not_be_empty', 0, () => {
      // Arrange
      const success = true;
      // Act
      const text = resolveLogoutToastMessage(success);
      // Assert
      expect(text.trim().length > 0).assertTrue();
    });

    it('boundary: settings_account_security_logout_failure_toast_should_not_be_empty', 0, () => {
      // Arrange
      const success = false;
      // Act
      const text = resolveLogoutToastMessage(success);
      // Assert
      expect(text.trim().length > 0).assertTrue();
    });

    it('invalid: settings_account_security_logout_toast_for_true_and_false_should_differ', 0, () => {
      // Arrange
      const successText = true;
      const failedText = false;
      // Act
      const success = resolveLogoutToastMessage(successText);
      const failed = resolveLogoutToastMessage(failedText);
      // Assert
      expect(success === failed).assertFalse();
    });

    it('conflict: settings_account_security_redirect_should_target_login_page', 0, () => {
      // Arrange
      const expected = 'pages/LoginPage';
      // Act
      const url = resolveLogoutRedirectUrl();
      // Assert
      expect(url).assertEqual(expected);
    });

    it('regression: td-20260412-settings_account_security_redirect_should_start_with_pages_prefix', 0, () => {
      // Arrange
      const prefix = 'pages/';
      // Act
      const url = resolveLogoutRedirectUrl();
      // Assert
      expect(url.indexOf(prefix) === 0).assertTrue();
    });

    it('combined: settings_account_security_helper_chain_should_keep_success_path_stable', 0, () => {
      // Arrange
      const success = true;
      // Act
      const toast = resolveLogoutToastMessage(success);
      const url = resolveLogoutRedirectUrl();
      const valid = toast.length > 0 && url === 'pages/LoginPage';
      // Assert
      expect(valid).assertTrue();
    });

    it('normal: settings_account_security_logout_should_bind_context_and_call_logout', 0, async () => {
      // Arrange
      const authFacade = new SettingsAccountSecurityAuthFacadeMockTest();
      const router = new SettingsAccountSecurityRouterMockTest();
      const page = createSettingsAccountSecurityPrivateForTest(authFacade, router);

      // Act
      await page.doLogout();

      // Assert
      expect(authFacade.bindCount).assertEqual(1);
      expect(authFacade.logoutCount).assertEqual(1);
    });

    it('invalid: settings_account_security_logout_failure_should_not_redirect', 0, async () => {
      // Arrange
      const authFacade = new SettingsAccountSecurityAuthFacadeMockTest();
      const router = new SettingsAccountSecurityRouterMockTest();
      const page = createSettingsAccountSecurityPrivateForTest(authFacade, router);
      authFacade.shouldFailLogout = true;

      // Act
      await page.doLogout();

      // Assert
      expect(authFacade.bindCount).assertEqual(1);
      expect(authFacade.logoutCount).assertEqual(1);
      expect(router.urls.length).assertEqual(0);
    });

    it('combined: settings_account_security_render_should_cover_theme_palette_paths', 0, () => {
      // Arrange
      const authFacade = new SettingsAccountSecurityAuthFacadeMockTest();
      const router = new SettingsAccountSecurityRouterMockTest();
      const page = createSettingsAccountSecurityPrivateForTest(authFacade, router);
      page.effectiveTheme = 'dark';
      let threw = false;

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }
      const palette = page.getThemePalette();

      // Assert
      expect(threw).assertFalse();
      expect(palette !== null).assertTrue();
    });

    it('combined: settings_account_security_logout_success_should_redirect_to_resolved_url', 0, async () => {
      // Arrange
      const authFacade = new SettingsAccountSecurityAuthFacadeMockTest();
      const router = new SettingsAccountSecurityRouterMockTest();
      const page = createSettingsAccountSecurityPrivateForTest(authFacade, router);

      // Act
      await page.doLogout();

      // Assert
      expect(router.urls.length).assertEqual(1);
      expect(router.urls[0]).assertEqual(resolveLogoutRedirectUrl());
    });

    it('combined: settings_account_security_logout_click_should_trigger_async_logout_flow', 0, async () => {
      // Arrange
      const authFacade = new SettingsAccountSecurityAuthFacadeMockTest();
      const router = new SettingsAccountSecurityRouterMockTest();
      const page = createSettingsAccountSecurityPrivateForTest(authFacade, router);

      // Act
      page.handleLogoutClick();
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 30);
      });

      // Assert
      expect(authFacade.bindCount).assertEqual(1);
      expect(authFacade.logoutCount).assertEqual(1);
      expect(router.urls.length).assertEqual(1);
      expect(router.urls[0]).assertEqual(resolveLogoutRedirectUrl());
    });

    it('regression: settings_account_security_failure_toast_should_keep_failure_keyword', 0, () => {
      // Arrange
      const success = false;
      // Act
      const text = resolveLogoutToastMessage(success);
      // Assert
      expect(text.indexOf('失败') >= 0).assertTrue();
    });
  });
}
