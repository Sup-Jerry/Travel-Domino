import { AppConfig } from '../../common/utils/AppConfig';
import {
  AuthCancelResult,
  AuthApiResponse,
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
  DeviceInfo,
  SocialCredential
} from '../../domain/auth/AuthModels';
import { AuthService } from './AuthService';
import { AuthApiClient } from './AuthApiClient';

class SendPhoneCodePayload {
  phoneNumber: string = '';
  countryCode: string = '';
  bizType: string = '';
}

class PhoneLoginPayload {
  phoneNumber: string = '';
  countryCode: string = '';
  code: string = '';
  agreementAccepted: boolean = false;
  deviceInfo: DeviceInfo = new DeviceInfo('', '', '');
}

class SocialLoginPayload {
  providerType: AuthProviderType = 'HUAWEI';
  credential: SocialCredential = new SocialCredential();
  agreementAccepted: boolean = false;
  deviceInfo: DeviceInfo = new DeviceInfo('', '', '');
}

class SocialCreatePayload {
  pendingToken: string = '';
  nickname: string = '';
  agreementAccepted: boolean = false;
  deviceInfo: DeviceInfo = new DeviceInfo('', '', '');
}

class SocialBindPhonePayload {
  pendingToken: string = '';
  phoneNumber: string = '';
  countryCode: string = '';
  code: string = '';
  deviceInfo: DeviceInfo = new DeviceInfo('', '', '');
}

class GuestCreatePayload {
  deviceInfo: DeviceInfo = new DeviceInfo('', '', '');
}

class GuestUpgradePayload {
  guestUserId: string = '';
  targetUserId: string = '';
}

class RefreshPayload {
  refreshToken: string = '';
}

class BindSocialPayload {
  providerType: AuthProviderType = 'HUAWEI';
  credential: SocialCredential = new SocialCredential();
}

class BindPhonePayload {
  phoneNumber: string = '';
  countryCode: string = '';
  code: string = '';
}

class UnbindPayload {
  providerType: AuthProviderType = 'PHONE';
}

class LogoutPayload {
  sessionId: string = '';
}

class CancelPayload {
  reauthToken: string = '';
  reason: string = '';
}

class EmptyPayload {
}

export class AuthGateway {
  private static readonly apiClient = new AuthApiClient();

  private static useMock(): boolean {
    return AppConfig.AUTH_USE_MOCK;
  }

  static async sendPhoneCode(
    phoneNumber: string,
    countryCode: string,
    bizType: string,
    deviceId: string,
    ipAddress: string
  ): Promise<AuthApiResponse<AuthCodeSendResult>> {
    if (AuthGateway.useMock()) {
      return AuthService.getInstance().sendPhoneCode(phoneNumber, countryCode, bizType, deviceId, ipAddress);
    }
    const payload = new SendPhoneCodePayload();
    payload.phoneNumber = phoneNumber;
    payload.countryCode = countryCode;
    payload.bizType = bizType;
    return AuthGateway.apiClient.post<AuthCodeSendResult>('/auth/phone/send-code', payload);
  }

  static async loginWithPhone(
    phoneNumber: string,
    countryCode: string,
    code: string,
    agreementAccepted: boolean,
    deviceInfo: DeviceInfo
  ): Promise<AuthApiResponse<AuthLoginResult>> {
    if (AuthGateway.useMock()) {
      return AuthService.getInstance().loginWithPhone(phoneNumber, countryCode, code, agreementAccepted, deviceInfo);
    }
    const payload = new PhoneLoginPayload();
    payload.phoneNumber = phoneNumber;
    payload.countryCode = countryCode;
    payload.code = code;
    payload.agreementAccepted = agreementAccepted;
    payload.deviceInfo = deviceInfo;
    return AuthGateway.apiClient.post<AuthLoginResult>('/auth/phone/login', payload);
  }

  static async loginWithSocial(
    providerType: AuthProviderType,
    credential: SocialCredential,
    agreementAccepted: boolean,
    deviceInfo: DeviceInfo
  ): Promise<AuthApiResponse<AuthSocialLoginResult>> {
    if (AuthGateway.useMock()) {
      return AuthService.getInstance().loginWithSocial(providerType, credential, agreementAccepted, deviceInfo);
    }
    const payload = new SocialLoginPayload();
    payload.providerType = providerType;
    payload.credential = credential;
    payload.agreementAccepted = agreementAccepted;
    payload.deviceInfo = deviceInfo;
    return AuthGateway.apiClient.post<AuthSocialLoginResult>('/auth/social/login', payload);
  }

  static async createSocialAccount(
    pendingToken: string,
    nickname: string,
    agreementAccepted: boolean,
    deviceInfo: DeviceInfo
  ): Promise<AuthApiResponse<AuthLoginResult>> {
    if (AuthGateway.useMock()) {
      return AuthService.getInstance().createSocialAccount(pendingToken, nickname, agreementAccepted, deviceInfo);
    }
    const payload = new SocialCreatePayload();
    payload.pendingToken = pendingToken;
    payload.nickname = nickname;
    payload.agreementAccepted = agreementAccepted;
    payload.deviceInfo = deviceInfo;
    return AuthGateway.apiClient.post<AuthLoginResult>('/auth/social/create-account', payload);
  }

