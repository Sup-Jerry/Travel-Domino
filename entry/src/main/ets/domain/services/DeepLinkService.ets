import { util } from '@kit.ArkTS';

/**
 * Deep Link 服务
 * 处理应用分享链接的生成和解析
 */
export class DeepLinkService {
  private static readonly SCHEME = 'travelapp';
  private static readonly HOST = 'import';
  private static readonly DATA_QUERY_KEY = 'data=';

  /**
   * 构建分享链接
   * @param compressedJson 压缩后的 JSON 字符串
   * @returns Deep Link URL
   */
  public static buildShareLink(compressedJson: string): string {
    const base64Data = DeepLinkService.encodeBase64(compressedJson);
    return `${DeepLinkService.SCHEME}://${DeepLinkService.HOST}?data=${encodeURIComponent(base64Data)}`;
  }

  /**
   * 解析分享链接
   * @param url Deep Link URL
   * @returns 解压后的 JSON 字符串
   */
  public static parseShareLink(url: string): string {
    if (!url.startsWith(`${DeepLinkService.SCHEME}://${DeepLinkService.HOST}`)) {
      throw new Error('invalid_deep_link_scheme');
    }

    const encodedData = DeepLinkService.extractDataQuery(url);
    if (!encodedData) {
      throw new Error('missing_data_parameter');
    }

    return DeepLinkService.decodeBase64(decodeURIComponent(encodedData));
  }

  private static encodeBase64(str: string): string {
    const textEncoder = new util.TextEncoder();
    const uint8Array = textEncoder.encodeInto(str);
    const base64Helper = new util.Base64Helper();
    return base64Helper.encodeToStringSync(uint8Array);
  }

  private static decodeBase64(base64: string): string {
    const base64Helper = new util.Base64Helper();
    const uint8Array = base64Helper.decodeSync(base64);
    const textDecoder = util.TextDecoder.create('utf-8');
    return textDecoder.decodeWithStream(uint8Array);
  }

  private static extractDataQuery(url: string): string | null {
    const queryStart = url.indexOf('?');
    if (queryStart < 0 || queryStart >= url.length - 1) {
      return null;
    }

    const queryString = url.slice(queryStart + 1);
    const segments = queryString.split('&');
    for (const segment of segments) {
      if (segment.startsWith(DeepLinkService.DATA_QUERY_KEY)) {
        const value = segment.slice(DeepLinkService.DATA_QUERY_KEY.length);
        return value.length > 0 ? value : null;
      }
    }
    return null;
  }
}
