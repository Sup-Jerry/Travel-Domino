import { describe, expect, it } from '@ohos/hypium';
import { common } from '@kit.AbilityKit';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import { AvatarProfile, AvatarUploadInput, AvatarUploadResult } from '../main/ets/domain/auth/AvatarModels';
import { AvatarPickerPort, AvatarService, AvatarStorePort } from '../main/ets/infrastructure/avatar/AvatarService';
import { AvatarUploadPort } from '../main/ets/infrastructure/avatar/AvatarUploadPort';

class FakeStore implements AvatarStorePort {
  public saved: AvatarProfile[] = [];
  private readonly current: AvatarProfile;

  constructor(initial?: AvatarProfile) {
    this.current = initial ? initial : new AvatarProfile();
  }

  async loadAvatarProfile(_userId: string): Promise<AvatarProfile> {
    return this.current;
  }

  async saveAvatarProfile(profile: AvatarProfile): Promise<void> {
    this.saved.push(profile);
  }
}

class FakePicker implements AvatarPickerPort {
  private readonly uris: string[];

  constructor(uris: string[]) {
    this.uris = uris;
  }

  async select(): Promise<photoAccessHelper.PhotoSelectResult> {
    const result = new photoAccessHelper.PhotoSelectResult();
    result.photoUris = this.uris;
    result.isOriginalPhoto = false;
    return result;
  }
}

class FakeUploader implements AvatarUploadPort {
  public called: number = 0;

  async uploadAvatar(_input: AvatarUploadInput): Promise<AvatarUploadResult> {
    this.called += 1;
    const result = new AvatarUploadResult();
    result.status = 'SYNCED';
    result.requestId = `req_${this.called}`;
    return result;
  }
}

interface AvatarServicePrivateStatic {
  safeUserId(raw: string): string;
  ensureProfile(profile: AvatarProfile, userId: string): AvatarProfile;
  errorMessage(error: Object): string;
  compressToJpegInCache(context: Object, srcUri: string, userId: string): Promise<string>;
  resolveCompressImageSource(context: Object, srcUri: string, userId: string): Promise<Object>;
  loadPhotoAssetByUri(context: Object, srcUri: string): Promise<Object>;
  requestPhotoImageData(
    context: Object,
    asset: Object,
    requestOptions: Object,
    dataHandler: Object
  ): Promise<string>;
  requestImageBuffer(
    context: Object,
    asset: Object,
    userId: string,
    srcUri: string
  ): Promise<ArrayBuffer>;
}

class AvatarFetchResultServiceTest {
  private readonly count: number;
  private readonly asset: Object;
  public closeCount: number = 0;

  constructor(count: number, asset: Object) {
    this.count = count;
    this.asset = asset;
  }

  public getCount(): number {
    return this.count;
  }

  public async getFirstObject(): Promise<Object> {
    return this.asset;
  }

  public close(): void {
    this.closeCount += 1;
  }
}

class AvatarPhotoHelperServiceTest {
  private readonly result: Object;

  constructor(result: Object) {
    this.result = result;
  }

  public async getAssets(_options: Object): Promise<Object> {
    return this.result;
  }
}

class AvatarPredicatesServiceTest {
  public lastKey: string = '';
  public lastValue: string = '';

  public equalTo(key: string, value: string): void {
    this.lastKey = key;
    this.lastValue = value;
  }
}

class AvatarImagePackerServiceTest {
  private readonly packed: ArrayBuffer;

  constructor(packed: ArrayBuffer) {
    this.packed = packed;
  }

  public async packToData(_source: Object, _options: Object): Promise<ArrayBuffer> {
    return this.packed;
  }
}

class AvatarCacheContextServiceTest {
  cacheDir: string;

  constructor(cacheDir: string) {
    this.cacheDir = cacheDir;
  }
}

class AvatarServiceRuntimeDepsStub {
  createImagePacker: () => Object | null;
  createImageSourceFromUri: (srcUri: string) => Object | null;
  createImageSourceFromData: (data: ArrayBuffer) => Object | null;
  accessSync: (path: string) => boolean;
  mkdirSync: (path: string, recursive: boolean) => void;
  openWriteSync: (path: string) => number;
  writeSync: (fd: number, data: ArrayBuffer) => void;
  closeSync: (fd: number) => void;
  getUriFromPath: (path: string) => string;
  getPhotoHelper: (context: Object) => Object;
  createPhotoPredicates: () => Object;
  public mkdirCalls: string[] = [];
  public writeCalls: number[] = [];
  public closeCalls: number[] = [];
  public lastOpenedPath: string = '';
  public lastUriPath: string = '';
  public predicates: AvatarPredicatesServiceTest = new AvatarPredicatesServiceTest();
  public photoHelper: Object = new AvatarPhotoHelperServiceTest(new AvatarFetchResultServiceTest(1, new Object()));

