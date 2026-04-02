import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import fileIo from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import agconnect from '@hw-agconnect/api-ohos';
import '@hw-agconnect/core-ohos';
import '@hw-agconnect/cloudstorage-ohos';
import { StorageManagement, StorageReference, UploadTask } from '@hw-agconnect/cloudstorage-ohos';

interface StorageReferenceCompat extends StorageReference {
  put?: (data: Uint8Array | ArrayBuffer) => UploadTask;
}

export class AvatarUploadPayload {
  avatarPath: string = '';
  avatarVersion: number = 0;
  downloadUrl: string = '';
}

export class AvatarStorageService {
  private static readonly LOG_DOMAIN: number = 0x0000;
  private static readonly LOG_TAG: string = 'AvatarStorage';
  private static readonly AVATAR_ROOT: string = 'avatars';
  private static readonly UPLOAD_IDLE_TIMEOUT_MS: number = 15000;
  private static readonly UPLOAD_TOTAL_TIMEOUT_MS: number = 90000;

  private readonly context: common.Context;

  constructor(context: common.Context) {
    this.context = context;
  }

  public static createDefault(context: common.Context): AvatarStorageService {
    return new AvatarStorageService(context);
  }

  public async uploadAvatar(accountId: string, localUri: string, avatarVersion?: number): Promise<AvatarUploadPayload> {
    const safeAccountId = this.normalizeAccountId(accountId);
    if (!safeAccountId) {
      throw new Error('account_id_required');
    }
    const safeVersion = this.normalizeAvatarVersion(avatarVersion);
    const avatarPath = `${AvatarStorageService.AVATAR_ROOT}/${safeAccountId}/${safeVersion}.jpg`;
    hilog.info(
      AvatarStorageService.LOG_DOMAIN,
      AvatarStorageService.LOG_TAG,
      `[PROFILE_TRACE][storage] upload start accountId=${safeAccountId}, localUriLen=${String(localUri || '').length}, avatarPath=${avatarPath}`
    );
    try {
      hilog.info(
        AvatarStorageService.LOG_DOMAIN,
        AvatarStorageService.LOG_TAG,
        '[PROFILE_TRACE][storage] step=read_file begin'
      );
      const data = AvatarStorageService.readFileAsBytes(localUri);
      hilog.info(
        AvatarStorageService.LOG_DOMAIN,
        AvatarStorageService.LOG_TAG,
        `[PROFILE_TRACE][storage] step=read_file ok bytes=${data.byteLength}`
      );
      hilog.info(
        AvatarStorageService.LOG_DOMAIN,
        AvatarStorageService.LOG_TAG,
        '[PROFILE_TRACE][storage] step=get_reference begin'
      );
      const reference = await this.getStorageReference(avatarPath);
      hilog.info(
        AvatarStorageService.LOG_DOMAIN,
        AvatarStorageService.LOG_TAG,
        '[PROFILE_TRACE][storage] step=get_reference ok'
      );
      hilog.info(
        AvatarStorageService.LOG_DOMAIN,
        AvatarStorageService.LOG_TAG,
        '[PROFILE_TRACE][storage] step=put begin'
      );
      const uploadTask = this.startUpload(reference, data);
      hilog.info(
        AvatarStorageService.LOG_DOMAIN,
        AvatarStorageService.LOG_TAG,
        '[PROFILE_TRACE][storage] step=put ok'
      );
      await this.waitUploadTask(uploadTask);
      hilog.info(
        AvatarStorageService.LOG_DOMAIN,
        AvatarStorageService.LOG_TAG,
        '[PROFILE_TRACE][storage] step=wait_upload ok'
      );
      const downloadUrl = await reference.getDownloadURL();
      const payload = new AvatarUploadPayload();
      payload.avatarPath = avatarPath;
      payload.avatarVersion = safeVersion;
      payload.downloadUrl = String(downloadUrl || '');
      hilog.info(
        AvatarStorageService.LOG_DOMAIN,
        AvatarStorageService.LOG_TAG,
        `[PROFILE_TRACE][storage] upload ok accountId=${safeAccountId}, version=${safeVersion}`
      );
      return payload;
    } catch (error) {
      const reason = error instanceof Error ? (error.message || 'storage_upload_failed') : 'storage_upload_failed';
      hilog.error(
        AvatarStorageService.LOG_DOMAIN,
        AvatarStorageService.LOG_TAG,
        `[PROFILE_TRACE][storage] upload fail accountId=${safeAccountId}, reason=${reason}`
      );
      throw error instanceof Error ? error : new Error(reason);
    }
  }

