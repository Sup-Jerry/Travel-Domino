import { image } from '@kit.ImageKit';
import { BarcodeFormat, BitMatrix, EncodeHintType, MultiFormatWriter } from '@ohos/zxing';

/**
 * 二维码生成服务
 * 使用 @ohos/zxing 生成可扫描二维码
 */
export class QRCodeService {
  /**
   * 生成二维码图片
   * @param data 要编码的数据
   * @param size 二维码尺寸（像素）
   * @returns PixelMap 对象
   */
  public static async generateQRCode(data: string, size: number = 200): Promise<image.PixelMap> {
    const content = data.trim();
    if (content.length <= 0) {
      throw new Error('qr_content_empty');
    }

    const width = Math.max(64, Math.floor(size));
    const height = Math.max(64, Math.floor(size));
    const hints: Map<EncodeHintType, number | string> = new Map<EncodeHintType, number | string>();
    hints.set(EncodeHintType.MARGIN, 0);
    hints.set(EncodeHintType.CHARACTER_SET, 'UTF-8');

    const writer: MultiFormatWriter = new MultiFormatWriter();
    const matrix: BitMatrix = writer.encode(content, BarcodeFormat.QR_CODE, width, height, hints);
    return QRCodeService.matrixToPixelMap(matrix);
  }

  private static async matrixToPixelMap(matrix: BitMatrix): Promise<image.PixelMap> {
    const width = matrix.getWidth();
    const height = matrix.getHeight();
    const buffer = new Uint8Array(width * height * 4);

    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        const offset = (y * width + x) * 4;
        const color = matrix.get(x, y) ? 0 : 255;
        buffer[offset] = color;
        buffer[offset + 1] = color;
        buffer[offset + 2] = color;
        buffer[offset + 3] = 255;
      }
    }

    const options: image.InitializationOptions = {
      size: { height: height, width: width },
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      alphaType: image.AlphaType.OPAQUE,
      editable: false
    };
    return image.createPixelMap(buffer.buffer, options);
  }
}
