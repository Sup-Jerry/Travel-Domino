import {
  AuthApiResponse,
  AuthCancelResult,
  AuthCodeSendResult,
  AuthGuestUpgradeResult,
  AuthIdentityView,
  AuthLoginResult,
  AuthMeResult,
  AuthProviderType,
  AuthSessionListItem,
  AuthSessionPayload,
  AuthSimpleResult,
  AuthSocialLoginResult,
  AuthSocialPendingProfile,
  AuthUserProfile,
  DeviceInfo,
  SocialCredential
} from '../../domain/auth/AuthModels';
import { AuthErrorCode } from './AuthErrorCode';

class UserRecord {
  userId: string = '';
  nickname: string = '';
  avatarUrl: string = '';
  mobileMasked: string = '';
  status: string = 'ACTIVE';
  isGuest: boolean = false;
  profileCompleted: boolean = false;
  defaultLoginMethod: AuthProviderType = 'PHONE';
  registerTime: number = 0;
  lastLoginTime: number = 0;
  mobileBindTime: number = 0;
}

class IdentityRecord {
  identityId: string = '';
  userId: string = '';
  providerType: AuthProviderType = 'PHONE';
  providerUid: string = '';
  phoneNumber: string = '';
  bindStatus: string = 'BOUND';
  lastUsedTime: number = 0;
}

class SessionRecord {
  sessionId: string = '';
  userId: string = '';
  deviceId: string = '';
  deviceName: string = '';
  platform: string = '';
  accessToken: string = '';
  refreshToken: string = '';
  issuedAt: number = 0;
  expireAt: number = 0;
  status: string = 'ACTIVE';
  loginMethod: AuthProviderType = 'PHONE';
}

class VerifyRecord {
  codeId: string = '';
  phoneNumber: string = '';
  codeHash: string = '';
  bizType: string = '';
  expiredAt: number = 0;
  status: string = 'PENDING';
}

class PendingSocialRecord {
  token: string = '';
  providerType: AuthProviderType = 'WECHAT';
  providerUid: string = '';
  nickname: string = '';
  avatarUrl: string = '';
}

class WindowCounter {
  startAt: number = 0;
  count: number = 0;
}

export class AuthService {
  private static instance: AuthService;
  private users: UserRecord[] = [];
  private identities: IdentityRecord[] = [];
  private sessions: SessionRecord[] = [];
  private verifyCodes: VerifyRecord[] = [];
  private pendingSocials: PendingSocialRecord[] = [];
  private lastCodeByPhone: Map<string, string> = new Map();
  private phoneCooldown: Map<string, number> = new Map();
  private phoneWindow: Map<string, WindowCounter> = new Map();
  private deviceWindow: Map<string, WindowCounter> = new Map();
  private ipWindow: Map<string, WindowCounter> = new Map();
  private requirePhoneFallback: boolean = false;
  private idSeq: number = 1000;
  private reqSeq: number = 0;

  private readonly codeExpireMs: number = 5 * 60 * 1000;
  private readonly accessExpireMs: number = 2 * 60 * 60 * 1000;
  private readonly refreshExpireMs: number = 30 * 24 * 60 * 60 * 1000;
  private readonly sendCooldownMs: number = 60 * 1000;
  private readonly sendWindowMs: number = 60 * 60 * 1000;

  public static getInstance(): AuthService {
    if (!AuthService.instance) {
      AuthService.instance = new AuthService();
    }
    return AuthService.instance;
  }

  public setRequirePhoneFallback(enabled: boolean): void {
    this.requirePhoneFallback = enabled;
  }

  public resetForTest(): void {
    this.users = [];
    this.identities = [];
    this.sessions = [];
    this.verifyCodes = [];
    this.pendingSocials = [];
    this.lastCodeByPhone.clear();
    this.phoneCooldown.clear();
    this.phoneWindow.clear();
    this.deviceWindow.clear();
    this.ipWindow.clear();
    this.requirePhoneFallback = false;
    this.idSeq = 1000;
    this.reqSeq = 0;
  }

