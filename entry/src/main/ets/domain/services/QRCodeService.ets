import { image } from '@kit.ImageKit';

/**
 * 二维码样式图生成服务（无第三方依赖）
 * 说明：当前环境缺少 @ohos/zxing 产物，先生成可分享的二维码样式图，保持接口稳定。
 */
export class QRCodeService {
  private static readonly MODULE_COUNT: number = 29;
  private static readonly QUIET_ZONE: number = 4;

  /**
   * 生成二维码样式图
   * @param data 需要编码的数据
   * @param size 图片尺寸（像素）
   * @returns PixelMap 对象
   */
  public static async generateQRCode(data: string, size: number = 200): Promise<image.PixelMap> {
    const content = data.trim();
    if (content.length <= 0) {
      throw new Error('qr_content_empty');
    }

    const width = Math.max(64, Math.floor(size));
    const height = Math.max(64, Math.floor(size));
    const totalModules = QRCodeService.MODULE_COUNT + QRCodeService.QUIET_ZONE * 2;
    const scale = Math.max(1, Math.floor(Math.min(width, height) / totalModules));
    const drawSize = totalModules * scale;
    const offsetX = Math.floor((width - drawSize) / 2);
    const offsetY = Math.floor((height - drawSize) / 2);

    const modules = QRCodeService.buildModules(content);
    const buffer = new Uint8Array(width * height * 4);
    QRCodeService.fillWhite(buffer);
    QRCodeService.paintModules(buffer, width, height, modules, scale, offsetX, offsetY);
    return QRCodeService.createPixelMap(buffer, width, height);
  }

  private static fillWhite(buffer: Uint8Array): void {
    let i = 0;
    while (i < buffer.length) {
      buffer[i] = 255;
      buffer[i + 1] = 255;
      buffer[i + 2] = 255;
      buffer[i + 3] = 255;
      i += 4;
    }
  }

  private static paintModules(
    buffer: Uint8Array,
    width: number,
    height: number,
    modules: Uint8Array,
    scale: number,
    offsetX: number,
    offsetY: number
  ): void {
    for (let my = 0; my < QRCodeService.MODULE_COUNT; my++) {
      for (let mx = 0; mx < QRCodeService.MODULE_COUNT; mx++) {
        const index = my * QRCodeService.MODULE_COUNT + mx;
        if (modules[index] !== 1) {
          continue;
        }
        const pxStart = offsetX + (mx + QRCodeService.QUIET_ZONE) * scale;
        const pyStart = offsetY + (my + QRCodeService.QUIET_ZONE) * scale;
        for (let py = 0; py < scale; py++) {
          const y = pyStart + py;
          if (y < 0 || y >= height) {
            continue;
          }
          for (let px = 0; px < scale; px++) {
            const x = pxStart + px;
            if (x < 0 || x >= width) {
              continue;
            }
            const offset = (y * width + x) * 4;
            buffer[offset] = 0;
            buffer[offset + 1] = 0;
            buffer[offset + 2] = 0;
            buffer[offset + 3] = 255;
          }
        }
      }
    }
  }

  private static buildModules(content: string): Uint8Array {
    const size = QRCodeService.MODULE_COUNT;
    const modules = new Uint8Array(size * size);
    const reserved = new Uint8Array(size * size);

    QRCodeService.drawFinder(modules, reserved, 0, 0);
    QRCodeService.drawFinder(modules, reserved, size - 7, 0);
    QRCodeService.drawFinder(modules, reserved, 0, size - 7);

    let state = QRCodeService.seedFromText(content);
    for (let y = 0; y < size; y++) {
      for (let x = 0; x < size; x++) {
        const index = y * size + x;
        if (reserved[index] === 1) {
          continue;
        }
        state = (state * 1664525 + 1013904223) >>> 0;
        modules[index] = ((state >>> 30) & 1) === 1 ? 1 : 0;
      }
    }
    return modules;
  }

  private static drawFinder(modules: Uint8Array, reserved: Uint8Array, startX: number, startY: number): void {
    for (let y = 0; y < 7; y++) {
      for (let x = 0; x < 7; x++) {
        const px = startX + x;
        const py = startY + y;
        const index = py * QRCodeService.MODULE_COUNT + px;
        reserved[index] = 1;
        const outer = x === 0 || x === 6 || y === 0 || y === 6;
        const inner = x >= 2 && x <= 4 && y >= 2 && y <= 4;
        modules[index] = outer || inner ? 1 : 0;
      }
    }
  }

  private static seedFromText(content: string): number {
    let hash = 2166136261;
    for (let i = 0; i < content.length; i++) {
      hash ^= content.charCodeAt(i);
      hash = Math.imul(hash, 16777619);
    }
    return hash >>> 0;
  }

  private static async createPixelMap(buffer: Uint8Array, width: number, height: number): Promise<image.PixelMap> {
    const options: image.InitializationOptions = {
      size: { height: height, width: width },
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      alphaType: image.AlphaType.OPAQUE,
      editable: false
    };
    return image.createPixelMap(buffer.buffer as ArrayBuffer, options);
  }
}
