import { http } from '@kit.NetworkKit';
import { HttpRequestHelper } from '../adapters/HttpRequestHelper';
import { AppConfig } from '../../common/utils/AppConfig';

interface ApiEnvelope<T> {
  code: number;
  message: string;
  requestId: string;
  data: T;
}

export class AuthApiClient {
  private static readonly OWNER_TAG = 'AuthApiClient';

  async post<T>(path: string, payload: object, accessToken: string = ''): Promise<ApiEnvelope<T>> {
    const url = `${AppConfig.AUTH_API_BASE_URL}${path}`;
    const headers: Record<string, string> = {
      'Content-Type': 'application/json'
    };
    if (accessToken.trim().length > 0) {
      headers['Authorization'] = `Bearer ${accessToken}`;
    }

    const response = await HttpRequestHelper.request(AuthApiClient.OWNER_TAG, `POST ${path}`, url, {
      method: http.RequestMethod.POST,
      header: headers,
      extraData: JSON.stringify(payload),
      readTimeout: 10000,
      connectTimeout: 5000
    });

    const body = JSON.parse(String(response.result)) as ApiEnvelope<T>;
    return body;
  }

  async get<T>(path: string, accessToken: string): Promise<ApiEnvelope<T>> {
    const url = `${AppConfig.AUTH_API_BASE_URL}${path}`;
    const response = await HttpRequestHelper.request(AuthApiClient.OWNER_TAG, `GET ${path}`, url, {
      method: http.RequestMethod.GET,
      header: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${accessToken}`
      },
      readTimeout: 10000,
      connectTimeout: 5000
    });

    const body = JSON.parse(String(response.result)) as ApiEnvelope<T>;
    return body;
  }

  async patch<T>(path: string, payload: object, accessToken: string): Promise<ApiEnvelope<T>> {
    const url = `${AppConfig.AUTH_API_BASE_URL}${path}`;
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${accessToken}`
    };

    const response = await HttpRequestHelper.request(AuthApiClient.OWNER_TAG, `PATCH ${path}`, url, {
      method: http.RequestMethod.POST,
      header: headers,
      extraData: JSON.stringify(payload),
      readTimeout: 10000,
      connectTimeout: 5000
    });

    const body = JSON.parse(String(response.result)) as ApiEnvelope<T>;
    return body;
  }
}