  public async getDownloadUrl(avatarPath: string): Promise<string> {
    const normalizedPath = String(avatarPath || '').trim();
    if (!normalizedPath) {
      return '';
    }
    if (AvatarStorageService.isDirectUrl(normalizedPath)) {
      return normalizedPath;
    }
    const reference = await this.getStorageReference(normalizedPath);
    const downloadUrl = await reference.getDownloadURL();
    return String(downloadUrl || '');
  }

  private async getStorageReference(path: string): Promise<StorageReference> {
    this.initAgconnect();
    try {
      hilog.info(
        AvatarStorageService.LOG_DOMAIN,
        AvatarStorageService.LOG_TAG,
        '[PROFILE_TRACE][storage] step=get_storage_service begin'
      );
      const storage: StorageManagement = agconnect.cloudStorage();
      hilog.info(
        AvatarStorageService.LOG_DOMAIN,
        AvatarStorageService.LOG_TAG,
        '[PROFILE_TRACE][storage] step=get_storage_service ok'
      );
      hilog.info(
        AvatarStorageService.LOG_DOMAIN,
        AvatarStorageService.LOG_TAG,
        '[PROFILE_TRACE][storage] step=get_root_reference begin'
      );
      const rootReference = await storage.storageReference();
      hilog.info(
        AvatarStorageService.LOG_DOMAIN,
        AvatarStorageService.LOG_TAG,
        '[PROFILE_TRACE][storage] step=get_root_reference ok'
      );
      return rootReference.child(path);
    } catch (error) {
      const reason = error instanceof Error ? (error.message || 'cloud_storage_reference_error') : 'cloud_storage_reference_error';
      hilog.error(
        AvatarStorageService.LOG_DOMAIN,
        AvatarStorageService.LOG_TAG,
        `[PROFILE_TRACE][storage] step=get_reference fail reason=${reason}`
      );
      throw new Error(reason);
    }
  }

  private waitUploadTask(uploadTask: UploadTask): Promise<void> {
    return new Promise<void>((resolve: () => void, reject: (reason: Error) => void) => {
      let settled = false;
      let lastPercent = -1;
      let idleTimer: number | undefined = undefined;
      const totalTimer = setTimeout(() => {
        if (settled) {
          return;
        }
        settled = true;
        reject(new Error(`upload_timeout_total_${AvatarStorageService.UPLOAD_TOTAL_TIMEOUT_MS}ms`));
      }, AvatarStorageService.UPLOAD_TOTAL_TIMEOUT_MS);

      const resetIdleTimer = () => {
        if (idleTimer !== undefined) {
          clearTimeout(idleTimer);
        }
        idleTimer = setTimeout(() => {
          if (settled) {
            return;
          }
          settled = true;
          clearTimeout(totalTimer);
          reject(new Error(`upload_timeout_idle_${AvatarStorageService.UPLOAD_IDLE_TIMEOUT_MS}ms`));
        }, AvatarStorageService.UPLOAD_IDLE_TIMEOUT_MS);
      };

      const clearTimers = () => {
        clearTimeout(totalTimer);
        if (idleTimer !== undefined) {
          clearTimeout(idleTimer);
        }
      };

      resetIdleTimer();
      try {
        uploadTask.on('progress', (uploadedSize: number, totalSize: number) => {
          if (settled || totalSize <= 0) {
            return;
          }
          resetIdleTimer();
          const percent = Math.floor((uploadedSize * 100) / totalSize);
          if (percent >= lastPercent + 25 || percent === 100) {
            lastPercent = percent;
            hilog.info(
              AvatarStorageService.LOG_DOMAIN,
              AvatarStorageService.LOG_TAG,
              `[PROFILE_TRACE][storage] step=upload_progress percent=${percent}, uploaded=${uploadedSize}, total=${totalSize}`
            );
          }
        });
        const chained = uploadTask.then(() => {
          if (settled) {
            return;
          }
          settled = true;
          clearTimers();
          resolve();
        });
        chained.catch((error: Error) => {
          if (settled) {
            return;
          }
          settled = true;
          clearTimers();
          reject(new Error(this.normalizeStorageError(error)));
        });
      } catch (error) {
        if (settled) {
          return;
        }
        settled = true;
        clearTimers();
        const reason = error instanceof Error ? (error.message || 'upload_task_wait_failed') : 'upload_task_wait_failed';
        reject(new Error(reason));
      }
    });
  }