  static async bindSocialToExistingPhone(
    pendingToken: string,
    phoneNumber: string,
    countryCode: string,
    code: string,
    deviceInfo: DeviceInfo
  ): Promise<AuthApiResponse<AuthLoginResult>> {
    if (AuthGateway.useMock()) {
      return AuthService.getInstance().bindSocialToExistingPhone(pendingToken, phoneNumber, code, deviceInfo);
    }
    const payload = new SocialBindPhonePayload();
    payload.pendingToken = pendingToken;
    payload.phoneNumber = phoneNumber;
    payload.countryCode = countryCode;
    payload.code = code;
    payload.deviceInfo = deviceInfo;
    return AuthGateway.apiClient.post<AuthLoginResult>('/auth/social/bind-existing-phone', payload);
  }

  static async createGuest(deviceInfo: DeviceInfo): Promise<AuthApiResponse<AuthLoginResult>> {
    if (AuthGateway.useMock()) {
      return AuthService.getInstance().createGuest(deviceInfo);
    }
    const payload = new GuestCreatePayload();
    payload.deviceInfo = deviceInfo;
    return AuthGateway.apiClient.post<AuthLoginResult>('/auth/guest/create', payload);
  }

  static async upgradeGuest(guestUserId: string, targetUserId: string): Promise<AuthApiResponse<AuthGuestUpgradeResult>> {
    if (AuthGateway.useMock()) {
      return AuthService.getInstance().upgradeGuest(guestUserId, targetUserId);
    }
    const payload = new GuestUpgradePayload();
    payload.guestUserId = guestUserId;
    payload.targetUserId = targetUserId;
    return AuthGateway.apiClient.post<AuthGuestUpgradeResult>('/auth/guest/upgrade', payload);
  }

  static async refreshSession(refreshToken: string): Promise<AuthApiResponse<AuthSessionPayload>> {
    if (AuthGateway.useMock()) {
      return AuthService.getInstance().refreshSession(refreshToken);
    }
    const payload = new RefreshPayload();
    payload.refreshToken = refreshToken;
    return AuthGateway.apiClient.post<AuthSessionPayload>('/auth/session/refresh', payload);
  }

  static async me(accessToken: string): Promise<AuthApiResponse<AuthMeResult>> {
    if (AuthGateway.useMock()) {
      return AuthService.getInstance().getMe(accessToken);
    }
    return AuthGateway.apiClient.get<AuthMeResult>('/auth/me', accessToken);
  }

  static async listIdentities(accessToken: string): Promise<AuthApiResponse<AuthIdentityView[]>> {
    if (AuthGateway.useMock()) {
      return AuthService.getInstance().listIdentities(accessToken);
    }
    return AuthGateway.apiClient.get<AuthIdentityView[]>('/auth/identities', accessToken);
  }

  static async bindSocial(
    accessToken: string,
    providerType: AuthProviderType,
    credential: SocialCredential
  ): Promise<AuthApiResponse<AuthSimpleResult>> {
    if (AuthGateway.useMock()) {
      return AuthService.getInstance().bindSocial(accessToken, providerType, credential);
    }
    const payload = new BindSocialPayload();
    payload.providerType = providerType;
    payload.credential = credential;
    return AuthGateway.apiClient.post<AuthSimpleResult>('/auth/identities/bind/social', payload, accessToken);
  }

  static async bindPhone(
    accessToken: string,
    phoneNumber: string,
    countryCode: string,
    code: string
  ): Promise<AuthApiResponse<AuthSimpleResult>> {
    if (AuthGateway.useMock()) {
      return AuthService.getInstance().bindPhone(accessToken, phoneNumber, code);
    }
    const payload = new BindPhonePayload();
    payload.phoneNumber = phoneNumber;
    payload.countryCode = countryCode;
    payload.code = code;
    return AuthGateway.apiClient.post<AuthSimpleResult>('/auth/identities/bind/phone', payload, accessToken);
  }

  static async unbind(accessToken: string, providerType: AuthProviderType): Promise<AuthApiResponse<AuthSimpleResult>> {
    if (AuthGateway.useMock()) {
      return AuthService.getInstance().unbind(accessToken, providerType);
    }
    const payload = new UnbindPayload();
    payload.providerType = providerType;
    return AuthGateway.apiClient.post<AuthSimpleResult>('/auth/identities/unbind', payload, accessToken);
  }

  static async logout(accessToken: string, sessionId: string): Promise<AuthApiResponse<AuthSimpleResult>> {
    if (AuthGateway.useMock()) {
      return AuthService.getInstance().logout(accessToken, sessionId);
    }
    const payload = new LogoutPayload();
    payload.sessionId = sessionId;
    return AuthGateway.apiClient.post<AuthSimpleResult>('/auth/logout', payload, accessToken);
  }

  static async logoutAll(accessToken: string): Promise<AuthApiResponse<AuthSimpleResult>> {
    if (AuthGateway.useMock()) {
      return AuthService.getInstance().logoutAll(accessToken);
    }
    return AuthGateway.apiClient.post<AuthSimpleResult>('/auth/logout-all', new EmptyPayload(), accessToken);
  }

  static async sessions(accessToken: string): Promise<AuthApiResponse<AuthSessionListItem[]>> {
    if (AuthGateway.useMock()) {
      return AuthService.getInstance().listSessions(accessToken);
    }
    return AuthGateway.apiClient.get<AuthSessionListItem[]>('/auth/sessions', accessToken);
  }

  static async cancelRequest(
    accessToken: string,
    reauthToken: string,
    reason: string
  ): Promise<AuthApiResponse<AuthCancelResult>> {
    if (AuthGateway.useMock()) {
      return AuthService.getInstance().requestCancel(accessToken, reauthToken);
    }
    const payload = new CancelPayload();
    payload.reauthToken = reauthToken;
    payload.reason = reason;
    return AuthGateway.apiClient.post<AuthCancelResult>('/auth/cancel/request', payload, accessToken);
  }
}