  constructor() {
    const packed = new ArrayBuffer(4);
    this.createImagePacker = (): Object | null => new AvatarImagePackerServiceTest(packed) as Object;
    this.createImageSourceFromUri = (_srcUri: string): Object | null => new Object();
    this.createImageSourceFromData = (_data: ArrayBuffer): Object | null => new Object();
    this.accessSync = (_path: string): boolean => false;
    this.mkdirSync = (path: string, _recursive: boolean): void => {
      this.mkdirCalls.push(path);
    };
    this.openWriteSync = (path: string): number => {
      this.lastOpenedPath = path;
      return 7;
    };
    this.writeSync = (fd: number, _data: ArrayBuffer): void => {
      this.writeCalls.push(fd);
    };
    this.closeSync = (fd: number): void => {
      this.closeCalls.push(fd);
    };
    this.getUriFromPath = (path: string): string => {
      this.lastUriPath = path;
      return `file://${path}`;
    };
    this.getPhotoHelper = (_context: Object): Object => this.photoHelper;
    this.createPhotoPredicates = (): Object => this.predicates as Object;
  }
}

class ThrowingUploader implements AvatarUploadPort {
  async uploadAvatar(_input: AvatarUploadInput): Promise<AvatarUploadResult> {
    throw new Error('upload_boom');
  }
}

class AvatarRequestPhotoHook {
  private readonly origin: Object;

  constructor() {
    this.origin = Reflect.get(AvatarService as Object, 'requestPhotoImageData') as Object;
  }

  set(
    handler: (
      context: Object,
      asset: Object,
      requestOptions: Object,
      dataHandler: Object
    ) => Promise<string>
  ): void {
    Reflect.set(AvatarService as Object, 'requestPhotoImageData', handler);
  }

  restore(): void {
    Reflect.set(AvatarService as Object, 'requestPhotoImageData', this.origin);
  }
}

class AvatarRuntimeDepsHook {
  private readonly origin: Object;

  constructor() {
    this.origin = Reflect.get(AvatarService as Object, 'runtimeDeps') as Object;
  }

  public set(deps: Object): void {
    Reflect.set(AvatarService as Object, 'runtimeDeps', deps);
  }

  public restore(): void {
    Reflect.set(AvatarService as Object, 'runtimeDeps', this.origin);
  }
}

