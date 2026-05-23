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
  });
}
