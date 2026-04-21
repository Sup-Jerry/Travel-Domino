import { AuthResult, LoginStatus, UserSession } from '../../domain/auth/AuthTypes';
import { AuthFacade } from './AuthFacade';
import { hilog } from '@kit.PerformanceAnalysisKit';

export class AppStartupCoordinator {
  private static readonly LOG_DOMAIN: number = 0x0000;
  private static readonly LOG_TAG: string = 'AppStartupCoordinator';
  private static readonly STARTUP_AUTH_TIMEOUT_MS: number = 900;
  private static instance: AppStartupCoordinator = new AppStartupCoordinator();
  private readonly authFacade: AuthFacade = AuthFacade.getInstance();
  private startupAuthInFlight: Promise<AuthResult<UserSession>> | null = null;

  public static getInstance(): AppStartupCoordinator {
    return AppStartupCoordinator.instance;
  }

  public async checkStartupAuth(): Promise<AuthResult<UserSession>> {
    if (this.startupAuthInFlight) {
      hilog.info(AppStartupCoordinator.LOG_DOMAIN, AppStartupCoordinator.LOG_TAG, '[LOGIN_TRACE][startup] reuse in_flight startup auth');
      return this.startupAuthInFlight;
    }
    hilog.info(AppStartupCoordinator.LOG_DOMAIN, AppStartupCoordinator.LOG_TAG, '[LOGIN_TRACE][startup] checkStartupAuth start');
    this.startupAuthInFlight = this.doCheckStartupAuth().finally(() => {
      hilog.info(AppStartupCoordinator.LOG_DOMAIN, AppStartupCoordinator.LOG_TAG, '[LOGIN_TRACE][startup] checkStartupAuth end clear in_flight');
      this.startupAuthInFlight = null;
    });
    return this.startupAuthInFlight;
  }

  private async doCheckStartupAuth(): Promise<AuthResult<UserSession>> {
    const silent = await this.silentLoginWithTimeout();
    hilog.info(
      AppStartupCoordinator.LOG_DOMAIN,
      AppStartupCoordinator.LOG_TAG,
      `[LOGIN_TRACE][startup] silent result success=${silent.success ? 1 : 0}, code=${silent.code}, source=${silent.source}, status=${silent.status}`
    );
    if (silent.success) {
      return silent;
    }
    const result = new AuthResult<UserSession>();
    result.success = false;
    result.code = silent.code;
    result.message = silent.message;
    result.source = silent.source;
    result.status = LoginStatus.UNAUTHENTICATED;
    result.data = null;
    return result;
  }

  private async silentLoginWithTimeout(): Promise<AuthResult<UserSession>> {
    let timeoutId: number = -1;
    const timeoutPromise = new Promise<AuthResult<UserSession>>((resolve) => {
      timeoutId = setTimeout(() => {
        const timeoutResult = new AuthResult<UserSession>();
        timeoutResult.success = false;
        timeoutResult.code = -1;
        timeoutResult.message = 'silent_login_timeout';
        timeoutResult.source = 'HUAWEI_SILENT';
        timeoutResult.status = LoginStatus.UNAUTHENTICATED;
        timeoutResult.data = null;
        hilog.warn(
          AppStartupCoordinator.LOG_DOMAIN,
          AppStartupCoordinator.LOG_TAG,
          `[LOGIN_TRACE][startup] silent_login_timeout timeout_ms=${AppStartupCoordinator.STARTUP_AUTH_TIMEOUT_MS}`
        );
        resolve(timeoutResult);
      }, AppStartupCoordinator.STARTUP_AUTH_TIMEOUT_MS) as number;
    });

    try {
      const silentPromise = this.authFacade.silentLogin();
      return await Promise.race([silentPromise, timeoutPromise]);
    } finally {
      if (timeoutId > 0) {
        clearTimeout(timeoutId);
      }
    }
  }
}

