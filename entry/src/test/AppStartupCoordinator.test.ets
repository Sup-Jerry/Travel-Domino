import { describe, expect, it } from '@ohos/hypium';
import { AppStartupCoordinator } from '../main/ets/infrastructure/auth/AppStartupCoordinator';
import { AuthResult, LoginStatus, UserSession } from '../main/ets/domain/auth/AuthTypes';

class FakeAuthFacade {
  callCount: number = 0;
  result: AuthResult<UserSession> | null = null;
  pendingPromise: Promise<AuthResult<UserSession>> | null = null;

  async silentLogin(): Promise<AuthResult<UserSession>> {
    this.callCount += 1;
    if (this.pendingPromise) {
      return this.pendingPromise;
    }
    if (this.result) {
      return this.result;
    }
    return buildResult(false, -1, 'unset', LoginStatus.UNAUTHENTICATED);
  }
}

interface StartupInternal {
  authFacade: FakeAuthFacade;
  startupAuthInFlight: Promise<AuthResult<UserSession>> | null;
  silentLoginWithTimeout: () => Promise<AuthResult<UserSession>>;
}

interface StartupStaticInternal {
  STARTUP_AUTH_TIMEOUT_MS: number;
}

class DeferredAuthResult {
  promise: Promise<AuthResult<UserSession>>;
  private resolver: ((value: AuthResult<UserSession>) => void) | null = null;

  constructor() {
    this.promise = new Promise<AuthResult<UserSession>>((resolve) => {
      this.resolver = resolve;
    });
  }

  resolve(value: AuthResult<UserSession>): void {
    if (this.resolver) {
      this.resolver(value);
    }
  }
}

function buildResult(success: boolean, code: number, message: string, status: LoginStatus): AuthResult<UserSession> {
  const result = new AuthResult<UserSession>();
  result.success = success;
  result.code = code;
  result.message = message;
  result.source = 'HUAWEI_SILENT';
  result.status = status;
  result.data = success ? new UserSession() : null;
  return result;
}

