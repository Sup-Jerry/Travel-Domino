import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import fileIo from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import image from '@ohos.multimedia.image';
import { PreferenceManager } from '../../common/utils/PreferenceManager';
import { AvatarProfile, AvatarUploadInput } from '../../domain/auth/AvatarModels';
import { AvatarUploadPort } from './AvatarUploadPort';
import { AvatarUploadApi } from './AvatarUploadApi';
import { AvatarStorageService } from '../storage/AvatarStorageService';

const TAG = 'AvatarService';

export interface AvatarStorePort {
  loadAvatarProfile(userId: string): Promise<AvatarProfile>;
  saveAvatarProfile(profile: AvatarProfile): Promise<void>;
}

export interface AvatarPickerPort {
  select(option?: photoAccessHelper.PhotoSelectOptions): Promise<photoAccessHelper.PhotoSelectResult>;
}

export interface AvatarServiceOptions {
  picker?: AvatarPickerPort;
  store?: AvatarStorePort;
  uploader?: AvatarUploadPort;
  compressor?: (context: common.Context, srcUri: string, userId: string) => Promise<string>;
  now?: () => number;
}

export interface AvatarUploadRuntimeOptions {
  waitForUpload?: boolean;
  onUploadSynced?: (profile: AvatarProfile) => Promise<void>;
}

class PreferenceAvatarStore implements AvatarStorePort {
  private readonly context: common.Context;

  constructor(context: common.Context) {
    this.context = context;
  }

  public async loadAvatarProfile(userId: string): Promise<AvatarProfile> {
    const manager = PreferenceManager.getInstance();
    await manager.init(this.context);
    return manager.getAvatarProfile(userId);
  }

  public async saveAvatarProfile(profile: AvatarProfile): Promise<void> {
    const manager = PreferenceManager.getInstance();
    await manager.init(this.context);
    await manager.setAvatarProfile(profile);
  }
}

class InMemoryAvatarStore implements AvatarStorePort {
  private readonly store: Map<string, AvatarProfile> = new Map<string, AvatarProfile>();

  public async loadAvatarProfile(userId: string): Promise<AvatarProfile> {
    return this.store.get(userId) || new AvatarProfile();
  }

  public async saveAvatarProfile(profile: AvatarProfile): Promise<void> {
    const safe = new AvatarProfile();
    safe.userId = (profile.userId || '').trim();
    safe.localUri = profile.localUri || '';
    safe.compressedUri = profile.compressedUri || '';
    safe.cloudUrl = profile.cloudUrl || '';
    safe.cloudPath = profile.cloudPath || '';
    safe.avatarVersion = Number.isFinite(Number(profile.avatarVersion)) && Number(profile.avatarVersion) > 0
      ? Math.floor(Number(profile.avatarVersion))
      : 0;
    safe.uploadState = profile.uploadState || 'EMPTY';
    safe.updatedAt = Number(profile.updatedAt) > 0 ? Number(profile.updatedAt) : 0;
    this.store.set(safe.userId, safe);
  }
}

export class AvatarService {
  private readonly picker: AvatarPickerPort;
  private readonly store: AvatarStorePort;
  private readonly uploader: AvatarUploadPort;
  private readonly compressor: (context: common.Context, srcUri: string, userId: string) => Promise<string>;
  private readonly now: () => number;

  constructor(options: AvatarServiceOptions) {
    this.picker = options.picker || new photoAccessHelper.PhotoViewPicker();
    this.store = options.store || new InMemoryAvatarStore();
    this.uploader = options.uploader || new AvatarUploadApi();
    this.compressor = options.compressor || AvatarService.compressToJpegInCache;
    this.now = options.now || (() => Date.now());
  }

  public static createDefault(context: common.Context): AvatarService {
    const storageService = AvatarStorageService.createDefault(context);
    return new AvatarService({
      uploader: new AvatarUploadApi({ storageService }),
      store: new PreferenceAvatarStore(context)
    });
  }