  public debugPeekLatestCode(phoneNumber: string): string {
    return this.lastCodeByPhone.get(phoneNumber) || '';
  }

  public debugIssuePhoneCode(phoneNumber: string): string {
    const code = this.generateCode();
    this.lastCodeByPhone.set(phoneNumber, code);
    const rec = new VerifyRecord();
    rec.codeId = this.nextId('code');
    rec.phoneNumber = phoneNumber;
    rec.codeHash = code;
    rec.bizType = 'REGISTER_LOGIN';
    rec.expiredAt = Date.now() + this.codeExpireMs;
    this.verifyCodes.push(rec);
    return code;
  }

  public createGuest(deviceInfo: DeviceInfo): AuthApiResponse<AuthLoginResult> {
    const now = Date.now();
    const user = this.createUser('游客', true, 'GUEST', now);
    this.createIdentity(user.userId, 'GUEST', `guest_${deviceInfo.deviceId}_${now}`, '');
    const session = this.issueSession(user.userId, deviceInfo, 'GUEST');
    const data = this.buildLoginResult(user, session, true);
    return this.ok(data);
  }

  public upgradeGuest(guestUserId: string, targetUserId: string): AuthApiResponse<AuthGuestUpgradeResult> {
    const guest = this.findUser(guestUserId);
    const target = this.findUser(targetUserId);
    if (!guest || !target || !guest.isGuest) {
      return this.fail(AuthErrorCode.INVALID_PARAM, 'invalid_guest_or_target', new AuthGuestUpgradeResult());
    }
    guest.status = 'CANCELLED';
    const result = new AuthGuestUpgradeResult();
    result.migrateStatus = 'DONE';
    return this.ok(result);
  }

  public sendPhoneCode(
    phoneNumber: string,
    countryCode: string,
    bizType: string,
    deviceId: string,
    ipAddress: string
  ): AuthApiResponse<AuthCodeSendResult> {
    if (!this.isValidPhone(phoneNumber) || countryCode.length === 0) {
      return this.fail(AuthErrorCode.INVALID_PARAM, 'invalid_phone_number', new AuthCodeSendResult());
    }

    const now = Date.now();
    const lastTs = this.phoneCooldown.get(phoneNumber) || 0;
    if (now - lastTs < this.sendCooldownMs) {
      return this.fail(AuthErrorCode.SMS_SEND_TOO_FREQUENT, 'send_too_frequent', new AuthCodeSendResult());
    }

    if (!this.incrementWindow(this.phoneWindow, `phone:${phoneNumber}`, 10, now) ||
      !this.incrementWindow(this.deviceWindow, `device:${deviceId}`, 20, now) ||
      !this.incrementWindow(this.ipWindow, `ip:${ipAddress}`, 50, now)) {
      return this.fail(AuthErrorCode.RISK_BLOCKED, 'rate_limit_exceeded', new AuthCodeSendResult());
    }

    const code = this.generateCode();
    this.phoneCooldown.set(phoneNumber, now);
    this.lastCodeByPhone.set(phoneNumber, code);

    const rec = new VerifyRecord();
    rec.codeId = this.nextId('code');
    rec.phoneNumber = phoneNumber;
    rec.codeHash = code;
    rec.bizType = bizType;
    rec.expiredAt = now + this.codeExpireMs;
    this.verifyCodes.push(rec);

    const data = new AuthCodeSendResult();
    data.expireInSeconds = Math.floor(this.codeExpireMs / 1000);
    data.retryAfterSeconds = Math.floor(this.sendCooldownMs / 1000);
    return this.ok(data);
  }

