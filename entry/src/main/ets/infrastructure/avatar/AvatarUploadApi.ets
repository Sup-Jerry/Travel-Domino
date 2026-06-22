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
const LOG_DOMAIN = 0x0000;

export type AvatarAccessTokenGetter = () => string;
export type AvatarDataUrlEncoder = (fileUriText: string, mimeType: string) => string;
export type AvatarUpdateGateway = (
  accessToken: string,
  imageDataUrl: string,
  mimeType: string
) => Promise<AuthApiResponse<UpdateAvatarResult>>;
export type AvatarNowGetter = () => number;

export interface AvatarUploadApiOptions {
  getAccessToken?: AvatarAccessTokenGetter;
  encodeFileToDataUrl?: AvatarDataUrlEncoder;
  updateAvatar?: AvatarUpdateGateway;
  now?: AvatarNowGetter;
}

interface AvatarUploadFileStatLike {
  size: number;
}

interface AvatarUploadBase64HelperLike {
  encodeToStringSync(content: Uint8Array, type: Object): string;
}

interface AvatarUploadFileUriLike {
  path: string;
}

interface AvatarUploadRuntimeDeps {
  statSync: (path: string) => AvatarUploadFileStatLike;
  openSync: (path: string, mode: number) => number;
  readSync: (fd: number, buffer: ArrayBuffer) => number;
  closeSync: (fd: number) => void;
  readOnlyMode: number;
  createFileUri: (raw: string) => AvatarUploadFileUriLike;
  createBase64Helper: () => AvatarUploadBase64HelperLike;
  basicType: Object;
}

export class AvatarUploadApi implements AvatarUploadPort {
  private static runtimeDeps: AvatarUploadRuntimeDeps = {
    statSync: (path: string) => fileIo.statSync(path) as AvatarUploadFileStatLike,
    openSync: (path: string, mode: number) => fileIo.openSync(path, mode).fd,
    readSync: (fd: number, buffer: ArrayBuffer) => fileIo.readSync(fd, buffer),
    closeSync: (fd: number) => fileIo.closeSync(fd),
    readOnlyMode: fileIo.OpenMode.READ_ONLY,
    createFileUri: (raw: string) => new fileUri.FileUri(raw) as AvatarUploadFileUriLike,
    createBase64Helper: () => new util.Base64Helper() as AvatarUploadBase64HelperLike,
    basicType: util.Type.BASIC as Object
  };

  private readonly getAccessToken: AvatarAccessTokenGetter;
  private readonly encodeFileToDataUrl: AvatarDataUrlEncoder;
  private readonly updateAvatar: AvatarUpdateGateway;
  private readonly now: AvatarNowGetter;

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
    const mimeType = input.mimeType || 'image/jpeg';
    hilog.info(
      LOG_DOMAIN,
      TAG,
      `[AVATAR_TRACE][upload_start] requestId=${result.requestId}, userId=${String(input.userId || '').trim()}, fileUriLen=${String(input.fileUri || '').trim().length}, mimeType=${mimeType}`
    );

    const accessToken = this.getAccessToken();
    if (!accessToken) {
      result.status = 'LOCAL_ONLY';
      result.errorCode = 'NO_SESSION';
      hilog.warn(LOG_DOMAIN, TAG, `[AVATAR_TRACE][upload_fail] requestId=${result.requestId}, phase=session, code=NO_SESSION`);
      return result;
    }

    try {
      const dataUrl = this.encodeFileToDataUrl(input.fileUri, mimeType);
      hilog.info(
        LOG_DOMAIN,
        TAG,
        `[AVATAR_TRACE][upload_encoded] requestId=${result.requestId}, dataUrlLen=${dataUrl.length}, tokenLen=${accessToken.length}`
      );
      const response = await this.updateAvatar(accessToken, dataUrl, mimeType);
      if (response.code !== 0) {
        result.status = 'LOCAL_ONLY';
        result.errorCode = `${response.code}`;
        hilog.warn(
          LOG_DOMAIN,
          TAG,
          `[AVATAR_TRACE][upload_fail] requestId=${result.requestId}, phase=gateway, code=${response.code}, message=${String(response.message || '')}`
        );
        return result;
      }

      result.status = 'SYNCED';
      result.remoteUrl = String(response.data.avatarUrl || '');
      hilog.info(
        LOG_DOMAIN,
        TAG,
        `[AVATAR_TRACE][upload_success] requestId=${result.requestId}, remoteUrlLen=${result.remoteUrl.length}`
      );
      return result;
    } catch (error) {
      result.status = 'LOCAL_ONLY';
      result.errorCode = 'UPLOAD_EXCEPTION';
      hilog.warn(
        LOG_DOMAIN,
        TAG,
        `[AVATAR_TRACE][upload_fail] requestId=${result.requestId}, phase=exception, code=UPLOAD_EXCEPTION, reason=${AvatarUploadApi.errorMessage(error)}`
      );
      return result;
    }
  }

  public static readFileAsDataUrl(fileUriText: string, mimeType: string): string {
    try {
      const path = AvatarUploadApi.resolveFilePath(fileUriText);
      const deps = AvatarUploadApi.runtimeDeps;
      const stat = deps.statSync(path);
      const total = Number(stat.size);
      if (!Number.isFinite(total) || total <= 0) {
        throw new Error('avatar_file_empty');
      }

      const fd = deps.openSync(path, deps.readOnlyMode);
      try {
        const buffer = new ArrayBuffer(total);
        const readSize = deps.readSync(fd, buffer);
        if (readSize <= 0) {
          throw new Error('avatar_file_read_empty');
        }
        const source = new Uint8Array(buffer);
        const content = source.slice(0, readSize);
        const helper = deps.createBase64Helper();
        const base64 = helper.encodeToStringSync(content, deps.basicType);
        const safeMime = mimeType && mimeType.trim().length > 0 ? mimeType.trim() : 'image/jpeg';
        return `data:${safeMime};base64,${base64}`;
      } finally {
        deps.closeSync(fd);
      }
    } catch (error) {
      const msg = AvatarUploadApi.errorMessage(error);
      hilog.error(LOG_DOMAIN, TAG, `[AVATAR_TRACE][encode_fail] reason=${msg}`);
      throw new Error(msg);
    }
  }

  private static resolveFilePath(rawFileUri: string): string {
    const trimmed = String(rawFileUri || '').trim();
    if (!trimmed) {
      throw new Error('avatar_uri_empty');
    }
    if (trimmed.startsWith('file://')) {
      const uri = AvatarUploadApi.runtimeDeps.createFileUri(trimmed);
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

