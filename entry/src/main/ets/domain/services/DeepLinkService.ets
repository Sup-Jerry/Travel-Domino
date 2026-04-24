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
    let uint8Array: Uint8Array = new Uint8Array();
    try {
      uint8Array = base64Helper.decodeSync(base64);
    } catch (_error) {
      uint8Array = DeepLinkService.decodeBase64Bytes(base64);
    }
    if (uint8Array.length === 0 && base64.length > 0) {
      uint8Array = DeepLinkService.decodeBase64Bytes(base64);
    }
    let textDecoder: util.TextDecoder | null = null;
    try {
      textDecoder = util.TextDecoder.create('utf-8');
    } catch (_error) {
      textDecoder = new util.TextDecoder('utf-8');
    }
    try {
      return textDecoder.decodeToString(uint8Array);
    } catch (_error) {
      try {
        return textDecoder.decodeWithStream(uint8Array);
      } catch (_fallbackError) {
        return DeepLinkService.decodeUtf8Bytes(uint8Array);
      }
    }
  }

  private static decodeBase64Bytes(base64: string): Uint8Array {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    const clean = (base64 || '').replace(/\s/g, '');
    const bytes: number[] = [];
    let buffer = 0;
    let bits = 0;
    for (let i = 0; i < clean.length; i++) {
      const ch = clean.charAt(i);
      if (ch === '=') {
        break;
      }
      const value = alphabet.indexOf(ch);
      if (value < 0) {
        throw new Error('invalid_base64_payload');
      }
      buffer = (buffer << 6) | value;
      bits += 6;
      if (bits >= 8) {
        bits -= 8;
        bytes.push((buffer >> bits) & 0xFF);
      }
    }
    return new Uint8Array(bytes);
  }

  private static decodeUtf8Bytes(bytes: Uint8Array): string {
    let result = '';
    let index = 0;
    while (index < bytes.length) {
      const first = bytes[index];
      if (first < 0x80) {
        result += String.fromCharCode(first);
        index += 1;
        continue;
      }
      if (first >= 0xC0 && first < 0xE0 && index + 1 < bytes.length) {
        const code = ((first & 0x1F) << 6) | (bytes[index + 1] & 0x3F);
        result += String.fromCharCode(code);
        index += 2;
        continue;
      }
      if (first >= 0xE0 && first < 0xF0 && index + 2 < bytes.length) {
        const code = ((first & 0x0F) << 12) | ((bytes[index + 1] & 0x3F) << 6) | (bytes[index + 2] & 0x3F);
        result += String.fromCharCode(code);
        index += 3;
        continue;
      }
      if (first >= 0xF0 && first < 0xF8 && index + 3 < bytes.length) {
        const codePoint = ((first & 0x07) << 18) |
          ((bytes[index + 1] & 0x3F) << 12) |
          ((bytes[index + 2] & 0x3F) << 6) |
          (bytes[index + 3] & 0x3F);
        const offset = codePoint - 0x10000;
        result += String.fromCharCode(0xD800 + (offset >> 10), 0xDC00 + (offset & 0x3FF));
        index += 4;
        continue;
      }
      result += String.fromCharCode(0xFFFD);
      index += 1;
    }
    return result;
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
