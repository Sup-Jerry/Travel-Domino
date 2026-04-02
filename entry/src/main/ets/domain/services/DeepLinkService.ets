import { util } from '@kit.ArkTS';

/**
 * Deep Link 服务
 * 处理应用分享链接的生成和解析
 */
export class DeepLinkService {
  private static readonly SCHEME = 'travelapp';
  private static readonly HOST = 'import';

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

    const urlObj = new URL(url);
    const base64Data = urlObj.searchParams.get('data');

    if (!base64Data) {
      throw new Error('missing_data_parameter');
    }

    return DeepLinkService.decodeBase64(decodeURIComponent(base64Data));
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
}
