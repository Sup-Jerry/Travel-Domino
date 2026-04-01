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
  private static readonly REQUEST_TIMEOUT_MS = 12000;

  async post<T>(path: string, payload: object, accessToken: string = ''): Promise<ApiEnvelope<T>> {
    const url = `${AppConfig.AUTH_API_BASE_URL}${path}`;
    const headers: Record<string, string> = {
      'Content-Type': 'application/json'
    };
    if (accessToken.trim().length > 0) {
      headers['Authorization'] = `Bearer ${accessToken}`;
    }

    const response = await this.withTimeout(
      HttpRequestHelper.request(AuthApiClient.OWNER_TAG, `POST ${path}`, url, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: JSON.stringify(payload),
        readTimeout: 10000,
        connectTimeout: 5000
      }),
      AuthApiClient.REQUEST_TIMEOUT_MS,
      `POST ${path}`
    );

    return this.parseBody<T>(response.result, `POST ${path}`);
  }

  async get<T>(path: string, accessToken: string): Promise<ApiEnvelope<T>> {
    const url = `${AppConfig.AUTH_API_BASE_URL}${path}`;
    const response = await this.withTimeout(
      HttpRequestHelper.request(AuthApiClient.OWNER_TAG, `GET ${path}`, url, {
        method: http.RequestMethod.GET,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${accessToken}`
        },
        readTimeout: 10000,
        connectTimeout: 5000
      }),
      AuthApiClient.REQUEST_TIMEOUT_MS,
      `GET ${path}`
    );

    return this.parseBody<T>(response.result, `GET ${path}`);
  }

  async patch<T>(path: string, payload: object, accessToken: string): Promise<ApiEnvelope<T>> {
    const url = `${AppConfig.AUTH_API_BASE_URL}${path}`;
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${accessToken}`
    };

    const response = await this.withTimeout(
      HttpRequestHelper.request(AuthApiClient.OWNER_TAG, `PATCH ${path}`, url, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: JSON.stringify(payload),
        readTimeout: 10000,
        connectTimeout: 5000
      }),
      AuthApiClient.REQUEST_TIMEOUT_MS,
      `PATCH ${path}`
    );

    return this.parseBody<T>(response.result, `PATCH ${path}`);
  }

  private parseBody<T>(rawResult: Object, traceName: string): ApiEnvelope<T> {
    try {
      const body = JSON.parse(String(rawResult)) as ApiEnvelope<T>;
      return body;
    } catch (_error) {
      throw new Error(`auth_api_invalid_json_${traceName}`);
    }
  }

  private async withTimeout<T>(task: Promise<T>, timeoutMs: number, traceName: string): Promise<T> {
    let timerId = -1;
    const timeoutPromise = new Promise<T>((_resolve, reject) => {
      timerId = setTimeout(() => {
        reject(new Error(`auth_api_timeout_${traceName}_${timeoutMs}`));
      }, timeoutMs);
    });

    try {
      return await Promise.race([task, timeoutPromise]);
    } finally {
      if (timerId >= 0) {
        clearTimeout(timerId);
      }
    }
  }
}
