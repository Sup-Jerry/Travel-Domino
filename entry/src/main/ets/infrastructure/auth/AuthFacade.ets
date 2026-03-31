import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AuthLoginResult, DeviceInfo, SocialCredential } from '../../domain/auth/AuthModels';
import { AuthResult, HuaweiCredential, LoginStatus, UserSession } from '../../domain/auth/AuthTypes';
import { AuthGateway } from './AuthGateway';
import { HuaweiAccountProvider } from './HuaweiAccountProvider';
import { SessionManager } from './SessionManager';

export class CurrentUserBasicProfile {
  userId: string = '';
  nickname: string = '';
  avatarUrl: string = '';
  isGuest: boolean = true;
}

export class AuthFacade {
  private static readonly LOG_DOMAIN: number = 0x0000;
  private static readonly LOG_TAG: string = 'AuthFacade';
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

  public async getCurrentUserProfile(defaultName: string): Promise<CurrentUserBasicProfile> {
    const profile = new CurrentUserBasicProfile();
    const session = this.sessionManager.load();
    if (!session) {
      profile.userId = 'guest_local';
      profile.nickname = defaultName;
      profile.isGuest = true;
      return profile;
    }
    const me = await AuthGateway.me(session.accessToken);
    if (me.code !== 0) {
      profile.userId = session.userId || 'guest_local';
      profile.nickname = defaultName;
      profile.isGuest = session.isGuest !== false;
      return profile;
    }
    profile.userId = String(me.data.userId || session.userId || 'guest_local');
    profile.nickname = String((me.data.nickname || '').trim() || defaultName);
    profile.avatarUrl = String(me.data.avatarUrl || '');
    profile.isGuest = Boolean(me.data.isGuest);
    return profile;
  }

  public async silentLogin(): Promise<AuthResult<UserSession>> {
    hilog.info(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, '[LOGIN_TRACE][facade] silentLogin start');
    if (this.appContext) {
      const blocked = await this.sessionManager.isSilentLoginBlockedAfterLogoutPersisted(this.appContext);
      if (blocked) {
        hilog.warn(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, '[LOGIN_TRACE][facade] silentLogin blocked by logout marker');
        return this.failure(-1, 'silent_login_blocked_after_logout', 'HUAWEI_SILENT', LoginStatus.UNAUTHENTICATED);
      }
    }
    const local = this.sessionManager.load();
    if (local) {
      const me = await AuthGateway.me(local.accessToken);
      if (me.code === 0) {
        local.userId = me.data.userId || '';
        local.isGuest = Boolean(me.data.isGuest);
        local.loginMethod = me.data.defaultLoginMethod || '';
        hilog.info(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, '[LOGIN_TRACE][facade] silentLogin local_session ok');
        return this.success(local, 'LOCAL_SESSION');
      }
      hilog.warn(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, `[LOGIN_TRACE][facade] silentLogin local_session invalid code=${me.code}`);
      this.sessionManager.clear();
    }

    try {
      const credential = await this.huaweiProvider.silentLogin(this.appContext || undefined);
      hilog.info(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, '[LOGIN_TRACE][facade] silentLogin provider ok');
      return this.exchangeHuaweiCredential(credential, 'HUAWEI_SILENT');
    } catch (error) {
      hilog.warn(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, `[LOGIN_TRACE][facade] silentLogin fail message=${this.normalizeError(error)}`);
      return this.failure(-1, this.normalizeError(error), 'HUAWEI_SILENT', LoginStatus.UNAUTHENTICATED);
    }
  }

  public async explicitLoginByButton(credential?: HuaweiCredential, allowGuestFallback: boolean = true): Promise<AuthResult<UserSession>> {
    hilog.info(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, '[LOGIN_TRACE][facade] explicitLoginByButton start');
    try {
      const finalCredential = credential || await this.huaweiProvider.explicitLogin(this.appContext || undefined);
      hilog.info(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, '[LOGIN_TRACE][facade] explicit provider ok');
      return this.exchangeHuaweiCredential(finalCredential, 'HUAWEI_BUTTON');
    } catch (error) {
      hilog.warn(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, `[LOGIN_TRACE][facade] explicit provider fail message=${this.normalizeError(error)}`);
      if (!allowGuestFallback) {
        hilog.warn(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, '[LOGIN_TRACE][facade] explicit guestFallback disabled');
        return this.failure(-1, this.normalizeError(error), 'HUAWEI_BUTTON', LoginStatus.LOGIN_FAILED);
      }
      const guestResult = await this.tryGuestFallback();
      if (guestResult.success) {
        hilog.info(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, '[LOGIN_TRACE][facade] explicit fallback guest ok');
        return guestResult;
      }
      hilog.error(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, '[LOGIN_TRACE][facade] explicit fallback guest fail');
      return this.failure(-1, this.normalizeError(error), 'HUAWEI_BUTTON', LoginStatus.LOGIN_FAILED);
    }
  }

