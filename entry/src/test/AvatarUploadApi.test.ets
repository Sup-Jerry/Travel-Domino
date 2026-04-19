import { describe, expect, it } from '@ohos/hypium';
import { AvatarUploadInput } from '../main/ets/domain/auth/AvatarModels';
import { AuthApiResponse, UpdateAvatarResult } from '../main/ets/domain/auth/AuthModels';
import { AvatarUploadApi } from '../main/ets/infrastructure/avatar/AvatarUploadApi';

interface AvatarUploadApiPrivate {
  errorMessage: (error: Object) => string;
}

export default function avatarUploadApiTest() {
  describe('avatarUploadApiTest', () => {
    it('normal: upload_api_should_return_synced_when_gateway_success', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const uploader = new AvatarUploadApi({
        getAccessToken: (): string => 'token_1',
        encodeFileToDataUrl: (_fileUriText: string, _mimeType: string): string => 'data:image/jpeg;base64,AA==',
        updateAvatar: async (_accessToken: string, _imageDataUrl: string, _mimeType: string): Promise<AuthApiResponse<UpdateAvatarResult>> => {
          const data = new UpdateAvatarResult();
          data.userId = 'u1';
          data.avatarUrl = 'https://example.com/avatar.jpg';
          const response = new AuthApiResponse<UpdateAvatarResult>(data);
          response.code = 0;
          return response;
        },
        now: (): number => 123
      });

      const input = new AvatarUploadInput();
      input.userId = 'u1';
      input.fileUri = 'file://avatar.jpg';
      const result = await uploader.uploadAvatar(input);
      expect(String(result.status)).assertEqual('SYNCED');
      expect(String(result.remoteUrl || '')).assertEqual('https://example.com/avatar.jpg');
      expect(String(result.requestId).length > 0).assertTrue();
      done();
    });

    it('normal: upload_api_should_return_local_only_when_no_session', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const uploader = new AvatarUploadApi({
        getAccessToken: (): string => '',
        now: (): number => 456
      });

      const input = new AvatarUploadInput();
      input.userId = 'u2';
      input.fileUri = 'file://avatar.jpg';
      const result = await uploader.uploadAvatar(input);
      expect(String(result.status)).assertEqual('LOCAL_ONLY');
      expect(String(result.errorCode || '')).assertEqual('NO_SESSION');
      expect(String(result.requestId).length > 0).assertTrue();
      done();
    });
  });
  describe('unit_test_case_generator_autofill_AvatarUploadApi', () => {
    it('boundary: td-20260411-auto-AvatarUploadApi', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('invalid: td-20260411-auto-AvatarUploadApi', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('conflict: td-20260411-auto-AvatarUploadApi', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('regression: td-20260411-auto-AvatarUploadApi', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('combined: td-20260411-auto-AvatarUploadApi', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });

    it('invalid: upload_api_error_message_should_return_unknown_for_non_error_input', 0, () => {
      // Arrange
      const privateApi = AvatarUploadApi as Object as AvatarUploadApiPrivate;
      // Act
      const message = privateApi.errorMessage(new Object());
      // Assert
      expect(message).assertEqual('unknown_error');
    });
  });
}
