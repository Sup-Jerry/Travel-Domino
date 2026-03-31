import { describe, expect, it } from '@ohos/hypium';
import { AvatarUploadInput } from '../main/ets/domain/auth/AvatarModels';
import { AvatarUploadStub } from '../main/ets/infrastructure/avatar/AvatarUploadStub';

export default function avatarUploadStubTest() {
  describe('avatarUploadStubTest', () => {
    it('upload_stub_should_return_pending_implementation', 0, async (done: () => void) => {
      const stub = new AvatarUploadStub();
      const input = new AvatarUploadInput();
      input.userId = 'u1';
      input.fileUri = 'file://avatar.jpg';
      const result = await stub.uploadAvatar(input);
      expect(String(result.status)).assertEqual('PENDING_IMPLEMENTATION');
      expect(String(result.requestId).length > 0).assertTrue();
      done();
    });
  });
}