  public async loadAvatarProfile(userId: string, remoteAvatarUrl: string): Promise<AvatarProfile> {
    const safeUserId = AvatarService.safeUserId(userId);
    const stored = await this.store.loadAvatarProfile(safeUserId);
    const merged = AvatarService.ensureProfile(stored, safeUserId);
    if (!merged.cloudUrl && remoteAvatarUrl) {
      merged.cloudUrl = remoteAvatarUrl;
    }
    return merged;
  }

  public resolveDisplayUri(profile: AvatarProfile): string {
    if (profile.compressedUri) {
      return profile.compressedUri;
    }
    if (profile.localUri) {
      return profile.localUri;
    }
    return profile.cloudUrl || '';
  }

  public async pickAndSaveAvatar(
    context: common.Context,
    accountId: string,
    remoteAvatarUrl: string,
    runtimeOptions?: AvatarUploadRuntimeOptions
  ): Promise<AvatarProfile | null> {
    const waitForUpload = runtimeOptions?.waitForUpload !== false;
    const safeAccountId = AvatarService.safeUserId(accountId);
    hilog.info(0x0000, TAG, `[PROFILE_TRACE][avatar_service] pick start accountId=${safeAccountId}, remoteUrlLen=${String(remoteAvatarUrl || '').length}`);
    const options = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 1;
    options.isEditSupported = true;
    options.isOriginalSupported = false;

    const selectResult = await this.picker.select(options);
    if (!selectResult.photoUris || selectResult.photoUris.length === 0) {
      hilog.info(0x0000, TAG, `[PROFILE_TRACE][avatar_service] pick cancel accountId=${safeAccountId}`);
      return null;
    }

    const selectedUri = selectResult.photoUris[0];
    hilog.info(0x0000, TAG, `[PROFILE_TRACE][avatar_service] pick selected accountId=${safeAccountId}, uriLen=${String(selectedUri || '').length}`);
    const profile = await this.loadAvatarProfile(safeAccountId, remoteAvatarUrl);
    profile.localUri = selectedUri;
    profile.updatedAt = this.now();

    let uploadFileUri = selectedUri;
    try {
      profile.compressedUri = await this.compressor(context, selectedUri, safeAccountId);
      uploadFileUri = profile.compressedUri;
      hilog.info(
        0x0000,
        TAG,
        `[PROFILE_TRACE][avatar_service] compress ok accountId=${safeAccountId}, compressedUriLen=${String(profile.compressedUri || '').length}`
      );
    } catch (error) {
      profile.compressedUri = '';
      uploadFileUri = selectedUri;
      hilog.warn(
        0x0000,
        TAG,
        `[PROFILE_TRACE][avatar_service] compress failed fallback original accountId=${safeAccountId}, reason=${AvatarService.errorMessage(error)}`
      );
    }

    if (waitForUpload) {
      await this.performUpload(profile, safeAccountId, uploadFileUri);
      await this.store.saveAvatarProfile(profile);
      hilog.info(
        0x0000,
        TAG,
        `[PROFILE_TRACE][avatar_service] save profile accountId=${safeAccountId}, uploadState=${profile.uploadState}, cloudPath=${profile.cloudPath || 'empty'}`
      );
      return profile;
    }

    profile.uploadState = 'LOCAL_ONLY';
    await this.store.saveAvatarProfile(profile);
    hilog.info(
      0x0000,
      TAG,
      `[PROFILE_TRACE][avatar_service] save local first accountId=${safeAccountId}, uploadState=${profile.uploadState}`
    );

    const profileForSync = AvatarService.ensureProfile(profile, safeAccountId);
    void this.syncUploadInBackground(profileForSync, safeAccountId, uploadFileUri, runtimeOptions?.onUploadSynced);
    return profile;
  }

