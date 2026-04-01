import { AuthResult, LoginStatus, UserSession } from '../../domain/auth/AuthTypes';
import { AuthFacade } from './AuthFacade';

export class AppStartupCoordinator {
  private static instance: AppStartupCoordinator = new AppStartupCoordinator();
  private readonly authFacade: AuthFacade = AuthFacade.getInstance();
  private startupAuthInFlight: Promise<AuthResult<UserSession>> | null = null;

  public static getInstance(): AppStartupCoordinator {
    return AppStartupCoordinator.instance;
  }

  public async checkStartupAuth(): Promise<AuthResult<UserSession>> {
    if (this.startupAuthInFlight) {
      return this.startupAuthInFlight;
    }
    this.startupAuthInFlight = this.doCheckStartupAuth().finally(() => {
      this.startupAuthInFlight = null;
    });
    return this.startupAuthInFlight;
  }

  private async doCheckStartupAuth(): Promise<AuthResult<UserSession>> {
    const silent = await this.authFacade.silentLogin();
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
}

