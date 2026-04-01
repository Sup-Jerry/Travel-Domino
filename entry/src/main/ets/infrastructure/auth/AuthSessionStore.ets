import { common } from '@kit.AbilityKit';
import { AppStorageKeys } from '../../common/constants/AppStorageKeys';
import { PreferenceManager } from '../../common/utils/PreferenceManager';
import { AuthSessionPayload } from '../../domain/auth/AuthModels';

class StoredSession {
  accountId: string = '';
  userId: string = '';
  isGuest: boolean = false;
  loginMethod: string = '';
  accessToken: string = '';
  refreshToken: string = '';
  sessionId: string = '';
  expireAt: number = 0;
}

export class AuthSessionStore {
  private static toStoredSession(session: AuthSessionPayload): StoredSession {
    const raw = new StoredSession();
    raw.accountId = session.accountId || '';
    raw.userId = session.userId || '';
    raw.isGuest = session.isGuest === true;
    raw.loginMethod = session.loginMethod || '';
    raw.accessToken = session.accessToken;
    raw.refreshToken = session.refreshToken;
    raw.sessionId = session.sessionId;
    raw.expireAt = session.expireAt;
    return raw;
  }

  private static parseStoredSession(rawText: string): AuthSessionPayload | null {
    if (!rawText) {
      return null;
    }
    try {
      const parsed = JSON.parse(rawText) as StoredSession;
      if (!parsed.accessToken || !parsed.refreshToken || !parsed.sessionId) {
        return null;
      }
      const payload = new AuthSessionPayload();
      payload.accountId = parsed.accountId || '';
      payload.userId = parsed.userId || '';
      payload.isGuest = parsed.isGuest === true;
      payload.loginMethod = parsed.loginMethod || '';
      payload.accessToken = parsed.accessToken;
      payload.refreshToken = parsed.refreshToken;
      payload.sessionId = parsed.sessionId;
      payload.expireAt = Number(parsed.expireAt);
      return payload;
    } catch (_error) {
      return null;
    }
  }

  public static save(session: AuthSessionPayload): void {
    const raw = AuthSessionStore.toStoredSession(session);
    AppStorage.setOrCreate(AppStorageKeys.AUTH_SESSION_JSON, JSON.stringify(raw));
  }

  public static load(): AuthSessionPayload | null {
    const rawText = AppStorage.get<string>(AppStorageKeys.AUTH_SESSION_JSON) || '';
    return AuthSessionStore.parseStoredSession(rawText);
  }

  public static getAccessToken(): string {
    const session = AuthSessionStore.load();
    if (!session) {
      return '';
    }
    if (Date.now() >= session.expireAt) {
      return '';
    }
    return session.accessToken;
  }

  public static clear(): void {
    AppStorage.setOrCreate(AppStorageKeys.AUTH_SESSION_JSON, '');
  }

  public static markGuestChosen(): void {
    AppStorage.setOrCreate(AppStorageKeys.AUTH_GUEST_CHOSEN, true);
  }

  public static hasGuestChosen(): boolean {
    return AppStorage.get<boolean>(AppStorageKeys.AUTH_GUEST_CHOSEN) ?? false;
  }

  public static markSilentLoginBlockedAfterLogout(): void {
    AppStorage.setOrCreate(AppStorageKeys.AUTH_BLOCK_SILENT_AFTER_LOGOUT, true);
  }

  public static clearSilentLoginBlockedAfterLogout(): void {
    AppStorage.setOrCreate(AppStorageKeys.AUTH_BLOCK_SILENT_AFTER_LOGOUT, false);
  }

  public static isSilentLoginBlockedAfterLogout(): boolean {
    return AppStorage.get<boolean>(AppStorageKeys.AUTH_BLOCK_SILENT_AFTER_LOGOUT) ?? false;
  }

  public static async markGuestChosenPersisted(context: common.Context): Promise<void> {
    AuthSessionStore.markGuestChosen();
    const pref = PreferenceManager.getInstance();
    await pref.init(context);
    await pref.setGuestChosen(true);
  }

  public static async hasGuestChosenPersisted(context: common.Context): Promise<boolean> {
    if (AuthSessionStore.hasGuestChosen()) {
      return true;
    }
    const pref = PreferenceManager.getInstance();
    await pref.init(context);
    const chosen = await pref.isGuestChosen();
    if (chosen) {
      AuthSessionStore.markGuestChosen();
    }
    return chosen;
  }

  public static async markSilentLoginBlockedAfterLogoutPersisted(context: common.Context): Promise<void> {
    AuthSessionStore.markSilentLoginBlockedAfterLogout();
    const pref = PreferenceManager.getInstance();
    await pref.init(context);
    await pref.setSilentLoginBlockedAfterLogout(true);
  }

  public static async clearSilentLoginBlockedAfterLogoutPersisted(context: common.Context): Promise<void> {
    AuthSessionStore.clearSilentLoginBlockedAfterLogout();
    const pref = PreferenceManager.getInstance();
    await pref.init(context);
    await pref.setSilentLoginBlockedAfterLogout(false);
  }

  public static async isSilentLoginBlockedAfterLogoutPersisted(context: common.Context): Promise<boolean> {
    if (AuthSessionStore.isSilentLoginBlockedAfterLogout()) {
      return true;
    }
    const pref = PreferenceManager.getInstance();
    await pref.init(context);
    const blocked = await pref.isSilentLoginBlockedAfterLogout();
    if (blocked) {
      AuthSessionStore.markSilentLoginBlockedAfterLogout();
    }
    return blocked;
  }

  public static async saveSessionPersisted(context: common.Context, session: AuthSessionPayload): Promise<void> {
    const raw = AuthSessionStore.toStoredSession(session);
    const pref = PreferenceManager.getInstance();
    await pref.init(context);
    await pref.setSessionCacheJson(JSON.stringify(raw));
  }

  public static async loadSessionPersisted(context: common.Context): Promise<AuthSessionPayload | null> {
    const pref = PreferenceManager.getInstance();
    await pref.init(context);
    const rawText = await pref.getSessionCacheJson();
    return AuthSessionStore.parseStoredSession(rawText);
  }

  public static async clearSessionPersisted(context: common.Context): Promise<void> {
    const pref = PreferenceManager.getInstance();
    await pref.init(context);
    await pref.setSessionCacheJson('');
  }
}
