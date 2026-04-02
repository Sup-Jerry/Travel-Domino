import { hilog } from '@kit.PerformanceAnalysisKit';
import { AvatarUploadInput, AvatarUploadResult } from '../../domain/auth/AvatarModels';
import { AvatarUploadPort } from './AvatarUploadPort';
import { AvatarStorageService, AvatarUploadPayload } from '../storage/AvatarStorageService';

const TAG = 'AvatarUploadApi';
const LOG_DOMAIN = 0x0000;

export interface AvatarUploadApiOptions {
  storageService?: AvatarStorageService;
  uploadAvatar?: (accountId: string, localUri: string, avatarVersion?: number) => Promise<AvatarUploadPayload>;
  now?: () => number;
}

export class AvatarUploadApi implements AvatarUploadPort {
  private readonly storageService: AvatarStorageService | null;
  private readonly uploadAvatarToCloud: (accountId: string, localUri: string, avatarVersion?: number) => Promise<AvatarUploadPayload>;
  private readonly now: () => number;

  constructor(options?: AvatarUploadApiOptions) {
    this.storageService = options?.storageService || null;
    this.uploadAvatarToCloud = options?.uploadAvatar || ((accountId: string, localUri: string, avatarVersion?: number) => {
      if (!this.storageService) {
        throw new Error('storage_service_required');
      }
      return this.storageService.uploadAvatar(accountId, localUri, avatarVersion);
    });
    this.now = options?.now || (() => Date.now());
  }

  public async uploadAvatar(input: AvatarUploadInput): Promise<AvatarUploadResult> {
    const result = new AvatarUploadResult();
    result.requestId = `avatar_req_${this.now()}`;
    const accountId = String(input.accountId || input.userId || '').trim();
    hilog.info(
      LOG_DOMAIN,
      TAG,
      `[PROFILE_TRACE][upload_api] start accountId=${accountId || 'empty'}, hasStorage=${this.storageService ? 1 : 0}, fileUriLen=${String(input.fileUri || '').length}`
    );
    if (!accountId) {
      result.status = 'LOCAL_ONLY';
      result.errorCode = 'NO_ACCOUNT_ID';
      hilog.warn(LOG_DOMAIN, TAG, '[PROFILE_TRACE][upload_api] skip no accountId');
      return result;
    }

    try {
      const safeVersion = Number.isFinite(Number(input.avatarVersion)) && Number(input.avatarVersion) > 0
        ? Math.floor(Number(input.avatarVersion))
        : this.now();
      const payload = await this.uploadAvatarToCloud(accountId, input.fileUri, safeVersion);
      result.status = 'SYNCED';
      result.remoteUrl = String(payload.downloadUrl || '');
      result.avatarPath = String(payload.avatarPath || '');
      result.avatarVersion = Number(payload.avatarVersion || 0);
      hilog.info(
        LOG_DOMAIN,
        TAG,
        `[PROFILE_TRACE][upload_api] success accountId=${accountId}, avatarPath=${result.avatarPath || 'empty'}, version=${Number(result.avatarVersion || 0)}, remoteUrlLen=${String(result.remoteUrl || '').length}`
      );
      return result;
    } catch (error) {
      result.status = 'LOCAL_ONLY';
      result.errorCode = 'UPLOAD_EXCEPTION';
      hilog.warn(
        LOG_DOMAIN,
        TAG,
        `[PROFILE_TRACE][upload_api] failed accountId=${accountId}, reason=${AvatarUploadApi.errorMessage(error)}`
      );
      return result;
    }
  }

  private static errorMessage(error: Object): string {
    if (error instanceof Error) {
      return error.message;
    }
    return 'unknown_error';
  }
}