  public loginWithPhone(
    phoneNumber: string,
    countryCode: string,
    code: string,
    agreementAccepted: boolean,
    deviceInfo: DeviceInfo
  ): AuthApiResponse<AuthLoginResult> {
    if (!agreementAccepted) {
      return this.fail(AuthErrorCode.AGREEMENT_NOT_ACCEPTED, 'agreement_not_accepted', new AuthLoginResult());
    }
    if (!this.isValidPhone(phoneNumber) || countryCode.length === 0 || code.length === 0) {
      return this.fail(AuthErrorCode.INVALID_PARAM, 'invalid_payload', new AuthLoginResult());
    }

    const verifyCode = this.verifyPhoneCode(phoneNumber, code);
    if (verifyCode !== AuthErrorCode.OK) {
      const message = verifyCode === AuthErrorCode.SMS_CODE_EXPIRED ? 'code_expired' : 'code_invalid';
      return this.fail(verifyCode, message, new AuthLoginResult());
    }

    const now = Date.now();
    const phoneIdentity = this.findIdentityByPhone(phoneNumber);
    let user: UserRecord;
    let isNewUser = false;

    if (!phoneIdentity) {
      user = this.createUser(`用户${this.idSeq}`, false, 'PHONE', now);
      user.mobileBindTime = now;
      user.mobileMasked = this.maskPhone(phoneNumber);
      this.createIdentity(user.userId, 'PHONE', phoneNumber, phoneNumber);
      isNewUser = true;
    } else {
      const hit = this.findUser(phoneIdentity.userId);
      if (!hit || !this.isUserActive(hit)) {
        return this.fail(AuthErrorCode.RISK_BLOCKED, 'user_status_blocked', new AuthLoginResult());
      }
      user = hit;
      user.lastLoginTime = now;
      user.defaultLoginMethod = 'PHONE';
      phoneIdentity.lastUsedTime = now;
    }

    const session = this.issueSession(user.userId, deviceInfo, 'PHONE');
    const data = this.buildLoginResult(user, session, isNewUser);
    return this.ok(data);
  }

  public loginWithSocial(
    providerType: AuthProviderType,
    credential: SocialCredential,
    agreementAccepted: boolean,
    deviceInfo: DeviceInfo
  ): AuthApiResponse<AuthSocialLoginResult> {
    if (!agreementAccepted) {
      return this.fail(AuthErrorCode.AGREEMENT_NOT_ACCEPTED, 'agreement_not_accepted', new AuthSocialLoginResult());
    }

    const providerUid = this.resolveProviderUid(credential);
    if (providerUid.length === 0) {
      return this.fail(AuthErrorCode.THIRD_PARTY_AUTH_FAILED, 'missing_credential', new AuthSocialLoginResult());
    }

    const boundIdentity = this.findIdentityByProvider(providerType, providerUid);
    if (boundIdentity) {
      const user = this.findUser(boundIdentity.userId);
      if (!user || !this.isUserActive(user)) {
        return this.fail(AuthErrorCode.RISK_BLOCKED, 'user_status_blocked', new AuthSocialLoginResult());
      }
      const session = this.issueSession(user.userId, deviceInfo, providerType);
      const login = this.buildLoginResult(user, session, false);
      const data = new AuthSocialLoginResult();
      data.action = 'LOGIN_SUCCESS';
      data.loginResult = login;
      return this.ok(data);
    }

    const pending = new PendingSocialRecord();
    pending.token = `pt_${this.nextId('pending')}`;
    pending.providerType = providerType;
    pending.providerUid = providerUid;
    pending.nickname = `${providerType}_用户`;
    pending.avatarUrl = '';
    this.pendingSocials.push(pending);

    const data = new AuthSocialLoginResult();
    data.action = 'NEED_BIND_OR_CREATE';
    data.pendingToken = pending.token;
    const profile = new AuthSocialPendingProfile();
    profile.nickname = pending.nickname;
    profile.avatarUrl = pending.avatarUrl;
    data.providerProfile = profile;
    return this.ok(data);
  }

  public createSocialAccount(
    pendingToken: string,
    nickname: string,
    agreementAccepted: boolean,
    deviceInfo: DeviceInfo
  ): AuthApiResponse<AuthLoginResult> {
    if (!agreementAccepted) {
      return this.fail(AuthErrorCode.AGREEMENT_NOT_ACCEPTED, 'agreement_not_accepted', new AuthLoginResult());
    }
    const pending = this.findPending(pendingToken);
    if (!pending) {
      return this.fail(AuthErrorCode.INVALID_PARAM, 'invalid_pending_token', new AuthLoginResult());
    }

    const userName = nickname.trim().length > 0 ? nickname : `${pending.providerType}_新用户`;
    const user = this.createUser(userName, false, pending.providerType, Date.now());
    this.createIdentity(user.userId, pending.providerType, pending.providerUid, '');
    this.removePending(pendingToken);

    const session = this.issueSession(user.userId, deviceInfo, pending.providerType);
    return this.ok(this.buildLoginResult(user, session, true));
  }

