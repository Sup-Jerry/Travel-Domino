import { describe, expect, it } from '@ohos/hypium';
import { LoginStatus } from '../main/ets/domain/auth/AuthTypes';
import {
  createAuthGatePageForTest,
  resolveAuthGateCheckingText,
  resolveAuthGateTargetUrl,
  shouldAuthGateRouteToPlanList
} from '../main/ets/pages/AuthGatePage';

interface AuthGatePagePrivateCP {
  checking: boolean;
  checkingInProgress: boolean;
  initialRender(): void;
  onPageShow(): void;
  checkAndRoute(): Promise<void>;
  replaceUrl(url: string): Promise<void>;
}

interface AuthGateStartupResultCP {
  success: boolean;
  status: LoginStatus;
  source?: string;
  message?: string;
  code?: number;
  data?: AuthGateSessionCP | null;
}

interface AuthGateSessionCP {
  accountId?: string;
}

class AuthGateStartupCoordinatorMockCP {
  public result: AuthGateStartupResultCP = {
    success: false,
    status: LoginStatus.UNAUTHENTICATED,
    source: 'test',
    message: 'none',
    code: 0,
    data: null
  };
  public shouldThrow: boolean = false;
  public checkCount: number = 0;

  async checkStartupAuth(): Promise<AuthGateStartupResultCP> {
    this.checkCount += 1;
    if (this.shouldThrow) {
      throw new Error('startup_failed_cp');
    }
    return this.result;
  }
}

class AuthGateAuthFacadeMockCP {
  public logoutCount: number = 0;

  async logout(): Promise<void> {
    this.logoutCount += 1;
  }
}

function createAuthGatePageCP(
  startupCoordinator: AuthGateStartupCoordinatorMockCP,
  authFacade: AuthGateAuthFacadeMockCP
): AuthGatePagePrivateCP {
  const page = createAuthGatePageForTest() as AuthGatePagePrivateCP;
  Reflect.set(page as Object, 'startupCoordinator', startupCoordinator);
  Reflect.set(page as Object, 'authFacade', authFacade);
  return page;
}

