import { AuthResult, LoginStatus, UserSession } from '../../domain/auth/AuthTypes';
import { AuthFacade } from './AuthFacade';

export class AppStartupCoordinator {
  private static instance: AppStartupCoordinator = new AppStartupCoordinator();
  private readonly authFacade: AuthFacade = AuthFacade.getInstance();

  public static getInstance(): AppStartupCoordinator {
    return AppStartupCoordinator.instance;
  }

  public async checkStartupAuth(): Promise<AuthResult<UserSession>> {
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

