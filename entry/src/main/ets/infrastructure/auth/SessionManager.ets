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
    const payload = new AuthSessionPayload();
    payload.accessToken = session.accessToken;
    payload.refreshToken = session.refreshToken;
    payload.expireAt = session.expireAt;
    payload.sessionId = session.sessionId;
    AuthSessionStore.save(payload);
  }

  public load(): UserSession | null {
    const raw = AuthSessionStore.load();
    if (!raw) {
      return null;
    }
    if (Date.now() >= Number(raw.expireAt)) {
      return null;
    }

    const session = new UserSession();
    session.accessToken = raw.accessToken;
    session.refreshToken = raw.refreshToken;
    session.expireAt = Number(raw.expireAt);
    session.sessionId = raw.sessionId;
    return session;
  }

  public clear(): void {
    AuthSessionStore.clear();
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
