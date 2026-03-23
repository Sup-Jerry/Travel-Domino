import { AuthErrorCode } from './AuthErrorCode';
import {
  AuthApiResponse,
  AuthLoginResult,
  AuthMeResult,
  AuthSessionPayload,
  AuthUserProfile,
  DeviceInfo
} from '../../domain/auth/AuthModels';

interface SessionRecord {
  userId: string;
  accessToken: string;
  expireAt: number;
}

interface UserRecord {
  userId: string;
  nickname: string;
  isGuest: boolean;
}

export class AuthService {
  private static instance: AuthService = new AuthService();

  private idSeq: number = 1000;
  private users: UserRecord[] = [];
  private sessions: SessionRecord[] = [];

  static getInstance(): AuthService {
    return AuthService.instance;
  }

  public createGuest(deviceInfo: DeviceInfo): AuthApiResponse<AuthLoginResult> {
    const now = Date.now();
    const userId = `u_${this.nextId()}`;
    const user: UserRecord = {
      userId,
      nickname: `游客${this.idSeq}`,
      isGuest: true
    };
    this.users.push(user);

    const accessToken = `guest_access_${deviceInfo.deviceId}_${now}`;
    const refreshToken = `guest_refresh_${deviceInfo.deviceId}_${now}`;
    const expireAt = now + 7 * 24 * 3600 * 1000;
    const sessionId = `s_${this.nextId()}`;
    this.sessions.push({ userId, accessToken, expireAt });

    const session = new AuthSessionPayload();
    session.accessToken = accessToken;
    session.refreshToken = refreshToken;
    session.expireAt = expireAt;
    session.sessionId = sessionId;

    const profile = new AuthUserProfile();
    profile.userId = user.userId;
    profile.nickname = user.nickname;
    profile.isGuest = true;
    profile.profileCompleted = false;
    profile.defaultLoginMethod = 'GUEST';

    const result = new AuthLoginResult();
    result.isNewUser = true;
    result.user = profile;
    result.session = session;
    return this.ok(result);
  }

  public getMe(accessToken: string): AuthApiResponse<AuthMeResult> {
    const session = this.sessions.find((item: SessionRecord) => item.accessToken === accessToken) || null;
    if (!session || Date.now() >= session.expireAt) {
      const guestFallback = this.buildGuestFallbackByToken(accessToken);
      if (guestFallback) {
        return this.ok(guestFallback);
      }
      return this.fail<AuthMeResult>(AuthErrorCode.SESSION_EXPIRED, 'session_expired', new AuthMeResult());
    }
    const user = this.users.find((item: UserRecord) => item.userId === session.userId) || null;
    if (!user) {
      return this.fail<AuthMeResult>(AuthErrorCode.ACCOUNT_NOT_FOUND, 'user_not_found', new AuthMeResult());
    }

    const me = new AuthMeResult();
    me.userId = user.userId;
    me.nickname = user.nickname;
    me.isGuest = user.isGuest;
    me.defaultLoginMethod = 'GUEST';
    return this.ok(me);
  }

  private buildGuestFallbackByToken(accessToken: string): AuthMeResult | null {
    if (!accessToken || !accessToken.startsWith('guest_access_')) {
      return null;
    }
    const me = new AuthMeResult();
    me.userId = 'guest_local';
    me.nickname = '游客用户';
    me.isGuest = true;
    me.defaultLoginMethod = 'GUEST';
    return me;
  }

  private nextId(): number {
    this.idSeq += 1;
    return this.idSeq;
  }

  private ok<T>(data: T): AuthApiResponse<T> {
    const response = new AuthApiResponse<T>(data);
    response.code = 0;
    response.message = 'ok';
    response.requestId = `${Date.now()}`;
    return response;
  }

  private fail<T>(code: number, message: string, fallback: T): AuthApiResponse<T> {
    const response = new AuthApiResponse<T>(fallback);
    response.code = code;
    response.message = message;
    response.requestId = `${Date.now()}`;
    return response;
  }
}