  public async explicitGuestLogin(): Promise<AuthResult<UserSession>> {
    return this.tryGuestFallback();
  }

  public async logout(): Promise<void> {
    this.sessionManager.clear();
    if (this.appContext) {
      await this.sessionManager.markSilentLoginBlockedAfterLogoutPersisted(this.appContext);
      hilog.info(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, '[LOGIN_TRACE][facade] logout set silent_block=1');
      return;
    }
    this.sessionManager.markSilentLoginBlockedAfterLogout();
    hilog.info(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, '[LOGIN_TRACE][facade] logout set silent_block=1(memory_only)');
  }

  private async exchangeHuaweiCredential(credential: HuaweiCredential, source: 'HUAWEI_BUTTON' | 'HUAWEI_SILENT'): Promise<AuthResult<UserSession>> {
    const socialCredential = new SocialCredential();
    socialCredential.authCode = credential.authorizationCode;
    socialCredential.idToken = credential.idToken;
    socialCredential.openId = credential.openId;
    socialCredential.unionId = credential.unionId;

    hilog.info(
      AuthFacade.LOG_DOMAIN,
      AuthFacade.LOG_TAG,
      `[LOGIN_TRACE][facade] exchange start source=${source}, authCodeLen=${credential.authorizationCode.length}, openIdLen=${credential.openId.length}, unionIdLen=${credential.unionId.length}`
    );
    const result = await AuthGateway.loginWithSocial('HUAWEI', socialCredential, this.makeDeviceInfo());
    if (result.code !== 0) {
      hilog.warn(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, `[LOGIN_TRACE][facade] exchange fail code=${result.code}, message=${result.message}`);
      return this.failure(result.code, result.message || 'social_login_failed', source, LoginStatus.LOGIN_FAILED);
    }

    const payload = result.data as AuthLoginResult;
    const session = this.convertSession(payload);
    if (!session) {
      hilog.warn(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, '[LOGIN_TRACE][facade] exchange fail session_empty');
      return this.failure(-1, 'session_empty', source, LoginStatus.LOGIN_FAILED);
    }
    if (source === 'HUAWEI_BUTTON') {
      if (this.appContext) {
        await this.sessionManager.clearSilentLoginBlockedAfterLogoutPersisted(this.appContext);
      } else {
        this.sessionManager.clearSilentLoginBlockedAfterLogout();
      }
      hilog.info(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, '[LOGIN_TRACE][facade] explicit success clear silent_block=0');
    }
    this.onLoginSuccess(session);
    hilog.info(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, `[LOGIN_TRACE][facade] exchange success source=${source}, isGuest=${session.isGuest ? 1 : 0}`);
    return this.success(session, source);
  }

  private async tryGuestFallback(): Promise<AuthResult<UserSession>> {
    hilog.info(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, '[LOGIN_TRACE][facade] guestFallback start');
    const guest = await AuthGateway.createGuest(this.makeDeviceInfo());
    if (guest.code !== 0) {
      hilog.warn(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, `[LOGIN_TRACE][facade] guestFallback fail code=${guest.code}`);
      return this.failure(guest.code, guest.message || 'guest_login_failed', 'GUEST_FALLBACK', LoginStatus.LOGIN_FAILED);
    }
    const payload = guest.data as AuthLoginResult;
    const session = this.convertSession(payload);
    if (!session) {
      hilog.warn(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, '[LOGIN_TRACE][facade] guestFallback fail session_empty');
      return this.failure(-1, 'guest_session_empty', 'GUEST_FALLBACK', LoginStatus.LOGIN_FAILED);
    }
    session.isGuest = true;
    this.onLoginSuccess(session);
    if (this.appContext) {
      await this.sessionManager.markGuestChosen(this.appContext);
    }
    hilog.info(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, '[LOGIN_TRACE][facade] guestFallback success');
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