  public bindSocialToExistingPhone(
    pendingToken: string,
    phoneNumber: string,
    code: string,
    deviceInfo: DeviceInfo
  ): AuthApiResponse<AuthLoginResult> {
    const pending = this.findPending(pendingToken);
    if (!pending) {
      return this.fail(AuthErrorCode.INVALID_PARAM, 'invalid_pending_token', new AuthLoginResult());
    }
    const verifyCode = this.verifyPhoneCode(phoneNumber, code);
    if (verifyCode !== AuthErrorCode.OK) {
      const message = verifyCode === AuthErrorCode.SMS_CODE_EXPIRED ? 'code_expired' : 'code_invalid';
      return this.fail(verifyCode, message, new AuthLoginResult());
    }

    const phoneIdentity = this.findIdentityByPhone(phoneNumber);
    if (!phoneIdentity) {
      return this.fail(AuthErrorCode.ACCOUNT_NOT_FOUND, 'phone_account_not_found', new AuthLoginResult());
    }

    const user = this.findUser(phoneIdentity.userId);
    if (!user || !this.isUserActive(user)) {
      return this.fail(AuthErrorCode.RISK_BLOCKED, 'user_status_blocked', new AuthLoginResult());
    }

    const existingSocial = this.findIdentityByProvider(pending.providerType, pending.providerUid);
    if (existingSocial && existingSocial.userId !== user.userId) {
      return this.fail(AuthErrorCode.ACCOUNT_CONFLICT, 'identity_bound_by_other_user', new AuthLoginResult());
    }
    if (!existingSocial) {
      this.createIdentity(user.userId, pending.providerType, pending.providerUid, '');
    }

    this.removePending(pendingToken);
    const session = this.issueSession(user.userId, deviceInfo, pending.providerType);
    return this.ok(this.buildLoginResult(user, session, false));
  }

  public refreshSession(refreshToken: string): AuthApiResponse<AuthSessionPayload> {
    const session = this.findSessionByRefresh(refreshToken);
    if (!session) {
      return this.fail(AuthErrorCode.SESSION_EXPIRED, 'refresh_token_invalid', new AuthSessionPayload());
    }

    if (Date.now() > session.issuedAt + this.refreshExpireMs) {
      session.status = 'EXPIRED';
      return this.fail(AuthErrorCode.SESSION_EXPIRED, 'refresh_token_expired', new AuthSessionPayload());
    }

    session.accessToken = `at_${this.nextId('token')}`;
    session.refreshToken = `rt_${this.nextId('token')}`;
    session.issuedAt = Date.now();
    session.expireAt = session.issuedAt + this.accessExpireMs;

    const payload = new AuthSessionPayload();
    payload.accessToken = session.accessToken;
    payload.refreshToken = session.refreshToken;
    payload.expireAt = session.expireAt;
    payload.sessionId = session.sessionId;
    return this.ok(payload);
  }

  public logout(accessToken: string, sessionId: string): AuthApiResponse<AuthSimpleResult> {
    const session = this.resolveSession(accessToken, sessionId);
    if (!session) {
      return this.fail(AuthErrorCode.SESSION_EXPIRED, 'session_not_found', new AuthSimpleResult());
    }
    session.status = 'REVOKED';
    const data = new AuthSimpleResult();
    data.result = 'SUCCESS';
    return this.ok(data);
  }

  public logoutAll(accessToken: string): AuthApiResponse<AuthSimpleResult> {
    const current = this.resolveSession(accessToken, '');
    if (!current) {
      return this.fail(AuthErrorCode.SESSION_EXPIRED, 'session_not_found', new AuthSimpleResult());
    }

    let idx = 0;
    while (idx < this.sessions.length) {
      const item = this.sessions[idx];
      if (item.userId === current.userId) {
        item.status = 'REVOKED';
      }
      idx += 1;
    }

    const data = new AuthSimpleResult();
    data.result = 'SUCCESS';
    return this.ok(data);
  }

