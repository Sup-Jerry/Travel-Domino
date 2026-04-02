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
    return new AvatarService({
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
    userId: string,
    remoteAvatarUrl: string
  ): Promise<AvatarProfile | null> {
    const safeUserId = AvatarService.safeUserId(userId);
    const options = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 1;
    options.isEditSupported = true;
    options.isOriginalSupported = false;

    const selectResult = await this.picker.select(options);
    if (!selectResult.photoUris || selectResult.photoUris.length === 0) {
      return null;
    }

    const selectedUri = selectResult.photoUris[0];
    const profile = await this.loadAvatarProfile(safeUserId, remoteAvatarUrl);
    profile.localUri = selectedUri;
    profile.updatedAt = this.now();

    try {
      profile.compressedUri = await this.compressor(context, selectedUri, safeUserId);
      const uploadInput = new AvatarUploadInput();
      uploadInput.userId = safeUserId;
      uploadInput.fileUri = profile.compressedUri;
      uploadInput.mimeType = 'image/jpeg';
      const uploadResult = await this.uploader.uploadAvatar(uploadInput);
      profile.uploadState = uploadResult.status;
      if (uploadResult.remoteUrl) {
        profile.cloudUrl = uploadResult.remoteUrl;
      }
    } catch (error) {
      profile.compressedUri = '';
      profile.uploadState = 'LOCAL_ONLY';
      hilog.warn(0x0000, TAG, `compress or upload failed: ${AvatarService.errorMessage(error)}`);
    }

    await this.store.saveAvatarProfile(profile);
    return profile;
  }

  public static async compressToJpegInCache(context: common.Context, srcUri: string, userId: string): Promise<string> {
    try {
      const imgSource = image.createImageSource(srcUri);
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
    } catch (error) {
      const msg = AvatarService.errorMessage(error);
      hilog.error(0x0000, 'AvatarService', `compressToJpegInCache failed: ${msg}`);
      throw new Error(msg);
    }
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
