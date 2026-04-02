export type AuthProviderType = 'GUEST' | 'CUSTOM' | 'HUAWEI';

export class DeviceInfo {
  deviceId: string = '';
  deviceName: string = '';
  platform: string = '';

  constructor(deviceId: string, deviceName: string, platform: string) {
    this.deviceId = deviceId;
    this.deviceName = deviceName;
    this.platform = platform;
  }
}

export class SocialCredential {
  authCode: string = '';
  idToken: string = '';
  accessToken: string = '';
  openId: string = '';
  unionId: string = '';
}

export class AuthSessionPayload {
  accountId: string = '';
  userId: string = '';
  isGuest: boolean = false;
  loginMethod: string = '';
  accessToken: string = '';
  refreshToken: string = '';
  expireAt: number = 0;
  sessionId: string = '';
}

export class AuthUserProfile {
  accountId: string = '';
  userId: string = '';
  nickname: string = '';
  avatarUrl: string = '';
  profileCompleted: boolean = false;
  isGuest: boolean = false;
  defaultLoginMethod: AuthProviderType = 'GUEST';
}

export class AuthLoginResult {
  isNewUser: boolean = false;
  user: AuthUserProfile = new AuthUserProfile();
  session: AuthSessionPayload = new AuthSessionPayload();
}

export class AuthSocialPendingProfile {
  nickname: string = '';
  avatarUrl: string = '';
}

export class AuthSocialLoginResult {
  action: string = '';
  pendingToken: string = '';
  providerProfile: AuthSocialPendingProfile = new AuthSocialPendingProfile();
  loginResult: AuthLoginResult | null = null;
}

export class AuthIdentityView {
  providerType: AuthProviderType = 'GUEST';
  displayName: string = '';
  bound: boolean = false;
  isPrimary: boolean = false;
}

export class AuthCodeSendResult {
  expireInSeconds: number = 0;
  retryAfterSeconds: number = 0;
}

export class AuthSimpleResult {
  result: string = '';
}

export class AuthCancelResult {
  cancelStatus: string = '';
}

export class AuthGuestUpgradeResult {
  migrateStatus: string = '';
}

export class AuthMeResult {
  accountId: string = '';
  userId: string = '';
  nickname: string = '';
  avatarUrl: string = '';
  mobileMasked: string = '';
  profileCompleted: boolean = false;
  isGuest: boolean = false;
  defaultLoginMethod: AuthProviderType = 'GUEST';
}

export class AuthSessionListItem {
  sessionId: string = '';
  deviceName: string = '';
  platform: string = '';
  loginMethod: AuthProviderType = 'GUEST';
  lastActiveTime: number = 0;
  current: boolean = false;
}

export class UpdateUsernamePayload {
  username: string = '';
}

export class UpdateUsernameResult {
  accountId: string = '';
  userId: string = '';
  nickname: string = '';
  avatarUrl: string = '';
  mobileMasked: string = '';
  profileCompleted: boolean = false;
  isGuest: boolean = false;
  defaultLoginMethod: AuthProviderType = 'GUEST';
}

export class UpdateAvatarPayload {
  imageDataUrl: string = '';
  mimeType: string = 'image/jpeg';
}

export class UpdateAvatarResult {
  accountId: string = '';
  userId: string = '';
  nickname: string = '';
  avatarUrl: string = '';
  mobileMasked: string = '';
  profileCompleted: boolean = false;
  isGuest: boolean = false;
  defaultLoginMethod: AuthProviderType = 'GUEST';
}

export class AuthApiResponse<T> {
  code: number = 0;
  message: string = 'ok';
  requestId: string = '';
  data: T;

  constructor(data: T) {
    this.data = data;
  }
}
