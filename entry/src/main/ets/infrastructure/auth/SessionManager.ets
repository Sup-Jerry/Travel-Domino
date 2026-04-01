import { common } from '@kit.AbilityKit';
import { AuthSessionPayload } from '../../domain/auth/AuthModels';
import { UserSession } from '../../domain/auth/AuthTypes';
import { AuthSessionStore } from './AuthSessionStore';

export class SessionManager {
  private static instance: SessionManager = new SessionManager();

  public static getInstance(): SessionManager {
    return SessionManager.instance;
  }

  public save(session: UserSession): void {
    const payload = this.toPayload(session);
    AuthSessionStore.save(payload);
  }

  public load(): UserSession | null {
    const raw = AuthSessionStore.load();
    return this.toSession(raw);
  }

  public async saveSessionPersisted(context: common.Context, session: UserSession): Promise<void> {
    const payload = this.toPayload(session);
    await AuthSessionStore.saveSessionPersisted(context, payload);
  }

  public async restoreSessionPersisted(context: common.Context): Promise<UserSession | null> {
    const raw = await AuthSessionStore.loadSessionPersisted(context);
    const session = this.toSession(raw);
    if (session) {
      this.save(session);
    }
    return session;
  }

  public async clearSessionPersisted(context: common.Context): Promise<void> {
    await AuthSessionStore.clearSessionPersisted(context);
  }

  private toPayload(session: UserSession): AuthSessionPayload {
    const normalizedExpireAt = Number(session.expireAt);
    const payload = new AuthSessionPayload();
    payload.accountId = session.accountId;
    payload.userId = session.userId;
    payload.isGuest = session.isGuest;
    payload.loginMethod = session.loginMethod;
    payload.accessToken = session.accessToken;
    payload.refreshToken = session.refreshToken;
    payload.expireAt = Number.isFinite(normalizedExpireAt) && normalizedExpireAt > 0
      ? normalizedExpireAt
      : Date.now() + 2 * 60 * 60 * 1000;
    payload.sessionId = session.sessionId;
    return payload;
  }

  private toSession(raw: AuthSessionPayload | null): UserSession | null {
    if (!raw) {
      return null;
    }
    if (Date.now() >= Number(raw.expireAt)) {
      return null;
    }

    const session = new UserSession();
    session.isLogin = true;
    session.accountId = raw.accountId || '';
    session.loginType = raw.isGuest === true ? 'guest' : 'huawei';
    session.lastLoginAt = Date.now();
    session.userId = raw.userId || '';
    session.isGuest = raw.isGuest === true;
    session.loginMethod = raw.loginMethod || '';
    session.accessToken = raw.accessToken;
    session.refreshToken = raw.refreshToken;
    session.expireAt = Number(raw.expireAt);
    session.sessionId = raw.sessionId;
    return session;
  }

  public clear(): void {
    AuthSessionStore.clear();
  }

  public saveSession(session: UserSession): void {
    this.save(session);
  }

  public restoreSession(): UserSession | null {
    return this.load();
  }

  public clearSession(): void {
    this.clear();
  }

  public getCurrentAccountId(): string {
    const session = this.load();
    if (!session) {
      return '';
    }
    return (session.accountId || '').trim();
  }

  public isLoggedIn(): boolean {
    return this.load() !== null;
  }

  public async markGuestChosen(context: common.Context): Promise<void> {
    await AuthSessionStore.markGuestChosenPersisted(context);
  }

  public async hasGuestChosen(context: common.Context): Promise<boolean> {
    return AuthSessionStore.hasGuestChosenPersisted(context);
  }

  public markSilentLoginBlockedAfterLogout(): void {
    AuthSessionStore.markSilentLoginBlockedAfterLogout();
  }

  public isSilentLoginBlockedAfterLogout(): boolean {
    return AuthSessionStore.isSilentLoginBlockedAfterLogout();
  }

  public clearSilentLoginBlockedAfterLogout(): void {
    AuthSessionStore.clearSilentLoginBlockedAfterLogout();
  }

  public async markSilentLoginBlockedAfterLogoutPersisted(context: common.Context): Promise<void> {
    await AuthSessionStore.markSilentLoginBlockedAfterLogoutPersisted(context);
  }

  public async clearSilentLoginBlockedAfterLogoutPersisted(context: common.Context): Promise<void> {
    await AuthSessionStore.clearSilentLoginBlockedAfterLogoutPersisted(context);
  }

  public async isSilentLoginBlockedAfterLogoutPersisted(context: common.Context): Promise<boolean> {
    return AuthSessionStore.isSilentLoginBlockedAfterLogoutPersisted(context);
  }
}
