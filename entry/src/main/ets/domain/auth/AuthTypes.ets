export enum LoginStatus {
  UNAUTHENTICATED = 'UNAUTHENTICATED',
  SILENT_CHECKING = 'SILENT_CHECKING',
  AUTHENTICATED = 'AUTHENTICATED',
  LOGIN_FAILED = 'LOGIN_FAILED'
}

export type AuthSource = 'LOCAL_SESSION' | 'HUAWEI_BUTTON' | 'HUAWEI_SILENT' | 'GUEST_FALLBACK' | 'NONE';

export class UserSession {
  userId: string = '';
  accessToken: string = '';
  refreshToken: string = '';
  expireAt: number = 0;
  sessionId: string = '';
  isGuest: boolean = false;
  loginMethod: string = '';
}

export class AuthResult<T> {
  success: boolean = false;
  code: number = -1;
  message: string = '';
  source: AuthSource = 'NONE';
  status: LoginStatus = LoginStatus.UNAUTHENTICATED;
  data: T | null = null;
}

export class HuaweiCredential {
  authorizationCode: string = '';
  idToken: string = '';
  openId: string = '';
  unionId: string = '';
}

