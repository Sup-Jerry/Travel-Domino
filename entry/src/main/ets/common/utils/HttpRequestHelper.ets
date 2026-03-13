import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

export class HttpRequestHelper {
  private static readonly TAG = 'HttpRequestHelper';

  public static async request(
    ownerTag: string,
    requestName: string,
    url: string,
    options: http.HttpRequestOptions
  ): Promise<http.HttpResponse> {
    const httpRequest = http.createHttp();
    const safeUrl = HttpRequestHelper.sanitizeUrl(url);
    const tracePrefix = `[HTTP_TRACE][${ownerTag}][${requestName}]`;

    hilog.info(0x0000, HttpRequestHelper.TAG, `${tracePrefix} create success, url=${safeUrl}`);

    try {
      const response = await httpRequest.request(url, options);
      hilog.info(
        0x0000,
        HttpRequestHelper.TAG,
        `${tracePrefix} request finished, responseCode=${response.responseCode}`
      );
      return response;
    } catch (error) {
      hilog.error(
        0x0000,
        HttpRequestHelper.TAG,
        `${tracePrefix} request failed, error=${JSON.stringify(error)}`
      );
      throw HttpRequestHelper.toError(error, `${tracePrefix} request failed`);
    } finally {
      try {
        httpRequest.destroy();
        hilog.info(0x0000, HttpRequestHelper.TAG, `${tracePrefix} destroy success`);
      } catch (destroyError) {
        hilog.error(
          0x0000,
          HttpRequestHelper.TAG,
          `${tracePrefix} destroy failed, error=${JSON.stringify(destroyError)}`
        );
      }
    }
  }

  private static sanitizeUrl(url: string): string {
    if (!url || url.trim() === '') {
      return '';
    }

    return url.replace(/([?&](?:key|api_key|token|Authorization)=)[^&]*/ig, '$1***');
  }

  private static toError(value: Object, fallbackMessage: string): Error {
    if (value instanceof Error) {
      return value;
    }
    const detail = JSON.stringify(value);
    return new Error(detail ? `${fallbackMessage}: ${detail}` : fallbackMessage);
  }
}
