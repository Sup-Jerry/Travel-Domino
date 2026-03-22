import { AppConfig } from '../../common/utils/AppConfig';
import { AuthApiResponse, AuthLoginResult, AuthMeResult, DeviceInfo } from '../../domain/auth/AuthModels';
import { AuthService } from './AuthService';
import { AuthApiClient } from './AuthApiClient';

class GuestCreatePayload {
  deviceInfo: DeviceInfo = new DeviceInfo('', '', '');
}

export class AuthGateway {
  private static readonly apiClient = new AuthApiClient();

  private static useMock(): boolean {
    return AppConfig.AUTH_USE_MOCK;
  }

  static async createGuest(deviceInfo: DeviceInfo): Promise<AuthApiResponse<AuthLoginResult>> {
    if (AuthGateway.useMock()) {
      return AuthService.getInstance().createGuest(deviceInfo);
    }
    const payload = new GuestCreatePayload();
    payload.deviceInfo = deviceInfo;
    return AuthGateway.apiClient.post<AuthLoginResult>('/auth/guest/create', payload);
  }

  static async me(accessToken: string): Promise<AuthApiResponse<AuthMeResult>> {
    if (AuthGateway.useMock()) {
      return AuthService.getInstance().getMe(accessToken);
    }
    return AuthGateway.apiClient.get<AuthMeResult>('/auth/me', accessToken);
  }
}