  public getMe(accessToken: string): AuthApiResponse<AuthMeResult> {
    const session = this.resolveSession(accessToken, '');
    if (!session) {
      return this.fail(AuthErrorCode.SESSION_EXPIRED, 'session_expired', new AuthMeResult());
    }

    const user = this.findUser(session.userId);
    if (!user) {
      return this.fail(AuthErrorCode.ACCOUNT_NOT_FOUND, 'user_not_found', new AuthMeResult());
    }

    const data = new AuthMeResult();
    data.userId = user.userId;
    data.nickname = user.nickname;
    data.avatarUrl = user.avatarUrl;
    data.mobileMasked = user.mobileMasked;
    data.profileCompleted = user.profileCompleted;
    data.isGuest = user.isGuest;
    data.defaultLoginMethod = user.defaultLoginMethod;
    return this.ok(data);
  }

  public listIdentities(accessToken: string): AuthApiResponse<AuthIdentityView[]> {
    const session = this.resolveSession(accessToken, '');
    if (!session) {
      const empty: AuthIdentityView[] = [];
      return this.fail(AuthErrorCode.SESSION_EXPIRED, 'session_expired', empty);
    }

    const user = this.findUser(session.userId);
    if (!user) {
      const empty: AuthIdentityView[] = [];
      return this.fail(AuthErrorCode.ACCOUNT_NOT_FOUND, 'user_not_found', empty);
    }

    const result: AuthIdentityView[] = [];
    const providers: AuthProviderType[] = ['PHONE', 'HUAWEI', 'WECHAT', 'QQ'];
    let i = 0;
    while (i < providers.length) {
      const provider = providers[i];
      const view = new AuthIdentityView();
      view.providerType = provider;
      view.bound = false;
      view.displayName = '未绑定';
      view.isPrimary = false;

      const identity = this.findBoundIdentityByUserAndProvider(user.userId, provider);
      if (identity) {
        view.bound = true;
        view.displayName = provider === 'PHONE' ? this.maskPhone(identity.phoneNumber) : `${provider}已绑定`;
        view.isPrimary = user.defaultLoginMethod === provider;
      }

      result.push(view);
      i += 1;
    }
    return this.ok(result);
  }

  public bindSocial(accessToken: string, providerType: AuthProviderType, credential: SocialCredential): AuthApiResponse<AuthSimpleResult> {
    const session = this.resolveSession(accessToken, '');
    if (!session) {
      return this.fail(AuthErrorCode.SESSION_EXPIRED, 'session_expired', new AuthSimpleResult());
    }

    const providerUid = this.resolveProviderUid(credential);
    if (providerUid.length === 0) {
      return this.fail(AuthErrorCode.THIRD_PARTY_AUTH_FAILED, 'missing_credential', new AuthSimpleResult());
    }

    const hit = this.findIdentityByProvider(providerType, providerUid);
    if (hit && hit.userId !== session.userId) {
      return this.fail(AuthErrorCode.ACCOUNT_CONFLICT, 'identity_bound_by_other_user', new AuthSimpleResult());
    }
    if (!hit) {
      this.createIdentity(session.userId, providerType, providerUid, '');
    }

    const data = new AuthSimpleResult();
    data.result = 'SUCCESS';
    return this.ok(data);
  }

