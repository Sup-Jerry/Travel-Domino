import { AuthErrorCode } from './AuthErrorCode';
import {
  AuthApiResponse,
  AuthLoginResult,
  AuthMeResult,
  AuthSessionPayload,
  UpdateUsernamePayload,
  UpdateUsernameResult,
  SocialCredential,
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
  providerUid?: string;
  providerType?: string;
}

export class AuthService {
  private static instance: AuthService = new AuthService();
  private static readonly USERNAME_PATTERN: RegExp = /^[\u4E00-\u9FFFa-zA-Z0-9_ ]+$/;

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
      nickname: '',
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

  public loginWithSocial(
    providerType: string,
    credential: SocialCredential,
    deviceInfo: DeviceInfo
  ): AuthApiResponse<AuthLoginResult> {
    const uid = (credential.unionId || credential.openId || credential.authCode || credential.idToken || '').trim();
    if (uid.length === 0) {
      return this.fail<AuthLoginResult>(AuthErrorCode.THIRD_PARTY_AUTH_FAILED, 'social_credential_invalid', new AuthLoginResult());
    }

    const now = Date.now();
    const providerKey = `${providerType}:${uid}`;
    let user = this.users.find((item: UserRecord) => `${item.providerType || ''}:${item.providerUid || ''}` === providerKey) || null;
    const isNewUser = !user;
    if (!user) {
      user = {
        userId: `u_${this.nextId()}`,
        nickname: this.buildDefaultUsername(),
        isGuest: false,
        providerUid: uid,
        providerType: providerType
      };
      this.users.push(user);
    }

    const accessToken = `social_access_${uid}_${now}`;
    const refreshToken = `social_refresh_${uid}_${now}`;
    const expireAt = now + 7 * 24 * 3600 * 1000;
    const sessionId = `s_${this.nextId()}`;
    this.sessions.push({ userId: user.userId, accessToken, expireAt });

    const session = new AuthSessionPayload();
    session.accessToken = accessToken;
    session.refreshToken = refreshToken;
    session.expireAt = expireAt;
    session.sessionId = sessionId;

    const profile = new AuthUserProfile();
    profile.userId = user.userId;
    profile.nickname = user.nickname;
    profile.isGuest = false;
    profile.profileCompleted = true;
    profile.defaultLoginMethod = 'CUSTOM';

    const result = new AuthLoginResult();
    result.isNewUser = isNewUser;
    result.user = profile;
    result.session = session;
    return this.ok(result);
  }

  public updateUsername(accessToken: string, payload: UpdateUsernamePayload): AuthApiResponse<UpdateUsernameResult> {
    const session = this.sessions.find((item: SessionRecord) => item.accessToken === accessToken) || null;
    if (!session || Date.now() >= session.expireAt) {
      return this.fail<UpdateUsernameResult>(AuthErrorCode.SESSION_EXPIRED, 'session_expired', new UpdateUsernameResult());
    }
    const user = this.users.find((item: UserRecord) => item.userId === session.userId) || null;
    if (!user) {
      return this.fail<UpdateUsernameResult>(AuthErrorCode.ACCOUNT_NOT_FOUND, 'user_not_found', new UpdateUsernameResult());
    }
    if (user.isGuest) {
      return this.fail<UpdateUsernameResult>(AuthErrorCode.GUEST_USERNAME_UNSUPPORTED, 'guest_username_unsupported', new UpdateUsernameResult());
    }

    const username = this.normalizeAndValidateUsername(payload.username);
    if (!username) {
      return this.fail<UpdateUsernameResult>(AuthErrorCode.USERNAME_INVALID, 'username_invalid', new UpdateUsernameResult());
    }
    user.nickname = username;

    const result = new UpdateUsernameResult();
    result.userId = user.userId;
    result.nickname = user.nickname;
    result.avatarUrl = '';
    result.mobileMasked = '';
    result.profileCompleted = true;
    result.isGuest = false;
    result.defaultLoginMethod = 'CUSTOM';
    return this.ok(result);
  }

  private buildGuestFallbackByToken(accessToken: string): AuthMeResult | null {
    if (!accessToken || !accessToken.startsWith('guest_access_')) {
      return null;
    }
    const me = new AuthMeResult();
    me.userId = 'guest_local';
    me.nickname = '';
    me.isGuest = true;
    me.defaultLoginMethod = 'GUEST';
    return me;
  }

  private nextId(): number {
    this.idSeq += 1;
    return this.idSeq;
  }

  private normalizeAndValidateUsername(rawValue: string): string {
    const normalized = String(rawValue || '').trim();
    if (!normalized || normalized.length > 32) {
      return '';
    }
    if (!AuthService.USERNAME_PATTERN.test(normalized)) {
      return '';
    }
    return normalized;
  }

  private buildDefaultUsername(): string {
    return `user_${Date.now() % 100000}`;
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

