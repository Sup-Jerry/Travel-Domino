import { describe, expect, it } from '@ohos/hypium';
import { AuthApiResponse, UpdateAvatarResult } from '../main/ets/domain/auth/AuthModels';
import { AvatarUploadApi } from '../main/ets/infrastructure/avatar/AvatarUploadApi';
import { AuthGateway } from '../main/ets/infrastructure/auth/AuthGateway';

interface AvatarUploadApiPrivateDR {
  getAccessToken(): string;
  encodeFileToDataUrl(fileUriText: string, mimeType: string): string;
  updateAvatar(accessToken: string, imageDataUrl: string, mimeType: string): Promise<AuthApiResponse<UpdateAvatarResult>>;
  now(): number;
}

class StaticPatchDR {
  private readonly target: Object;
  private readonly key: string;
  private readonly origin: Object;

  constructor(target: Object, key: string, replacement: Object) {
    this.target = target;
    this.key = key;
    this.origin = Reflect.get(target, key) as Object;
    Reflect.set(target, key, replacement);
  }

  restore(): void {
    Reflect.set(this.target, this.key, this.origin);
  }
}

function createSuccessResponseDR(url: string): AuthApiResponse<UpdateAvatarResult> {
  const data = new UpdateAvatarResult();
  data.avatarUrl = url;
  const response = new AuthApiResponse<UpdateAvatarResult>(data);
  response.code = 0;
  return response;
}

export default function phase2BatchDRTest() {
  describe('phase2BatchDRTest', () => {
    it('normal: avatar_upload_default_now_should_return_runtime_timestamp', 0, () => {
      // Arrange
      const api = new AvatarUploadApi() as Object as AvatarUploadApiPrivateDR;

      // Act
      const value = api.now();

      // Assert
      expect(value > 0).assertTrue();
    });

    it('boundary: avatar_upload_default_access_token_reader_should_be_callable', 0, () => {
      // Arrange
      const api = new AvatarUploadApi() as Object as AvatarUploadApiPrivateDR;
      let threw = false;
      let token = '';

      // Act
      try {
        token = api.getAccessToken();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(token.length >= 0).assertTrue();
    });

    it('invalid: avatar_upload_default_encoder_should_surface_empty_uri_error', 0, () => {
      // Arrange
      const api = new AvatarUploadApi() as Object as AvatarUploadApiPrivateDR;
      let message = '';

      // Act
      try {
        api.encodeFileToDataUrl('', 'image/jpeg');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }

      // Assert
      expect(message).assertEqual('avatar_uri_empty');
    });

    it('conflict: avatar_upload_default_gateway_closure_should_delegate_to_auth_gateway', 0, async () => {
      // Arrange
      const patch = new StaticPatchDR(
        AuthGateway as Object,
        'updateAvatar',
        async (_accessToken: string, _imageDataUrl: string, _mimeType: string): Promise<AuthApiResponse<UpdateAvatarResult>> =>
          createSuccessResponseDR('https://example.com/dr.jpg')
      );
      const api = new AvatarUploadApi() as Object as AvatarUploadApiPrivateDR;

      // Act
      const response = await api.updateAvatar('token-dr', 'data:image/jpeg;base64,AA==', 'image/jpeg');

      // Assert
      expect(response.code).assertEqual(0);
      expect(response.data.avatarUrl).assertEqual('https://example.com/dr.jpg');
      patch.restore();
    });

    it('regression: avatar_upload_default_encoder_should_accept_plain_path_and_report_fs_error', 0, () => {
      // Arrange
      const api = new AvatarUploadApi() as Object as AvatarUploadApiPrivateDR;
      let message = '';

      // Act
      try {
        api.encodeFileToDataUrl('Z:/not-existing-avatar-dr.jpg', 'image/png');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }

      // Assert
      expect(message.length > 0).assertTrue();
    });

    it('combined: avatar_upload_default_closures_should_work_with_gateway_patch', 0, async () => {
      // Arrange
      const patch = new StaticPatchDR(
        AuthGateway as Object,
        'updateAvatar',
        async (_accessToken: string, _imageDataUrl: string, _mimeType: string): Promise<AuthApiResponse<UpdateAvatarResult>> =>
          createSuccessResponseDR('https://example.com/dr-combined.jpg')
      );
      const api = new AvatarUploadApi() as Object as AvatarUploadApiPrivateDR;

      // Act
      const timestamp = api.now();
      const response = await api.updateAvatar('token-dr-combined', 'data:image/jpeg;base64,AA==', 'image/jpeg');

      // Assert
      expect(timestamp > 0).assertTrue();
      expect(response.data.avatarUrl).assertEqual('https://example.com/dr-combined.jpg');
      patch.restore();
    });
  });
}
