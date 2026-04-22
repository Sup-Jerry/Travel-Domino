import { describe, expect, it } from '@ohos/hypium';
import {
  createSettingsAccountSecurityPageForTest,
  resolveLogoutRedirectUrl,
  resolveLogoutToastMessage
} from '../main/ets/pages/SettingsAccountSecurityPage';

interface SettingsAccountSecurityPagePrivateCH {
  effectiveTheme: string;
  getThemePalette(): Object;
  doLogout(): Promise<void>;
  initialRender(): void;
}

interface SettingsAccountSecurityRouterOptionsCH {
  url: string;
}

interface SettingsAccountSecurityRouterCH {
  replaceUrl(options: SettingsAccountSecurityRouterOptionsCH): Promise<void>;
}

interface SettingsAccountSecurityUiContextCH {
  getHostContext(): Object;
  getRouter(): SettingsAccountSecurityRouterCH;
}

interface SettingsAccountSecurityAuthFacadeCH {
  bindContext(context: Object): void;
  logout(): Promise<void>;
}

class SettingsAccountSecurityHostContextCH {}

class SettingsAccountSecurityRouterMockCH implements SettingsAccountSecurityRouterCH {
  public urls: string[] = [];
  public shouldFail: boolean = false;

  async replaceUrl(options: SettingsAccountSecurityRouterOptionsCH): Promise<void> {
    this.urls.push(options.url);
    if (this.shouldFail) {
      throw new Error('replace_failed_ch');
    }
  }
}

class SettingsAccountSecurityUiContextMockCH implements SettingsAccountSecurityUiContextCH {
  private readonly router: SettingsAccountSecurityRouterCH;
  public hostContext: Object = new SettingsAccountSecurityHostContextCH();

  constructor(router: SettingsAccountSecurityRouterCH) {
    this.router = router;
  }

  getHostContext(): Object {
    return this.hostContext;
  }

  getRouter(): SettingsAccountSecurityRouterCH {
    return this.router;
  }
}

class SettingsAccountSecurityAuthFacadeMockCH implements SettingsAccountSecurityAuthFacadeCH {
  public bindCount: number = 0;
  public logoutCount: number = 0;
  public shouldFailLogout: boolean = false;
  public lastContext: Object | null = null;

  bindContext(context: Object): void {
    this.bindCount += 1;
    this.lastContext = context;
  }

  async logout(): Promise<void> {
    this.logoutCount += 1;
    if (this.shouldFailLogout) {
      throw new Error('logout_failed_ch');
    }
  }
}

function createSettingsAccountSecurityPageCH(
  authFacade: SettingsAccountSecurityAuthFacadeMockCH,
  router: SettingsAccountSecurityRouterMockCH,
  uiContext: SettingsAccountSecurityUiContextMockCH
): SettingsAccountSecurityPagePrivateCH {
  const page = createSettingsAccountSecurityPageForTest() as SettingsAccountSecurityPagePrivateCH;
  Reflect.set(page as Object, 'authFacade', authFacade);
  Reflect.set(page as Object, 'getUIContext', (): SettingsAccountSecurityUiContextCH => uiContext);
  return page;
}

