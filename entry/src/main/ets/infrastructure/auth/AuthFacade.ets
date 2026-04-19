import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AuthErrorCode } from './AuthErrorCode';
import { AuthLoginResult, DeviceInfo, SocialCredential } from '../../domain/auth/AuthModels';
import { AuthResult, HuaweiCredential, LoginStatus, UserSession } from '../../domain/auth/AuthTypes';
import { AuthGateway } from './AuthGateway';
import { HuaweiAccountProvider } from './HuaweiAccountProvider';
import { SessionManager } from './SessionManager';

export class CurrentUserBasicProfile {
  accountId: string = '';
  userId: string = '';
  nickname: string = '';
  avatarUrl: string = '';
  isGuest: boolean = true;
}

export class AuthFacade {
  private static readonly LOG_DOMAIN: number = 0x0000;
  private static readonly LOG_TAG: string = 'AuthFacade';
  private static readonly USERNAME_PATTERN: RegExp = /^[\u4E00-\u9FFFa-zA-Z0-9_ ]+$/;
  private static readonly LOCAL_GUEST_ACCOUNT_ID: string = 'guest_local';
  private static readonly LOCAL_GUEST_SESSION_TTL_MS: number = 30 * 24 * 60 * 60 * 1000;
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
      const fallbackId = session.accountId || session.userId || 'guest_local';
      profile.accountId = session.accountId || '';
      profile.userId = fallbackId;
      profile.nickname = defaultName;
      profile.isGuest = session.isGuest !== false;
      return profile;
    }
    const accountId = String(me.data.accountId || session.accountId || '').trim();
    const userId = String(me.data.userId || session.userId || '').trim();
    profile.accountId = accountId;
    profile.userId = accountId || userId || 'guest_local';
    profile.nickname = String((me.data.nickname || '').trim() || defaultName);
    profile.avatarUrl = String(me.data.avatarUrl || '');
    profile.isGuest = Boolean(me.data.isGuest);
    return profile;
  }

  public async silentLogin(): Promise<AuthResult<UserSession>> {
    const traceId = `sl_${Date.now()}`;
    hilog.info(
      AuthFacade.LOG_DOMAIN,
      AuthFacade.LOG_TAG,
      `[LOGIN_TRACE][facade] silentLogin start trace=${traceId}, hasContext=${this.appContext ? 1 : 0}`
    );
    if (this.sessionManager.isSilentLoginBlockedAfterLogout()) {
      hilog.warn(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, `[LOGIN_TRACE][facade] silentLogin blocked by logout marker(memory) trace=${traceId}`);
      return this.failure(-1, 'silent_login_blocked_after_logout', 'HUAWEI_SILENT', LoginStatus.UNAUTHENTICATED);
    }
    if (this.appContext) {
      const blocked = await this.sessionManager.isSilentLoginBlockedAfterLogoutPersisted(this.appContext);
      if (blocked) {
        hilog.warn(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, `[LOGIN_TRACE][facade] silentLogin blocked by logout marker trace=${traceId}`);
        return this.failure(-1, 'silent_login_blocked_after_logout', 'HUAWEI_SILENT', LoginStatus.UNAUTHENTICATED);
      }
    }
    const local = this.sessionManager.load();
    let workingLocal = local;
    if (!workingLocal && this.appContext) {
      workingLocal = await this.sessionManager.restoreSessionPersisted(this.appContext);
      if (workingLocal) {
          hilog.info(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, `[LOGIN_TRACE][facade] silentLogin restored persisted session trace=${traceId}`);
      }
    }
    if (workingLocal) {
      try {
        const me = await AuthGateway.me(workingLocal.accessToken);
        if (me.code === 0) {
          workingLocal.accountId = me.data.accountId || workingLocal.accountId || '';
          workingLocal.userId = me.data.userId || workingLocal.userId || '';
          workingLocal.isGuest = Boolean(me.data.isGuest);
          workingLocal.loginMethod = me.data.defaultLoginMethod || workingLocal.loginMethod || '';
          workingLocal.loginType = workingLocal.isGuest ? 'guest' : 'huawei';
          workingLocal.isLogin = true;
          workingLocal.lastLoginAt = Date.now();
          await this.onLoginSuccess(workingLocal);
          hilog.info(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, `[LOGIN_TRACE][facade] silentLogin local_session ok trace=${traceId}`);
          return this.success(workingLocal, 'LOCAL_SESSION');
        }

        if (this.isSessionInvalidCode(me.code)) {
          hilog.warn(
            AuthFacade.LOG_DOMAIN,
            AuthFacade.LOG_TAG,
            `[LOGIN_TRACE][facade] silentLogin local_session invalid code=${me.code}, trace=${traceId}`
          );
          this.sessionManager.clear();
          if (this.appContext) {
            await this.sessionManager.clearSessionPersisted(this.appContext);
          }
        } else {
          // 离线或服务异常时保留本地会话，避免重启后卡在登录页。
          workingLocal.isLogin = true;
          workingLocal.lastLoginAt = Date.now();
          await this.onLoginSuccess(workingLocal);
          hilog.warn(
            AuthFacade.LOG_DOMAIN,
            AuthFacade.LOG_TAG,
            `[LOGIN_TRACE][facade] silentLogin local_session fallback code=${me.code}, message=${me.message}, trace=${traceId}`
          );
          return this.success(workingLocal, 'LOCAL_SESSION');
        }
      } catch (error) {
        workingLocal.isLogin = true;
        workingLocal.lastLoginAt = Date.now();
        await this.onLoginSuccess(workingLocal);
        hilog.warn(
          AuthFacade.LOG_DOMAIN,
          AuthFacade.LOG_TAG,
          `[LOGIN_TRACE][facade] silentLogin local_session fallback error=${this.normalizeError(error)}, trace=${traceId}`
        );
        return this.success(workingLocal, 'LOCAL_SESSION');
      }
    }

    if (!this.appContext) {
      // EntryAbility 早期阶段没有可用 UI 上下文，不能走 provider 静默登录。
      hilog.warn(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, `[LOGIN_TRACE][facade] silentLogin skip provider: context unavailable trace=${traceId}`);
      return this.failure(-1, 'silent_login_context_unavailable', 'HUAWEI_SILENT', LoginStatus.UNAUTHENTICATED);
    }

    try {
      const credential = await this.huaweiProvider.silentLogin(this.appContext);
      hilog.info(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, `[LOGIN_TRACE][facade] silentLogin provider ok trace=${traceId}`);
      return this.exchangeHuaweiCredential(credential, 'HUAWEI_SILENT');
    } catch (error) {
      hilog.warn(
        AuthFacade.LOG_DOMAIN,
        AuthFacade.LOG_TAG,
        `[LOGIN_TRACE][facade] silentLogin fail message=${this.normalizeError(error)}, trace=${traceId}`
      );
      return this.failure(-1, this.normalizeError(error), 'HUAWEI_SILENT', LoginStatus.UNAUTHENTICATED);
    }
  }

  public async explicitLoginByButton(credential?: HuaweiCredential, allowGuestFallback: boolean = true): Promise<AuthResult<UserSession>> {
    const traceId = `el_${Date.now()}`;
    hilog.info(
      AuthFacade.LOG_DOMAIN,
      AuthFacade.LOG_TAG,
      `[LOGIN_TRACE][facade] explicitLoginByButton start trace=${traceId}, hasCredential=${credential ? 1 : 0}, allowGuestFallback=${allowGuestFallback ? 1 : 0}, hasContext=${this.appContext ? 1 : 0}`
    );
    try {
      const finalCredential = credential || await this.huaweiProvider.explicitLogin(this.appContext || undefined);
      hilog.info(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, `[LOGIN_TRACE][facade] explicit provider ok trace=${traceId}`);
      return this.exchangeHuaweiCredential(finalCredential, 'HUAWEI_BUTTON');
    } catch (error) {
      hilog.warn(
        AuthFacade.LOG_DOMAIN,
        AuthFacade.LOG_TAG,
        `[LOGIN_TRACE][facade] explicit provider fail message=${this.normalizeError(error)}, trace=${traceId}`
      );
      if (!allowGuestFallback) {
        hilog.warn(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, `[LOGIN_TRACE][facade] explicit guestFallback disabled trace=${traceId}`);
        return this.failure(-1, this.normalizeError(error), 'HUAWEI_BUTTON', LoginStatus.LOGIN_FAILED);
      }
      const guestResult = await this.tryGuestFallback();
      if (guestResult.success) {
        hilog.info(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, `[LOGIN_TRACE][facade] explicit fallback guest ok trace=${traceId}`);
        return guestResult;
      }
      hilog.error(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, `[LOGIN_TRACE][facade] explicit fallback guest fail trace=${traceId}`);
      return this.failure(-1, this.normalizeError(error), 'HUAWEI_BUTTON', LoginStatus.LOGIN_FAILED);
    }
  }

  public async explicitGuestLogin(): Promise<AuthResult<UserSession>> {
    try {
      const result = await this.tryGuestFallback();
      if (result.success && result.data) {
        return result;
      }
      hilog.warn(
        AuthFacade.LOG_DOMAIN,
        AuthFacade.LOG_TAG,
        `[LOGIN_TRACE][facade] explicitGuestLogin force_local_fallback message=${result.message}`
      );
      return await this.forceLocalGuestSuccess('guest_result_failure', result.message);
    } catch (error) {
      const normalized = this.normalizeError(error);
      hilog.error(
        AuthFacade.LOG_DOMAIN,
        AuthFacade.LOG_TAG,
        `[LOGIN_TRACE][facade] explicitGuestLogin force_local_exception message=${normalized}`
      );
      return await this.forceLocalGuestSuccess('guest_exception', normalized);
    }
  }

  public async logout(): Promise<void> {
    this.sessionManager.clear();
    if (this.appContext) {
      await this.sessionManager.clearSessionPersisted(this.appContext);
      await this.sessionManager.markSilentLoginBlockedAfterLogoutPersisted(this.appContext);
      hilog.info(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, '[LOGIN_TRACE][facade] logout set silent_block=1');
      return;
    }
    this.sessionManager.markSilentLoginBlockedAfterLogout();
    hilog.info(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, '[LOGIN_TRACE][facade] logout set silent_block=1(memory_only)');
  }

  public async updateUsername(username: string): Promise<AuthResult<CurrentUserBasicProfile>> {
    const session = this.sessionManager.load();
    if (!session) {
      return this.profileFailure(AuthErrorCode.SESSION_EXPIRED, 'session_expired');
    }
    if (session.isGuest) {
      return this.profileFailure(AuthErrorCode.GUEST_USERNAME_UNSUPPORTED, 'guest_username_unsupported');
    }

    const normalized = this.normalizeAndValidateUsername(username);
    if (!normalized) {
      return this.profileFailure(AuthErrorCode.USERNAME_INVALID, 'username_invalid');
    }

    const response = await AuthGateway.updateUsername(session.accessToken, normalized);
    if (response.code !== 0) {
      return this.profileFailure(response.code, response.message || 'update_username_failed');
    }

    const profile = new CurrentUserBasicProfile();
    profile.accountId = String(response.data.accountId || session.accountId || '');
    profile.userId = String(profile.accountId || response.data.userId || session.userId || '');
    profile.nickname = String((response.data.nickname || '').trim());
    profile.avatarUrl = String(response.data.avatarUrl || '');
    profile.isGuest = Boolean(response.data.isGuest);

    const result = new AuthResult<CurrentUserBasicProfile>();
    result.success = true;
    result.code = 0;
    result.message = 'ok';
    result.source = 'LOCAL_SESSION';
    result.status = LoginStatus.AUTHENTICATED;
    result.data = profile;
    return result;
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
    await this.onLoginSuccess(session);
    hilog.info(
      AuthFacade.LOG_DOMAIN,
      AuthFacade.LOG_TAG,
      `[LOGIN_TRACE][facade] exchange success source=${source}, isGuest=${session.isGuest ? 1 : 0}, accountId=${session.accountId}, userId=${session.userId}`
    );
    return this.success(session, source);
  }

  private async tryGuestFallback(): Promise<AuthResult<UserSession>> {
    hilog.info(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, '[LOGIN_TRACE][facade] guestFallback start');
    try {
      const guest = await AuthGateway.createGuest(this.makeDeviceInfo());
      if (guest.code !== 0) {
        hilog.warn(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, `[LOGIN_TRACE][facade] guestFallback fail code=${guest.code}`);
        const offlineResult = await this.tryOfflineGuestFallback(`gateway_code_${guest.code}`, guest.message || 'guest_login_failed');
        if (offlineResult) {
          return offlineResult;
        }
        return this.failure(guest.code, guest.message || 'guest_login_failed', 'GUEST_FALLBACK', LoginStatus.LOGIN_FAILED);
      }
      const payload = guest.data as AuthLoginResult;
      const session = this.convertSession(payload);
      if (!session) {
        hilog.warn(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, '[LOGIN_TRACE][facade] guestFallback fail session_empty');
        const offlineResult = await this.tryOfflineGuestFallback('session_empty', 'guest_session_empty');
        if (offlineResult) {
          return offlineResult;
        }
        return this.failure(-1, 'guest_session_empty', 'GUEST_FALLBACK', LoginStatus.LOGIN_FAILED);
      }
      session.isGuest = true;
      session.loginType = 'guest';
      session.loginMethod = session.loginMethod || 'GUEST';
      return await this.finalizeGuestSuccess(session, 'remote_session', 'guest_gateway_ok');
    } catch (error) {
      const normalized = this.normalizeError(error);
      hilog.warn(AuthFacade.LOG_DOMAIN, AuthFacade.LOG_TAG, `[LOGIN_TRACE][facade] guestFallback exception=${normalized}`);
      const offlineResult = await this.tryOfflineGuestFallback('gateway_exception', normalized);
      if (offlineResult) {
        return offlineResult;
      }
      return this.failure(-1, normalized, 'GUEST_FALLBACK', LoginStatus.LOGIN_FAILED);
    }
  }

  private async tryOfflineGuestFallback(reason: string, detail: string): Promise<AuthResult<UserSession> | null> {
    const session = this.buildLocalGuestSession('GUEST_OFFLINE');
    return await this.finalizeGuestSuccess(session, reason, detail);
  }

  private buildLocalGuestSession(loginMethod: string): UserSession {
    const now = Date.now();
    const session = new UserSession();
    session.isLogin = true;
    session.accountId = AuthFacade.LOCAL_GUEST_ACCOUNT_ID;
    session.userId = AuthFacade.LOCAL_GUEST_ACCOUNT_ID;
    session.loginType = 'guest';
    session.lastLoginAt = now;
    session.accessToken = '';
    session.refreshToken = '';
    session.expireAt = now + AuthFacade.LOCAL_GUEST_SESSION_TTL_MS;
    session.sessionId = `offline_guest_${now}`;
    session.isGuest = true;
    session.loginMethod = loginMethod;
    return session;
  }

  private async finalizeGuestSuccess(session: UserSession, reason: string, detail: string): Promise<AuthResult<UserSession>> {
    try {
      await this.onLoginSuccess(session);
    } catch (error) {
      hilog.warn(
        AuthFacade.LOG_DOMAIN,
        AuthFacade.LOG_TAG,
        `[LOGIN_TRACE][facade] guestFallback persist_fail reason=${reason}, detail=${detail}, error=${this.normalizeError(error)}`
      );
      this.sessionManager.save(session);
    }

    if (this.appContext) {
      try {
        await this.sessionManager.markGuestChosen(this.appContext);
      } catch (error) {
        hilog.warn(
          AuthFacade.LOG_DOMAIN,
          AuthFacade.LOG_TAG,
          `[LOGIN_TRACE][facade] guestFallback mark_guest_fail reason=${reason}, detail=${detail}, error=${this.normalizeError(error)}`
        );
      }
    }

    hilog.warn(
      AuthFacade.LOG_DOMAIN,
      AuthFacade.LOG_TAG,
      `[LOGIN_TRACE][facade] guestFallback finalized reason=${reason}, detail=${detail}, accountId=${session.accountId}`
    );
    return this.success(session, 'GUEST_FALLBACK');
  }

  private async forceLocalGuestSuccess(reason: string, detail: string): Promise<AuthResult<UserSession>> {
    const session = this.buildLocalGuestSession('GUEST_HARD_FALLBACK');
    return await this.finalizeGuestSuccess(session, reason, detail);
  }

  private convertSession(payload: AuthLoginResult): UserSession | null {
    if (!payload || !payload.session) {
      return null;
    }
    const session = new UserSession();
    session.accountId = payload.user.accountId || '';
    session.userId = payload.user.userId || '';
    session.accessToken = payload.session.accessToken || '';
    session.refreshToken = payload.session.refreshToken || '';
    session.expireAt = this.normalizeExpireAt(payload.session.expireAt);
    session.sessionId = payload.session.sessionId || '';
    session.isGuest = Boolean(payload.user.isGuest);
    session.loginMethod = payload.user.defaultLoginMethod || '';
    session.loginType = session.isGuest ? 'guest' : 'huawei';
    session.isLogin = true;
    session.lastLoginAt = Date.now();
    return session;
  }

  private async onLoginSuccess(session: UserSession): Promise<void> {
    this.sessionManager.save(session);
    if (this.appContext) {
      await this.sessionManager.saveSessionPersisted(this.appContext, session);
    }
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

  private normalizeExpireAt(rawExpireAt: number | string): number {
    const text = String(rawExpireAt || '').trim();
    const numeric = Number(text);
    if (Number.isFinite(numeric) && numeric > 0) {
      // 兼容秒级时间戳
      if (numeric < 1_000_000_000_000) {
        return numeric * 1000;
      }
      return numeric;
    }
    const parsed = Date.parse(text);
    if (!Number.isNaN(parsed) && parsed > 0) {
      return parsed;
    }
    // 兜底 2 小时，避免会话被立即判定为失效
    return Date.now() + 2 * 60 * 60 * 1000;
  }

  private normalizeError(error: Object): string {
    if (error instanceof Error) {
      return error.message || 'auth_error';
    }
    return 'auth_error';
  }

  private isSessionInvalidCode(code: number): boolean {
    return code === AuthErrorCode.SESSION_EXPIRED || code === 401;
  }

  private normalizeAndValidateUsername(rawValue: string): string {
    const normalized = String(rawValue || '').trim();
    if (!normalized || normalized.length > 32) {
      return '';
    }
    if (!AuthFacade.USERNAME_PATTERN.test(normalized)) {
      return '';
    }
    return normalized;
  }

  private profileFailure(code: number, message: string): AuthResult<CurrentUserBasicProfile> {
    const result = new AuthResult<CurrentUserBasicProfile>();
    result.success = false;
    result.code = code;
    result.message = message;
    result.source = 'LOCAL_SESSION';
    result.status = LoginStatus.LOGIN_FAILED;
    result.data = null;
    return result;
  }
}
