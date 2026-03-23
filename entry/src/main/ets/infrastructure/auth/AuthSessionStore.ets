import { common } from '@kit.AbilityKit';
import { AppStorageKeys } from '../../common/constants/AppStorageKeys';
import { PreferenceManager } from '../../common/utils/PreferenceManager';
import { AuthSessionPayload } from '../../domain/auth/AuthModels';

class StoredSession {
  accessToken: string = '';
  refreshToken: string = '';
  sessionId: string = '';
  expireAt: number = 0;
}

export class AuthSessionStore {
  public static save(session: AuthSessionPayload): void {
    const raw = new StoredSession();
    raw.accessToken = session.accessToken;
    raw.refreshToken = session.refreshToken;
    raw.sessionId = session.sessionId;
    raw.expireAt = session.expireAt;
    AppStorage.setOrCreate(AppStorageKeys.AUTH_SESSION_JSON, JSON.stringify(raw));
  }

  public static load(): StoredSession | null {
    const rawText = AppStorage.get<string>(AppStorageKeys.AUTH_SESSION_JSON) || '';
    if (!rawText) {
      return null;
    }
    try {
      const parsed = JSON.parse(rawText) as StoredSession;
      if (!parsed.accessToken || !parsed.refreshToken || !parsed.sessionId) {
        return null;
      }
      return parsed;
    } catch (_error) {
      return null;
    }
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
}