  public bindPhone(accessToken: string, phoneNumber: string, code: string): AuthApiResponse<AuthSimpleResult> {
    const session = this.resolveSession(accessToken, '');
    if (!session) {
      return this.fail(AuthErrorCode.SESSION_EXPIRED, 'session_expired', new AuthSimpleResult());
    }

    const verifyCode = this.verifyPhoneCode(phoneNumber, code);
    if (verifyCode !== AuthErrorCode.OK) {
      const message = verifyCode === AuthErrorCode.SMS_CODE_EXPIRED ? 'code_expired' : 'code_invalid';
      return this.fail(verifyCode, message, new AuthSimpleResult());
    }

    const hit = this.findIdentityByPhone(phoneNumber);
    if (hit && hit.userId !== session.userId) {
      return this.fail(AuthErrorCode.ACCOUNT_CONFLICT, 'phone_bound_by_other_user', new AuthSimpleResult());
    }
    if (!hit) {
      this.createIdentity(session.userId, 'PHONE', phoneNumber, phoneNumber);
    }

    const user = this.findUser(session.userId);
    if (user) {
      user.mobileBindTime = Date.now();
      user.mobileMasked = this.maskPhone(phoneNumber);
    }

    const data = new AuthSimpleResult();
    data.result = 'SUCCESS';
    return this.ok(data);
  }

  public unbind(accessToken: string, providerType: AuthProviderType): AuthApiResponse<AuthSimpleResult> {
    const session = this.resolveSession(accessToken, '');
    if (!session) {
      return this.fail(AuthErrorCode.SESSION_EXPIRED, 'session_expired', new AuthSimpleResult());
    }

    const boundList = this.listBoundIdentitiesByUser(session.userId);
    let target: IdentityRecord | null = null;
    let i = 0;
    while (i < boundList.length) {
      if (boundList[i].providerType === providerType) {
        target = boundList[i];
        break;
      }
      i += 1;
    }

    if (!target) {
      return this.fail(AuthErrorCode.INVALID_PARAM, 'identity_not_found', new AuthSimpleResult());
    }
    if (boundList.length <= 1) {
      return this.fail(AuthErrorCode.LAST_LOGIN_METHOD_CANNOT_UNBIND, 'must_keep_one_login_method', new AuthSimpleResult());
    }
    if (this.requirePhoneFallback && providerType === 'PHONE') {
      return this.fail(AuthErrorCode.LAST_LOGIN_METHOD_CANNOT_UNBIND, 'phone_fallback_required', new AuthSimpleResult());
    }

    target.bindStatus = 'UNBOUND';
    const data = new AuthSimpleResult();
    data.result = 'SUCCESS';
    return this.ok(data);
  }

  public listSessions(accessToken: string): AuthApiResponse<AuthSessionListItem[]> {
    const current = this.resolveSession(accessToken, '');
    if (!current) {
      const empty: AuthSessionListItem[] = [];
      return this.fail(AuthErrorCode.SESSION_EXPIRED, 'session_expired', empty);
    }

    const result: AuthSessionListItem[] = [];
    let i = 0;
    while (i < this.sessions.length) {
      const item = this.sessions[i];
      if (item.userId === current.userId && item.status === 'ACTIVE') {
        const line = new AuthSessionListItem();
        line.sessionId = item.sessionId;
        line.deviceName = item.deviceName;
        line.platform = item.platform;
        line.loginMethod = item.loginMethod;
        line.lastActiveTime = item.issuedAt;
        line.current = item.sessionId === current.sessionId;
        result.push(line);
      }
      i += 1;
    }
    return this.ok(result);
  }

  public requestCancel(accessToken: string, reauthToken: string): AuthApiResponse<AuthCancelResult> {
    const session = this.resolveSession(accessToken, '');
    if (!session) {
      return this.fail(AuthErrorCode.SESSION_EXPIRED, 'session_expired', new AuthCancelResult());
    }
    if (reauthToken.trim().length === 0) {
      return this.fail(AuthErrorCode.REAUTH_REQUIRED, 'reauth_required', new AuthCancelResult());
    }

    const user = this.findUser(session.userId);
    if (!user) {
      return this.fail(AuthErrorCode.ACCOUNT_NOT_FOUND, 'user_not_found', new AuthCancelResult());
    }

    user.status = 'CANCEL_PENDING';
    const data = new AuthCancelResult();
    data.cancelStatus = 'PENDING';
    return this.ok(data);
  }

  private createUser(nickname: string, isGuest: boolean, loginMethod: AuthProviderType, now: number): UserRecord {
    const user = new UserRecord();
    user.userId = this.nextId('u');
    user.nickname = nickname;
    user.isGuest = isGuest;
    user.defaultLoginMethod = loginMethod;
    user.registerTime = now;
    user.lastLoginTime = now;
    this.users.push(user);
    return user;
  }

