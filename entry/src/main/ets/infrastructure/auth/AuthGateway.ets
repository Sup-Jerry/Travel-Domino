import {
  AuthApiResponse,
  AuthLoginResult,
  AuthMeResult,
  DeviceInfo,
  SocialCredential,
  UpdateUsernameResult
} from '../../domain/auth/AuthModels';
import { AuthApiClient } from './AuthApiClient';

class GuestCreatePayload {
  deviceInfo: DeviceInfo = new DeviceInfo('', '', '');
}

class SocialLoginPayload {
  providerType: string = 'HUAWEI';
  credential: SocialCredential = new SocialCredential();
  deviceInfo: DeviceInfo = new DeviceInfo('', '', '');
}

class UpdateUsernameRequestPayload {
  username: string = '';
}

export class AuthGateway {
  private static readonly apiClient = new AuthApiClient();

  static async createGuest(deviceInfo: DeviceInfo): Promise<AuthApiResponse<AuthLoginResult>> {
    const payload = new GuestCreatePayload();
    payload.deviceInfo = deviceInfo;
    return AuthGateway.apiClient.post<AuthLoginResult>('/auth/guest/create', payload);
  }

  static async me(accessToken: string): Promise<AuthApiResponse<AuthMeResult>> {
    return AuthGateway.apiClient.get<AuthMeResult>('/auth/me', accessToken);
  }

  static async loginWithSocial(
    providerType: string,
    credential: SocialCredential,
    deviceInfo: DeviceInfo
  ): Promise<AuthApiResponse<AuthLoginResult>> {
    const payload = new SocialLoginPayload();
    payload.providerType = providerType;
    payload.credential = credential;
    payload.deviceInfo = deviceInfo;
    return AuthGateway.apiClient.post<AuthLoginResult>('/auth/social/login', payload);
  }

  static async updateUsername(accessToken: string, username: string): Promise<AuthApiResponse<UpdateUsernameResult>> {
    const payload = new UpdateUsernameRequestPayload();
    payload.username = username;
    return AuthGateway.apiClient.patch<UpdateUsernameResult>('/auth/profile/username', payload, accessToken);
  }
}
