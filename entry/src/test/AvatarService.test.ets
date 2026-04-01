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

export default function avatarServiceTest() {
  describe('avatarServiceTest', () => {
    it('pick_success_should_save_profile_with_compressed_uri', 0, async (done: () => void) => {
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

    it('pick_cancel_should_return_null_and_keep_profile', 0, async (done: () => void) => {
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

    it('compress_fail_should_fallback_to_local_only', 0, async (done: () => void) => {
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
  });
}