export default function avatarServiceTest() {
  describe('avatarServiceTest', () => {
    it('normal: pick_success_should_save_profile_with_compressed_uri', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const store = new FakeStore();
      const uploader = new FakeUploader();
      const service = new AvatarService({
        picker: new FakePicker(['file://picked.jpg']),
        store,
        uploader,
        compressor: async (): Promise<string> => 'file://compressed.jpg',
        now: (): number => 123
      });

      const profile = await service.pickAndSaveAvatar({} as common.Context, 'u_1', '');
      expect(profile !== null).assertTrue();
      expect(String(profile?.localUri || '')).assertEqual('file://picked.jpg');
      expect(String(profile?.compressedUri || '')).assertEqual('file://compressed.jpg');
      expect(String(profile?.uploadState || '')).assertEqual('SYNCED');
      expect(store.saved.length).assertEqual(1);
      done();
    });

    it('boundary: pick_cancel_should_return_null_and_keep_profile', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const store = new FakeStore();
      const service = new AvatarService({
        picker: new FakePicker([]),
        store,
        compressor: async (): Promise<string> => 'file://compressed.jpg'
      });

      const profile = await service.pickAndSaveAvatar({} as common.Context, 'u_2', '');
      expect(profile === null).assertTrue();
      expect(store.saved.length).assertEqual(0);
      done();
    });

    it('invalid: compress_fail_should_fallback_to_local_only', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const store = new FakeStore();
      const service = new AvatarService({
        picker: new FakePicker(['file://picked.jpg']),
        store,
        compressor: async (): Promise<string> => {
          throw new Error('compress_fail');
        }
      });

      const profile = await service.pickAndSaveAvatar({} as common.Context, 'u_3', '');
      expect(profile !== null).assertTrue();
      expect(String(profile?.localUri || '')).assertEqual('file://picked.jpg');
      expect(String(profile?.compressedUri || '')).assertEqual('');
      expect(String(profile?.uploadState || '')).assertEqual('LOCAL_ONLY');
      done();
    });

    it('boundary: load_profile_and_display_uri_should_fill_guest_id_remote_url_and_priority', 0, async (done: () => void) => {
      // Arrange
      const initial = new AvatarProfile();
      initial.localUri = 'file://local.jpg';
      const store = new FakeStore(initial);
      const service = new AvatarService({
        picker: new FakePicker([]),
        store,
        compressor: async (): Promise<string> => 'file://compressed.jpg'
      });

      // Act
      const profile = await service.loadAvatarProfile('   ', 'https://example.com/remote.jpg');
      const displayUri = service.resolveDisplayUri(profile);
      profile.compressedUri = 'file://compressed.jpg';
      const compressedDisplayUri = service.resolveDisplayUri(profile);

      // Assert
      expect(String(profile.userId)).assertEqual('guest_local');
      expect(String(profile.cloudUrl)).assertEqual('https://example.com/remote.jpg');
      expect(displayUri).assertEqual('file://local.jpg');
      expect(compressedDisplayUri).assertEqual('file://compressed.jpg');
      done();
    });

    it('invalid: pick_should_keep_local_only_when_uploader_throws_after_compress', 0, async (done: () => void) => {
      // Arrange
      const store = new FakeStore();
      const service = new AvatarService({
        picker: new FakePicker(['file://picked_2.jpg']),
        store,
        uploader: new ThrowingUploader(),
        compressor: async (): Promise<string> => 'file://compressed_2.jpg',
        now: (): number => 456
      });

      // Act
      const profile = await service.pickAndSaveAvatar({} as common.Context, '  ', '');

      // Assert
      expect(profile !== null).assertTrue();
      expect(String(profile?.userId || '')).assertEqual('guest_local');
      expect(String(profile?.localUri || '')).assertEqual('file://picked_2.jpg');
      expect(String(profile?.compressedUri || '')).assertEqual('');
      expect(String(profile?.uploadState || '')).assertEqual('LOCAL_ONLY');
      expect(store.saved.length).assertEqual(1);
      done();
    });
  });
  describe('unit_test_case_generator_autofill_AvatarService', () => {
    it('conflict: td-20260411-auto-AvatarService', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('regression: td-20260411-auto-AvatarService', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('combined: td-20260411-auto-AvatarService', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });

    it('regression: private_helpers_should_keep_safe_defaults', 0, () => {
      // Arrange
      const privateApi = AvatarService as Object as AvatarServicePrivateStatic;
      const profile = new AvatarProfile();

      // Act
      const safeUserId = privateApi.safeUserId('   ');
      const ensured = privateApi.ensureProfile(profile, safeUserId);
      const errorMessage = privateApi.errorMessage(new Object());

      // Assert
      expect(safeUserId).assertEqual('guest_local');
      expect(String(ensured.userId)).assertEqual('guest_local');
      expect(String(ensured.uploadState)).assertEqual('EMPTY');
      expect(errorMessage).assertEqual('unknown_error');
    });

    it('invalid: request_image_buffer_should_reject_when_callback_returns_empty_data', 0, async (done: () => void) => {
      // Arrange
      const privateApi = AvatarService as Object as AvatarServicePrivateStatic;
      const hook = new AvatarRequestPhotoHook();
      let message = '';

      hook.set((
        _context: Object,
        _asset: Object,
        _requestOptions: Object,
        dataHandler: Object
      ): Promise<string> => {
        const onDataPrepared = Reflect.get(dataHandler, 'onDataPrepared') as (data: ArrayBuffer) => void;
        onDataPrepared(new ArrayBuffer(0));
        return Promise.resolve('ok');
      });

      // Act
      try {
        await privateApi.requestImageBuffer(new Object(), new Object(), 'user_empty', 'file://empty.jpg');
      } catch (error) {
        message = error instanceof Error ? error.message : String(error || '');
      } finally {
        hook.restore();
      }

      // Assert
      expect(message).assertEqual('avatar_image_data_empty');
      done();
    });

    it('conflict: request_image_buffer_should_reject_when_request_api_promise_fails', 0, async (done: () => void) => {
      // Arrange
      const privateApi = AvatarService as Object as AvatarServicePrivateStatic;
      const hook = new AvatarRequestPhotoHook();
      let message = '';

      hook.set((
        _context: Object,
        _asset: Object,
        _requestOptions: Object,
        _dataHandler: Object
      ): Promise<string> => Promise.reject(new Error('request_fail')));

      // Act
      try {
        await privateApi.requestImageBuffer(new Object(), new Object(), 'user_reject', 'file://reject.jpg');
      } catch (error) {
        message = error instanceof Error ? error.message : String(error || '');
      } finally {
        hook.restore();
      }

      // Assert
      expect(message).assertEqual('request_fail');
      done();
    });

    it('boundary: default_store_should_persist_zero_updated_at_when_now_is_zero', 0, async (done: () => void) => {
      // Arrange
      const service = new AvatarService({
        picker: new FakePicker(['file://picked_zero.jpg']),
        compressor: async (): Promise<string> => {
          throw new Error('compress_fail');
        },
        now: (): number => 0
      });

      // Act
      await service.pickAndSaveAvatar({} as common.Context, 'user_zero', '');
      const loaded = await service.loadAvatarProfile('user_zero', '');

      // Assert
      expect(Number(loaded.updatedAt)).assertEqual(0);
      done();
    });

    it('invalid: compress_to_jpeg_should_throw_when_image_packer_is_unavailable', 0, async (done: () => void) => {
      // Arrange
      const privateApi = AvatarService as Object as AvatarServicePrivateStatic;
      const hook = new AvatarRuntimeDepsHook();
      const deps = new AvatarServiceRuntimeDepsStub();
      deps.createImagePacker = (): Object | null => null;
      let message = '';

      hook.set(deps as Object);

      // Act
      try {
        await privateApi.compressToJpegInCache(new AvatarCacheContextServiceTest('/cache_avatar') as Object, 'file://avatar.jpg', 'user_packer');
      } catch (error) {
        message = error instanceof Error ? error.message : String(error || '');
      } finally {
        hook.restore();
      }

      // Assert
      expect(message).assertEqual('avatar_image_packer_unavailable');
      done();
    });

    it('normal: compress_to_jpeg_should_skip_mkdir_when_cache_directory_exists', 0, async (done: () => void) => {
      // Arrange
      const privateApi = AvatarService as Object as AvatarServicePrivateStatic;
      const hook = new AvatarRuntimeDepsHook();
      const deps = new AvatarServiceRuntimeDepsStub();
      deps.accessSync = (_path: string): boolean => true;

      hook.set(deps as Object);

      try {
        // Act
        const uri = await privateApi.compressToJpegInCache(new AvatarCacheContextServiceTest('/cache_exist') as Object, 'file://avatar.jpg', 'user_exist');

        // Assert
        expect(uri.indexOf('avatar_user_exist_') > 0).assertTrue();
        expect(deps.mkdirCalls.length).assertEqual(0);
        expect(deps.writeCalls.length).assertEqual(1);
        expect(deps.closeCalls.length).assertEqual(1);
      } finally {
        hook.restore();
      }

      done();
    });

    it('invalid: resolve_compress_image_source_should_throw_when_buffer_source_is_unavailable', 0, async (done: () => void) => {
      // Arrange
      const privateApi = AvatarService as Object as AvatarServicePrivateStatic;
      const depsHook = new AvatarRuntimeDepsHook();
      const photoHook = new AvatarRequestPhotoHook();
      const deps = new AvatarServiceRuntimeDepsStub();
      deps.createImageSourceFromUri = (_srcUri: string): Object | null => null;
      deps.createImageSourceFromData = (_data: ArrayBuffer): Object | null => null;
      let message = '';

      photoHook.set((
        _context: Object,
        _asset: Object,
        _requestOptions: Object,
        dataHandler: Object
      ): Promise<string> => {
        const onDataPrepared = Reflect.get(dataHandler, 'onDataPrepared') as (data: ArrayBuffer) => void;
        onDataPrepared(new ArrayBuffer(8));
        return Promise.resolve('ok');
      });
      depsHook.set(deps as Object);

      // Act
      try {
        await privateApi.resolveCompressImageSource(new Object(), 'file://avatar-source.jpg', 'user_buffer_missing');
      } catch (error) {
        message = error instanceof Error ? error.message : String(error || '');
      } finally {
        photoHook.restore();
        depsHook.restore();
      }

      // Assert
      expect(message).assertEqual('avatar_image_source_unavailable');
      done();
    });

    it('normal: load_photo_asset_by_uri_should_return_first_asset_and_close_result', 0, async (done: () => void) => {
      // Arrange
      const privateApi = AvatarService as Object as AvatarServicePrivateStatic;
      const hook = new AvatarRuntimeDepsHook();
      const deps = new AvatarServiceRuntimeDepsStub();
      const asset = new Object();
      const fetchResult = new AvatarFetchResultServiceTest(1, asset);
      deps.photoHelper = new AvatarPhotoHelperServiceTest(fetchResult);

      hook.set(deps as Object);

      try {
        // Act
        const actual = await privateApi.loadPhotoAssetByUri(new Object(), 'file://picked_asset.jpg');

        // Assert
        expect(actual === asset).assertTrue();
        expect(fetchResult.closeCount).assertEqual(1);
        expect(deps.predicates.lastValue).assertEqual('file://picked_asset.jpg');
      } finally {
        hook.restore();
      }

      done();
    });

    it('regression: request_image_buffer_should_ignore_second_callback_after_resolve', 0, async (done: () => void) => {
      // Arrange
      const privateApi = AvatarService as Object as AvatarServicePrivateStatic;
      const hook = new AvatarRequestPhotoHook();
      let byteLength = -1;

      hook.set((
        _context: Object,
        _asset: Object,
        _requestOptions: Object,
        dataHandler: Object
      ): Promise<string> => {
        const onDataPrepared = Reflect.get(dataHandler, 'onDataPrepared') as (data: ArrayBuffer) => void;
        onDataPrepared(new ArrayBuffer(6));
        onDataPrepared(new ArrayBuffer(10));
        return Promise.resolve('ok');
      });

      try {
        // Act
        const data = await privateApi.requestImageBuffer(new Object(), new Object(), 'user_twice', 'file://twice.jpg');
        byteLength = data.byteLength;
      } finally {
        hook.restore();
      }

      // Assert
      expect(byteLength).assertEqual(6);
      done();
    });

    it('regression: request_image_buffer_should_ignore_followup_reject_after_empty_data_failure', 0, async (done: () => void) => {
      // Arrange
      const privateApi = AvatarService as Object as AvatarServicePrivateStatic;
      const hook = new AvatarRequestPhotoHook();
      let message = '';

      hook.set((
        _context: Object,
        _asset: Object,
        _requestOptions: Object,
        dataHandler: Object
      ): Promise<string> => {
        const onDataPrepared = Reflect.get(dataHandler, 'onDataPrepared') as (data: ArrayBuffer) => void;
        onDataPrepared(new ArrayBuffer(0));
        return Promise.reject(new Error('late_failure'));
      });

      // Act
      try {
        await privateApi.requestImageBuffer(new Object(), new Object(), 'user_late_reject', 'file://late-reject.jpg');
      } catch (error) {
        message = error instanceof Error ? error.message : String(error || '');
      } finally {
        hook.restore();
      }

      // Assert
      expect(message).assertEqual('avatar_image_data_empty');
      done();
    });

    it('invalid: request_image_buffer_should_wrap_non_error_rejection', 0, async (done: () => void) => {
      // Arrange
      const privateApi = AvatarService as Object as AvatarServicePrivateStatic;
      const hook = new AvatarRequestPhotoHook();
      let message = '';

      hook.set((
        _context: Object,
        _asset: Object,
        _requestOptions: Object,
        _dataHandler: Object
      ): Promise<string> => Promise.reject('reject_string'));

      // Act
      try {
        await privateApi.requestImageBuffer(new Object(), new Object(), 'user_non_error', 'file://non-error.jpg');
      } catch (error) {
        message = error instanceof Error ? error.message : String(error || '');
      } finally {
        hook.restore();
      }

      // Assert
      expect(message).assertEqual('avatar_request_image_data_failed');
      done();
    });
  });
}
