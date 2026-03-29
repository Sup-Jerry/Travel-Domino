import { common } from '@kit.AbilityKit';
import { AuthLoginResult, DeviceInfo, SocialCredential } from '../../domain/auth/AuthModels';
import { AuthResult, HuaweiCredential, LoginStatus, UserSession } from '../../domain/auth/AuthTypes';
import { AuthGateway } from './AuthGateway';
import { HuaweiAccountProvider } from './HuaweiAccountProvider';
import { SessionManager } from './SessionManager';

export class AuthFacade {
  private static instance: AuthFacade = new AuthFacade();
  private readonly sessionManager: SessionManager = SessionManager.getInstance();
  private readonly huaweiProvider: HuaweiAccountProvider = HuaweiAccountProvider.getInstance();
  private appContext: common.Context | null = null;

  public static getInstance(): AuthFacade {
    return AuthFacade.instance;
  }

  public bindContext(context: common.Context): void {
    this.appContext = context;
  }

  public getCurrentSession(): UserSession | null {
    return this.sessionManager.load();
  }

  public async getCurrentNickname(defaultName: string): Promise<string> {
    const session = this.sessionManager.load();
    if (!session) {
      return defaultName;
    }
    const me = await AuthGateway.me(session.accessToken);
    if (me.code !== 0) {
      return defaultName;
    }
    const nickname = (me.data.nickname || '').trim();
    return nickname.length > 0 ? nickname : defaultName;
  }

  public async silentLogin(): Promise<AuthResult<UserSession>> {
    const local = this.sessionManager.load();
    if (local) {
      const me = await AuthGateway.me(local.accessToken);
      if (me.code === 0) {
        local.userId = me.data.userId || '';
        local.isGuest = Boolean(me.data.isGuest);
        local.loginMethod = me.data.defaultLoginMethod || '';
        return this.success(local, 'LOCAL_SESSION');
      }
      this.sessionManager.clear();
    }

    try {
      const credential = await this.huaweiProvider.silentLogin(this.appContext || undefined);
      return this.exchangeHuaweiCredential(credential, 'HUAWEI_SILENT');
    } catch (error) {
      return this.failure(-1, this.normalizeError(error), 'HUAWEI_SILENT', LoginStatus.UNAUTHENTICATED);
    }
  }

  public async explicitLoginByButton(credential?: HuaweiCredential): Promise<AuthResult<UserSession>> {
    try {
      const finalCredential = credential || await this.huaweiProvider.explicitLogin(this.appContext || undefined);
      return this.exchangeHuaweiCredential(finalCredential, 'HUAWEI_BUTTON');
    } catch (error) {
      const guestResult = await this.tryGuestFallback();
      if (guestResult.success) {
        return guestResult;
      }
      return this.failure(-1, this.normalizeError(error), 'HUAWEI_BUTTON', LoginStatus.LOGIN_FAILED);
    }
  }

  public async logout(): Promise<void> {
    this.sessionManager.clear();
  }

  private async exchangeHuaweiCredential(credential: HuaweiCredential, source: 'HUAWEI_BUTTON' | 'HUAWEI_SILENT'): Promise<AuthResult<UserSession>> {
    const socialCredential = new SocialCredential();
    socialCredential.authCode = credential.authorizationCode;
    socialCredential.idToken = credential.idToken;
    socialCredential.openId = credential.openId;
    socialCredential.unionId = credential.unionId;

    const result = await AuthGateway.loginWithSocial('HUAWEI', socialCredential, this.makeDeviceInfo());
    if (result.code !== 0) {
      return this.failure(result.code, result.message || 'social_login_failed', source, LoginStatus.LOGIN_FAILED);
    }

    const payload = result.data as AuthLoginResult;
    const session = this.convertSession(payload);
    if (!session) {
      return this.failure(-1, 'session_empty', source, LoginStatus.LOGIN_FAILED);
    }
    this.onLoginSuccess(session);
    return this.success(session, source);
  }

  private async tryGuestFallback(): Promise<AuthResult<UserSession>> {
    const guest = await AuthGateway.createGuest(this.makeDeviceInfo());
    if (guest.code !== 0) {
      return this.failure(guest.code, guest.message || 'guest_login_failed', 'GUEST_FALLBACK', LoginStatus.LOGIN_FAILED);
    }
    const payload = guest.data as AuthLoginResult;
    const session = this.convertSession(payload);
    if (!session) {
      return this.failure(-1, 'guest_session_empty', 'GUEST_FALLBACK', LoginStatus.LOGIN_FAILED);
    }
    session.isGuest = true;
    this.onLoginSuccess(session);
    if (this.appContext) {
      await this.sessionManager.markGuestChosen(this.appContext);
    }
    return this.success(session, 'GUEST_FALLBACK');
  }

  private convertSession(payload: AuthLoginResult): UserSession | null {
    if (!payload || !payload.session) {
      return null;
    }
    const session = new UserSession();
    session.userId = payload.user.userId || '';
    session.accessToken = payload.session.accessToken || '';
    session.refreshToken = payload.session.refreshToken || '';
    session.expireAt = Number(payload.session.expireAt);
    session.sessionId = payload.session.sessionId || '';
    session.isGuest = Boolean(payload.user.isGuest);
    session.loginMethod = payload.user.defaultLoginMethod || '';
    return session;
  }

  private onLoginSuccess(session: UserSession): void {
    this.sessionManager.save(session);
  }

  private makeDeviceInfo(): DeviceInfo {
    return new DeviceInfo('device-local', 'HarmonyDevice', 'HARMONY');
  }

  private success(session: UserSession, source: 'LOCAL_SESSION' | 'HUAWEI_BUTTON' | 'HUAWEI_SILENT' | 'GUEST_FALLBACK'): AuthResult<UserSession> {
    const result = new AuthResult<UserSession>();
    result.success = true;
    result.code = 0;
    result.message = 'ok';
    result.source = source;
    result.status = LoginStatus.AUTHENTICATED;
    result.data = session;
    return result;
  }

  private failure(
    code: number,
    message: string,
    source: 'HUAWEI_BUTTON' | 'HUAWEI_SILENT' | 'GUEST_FALLBACK',
    status: LoginStatus
  ): AuthResult<UserSession> {
    const result = new AuthResult<UserSession>();
    result.success = false;
    result.code = code;
    result.message = message;
    result.source = source;
    result.status = status;
    result.data = null;
    return result;
  }

  private normalizeError(error: Object): string {
    if (error instanceof Error) {
      return error.message || 'auth_error';
    }
    return 'auth_error';
  }
}