export default function phase2BatchCPTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchCP_auth_gate_extra', () => {
    it('normal: auth_gate_should_route_authenticated_success_to_plan_list', 0, () => {
      // Arrange
      const success = true;
      const status = LoginStatus.AUTHENTICATED;

      // Act
      const shouldRoute = shouldAuthGateRouteToPlanList(success, status);
      const target = resolveAuthGateTargetUrl(success, status);

      // Assert
      expect(shouldRoute).assertTrue();
      expect(target).assertEqual('pages/PlanListPage');
    });

    it('boundary: auth_gate_should_route_all_non_authenticated_states_to_login', 0, () => {
      // Arrange
      const success = true;
      const states: LoginStatus[] = [LoginStatus.UNAUTHENTICATED, LoginStatus.LOGIN_FAILED];

      // Act
      const targets = states.map((status) => resolveAuthGateTargetUrl(success, status));
      const allLogin = targets.every((target) => target === 'pages/LoginPage');

      // Assert
      expect(allLogin).assertTrue();
    });

    it('invalid: auth_gate_should_not_route_to_plan_list_when_success_false_even_if_status_authenticated', 0, () => {
      // Arrange
      const success = false;
      const status = LoginStatus.AUTHENTICATED;

      // Act
      const shouldRoute = shouldAuthGateRouteToPlanList(success, status);
      const target = resolveAuthGateTargetUrl(success, status);

      // Assert
      expect(shouldRoute).assertFalse();
      expect(target).assertEqual('pages/LoginPage');
    });

    it('conflict: auth_gate_checking_text_should_differ_between_checking_and_redirecting', 0, () => {
      // Arrange
      const checking = true;
      const redirecting = false;

      // Act
      const checkingText = resolveAuthGateCheckingText(checking);
      const redirectingText = resolveAuthGateCheckingText(redirecting);

      // Assert
      expect(checkingText.trim().length > 0).assertTrue();
      expect(redirectingText.trim().length > 0).assertTrue();
      expect(checkingText === redirectingText).assertFalse();
    });

    it('regression: auth_gate_check_and_route_should_use_plan_list_for_authenticated_startup', 0, async () => {
      // Arrange
      const startup = new AuthGateStartupCoordinatorMockCP();
      const auth = new AuthGateAuthFacadeMockCP();
      const page = createAuthGatePageCP(startup, auth);
      const routed: string[] = [];
      startup.result = {
        success: true,
        status: LoginStatus.AUTHENTICATED,
        source: 'cache',
        message: 'ok',
        data: { accountId: 'account_cp' }
      };
      Reflect.set(page as Object, 'replaceUrl', async (url: string): Promise<void> => {
        routed.push(url);
      });

      // Act
      await page.checkAndRoute();

      // Assert
      expect(startup.checkCount).assertEqual(1);
      expect(routed[0]).assertEqual('pages/PlanListPage');
      expect(auth.logoutCount).assertEqual(0);
    });

    it('boundary: auth_gate_check_and_route_should_send_unauthenticated_success_to_login_without_logout', 0, async () => {
      // Arrange
      const startup = new AuthGateStartupCoordinatorMockCP();
      const auth = new AuthGateAuthFacadeMockCP();
      const page = createAuthGatePageCP(startup, auth);
      const routed: string[] = [];
      startup.result = {
        success: true,
        status: LoginStatus.UNAUTHENTICATED,
        source: 'cache',
        message: 'missing_session',
        data: null
      };
      Reflect.set(page as Object, 'replaceUrl', async (url: string): Promise<void> => {
        routed.push(url);
      });

      // Act
      await page.checkAndRoute();

      // Assert
      expect(startup.checkCount).assertEqual(1);
      expect(routed[0]).assertEqual('pages/LoginPage');
      expect(auth.logoutCount).assertEqual(0);
    });

    it('invalid: auth_gate_check_and_route_should_send_failed_authenticated_status_to_login', 0, async () => {
      // Arrange
      const startup = new AuthGateStartupCoordinatorMockCP();
      const auth = new AuthGateAuthFacadeMockCP();
      const page = createAuthGatePageCP(startup, auth);
      const routed: string[] = [];
      startup.result = {
        success: false,
        status: LoginStatus.AUTHENTICATED,
        source: 'network',
        message: 'invalid',
        data: { accountId: 'account_cp' }
      };
      Reflect.set(page as Object, 'replaceUrl', async (url: string): Promise<void> => {
        routed.push(url);
      });

      // Act
      await page.checkAndRoute();

      // Assert
      expect(routed[0]).assertEqual('pages/LoginPage');
      expect(auth.logoutCount).assertEqual(0);
    });

    it('combined: auth_gate_check_and_route_should_fallback_to_login_and_logout_on_exception', 0, async () => {
      // Arrange
      const startup = new AuthGateStartupCoordinatorMockCP();
      const auth = new AuthGateAuthFacadeMockCP();
      const page = createAuthGatePageCP(startup, auth);
      const routed: string[] = [];
      startup.shouldThrow = true;
      Reflect.set(page as Object, 'replaceUrl', async (url: string): Promise<void> => {
        routed.push(url);
      });

      // Act
      await page.checkAndRoute();

      // Assert
      expect(auth.logoutCount).assertEqual(1);
      expect(routed[0]).assertEqual('pages/LoginPage');
    });

    it('combined: auth_gate_on_page_show_should_skip_when_checking_already_in_progress', 0, () => {
      // Arrange
      const startup = new AuthGateStartupCoordinatorMockCP();
      const auth = new AuthGateAuthFacadeMockCP();
      const page = createAuthGatePageCP(startup, auth);
      page.checkingInProgress = true;

      // Act
      page.onPageShow();

      // Assert
      expect(startup.checkCount).assertEqual(0);
      expect(page.checkingInProgress).assertTrue();
    });

    it('combined: auth_gate_on_page_show_should_mark_checking_in_progress_for_new_cycle', 0, () => {
      // Arrange
      const startup = new AuthGateStartupCoordinatorMockCP();
      const auth = new AuthGateAuthFacadeMockCP();
      const page = createAuthGatePageCP(startup, auth);
      page.checking = false;
      page.checkingInProgress = false;

      // Act
      page.onPageShow();

      // Assert
      expect(page.checking).assertTrue();
      expect(page.checkingInProgress).assertTrue();
    });

    it('combined: auth_gate_render_should_cover_checking_and_redirecting_text_states', 0, () => {
      // Arrange
      const startup = new AuthGateStartupCoordinatorMockCP();
      const auth = new AuthGateAuthFacadeMockCP();
      const page = createAuthGatePageCP(startup, auth);

      // Act
      page.checking = true;
      page.initialRender();
      page.checking = false;
      page.initialRender();

      // Assert
      expect(resolveAuthGateCheckingText(true).length > 0).assertTrue();
      expect(resolveAuthGateCheckingText(false).length > 0).assertTrue();
    });
  });
}