  private createIdentity(userId: string, providerType: AuthProviderType, providerUid: string, phoneNumber: string): IdentityRecord {
    const idn = new IdentityRecord();
    idn.identityId = this.nextId('idn');
    idn.userId = userId;
    idn.providerType = providerType;
    idn.providerUid = providerUid;
    idn.phoneNumber = phoneNumber;
    idn.bindStatus = 'BOUND';
    idn.lastUsedTime = Date.now();
    this.identities.push(idn);
    return idn;
  }

  private issueSession(userId: string, deviceInfo: DeviceInfo, method: AuthProviderType): SessionRecord {
    const now = Date.now();
    const session = new SessionRecord();
    session.sessionId = this.nextId('s');
    session.userId = userId;
    session.deviceId = deviceInfo.deviceId;
    session.deviceName = deviceInfo.deviceName;
    session.platform = deviceInfo.platform;
    session.accessToken = `at_${this.nextId('token')}`;
    session.refreshToken = `rt_${this.nextId('token')}`;
    session.issuedAt = now;
    session.expireAt = now + this.accessExpireMs;
    session.loginMethod = method;
    this.sessions.push(session);
    return session;
  }

  private buildLoginResult(user: UserRecord, session: SessionRecord, isNewUser: boolean): AuthLoginResult {
    const result = new AuthLoginResult();
    result.isNewUser = isNewUser;

    const profile = new AuthUserProfile();
    profile.userId = user.userId;
    profile.nickname = user.nickname;
    profile.avatarUrl = user.avatarUrl;
    profile.profileCompleted = user.profileCompleted;
    profile.isGuest = user.isGuest;
    profile.defaultLoginMethod = user.defaultLoginMethod;

    const payload = new AuthSessionPayload();
    payload.accessToken = session.accessToken;
    payload.refreshToken = session.refreshToken;
    payload.expireAt = session.expireAt;
    payload.sessionId = session.sessionId;

    result.user = profile;
    result.session = payload;
    return result;
  }

  private resolveSession(accessToken: string, sessionId: string): SessionRecord | null {
    let i = 0;
    while (i < this.sessions.length) {
      const item = this.sessions[i];
      if (item.accessToken === accessToken && item.status === 'ACTIVE') {
        if (sessionId.length > 0 && item.sessionId !== sessionId) {
          i += 1;
          continue;
        }
        if (Date.now() > item.expireAt) {
          item.status = 'EXPIRED';
          return null;
        }
        return item;
      }
      i += 1;
    }
    return null;
  }

  private findSessionByRefresh(refreshToken: string): SessionRecord | null {
    let i = 0;
    while (i < this.sessions.length) {
      const item = this.sessions[i];
      if (item.refreshToken === refreshToken && item.status === 'ACTIVE') {
        return item;
      }
      i += 1;
    }
    return null;
  }

  private findUser(userId: string): UserRecord | null {
    let i = 0;
    while (i < this.users.length) {
      if (this.users[i].userId === userId) {
        return this.users[i];
      }
      i += 1;
    }
    return null;
  }

  private findIdentityByPhone(phoneNumber: string): IdentityRecord | null {
    let i = 0;
    while (i < this.identities.length) {
      const item = this.identities[i];
      if (item.providerType === 'PHONE' && item.phoneNumber === phoneNumber && item.bindStatus === 'BOUND') {
        return item;
      }
      i += 1;
    }
    return null;
  }

  private findIdentityByProvider(providerType: AuthProviderType, providerUid: string): IdentityRecord | null {
    let i = 0;
    while (i < this.identities.length) {
      const item = this.identities[i];
      if (item.providerType === providerType && item.providerUid === providerUid && item.bindStatus === 'BOUND') {
        return item;
      }
      i += 1;
    }
    return null;
  }

