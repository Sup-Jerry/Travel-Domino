import { hilog } from '@kit.PerformanceAnalysisKit';
import fileIo from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import util from '@ohos.util';
import { AuthApiResponse, UpdateAvatarResult } from '../../domain/auth/AuthModels';
import { AvatarUploadInput, AvatarUploadResult } from '../../domain/auth/AvatarModels';
import { AuthGateway } from '../auth/AuthGateway';
import { AuthSessionStore } from '../auth/AuthSessionStore';
import { AvatarUploadPort } from './AvatarUploadPort';

const TAG = 'AvatarUploadApi';

export interface AvatarUploadApiOptions {
  getAccessToken?: () => string;
  encodeFileToDataUrl?: (fileUriText: string, mimeType: string) => string;
  updateAvatar?: (accessToken: string, imageDataUrl: string, mimeType: string) => Promise<AuthApiResponse<UpdateAvatarResult>>;
  now?: () => number;
}

export class AvatarUploadApi implements AvatarUploadPort {
  private readonly getAccessToken: () => string;
  private readonly encodeFileToDataUrl: (fileUriText: string, mimeType: string) => string;
  private readonly updateAvatar: (accessToken: string, imageDataUrl: string, mimeType: string) => Promise<AuthApiResponse<UpdateAvatarResult>>;
  private readonly now: () => number;

  constructor(options?: AvatarUploadApiOptions) {
    this.getAccessToken = options?.getAccessToken || (() => AuthSessionStore.getAccessToken());
    this.encodeFileToDataUrl = options?.encodeFileToDataUrl || AvatarUploadApi.readFileAsDataUrl;
    this.updateAvatar = options?.updateAvatar || ((accessToken: string, imageDataUrl: string, mimeType: string) =>
      AuthGateway.updateAvatar(accessToken, imageDataUrl, mimeType));
    this.now = options?.now || (() => Date.now());
  }

  public async uploadAvatar(input: AvatarUploadInput): Promise<AvatarUploadResult> {
    const result = new AvatarUploadResult();
    result.requestId = `avatar_req_${this.now()}`;

    const accessToken = this.getAccessToken();
    if (!accessToken) {
      result.status = 'LOCAL_ONLY';
      result.errorCode = 'NO_SESSION';
      return result;
    }

    try {
      const dataUrl = this.encodeFileToDataUrl(input.fileUri, input.mimeType || 'image/jpeg');
      const response = await this.updateAvatar(accessToken, dataUrl, input.mimeType || 'image/jpeg');
      if (response.code !== 0) {
        result.status = 'LOCAL_ONLY';
        result.errorCode = `${response.code}`;
        return result;
      }

      result.status = 'SYNCED';
      result.remoteUrl = String(response.data.avatarUrl || '');
      return result;
    } catch (error) {
      result.status = 'LOCAL_ONLY';
      result.errorCode = 'UPLOAD_EXCEPTION';
      hilog.warn(0x0000, TAG, `upload avatar failed: ${AvatarUploadApi.errorMessage(error)}`);
      return result;
    }
  }

  public static readFileAsDataUrl(fileUriText: string, mimeType: string): string {
    try {
      const path = AvatarUploadApi.resolveFilePath(fileUriText);
      const stat = fileIo.statSync(path);
      const total = Number(stat.size);
      if (!Number.isFinite(total) || total <= 0) {
        throw new Error('avatar_file_empty');
      }

      const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      try {
        const buffer = new ArrayBuffer(total);
        const readSize = fileIo.readSync(file.fd, buffer);
        if (readSize <= 0) {
          throw new Error('avatar_file_read_empty');
        }
        const source = new Uint8Array(buffer);
        const content = source.slice(0, readSize);
        const helper = new util.Base64Helper();
        const base64 = helper.encodeToStringSync(content, util.Type.BASIC);
        const safeMime = mimeType && mimeType.trim().length > 0 ? mimeType.trim() : 'image/jpeg';
        return `data:${safeMime};base64,${base64}`;
      } finally {
        fileIo.closeSync(file);
      }
    } catch (error) {
      const msg = AvatarUploadApi.errorMessage(error);
      hilog.error(0x0000, TAG, `readFileAsDataUrl failed: ${msg}`);
      throw new Error(msg);
    }
  }

  private static resolveFilePath(rawFileUri: string): string {
    const trimmed = String(rawFileUri || '').trim();
    if (!trimmed) {
      throw new Error('avatar_uri_empty');
    }
    if (trimmed.startsWith('file://')) {
      const uri = new fileUri.FileUri(trimmed);
      return decodeURIComponent(uri.path);
    }
    return trimmed;
  }

  private static errorMessage(error: Object): string {
    if (error instanceof Error) {
      return error.message;
    }
    return 'unknown_error';
  }
}