  private startUpload(reference: StorageReference, data: Uint8Array): UploadTask {
    const compatReference = reference as StorageReferenceCompat;
    if (typeof compatReference.putData === 'function') {
      return compatReference.putData(data);
    }
    if (typeof compatReference.put === 'function') {
      return compatReference.put(data);
    }
    throw new Error('storage_put_method_missing');
  }

  private initAgconnect(): void {
    const appContext = this.context.getApplicationContext();
    agconnect.instance().init(appContext);
  }

  private normalizeAccountId(accountId: string): string {
    const raw = String(accountId || '').trim();
    if (!raw) {
      return '';
    }
    return raw.replace(/[^A-Za-z0-9_\-]/g, '_');
  }

  private normalizeAvatarVersion(avatarVersion?: number): number {
    const raw = Number(avatarVersion);
    if (Number.isFinite(raw) && raw > 0) {
      return Math.floor(raw);
    }
    return Date.now();
  }

  private static readFileAsBytes(fileUriText: string): Uint8Array {
    const candidates = AvatarStorageService.resolveReadCandidates(fileUriText);
    let lastReason: string = 'avatar_file_read_failed';
    for (let i = 0; i < candidates.length; i += 1) {
      const candidate = candidates[i];
      try {
        return AvatarStorageService.readBytesByCandidate(candidate);
      } catch (error) {
        const reason = error instanceof Error ? (error.message || 'avatar_file_read_failed') : 'avatar_file_read_failed';
        lastReason = reason;
        hilog.warn(
          AvatarStorageService.LOG_DOMAIN,
          AvatarStorageService.LOG_TAG,
          `[PROFILE_TRACE][storage] step=read_file candidate_fail index=${i}, candidateLen=${candidate.length}, reason=${reason}`
        );
      }
    }
    throw new Error(lastReason);
  }

  private static readBytesByCandidate(candidate: string): Uint8Array {
    const stat = fileIo.statSync(candidate);
    const total = Number(stat.size);
    if (!Number.isFinite(total) || total <= 0) {
      throw new Error('avatar_file_empty');
    }
    const file = fileIo.openSync(candidate, fileIo.OpenMode.READ_ONLY);
    try {
      const buffer = new ArrayBuffer(total);
      const readSize = fileIo.readSync(file.fd, buffer);
      if (readSize <= 0) {
        throw new Error('avatar_file_read_empty');
      }
      return new Uint8Array(buffer).slice(0, readSize);
    } finally {
      fileIo.closeSync(file);
    }
  }

  private static resolveReadCandidates(rawFileUri: string): string[] {
    const trimmed = String(rawFileUri || '').trim();
    if (!trimmed) {
      throw new Error('avatar_uri_empty');
    }
    const candidates: string[] = [];
    candidates.push(trimmed);
    if (trimmed.startsWith('file://')) {
      try {
        const uri = new fileUri.FileUri(trimmed);
        const decodedPath = decodeURIComponent(uri.path);
        if (decodedPath) {
          candidates.push(decodedPath);
        }
      } catch (_error) {
        // ignore parse error and keep fallback candidates
      }
      const removedPrefix = trimmed.replace('file://', '');
      if (removedPrefix && removedPrefix !== trimmed) {
        candidates.push(removedPrefix);
      }
    }
    return candidates.filter((value: string, index: number, arr: string[]) => arr.indexOf(value) === index);
  }

  private static isDirectUrl(value: string): boolean {
    return value.startsWith('http://') || value.startsWith('https://') || value.startsWith('file://');
  }

  private normalizeStorageError(error: Object | undefined): string {
    if (error instanceof Error) {
      return error.message || 'storage_upload_failed';
    }
    const message = (error as Record<string, Object> | undefined)?.message;
    if (typeof message === 'string' && message.trim().length > 0) {
      return message;
    }
    try {
      return JSON.stringify(error);
    } catch (_jsonError) {
      return 'storage_upload_failed';
    }
  }
}