  private async performUpload(profile: AvatarProfile, safeAccountId: string, uploadFileUri: string): Promise<void> {
    try {
      const uploadInput = new AvatarUploadInput();
      uploadInput.userId = safeAccountId;
      uploadInput.accountId = safeAccountId;
      uploadInput.fileUri = uploadFileUri;
      uploadInput.mimeType = 'image/jpeg';
      uploadInput.avatarVersion = this.now();
      const uploadResult = await this.uploader.uploadAvatar(uploadInput);
      profile.uploadState = uploadResult.status;
      hilog.info(
        0x0000,
        TAG,
        `[PROFILE_TRACE][avatar_service] upload result accountId=${safeAccountId}, status=${uploadResult.status}, errorCode=${uploadResult.errorCode || 'none'}, avatarPath=${uploadResult.avatarPath || 'empty'}, version=${Number(uploadResult.avatarVersion || 0)}`
      );
      if (uploadResult.remoteUrl) {
        profile.cloudUrl = uploadResult.remoteUrl;
      }
      if (uploadResult.avatarPath) {
        profile.cloudPath = uploadResult.avatarPath;
      }
      profile.avatarVersion = Number.isFinite(Number(uploadResult.avatarVersion)) && Number(uploadResult.avatarVersion) > 0
        ? Math.floor(Number(uploadResult.avatarVersion))
        : profile.avatarVersion;
    } catch (error) {
      profile.uploadState = 'LOCAL_ONLY';
      hilog.warn(
        0x0000,
        TAG,
        `[PROFILE_TRACE][avatar_service] upload failed accountId=${safeAccountId}, reason=${AvatarService.errorMessage(error)}`
      );
    }
  }

  private async syncUploadInBackground(
    profile: AvatarProfile,
    safeAccountId: string,
    uploadFileUri: string,
    onUploadSynced?: (profile: AvatarProfile) => Promise<void>
  ): Promise<void> {
    await this.performUpload(profile, safeAccountId, uploadFileUri);
    await this.store.saveAvatarProfile(profile);
    hilog.info(
      0x0000,
      TAG,
      `[PROFILE_TRACE][avatar_service] background sync done accountId=${safeAccountId}, uploadState=${profile.uploadState}, cloudPath=${profile.cloudPath || 'empty'}`
    );
    if (profile.uploadState === 'SYNCED' && profile.cloudPath && profile.avatarVersion > 0 && onUploadSynced) {
      try {
        await onUploadSynced(AvatarService.ensureProfile(profile, safeAccountId));
      } catch (error) {
        hilog.warn(
          0x0000,
          TAG,
          `[PROFILE_TRACE][avatar_service] onUploadSynced failed accountId=${safeAccountId}, reason=${AvatarService.errorMessage(error)}`
        );
      }
    }
  }

  public static async compressToJpegInCache(context: common.Context, srcUri: string, userId: string): Promise<string> {
    const imgSource = image.createImageSource(srcUri);
    if (!imgSource) {
      throw new Error('image_source_unavailable');
    }
    const pixelMap = await imgSource.createPixelMap();
    const packer = image.createImagePacker();
    const packed = await packer.packToData(pixelMap, {
      format: 'image/jpeg',
      quality: 80
    });

    const cacheDir = `${context.cacheDir}/avatar`;
    if (!fileIo.accessSync(cacheDir)) {
      fileIo.mkdirSync(cacheDir, true);
    }
    const filePath = `${cacheDir}/avatar_${userId}_${Date.now()}.jpg`;
    const file = fileIo.openSync(
      filePath,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
    );
    try {
      fileIo.writeSync(file.fd, packed);
    } finally {
      fileIo.closeSync(file);
    }
    return fileUri.getUriFromPath(filePath);
  }

  private static safeUserId(raw: string): string {
    const safe = (raw || '').trim();
    return safe.length > 0 ? safe : 'guest_local';
  }

  private static ensureProfile(profile: AvatarProfile, userId: string): AvatarProfile {
    const safe = new AvatarProfile();
    safe.userId = userId;
    safe.localUri = profile.localUri || '';
    safe.compressedUri = profile.compressedUri || '';
    safe.cloudUrl = profile.cloudUrl || '';
    safe.cloudPath = profile.cloudPath || '';
    safe.avatarVersion = Number.isFinite(Number(profile.avatarVersion)) && Number(profile.avatarVersion) > 0
      ? Math.floor(Number(profile.avatarVersion))
      : 0;
    safe.uploadState = profile.uploadState || 'EMPTY';
    safe.updatedAt = Number(profile.updatedAt) > 0 ? Number(profile.updatedAt) : 0;
    return safe;
  }

  private static errorMessage(error: Object): string {
    if (error instanceof Error) {
      return error.message;
    }
    return 'unknown_error';
  }
}

