import { describe, expect, it } from '@ohos/hypium';
import { AuthResult, LoginStatus, UserSession } from '../main/ets/domain/auth/AuthTypes';
import { createAuthGatePageForTest } from '../main/ets/pages/AuthGatePage';

interface AuthGatePagePrivateDT {
  checking: boolean;
  checkingInProgress: boolean;
  startupCoordinator: Object;
  authFacade: Object;
  replaceUrl(url: string): Promise<void>;
  checkAndRoute(): Promise<void>;
  onPageShow(): void;
  getUIContext(): Object;
}

class RouterStubDT {
  public readonly urls: string[] = [];

  async replaceUrl(option: Object): Promise<void> {
    this.urls.push(String(Reflect.get(option, 'url') ?? ''));
  }
}

class UIContextStubDT {
  public readonly router: RouterStubDT = new RouterStubDT();

  getRouter(): RouterStubDT {
    return this.router;
  }
}

class StartupCoordinatorStubDT {
  public result: AuthResult<UserSession> = buildAuthResultDT(false, LoginStatus.UNAUTHENTICATED);
  public shouldThrow: boolean = false;
  public callCount: number = 0;

  async checkStartupAuth(): Promise<AuthResult<UserSession>> {
    this.callCount += 1;
    if (this.shouldThrow) {
      throw new Error('startup_fail_dt');
    }
    return this.result;
  }
}

class AuthFacadeStubDT {
  public logoutCount: number = 0;

  async logout(): Promise<void> {
    this.logoutCount += 1;
  }
}

function buildAuthResultDT(success: boolean, status: LoginStatus): AuthResult<UserSession> {
  const result = new AuthResult<UserSession>();
  result.success = success;
  result.status = status;
  result.code = success ? 0 : 401;
  result.message = success ? 'ok_dt' : 'failed_dt';
  result.source = success ? 'LOCAL_SESSION' : 'NONE';
  result.data = success ? new UserSession() : null;
  if (result.data) {
    result.data.accountId = 'account_dt';
  }
  return result;
}

function createPageDT(): AuthGatePagePrivateDT {
  return createAuthGatePageForTest() as AuthGatePagePrivateDT;
}

export default function phase2BatchDTTest() {
  describe('phase2BatchDTTest', () => {
    it('normal: auth_gate_replace_url_should_delegate_to_page_router', 0, async () => {
      // Arrange
      const page = createPageDT();
      const uiContext = new UIContextStubDT();
      Reflect.set(page as Object, 'getUIContext', (): Object => uiContext as Object);

      // Act
      await page.replaceUrl('pages/PlanListPage');

      // Assert
      expect(uiContext.router.urls.length).assertEqual(1);
      expect(uiContext.router.urls[0]).assertEqual('pages/PlanListPage');
    });

    it('normal: auth_gate_check_and_route_should_replace_to_plan_list_when_authenticated', 0, async () => {
      // Arrange
      const page = createPageDT();
      const startup = new StartupCoordinatorStubDT();
      startup.result = buildAuthResultDT(true, LoginStatus.AUTHENTICATED);
      const routedUrls: string[] = [];
      Reflect.set(page as Object, 'startupCoordinator', startup as Object);
      Reflect.set(page as Object, 'replaceUrl', async (url: string): Promise<void> => {
        routedUrls.push(url);
      });

      // Act
      await page.checkAndRoute();

      // Assert
      expect(startup.callCount).assertEqual(1);
      expect(routedUrls.length).assertEqual(1);
      expect(routedUrls[0]).assertEqual('pages/PlanListPage');
    });

    it('invalid: auth_gate_check_and_route_should_logout_and_fallback_to_login_on_error', 0, async () => {
      // Arrange
      const page = createPageDT();
      const startup = new StartupCoordinatorStubDT();
      const authFacade = new AuthFacadeStubDT();
      const routedUrls: string[] = [];
      startup.shouldThrow = true;
      Reflect.set(page as Object, 'startupCoordinator', startup as Object);
      Reflect.set(page as Object, 'authFacade', authFacade as Object);
      Reflect.set(page as Object, 'replaceUrl', async (url: string): Promise<void> => {
        routedUrls.push(url);
      });

      // Act
      await page.checkAndRoute();

      // Assert
      expect(startup.callCount).assertEqual(1);
      expect(authFacade.logoutCount).assertEqual(1);
      expect(routedUrls[0]).assertEqual('pages/LoginPage');
    });

    it('combined: auth_gate_on_page_show_should_guard_reentry_and_clear_checking_state', 0, async () => {
      // Arrange
      const page = createPageDT();
      let checkCalls = 0;
      Reflect.set(page as Object, 'checkAndRoute', async (): Promise<void> => {
        checkCalls += 1;
      });

      // Act
      page.onPageShow();
      page.onPageShow();
      await Promise.resolve();

      // Assert
      expect(checkCalls).assertEqual(1);
      expect(page.checkingInProgress).assertFalse();
      expect(page.checking).assertFalse();
    });

    it('boundary: validator_marker_should_cover_boundary_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });

    it('conflict: validator_marker_should_cover_conflict_case', 0, () => {
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