  private findBoundIdentityByUserAndProvider(userId: string, providerType: AuthProviderType): IdentityRecord | null {
    let i = 0;
    while (i < this.identities.length) {
      const item = this.identities[i];
      if (item.userId === userId && item.providerType === providerType && item.bindStatus === 'BOUND') {
        return item;
      }
      i += 1;
    }
    return null;
  }

  private listBoundIdentitiesByUser(userId: string): IdentityRecord[] {
    const result: IdentityRecord[] = [];
    let i = 0;
    while (i < this.identities.length) {
      const item = this.identities[i];
      if (item.userId === userId && item.bindStatus === 'BOUND') {
        result.push(item);
      }
      i += 1;
    }
    return result;
  }

  private findPending(token: string): PendingSocialRecord | null {
    let i = 0;
    while (i < this.pendingSocials.length) {
      if (this.pendingSocials[i].token === token) {
        return this.pendingSocials[i];
      }
      i += 1;
    }
    return null;
  }

  private removePending(token: string): void {
    this.pendingSocials = this.pendingSocials.filter((item: PendingSocialRecord) => item.token !== token);
  }

  private verifyPhoneCode(phoneNumber: string, code: string): AuthErrorCode {
    for (let i = this.verifyCodes.length - 1; i >= 0; i -= 1) {
      const item = this.verifyCodes[i];
      if (item.phoneNumber !== phoneNumber || item.status !== 'PENDING') {
        continue;
      }
      if (Date.now() > item.expiredAt) {
        item.status = 'EXPIRED';
        return AuthErrorCode.SMS_CODE_EXPIRED;
      }
      if (item.codeHash !== code) {
        return AuthErrorCode.SMS_CODE_INVALID;
      }
      item.status = 'USED';
      return AuthErrorCode.OK;
    }
    return AuthErrorCode.SMS_CODE_INVALID;
  }

  private resolveProviderUid(credential: SocialCredential): string {
    if (credential.unionId.trim().length > 0) {
      return credential.unionId.trim();
    }
    if (credential.openId.trim().length > 0) {
      return credential.openId.trim();
    }
    if (credential.authCode.trim().length > 0) {
      return credential.authCode.trim();
    }
    if (credential.idToken.trim().length > 0) {
      return credential.idToken.trim();
    }
    return '';
  }

  private isUserActive(user: UserRecord): boolean {
    return user.status === 'ACTIVE';
  }

  private isValidPhone(phone: string): boolean {
    const normalized = phone.trim();
    if (normalized.length < 6 || normalized.length > 20) {
      return false;
    }
    for (let i = 0; i < normalized.length; i += 1) {
      const ch = normalized.charCodeAt(i);
      if (ch < 48 || ch > 57) {
        return false;
      }
    }
    return true;
  }

  private maskPhone(phone: string): string {
    if (phone.length < 7) {
      return phone;
    }
    return `${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}`;
  }

  private incrementWindow(store: Map<string, WindowCounter>, key: string, max: number, now: number): boolean {
    const current = store.get(key);
    if (!current || now - current.startAt >= this.sendWindowMs) {
      const next = new WindowCounter();
      next.startAt = now;
      next.count = 1;
      store.set(key, next);
      return true;
    }
    if (current.count >= max) {
      return false;
    }
    current.count += 1;
    store.set(key, current);
    return true;
  }

  private generateCode(): string {
    const num = Math.floor(Math.random() * 900000) + 100000;
    return `${num}`;
  }

  private nextId(prefix: string): string {
    this.idSeq += 1;
    return `${prefix}_${this.idSeq}`;
  }

  private nextRequestId(): string {
    this.reqSeq += 1;
    return `req_${Date.now()}_${this.reqSeq}`;
  }

  private ok<T>(data: T): AuthApiResponse<T> {
    const response = new AuthApiResponse<T>(data);
    response.code = AuthErrorCode.OK;
    response.message = 'ok';
    response.requestId = this.nextRequestId();
    return response;
  }

  private fail<T>(code: AuthErrorCode, message: string, data: T): AuthApiResponse<T> {
    const response = new AuthApiResponse<T>(data);
    response.code = code;
    response.message = message;
    response.requestId = this.nextRequestId();
    return response;
  }
}


