import { AppStorageKeys } from '../../common/constants/AppStorageKeys';
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
}
