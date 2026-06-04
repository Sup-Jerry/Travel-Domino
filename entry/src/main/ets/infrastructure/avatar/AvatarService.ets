import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import dataSharePredicates from '@ohos.data.dataSharePredicates';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import fileIo from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import image from '@ohos.multimedia.image';
import { PreferenceManager } from '../../common/utils/PreferenceManager';
import { AvatarProfile, AvatarUploadInput } from '../../domain/auth/AvatarModels';
import { AvatarUploadPort } from './AvatarUploadPort';
import { AvatarUploadApi } from './AvatarUploadApi';

const TAG = 'AvatarService';

export type AvatarCompressor = (context: common.Context, srcUri: string, userId: string) => Promise<string>;
export type AvatarServiceNowGetter = () => number;

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
  compressor?: AvatarCompressor;
  now?: AvatarServiceNowGetter;
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
  private readonly compressor: AvatarCompressor;
  private readonly now: AvatarServiceNowGetter;

  constructor(options: AvatarServiceOptions) {
    this.picker = options.picker || new photoAccessHelper.PhotoViewPicker();
    this.store = options.store || new InMemoryAvatarStore();
    this.uploader = options.uploader || new AvatarUploadApi();
    this.compressor = options.compressor || AvatarService.compressToJpegInCache;
    this.now = options.now || (() => Date.now());
  }

  private static getPhotoHelper(context: common.Context): photoAccessHelper.PhotoAccessHelper {
    return photoAccessHelper.getPhotoAccessHelper(context);
  }

  private static createPhotoPredicates(): dataSharePredicates.DataSharePredicates {
    return new dataSharePredicates.DataSharePredicates();
  }

  private static requestPhotoImageData(
    context: common.Context,
    asset: photoAccessHelper.PhotoAsset,
    requestOptions: photoAccessHelper.RequestOptions,
    dataHandler: photoAccessHelper.MediaAssetDataHandler<ArrayBuffer>
  ): Promise<string> {
    return photoAccessHelper.MediaAssetManager.requestImageData(context, asset, requestOptions, dataHandler);
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
      hilog.info(0x0000, TAG, `[AVATAR_TRACE][pick_cancel] userId=${safeUserId}`);
      return null;
    }

    const selectedUri = selectResult.photoUris[0];
    hilog.info(
      0x0000,
      TAG,
      `[AVATAR_TRACE][pick_selected] userId=${safeUserId}, selectedUriLen=${String(selectedUri || '').length}, remoteUrlLen=${String(remoteAvatarUrl || '').length}`
    );
    const profile = await this.loadAvatarProfile(safeUserId, remoteAvatarUrl);
    profile.localUri = selectedUri;
    profile.updatedAt = this.now();

    try {
      profile.compressedUri = await this.compressor(context, selectedUri, safeUserId);
      hilog.info(
        0x0000,
        TAG,
        `[AVATAR_TRACE][compress_ok] userId=${safeUserId}, compressedUriLen=${String(profile.compressedUri || '').length}`
      );
      const uploadInput = new AvatarUploadInput();
      uploadInput.userId = safeUserId;
      uploadInput.fileUri = profile.compressedUri;
      uploadInput.mimeType = 'image/jpeg';
      const uploadResult = await this.uploader.uploadAvatar(uploadInput);
      profile.uploadState = uploadResult.status;
      if (uploadResult.remoteUrl) {
        profile.cloudUrl = uploadResult.remoteUrl;
      }
      hilog.info(
        0x0000,
        TAG,
        `[AVATAR_TRACE][upload_result] userId=${safeUserId}, requestId=${String(uploadResult.requestId || '')}, status=${profile.uploadState}, errorCode=${String(uploadResult.errorCode || '')}, remoteUrlLen=${String(profile.cloudUrl || '').length}`
      );
    } catch (error) {
      profile.compressedUri = '';
      profile.uploadState = 'LOCAL_ONLY';
      hilog.warn(
        0x0000,
        TAG,
        `[AVATAR_TRACE][pick_fail] userId=${safeUserId}, phase=compress_or_upload, reason=${AvatarService.errorMessage(error)}`
      );
    }

    await this.store.saveAvatarProfile(profile);
    hilog.info(
      0x0000,
      TAG,
      `[AVATAR_TRACE][profile_saved] userId=${safeUserId}, uploadState=${profile.uploadState}, localUriLen=${String(profile.localUri || '').length}, cloudUrlLen=${String(profile.cloudUrl || '').length}`
    );
    return profile;
  }

  public static async compressToJpegInCache(context: common.Context, srcUri: string, userId: string): Promise<string> {
    try {
      const imgSource = await AvatarService.resolveCompressImageSource(context, srcUri, userId);
      const packer = image.createImagePacker();
      if (!packer) {
        throw new Error('avatar_image_packer_unavailable');
      }
      const packed = await packer.packToData(imgSource, {
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

  private static async resolveCompressImageSource(
    context: common.Context,
    srcUri: string,
    userId: string
  ): Promise<image.ImageSource> {
    const directSource = image.createImageSource(srcUri);
    if (directSource) {
      return directSource;
    }

    hilog.warn(
      0x0000,
      TAG,
      `[AVATAR_TRACE][compress_source_retry] userId=${userId}, phase=direct_uri_unavailable, uriLen=${String(srcUri || '').length}`
    );

    const photoAsset = await AvatarService.loadPhotoAssetByUri(context, srcUri);
    const imageBuffer = await AvatarService.requestImageBuffer(context, photoAsset, userId, srcUri);
    const bufferSource = image.createImageSource(imageBuffer);
    if (bufferSource) {
      return bufferSource;
    }
    throw new Error('avatar_image_source_unavailable');
  }

  private static async loadPhotoAssetByUri(
    context: common.Context,
    srcUri: string
  ): Promise<photoAccessHelper.PhotoAsset> {
    const helper = AvatarService.getPhotoHelper(context);
    const predicates = AvatarService.createPhotoPredicates();
    predicates.equalTo(String(photoAccessHelper.PhotoKeys.URI), srcUri);
    const options: photoAccessHelper.FetchOptions = {
      fetchColumns: [
        String(photoAccessHelper.PhotoKeys.URI),
        String(photoAccessHelper.PhotoKeys.DISPLAY_NAME)
      ],
      predicates
    };
    const result = await helper.getAssets(options);
    try {
      if (result.getCount() <= 0) {
        throw new Error('avatar_asset_not_found');
      }
      return await result.getFirstObject();
    } finally {
      result.close();
    }
  }

  private static async requestImageBuffer(
    context: common.Context,
    asset: photoAccessHelper.PhotoAsset,
    userId: string,
    srcUri: string
  ): Promise<ArrayBuffer> {
    const requestOptions: photoAccessHelper.RequestOptions = {
      deliveryMode: photoAccessHelper.DeliveryMode.HIGH_QUALITY_MODE
    };
    return await new Promise<ArrayBuffer>((resolve: (value: ArrayBuffer) => void, reject: (reason?: Object) => void) => {
      let settled = false;
      const settleReject = (error: Object): void => {
        if (settled) {
          return;
        }
        settled = true;
        reject(error instanceof Error ? error : new Error('avatar_request_image_data_failed'));
      };
      AvatarService.requestPhotoImageData(context, asset, requestOptions, {
        onDataPrepared: (data: ArrayBuffer): void => {
          if (settled) {
            return;
          }
          if (!data || data.byteLength <= 0) {
            settleReject(new Error('avatar_image_data_empty'));
            return;
          }
          settled = true;
          hilog.info(
            0x0000,
            TAG,
            `[AVATAR_TRACE][compress_source_ready] userId=${userId}, phase=request_image_data, uriLen=${String(srcUri || '').length}, byteLen=${data.byteLength}`
          );
          resolve(data);
        }
      }).catch((error: Object) => {
        settleReject(error);
      });
    });
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