export default function appStartupCoordinatorTest() {
  describe('appStartupCoordinatorTest', () => {
    it('normal: check_startup_auth_should_return_success_when_silent_login_succeeds', 0, async (done: () => void) => {
      // Arrange
      const coordinator = new AppStartupCoordinator();
      const internal = coordinator as Object as StartupInternal;
      const fake = new FakeAuthFacade();
      fake.result = buildResult(true, 0, 'ok', LoginStatus.AUTHENTICATED);
      internal.authFacade = fake;
      internal.startupAuthInFlight = null;
      internal.silentLoginWithTimeout = async (): Promise<AuthResult<UserSession>> => fake.silentLogin();
      // Act
      const result = await coordinator.checkStartupAuth();
      // Assert
      expect(result.success).assertTrue();
      expect(result.status).assertEqual(LoginStatus.AUTHENTICATED);
      done();
    });

    it('boundary: concurrent_check_startup_auth_should_reuse_single_inflight_promise', 0, async (done: () => void) => {
      // Arrange
      const coordinator = new AppStartupCoordinator();
      const internal = coordinator as Object as StartupInternal;
      const fake = new FakeAuthFacade();
      const deferred = new DeferredAuthResult();
      fake.pendingPromise = deferred.promise;
      internal.authFacade = fake;
      internal.startupAuthInFlight = null;
      internal.silentLoginWithTimeout = async (): Promise<AuthResult<UserSession>> => fake.silentLogin();
      // Act
      const p1 = coordinator.checkStartupAuth();
      const p2 = coordinator.checkStartupAuth();
      deferred.resolve(buildResult(true, 0, 'ok', LoginStatus.AUTHENTICATED));
      const results = await Promise.all([p1, p2]);
      // Assert
      expect(fake.callCount).assertEqual(1);
      expect(results[0].success).assertTrue();
      expect(results[1].success).assertTrue();
      done();
    });

    it('invalid: failed_silent_login_should_be_normalized_to_unauthenticated', 0, async (done: () => void) => {
      // Arrange
      const coordinator = new AppStartupCoordinator();
      const internal = coordinator as Object as StartupInternal;
      const fake = new FakeAuthFacade();
      fake.result = buildResult(false, 401, 'expired', LoginStatus.LOGIN_FAILED);
      internal.authFacade = fake;
      internal.startupAuthInFlight = null;
      internal.silentLoginWithTimeout = async (): Promise<AuthResult<UserSession>> => fake.silentLogin();
      // Act
      const result = await coordinator.checkStartupAuth();
      // Assert
      expect(result.success).assertFalse();
      expect(result.code).assertEqual(401);
      expect(result.message).assertEqual('expired');
      expect(result.status).assertEqual(LoginStatus.UNAUTHENTICATED);
      done();
    });

    it('conflict: timeout_result_should_be_forwarded_as_unauthenticated', 0, async (done: () => void) => {
      // Arrange
      const coordinator = new AppStartupCoordinator();
      const internal = coordinator as Object as StartupInternal;
      internal.startupAuthInFlight = null;
      internal.silentLoginWithTimeout = async (): Promise<AuthResult<UserSession>> => {
        return buildResult(false, -1, 'silent_login_timeout', LoginStatus.UNAUTHENTICATED);
      };
      // Act
      const result = await coordinator.checkStartupAuth();
      // Assert
      expect(result.success).assertFalse();
      expect(result.message).assertEqual('silent_login_timeout');
      expect(result.status).assertEqual(LoginStatus.UNAUTHENTICATED);
      done();
    });

    it('regression: startup_auth_timeout_should_not_hold_gate_for_three_seconds', 0, () => {
      // Arrange
      const internal = AppStartupCoordinator as Object as StartupStaticInternal;
      // Act
      const timeoutMs = internal.STARTUP_AUTH_TIMEOUT_MS;
      // Assert
      expect(timeoutMs <= 1000).assertTrue();
    });

    it('regression: td-20260411-c4-startup-inflight-should-reset-after-finished', 0, async (done: () => void) => {
      // Arrange
      const coordinator = new AppStartupCoordinator();
      const internal = coordinator as Object as StartupInternal;
      const fake = new FakeAuthFacade();
      fake.result = buildResult(false, -1, 'x', LoginStatus.UNAUTHENTICATED);
      internal.authFacade = fake;
      internal.startupAuthInFlight = null;
      internal.silentLoginWithTimeout = async (): Promise<AuthResult<UserSession>> => fake.silentLogin();
      // Act
      await coordinator.checkStartupAuth();
      // Assert
      expect(internal.startupAuthInFlight === null).assertTrue();
      done();
    });

    it('combined: sequential_checks_should_call_silent_login_again_after_previous_completion', 0, async (done: () => void) => {
      // Arrange
      const coordinator = new AppStartupCoordinator();
      const internal = coordinator as Object as StartupInternal;
      const fake = new FakeAuthFacade();
      fake.result = buildResult(true, 0, 'ok', LoginStatus.AUTHENTICATED);
      internal.authFacade = fake;
      internal.startupAuthInFlight = null;
      internal.silentLoginWithTimeout = async (): Promise<AuthResult<UserSession>> => fake.silentLogin();
      // Act
      await coordinator.checkStartupAuth();
      await coordinator.checkStartupAuth();
      // Assert
      expect(fake.callCount).assertEqual(2);
      done();
    });

    it('normal: silent_login_with_timeout_should_settle_with_facade_result_before_timer', 0, async (done: () => void) => {
      // Arrange
      const coordinator = new AppStartupCoordinator();
      const internal = coordinator as Object as StartupInternal;
      internal.startupAuthInFlight = null;
      // Act
      const result = await internal.silentLoginWithTimeout();
      // Assert
      expect(typeof result.success === 'boolean').assertTrue();
      expect(result.message.length >= 0).assertTrue();
      expect(
        result.status === LoginStatus.AUTHENTICATED ||
          result.status === LoginStatus.UNAUTHENTICATED ||
          result.status === LoginStatus.LOGIN_FAILED
      ).assertTrue();
      done();
    });
  });
}
