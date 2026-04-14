import { http } from '@kit.NetworkKit';
import { HttpRequestHelper } from '../adapters/HttpRequestHelper';
import { AppConfig } from '../../common/utils/AppConfig';
import { hilog } from '@kit.PerformanceAnalysisKit';

interface ApiEnvelope<T> {
  code: number;
  message: string;
  requestId: string;
  data: T;
}

export class AuthApiClient {
  private static readonly OWNER_TAG = 'AuthApiClient';
  private static readonly LOG_DOMAIN: number = 0x0000;
  private static readonly LOG_TAG: string = 'AuthApiClient';
  private static readonly REQUEST_TIMEOUT_MS = 12000;

  async post<T>(path: string, payload: object, accessToken: string = ''): Promise<ApiEnvelope<T>> {
    const url = `${AppConfig.AUTH_API_BASE_URL}${path}`;
    hilog.info(
      AuthApiClient.LOG_DOMAIN,
      AuthApiClient.LOG_TAG,
      `[LOGIN_TRACE][api] request method=POST, path=${path}, base=${AppConfig.AUTH_API_BASE_URL}, hasToken=${accessToken.trim().length > 0 ? 1 : 0}`
    );
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
    this.logRawResult('POST', path, response.result);

    return this.parseBody<T>(response.result, `POST ${path}`);
  }

  async get<T>(path: string, accessToken: string): Promise<ApiEnvelope<T>> {
    const url = `${AppConfig.AUTH_API_BASE_URL}${path}`;
    hilog.info(
      AuthApiClient.LOG_DOMAIN,
      AuthApiClient.LOG_TAG,
      `[LOGIN_TRACE][api] request method=GET, path=${path}, base=${AppConfig.AUTH_API_BASE_URL}, hasToken=${accessToken.trim().length > 0 ? 1 : 0}`
    );
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
    this.logRawResult('GET', path, response.result);

    return this.parseBody<T>(response.result, `GET ${path}`);
  }

  async patch<T>(path: string, payload: object, accessToken: string): Promise<ApiEnvelope<T>> {
    const url = `${AppConfig.AUTH_API_BASE_URL}${path}`;
    hilog.info(
      AuthApiClient.LOG_DOMAIN,
      AuthApiClient.LOG_TAG,
      `[LOGIN_TRACE][api] request method=PATCH, path=${path}, base=${AppConfig.AUTH_API_BASE_URL}, hasToken=${accessToken.trim().length > 0 ? 1 : 0}`
    );
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
    this.logRawResult('PATCH', path, response.result);

    return this.parseBody<T>(response.result, `PATCH ${path}`);
  }

  private parseBody<T>(rawResult: Object, traceName: string): ApiEnvelope<T> {
    try {
      const body = JSON.parse(String(rawResult)) as ApiEnvelope<T>;
      hilog.info(
        AuthApiClient.LOG_DOMAIN,
        AuthApiClient.LOG_TAG,
        `[LOGIN_TRACE][api] envelope trace=${traceName}, code=${Number(body?.code || 0)}, message=${String(body?.message || '')}, hasData=${body?.data ? 1 : 0}`
      );
      return body;
    } catch (_error) {
      hilog.error(
        AuthApiClient.LOG_DOMAIN,
        AuthApiClient.LOG_TAG,
        `[LOGIN_TRACE][api] parse_fail trace=${traceName}, rawLen=${String(rawResult || '').length}`
      );
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
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error || '');
      hilog.error(
        AuthApiClient.LOG_DOMAIN,
        AuthApiClient.LOG_TAG,
        `[LOGIN_TRACE][api] request_fail trace=${traceName}, message=${message}`
      );
      throw new Error(message || `auth_api_request_fail_${traceName}`);
    } finally {
      if (timerId >= 0) {
        clearTimeout(timerId);
      }
    }
  }

  private logRawResult(method: string, path: string, rawResult: Object): void {
    const text = String(rawResult || '');
    hilog.info(
      AuthApiClient.LOG_DOMAIN,
      AuthApiClient.LOG_TAG,
      `[LOGIN_TRACE][api] response method=${method}, path=${path}, rawLen=${text.length}, preview=${text.substring(0, 120)}`
    );
  }
}
