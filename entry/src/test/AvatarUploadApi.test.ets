import { describe, expect, it } from '@ohos/hypium';
import { AvatarUploadInput } from '../main/ets/domain/auth/AvatarModels';
import { AvatarUploadApi } from '../main/ets/infrastructure/avatar/AvatarUploadApi';
import { AvatarUploadPayload } from '../main/ets/infrastructure/storage/AvatarStorageService';

export default function avatarUploadApiTest() {
  describe('avatarUploadApiTest', () => {
    it('upload_api_should_return_synced_when_cloud_storage_success', 0, async (done: () => void) => {
      const uploader = new AvatarUploadApi({
        uploadAvatar: async (_accountId: string, _localUri: string, _avatarVersion?: number): Promise<AvatarUploadPayload> => {
          const payload = new AvatarUploadPayload();
          payload.avatarPath = 'avatars/u1/100.jpg';
          payload.avatarVersion = 100;
          payload.downloadUrl = 'https://example.com/avatar.jpg';
          return payload;
        },
        now: (): number => 123
      });

      const input = new AvatarUploadInput();
      input.accountId = 'u1';
      input.fileUri = 'file://avatar.jpg';
      const result = await uploader.uploadAvatar(input);
      expect(String(result.status)).assertEqual('SYNCED');
      expect(String(result.remoteUrl || '')).assertEqual('https://example.com/avatar.jpg');
      expect(String(result.avatarPath || '')).assertEqual('avatars/u1/100.jpg');
      expect(Number(result.avatarVersion || 0)).assertEqual(100);
      expect(String(result.requestId).length > 0).assertTrue();
      done();
    });

    it('upload_api_should_return_local_only_when_no_account', 0, async (done: () => void) => {
      const uploader = new AvatarUploadApi({
        now: (): number => 456
      });

      const input = new AvatarUploadInput();
      input.fileUri = 'file://avatar.jpg';
      const result = await uploader.uploadAvatar(input);
      expect(String(result.status)).assertEqual('LOCAL_ONLY');
      expect(String(result.errorCode || '')).assertEqual('NO_ACCOUNT_ID');
      expect(String(result.requestId).length > 0).assertTrue();
      done();
    });
  });
}