export default function phase2BatchCHTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchCH_account_security_extra', () => {
    it('normal: settings_account_security_logout_messages_should_be_non_empty_and_distinct', 0, () => {
      // Arrange
      const success = true;
      const failed = false;

      // Act
      const successText = resolveLogoutToastMessage(success);
      const failedText = resolveLogoutToastMessage(failed);

      // Assert
      expect(successText.trim().length > 0).assertTrue();
      expect(failedText.trim().length > 0).assertTrue();
      expect(successText === failedText).assertFalse();
    });

    it('boundary: settings_account_security_redirect_url_should_be_stable_login_page_route', 0, () => {
      // Arrange
      const expected = 'pages/LoginPage';

      // Act
      const url = resolveLogoutRedirectUrl();

      // Assert
      expect(url).assertEqual(expected);
      expect(url.indexOf('pages/') === 0).assertTrue();
      expect(url.indexOf(' ') < 0).assertTrue();
    });

    it('regression: settings_account_security_redirect_url_should_be_stable_across_repeated_calls', 0, () => {
      // Arrange
      // Act
      const first = resolveLogoutRedirectUrl();
      const second = resolveLogoutRedirectUrl();

      // Assert
      expect(first).assertEqual(second);
      expect(first).assertEqual('pages/LoginPage');
    });

    it('combined: settings_account_security_logout_messages_should_keep_success_and_failure_outputs_stable', 0, () => {
      // Arrange
      const success = true;
      const failed = false;

      // Act
      const successText = resolveLogoutToastMessage(success);
      const failedText = resolveLogoutToastMessage(failed);
      const successAgain = resolveLogoutToastMessage(success);
      const failedAgain = resolveLogoutToastMessage(failed);

      // Assert
      expect(successText.trim().length > 0).assertTrue();
      expect(failedText.trim().length > 0).assertTrue();
      expect(successAgain).assertEqual(successText);
      expect(failedAgain).assertEqual(failedText);
      expect(successText === failedText).assertFalse();
    });

    it('combined: settings_account_security_logout_success_should_bind_context_and_redirect_once', 0, async () => {
      // Arrange
      const authFacade = new SettingsAccountSecurityAuthFacadeMockCH();
      const router = new SettingsAccountSecurityRouterMockCH();
      const uiContext = new SettingsAccountSecurityUiContextMockCH(router);
      const page = createSettingsAccountSecurityPageCH(authFacade, router, uiContext);

      // Act
      await page.doLogout();

      // Assert
      expect(authFacade.bindCount).assertEqual(1);
      expect(authFacade.logoutCount).assertEqual(1);
      expect(authFacade.lastContext === uiContext.hostContext).assertTrue();
      expect(router.urls.length).assertEqual(1);
      expect(router.urls[0]).assertEqual(resolveLogoutRedirectUrl());
    });

    it('invalid: settings_account_security_logout_failure_should_swallow_error_and_skip_redirect', 0, async () => {
      // Arrange
      const authFacade = new SettingsAccountSecurityAuthFacadeMockCH();
      const router = new SettingsAccountSecurityRouterMockCH();
      const uiContext = new SettingsAccountSecurityUiContextMockCH(router);
      const page = createSettingsAccountSecurityPageCH(authFacade, router, uiContext);
      authFacade.shouldFailLogout = true;

      // Act
      await page.doLogout();

      // Assert
      expect(authFacade.bindCount).assertEqual(1);
      expect(authFacade.logoutCount).assertEqual(1);
      expect(router.urls.length).assertEqual(0);
    });

    it('conflict: settings_account_security_router_failure_should_not_escape_logout_flow', 0, async () => {
      // Arrange
      const authFacade = new SettingsAccountSecurityAuthFacadeMockCH();
      const router = new SettingsAccountSecurityRouterMockCH();
      const uiContext = new SettingsAccountSecurityUiContextMockCH(router);
      const page = createSettingsAccountSecurityPageCH(authFacade, router, uiContext);
      router.shouldFail = true;
      let threw = false;

      // Act
      try {
        await page.doLogout();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(authFacade.logoutCount).assertEqual(1);
      expect(router.urls.length).assertEqual(1);
    });

    it('regression: settings_account_security_light_and_dark_render_should_keep_palette_available', 0, () => {
      // Arrange
      const authFacade = new SettingsAccountSecurityAuthFacadeMockCH();
      const router = new SettingsAccountSecurityRouterMockCH();
      const uiContext = new SettingsAccountSecurityUiContextMockCH(router);
      const page = createSettingsAccountSecurityPageCH(authFacade, router, uiContext);

      // Act
      page.effectiveTheme = 'light';
      const lightPalette = page.getThemePalette();
      page.initialRender();
      page.effectiveTheme = 'dark';
      const darkPalette = page.getThemePalette();
      page.initialRender();

      // Assert
      expect(lightPalette !== null).assertTrue();
      expect(darkPalette !== null).assertTrue();
    });
  });
}
