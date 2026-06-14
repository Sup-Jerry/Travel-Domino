import { describe, expect, it } from '@ohos/hypium';
import { AvatarUploadInput } from '../main/ets/domain/auth/AvatarModels';
import { AuthApiResponse, UpdateAvatarResult } from '../main/ets/domain/auth/AuthModels';
import { AvatarUploadApi } from '../main/ets/infrastructure/avatar/AvatarUploadApi';
import { AuthGateway } from '../main/ets/infrastructure/auth/AuthGateway';
import { AuthSessionStore } from '../main/ets/infrastructure/auth/AuthSessionStore';

interface AvatarUploadApiPrivate {
  errorMessage: (error: Object) => string;
  resolveFilePath: (rawFileUri: string) => string;
  readFileAsDataUrl: (fileUriText: string, mimeType: string) => string;
}

interface AvatarUploadApiRuntimeDepsPrivate {
  runtimeDeps: Object;
}

type AvatarUploadCreateFileUri = (raw: string) => Object;
type AvatarUploadCreateBase64Helper = () => Object;

class AvatarUploadBase64HelperStub {
  public encodeToStringSync(_content: Uint8Array, _type: Object): string {
    return 'QUJD';
  }
}

class AvatarUploadFileUriStub {
  path: string;

  constructor(raw: string) {
    this.path = raw.replace('file://', '');
  }
}

class AvatarUploadFileStatStub {
  size: number;

  constructor(size: number) {
    this.size = size;
  }
}

class AvatarUploadOpenedFileStub {
  fd: number;

  constructor(fd: number) {
    this.fd = fd;
  }
}

class AvatarUploadOpenModeStub {
  READ_ONLY: number = 0;
}

class AvatarUploadRuntimeDepsStub {
  statSync: (path: string) => Object;
  openSync: (path: string, mode: number) => number;
  readSync: (fd: number, buffer: ArrayBuffer) => number;
  closeSync: (fd: number) => void;
  readOnlyMode: number;
  createFileUri: AvatarUploadCreateFileUri;
  createBase64Helper: AvatarUploadCreateBase64Helper;
  basicType: Object;

  constructor(
    statSize: number,
    fd: number,
    readSize: number,
    createBase64Helper?: AvatarUploadCreateBase64Helper
  ) {
    this.statSync = (_path: string): Object => new AvatarUploadFileStatStub(statSize) as Object;
    this.openSync = (_path: string, _mode: number): number => fd;
    this.readSync = (_fd: number, _buffer: ArrayBuffer): number => readSize;
    this.closeSync = (_fd: number): void => {};
    this.readOnlyMode = new AvatarUploadOpenModeStub().READ_ONLY;
    this.createFileUri = (raw: string): Object => new AvatarUploadFileUriStub(raw) as Object;
    this.createBase64Helper = createBase64Helper || (() => new AvatarUploadBase64HelperStub() as Object);
    this.basicType = new Object();
  }
}

class AvatarUploadRuntimeDepsHooks {
  private readonly avatarUploadApiObj: Object;
  private readonly originRuntimeDeps: Object;

  constructor() {
    this.avatarUploadApiObj = AvatarUploadApi as Object;
    this.originRuntimeDeps = Reflect.get(this.avatarUploadApiObj, 'runtimeDeps') as Object;
  }

  public replace(runtimeDeps: Object): void {
    Reflect.set(this.avatarUploadApiObj, 'runtimeDeps', runtimeDeps);
  }

  public restore(): void {
    Reflect.set(this.avatarUploadApiObj, 'runtimeDeps', this.originRuntimeDeps);
  }
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
    it('boundary: upload_api_should_default_mime_type_when_input_missing', 0, async (done: () => void) => {
      // Arrange
      let capturedMimeType = '';
      const uploader = new AvatarUploadApi({
        getAccessToken: (): string => 'token_boundary',
        encodeFileToDataUrl: (_fileUriText: string, mimeType: string): string => {
          capturedMimeType = mimeType;
          return 'data:image/jpeg;base64,AA==';
        },
        updateAvatar: async (_accessToken: string, _imageDataUrl: string, mimeType: string): Promise<AuthApiResponse<UpdateAvatarResult>> => {
          capturedMimeType = mimeType;
          const data = new UpdateAvatarResult();
          const response = new AuthApiResponse<UpdateAvatarResult>(data);
          response.code = 0;
          return response;
        },
        now: (): number => 1001
      });
      const input = new AvatarUploadInput();
      input.userId = 'u_boundary';
      input.fileUri = 'file://avatar-boundary.jpg';
      input.mimeType = '';

      // Act
      const result = await uploader.uploadAvatar(input);

      // Assert
      expect(String(result.status)).assertEqual('SYNCED');
      expect(capturedMimeType).assertEqual('image/jpeg');
      done();
    });

    it('invalid: upload_api_should_return_local_only_when_gateway_returns_non_zero_code', 0, async (done: () => void) => {
      // Arrange
      const uploader = new AvatarUploadApi({
        getAccessToken: (): string => 'token_invalid',
        encodeFileToDataUrl: (_fileUriText: string, _mimeType: string): string => 'data:image/jpeg;base64,BB==',
        updateAvatar: async (): Promise<AuthApiResponse<UpdateAvatarResult>> => {
          const data = new UpdateAvatarResult();
          const response = new AuthApiResponse<UpdateAvatarResult>(data);
          response.code = 409;
          response.message = 'avatar_conflict';
          return response;
        },
        now: (): number => 1002
      });
      const input = new AvatarUploadInput();
      input.userId = 'u_invalid';
      input.fileUri = 'file://avatar-invalid.jpg';

      // Act
      const result = await uploader.uploadAvatar(input);

      // Assert
      expect(String(result.status)).assertEqual('LOCAL_ONLY');
      expect(String(result.errorCode || '')).assertEqual('409');
      done();
    });

    it('conflict: upload_api_should_keep_distinct_request_ids_for_back_to_back_calls', 0, async (done: () => void) => {
      // Arrange
      const uploader = new AvatarUploadApi({
        getAccessToken: (): string => 'token_conflict',
        encodeFileToDataUrl: (_fileUriText: string, _mimeType: string): string => 'data:image/jpeg;base64,CC==',
        updateAvatar: async (): Promise<AuthApiResponse<UpdateAvatarResult>> => {
          const data = new UpdateAvatarResult();
          const response = new AuthApiResponse<UpdateAvatarResult>(data);
          response.code = 0;
          return response;
        },
        now: (() => {
          let current = 2000;
          return (): number => {
            current += 1;
            return current;
          };
        })()
      });
      const first = new AvatarUploadInput();
      first.userId = 'u_conflict_1';
      first.fileUri = 'file://avatar-1.jpg';
      const second = new AvatarUploadInput();
      second.userId = 'u_conflict_2';
      second.fileUri = 'file://avatar-2.jpg';

      // Act
      const firstResult = await uploader.uploadAvatar(first);
      const secondResult = await uploader.uploadAvatar(second);

      // Assert
      expect(String(firstResult.status)).assertEqual('SYNCED');
      expect(String(secondResult.status)).assertEqual('SYNCED');
      expect(String(firstResult.requestId)).assertEqual('avatar_req_2001');
      expect(String(secondResult.requestId)).assertEqual('avatar_req_2002');
      done();
    });

    it('regression: upload_api_should_wrap_encode_exception_as_upload_exception', 0, async (done: () => void) => {
      // Arrange
      const uploader = new AvatarUploadApi({
        getAccessToken: (): string => 'token_regression',
        encodeFileToDataUrl: (): string => {
          throw new Error('encode_failed');
        },
        now: (): number => 1003
      });
      const input = new AvatarUploadInput();
      input.userId = 'u_regression';
      input.fileUri = 'file://avatar-regression.jpg';

      // Act
      const result = await uploader.uploadAvatar(input);

      // Assert
      expect(String(result.status)).assertEqual('LOCAL_ONLY');
      expect(String(result.errorCode || '')).assertEqual('UPLOAD_EXCEPTION');
      expect(String(result.requestId)).assertEqual('avatar_req_1003');
      done();
    });

    it('combined: upload_api_should_mix_sync_failure_and_session_failure_across_multiple_calls', 0, async (done: () => void) => {
      // Arrange
      let hasToken = true;
      let gatewayCalls = 0;
      const uploader = new AvatarUploadApi({
        getAccessToken: (): string => hasToken ? 'token_combined' : '',
        encodeFileToDataUrl: (_fileUriText: string, _mimeType: string): string => 'data:image/jpeg;base64,DD==',
        updateAvatar: async (): Promise<AuthApiResponse<UpdateAvatarResult>> => {
          gatewayCalls += 1;
          const data = new UpdateAvatarResult();
          const response = new AuthApiResponse<UpdateAvatarResult>(data);
          response.code = gatewayCalls === 1 ? 0 : 503;
          if (response.code === 0) {
            data.avatarUrl = 'https://example.com/combined.jpg';
          }
          return response;
        },
        now: (() => {
          let current = 3000;
          return (): number => {
            current += 10;
            return current;
          };
        })()
      });
      const first = new AvatarUploadInput();
      first.userId = 'u_combined_1';
      first.fileUri = 'file://avatar-combined-1.jpg';
      const second = new AvatarUploadInput();
      second.userId = 'u_combined_2';
      second.fileUri = 'file://avatar-combined-2.jpg';
      const third = new AvatarUploadInput();
      third.userId = 'u_combined_3';
      third.fileUri = 'file://avatar-combined-3.jpg';

      // Act
      const firstResult = await uploader.uploadAvatar(first);
      const secondResult = await uploader.uploadAvatar(second);
      hasToken = false;
      const thirdResult = await uploader.uploadAvatar(third);

      // Assert
      expect(String(firstResult.status)).assertEqual('SYNCED');
      expect(String(firstResult.remoteUrl || '')).assertEqual('https://example.com/combined.jpg');
      expect(String(secondResult.status)).assertEqual('LOCAL_ONLY');
      expect(String(secondResult.errorCode || '')).assertEqual('503');
      expect(String(thirdResult.status)).assertEqual('LOCAL_ONLY');
      expect(String(thirdResult.errorCode || '')).assertEqual('NO_SESSION');
      expect(gatewayCalls).assertEqual(2);
      done();
    });

    it('invalid: upload_api_error_message_should_return_unknown_for_non_error_input', 0, () => {
      // Arrange
      const privateApi = AvatarUploadApi as Object as AvatarUploadApiPrivate;
      // Act
      const message = privateApi.errorMessage(new Object());
      // Assert
      expect(message).assertEqual('unknown_error');
    });

    it('boundary: upload_api_resolve_file_path_should_trim_plain_path_without_scheme', 0, () => {
      // Arrange
      const privateApi = AvatarUploadApi as Object as AvatarUploadApiPrivate;
      const rawPath = '  /data/storage/el2/base/files/avatar.jpg  ';

      // Act
      const resolved = privateApi.resolveFilePath(rawPath);

      // Assert
      expect(resolved).assertEqual('/data/storage/el2/base/files/avatar.jpg');
    });

    it('boundary: upload_api_resolve_file_path_should_decode_encoded_file_uri', 0, () => {
      // Arrange
      const privateApi = AvatarUploadApi as Object as AvatarUploadApiPrivate;

      // Act
      const resolved = privateApi.resolveFilePath('file://C:/avatar%20space.jpg');

      // Assert
      expect(resolved.indexOf('%20') < 0).assertTrue();
      expect(resolved.length > 0).assertTrue();
    });

    it('invalid: upload_api_resolve_file_path_should_throw_for_blank_uri', 0, () => {
      // Arrange
      const privateApi = AvatarUploadApi as Object as AvatarUploadApiPrivate;
      let message = '';

      // Act
      try {
        privateApi.resolveFilePath('   ');
      } catch (error) {
        message = privateApi.errorMessage(error as Object);
      }

      // Assert
      expect(message).assertEqual('avatar_uri_empty');
    });

    it('regression: upload_api_error_message_should_return_error_message_for_error_instance', 0, () => {
      // Arrange
      const privateApi = AvatarUploadApi as Object as AvatarUploadApiPrivate;
      const error = new Error('avatar_decode_failed');

      // Act
      const message = privateApi.errorMessage(error);

      // Assert
      expect(message).assertEqual('avatar_decode_failed');
    });

    it('combined: upload_api_read_file_as_data_url_should_wrap_blank_uri_as_error', 0, () => {
      // Arrange
      const privateApi = AvatarUploadApi as Object as AvatarUploadApiPrivate;
      let message = '';

      // Act
      try {
        privateApi.readFileAsDataUrl('', '');
      } catch (error) {
        message = privateApi.errorMessage(error as Object);
      }

      // Assert
      expect(message).assertEqual('avatar_uri_empty');
    });

    it('combined: upload_api_should_use_default_session_encoder_and_gateway_callbacks', 0, async (done: () => void) => {
      // Arrange
      const authSessionStoreObj = AuthSessionStore as Object;
      const authGatewayObj = AuthGateway as Object;
      const avatarUploadApiObj = AvatarUploadApi as Object;
      const originalGetAccessToken = Reflect.get(authSessionStoreObj, 'getAccessToken') as Object;
      const originalUpdateAvatar = Reflect.get(authGatewayObj, 'updateAvatar') as Object;
      const originalReadFileAsDataUrl = Reflect.get(avatarUploadApiObj, 'readFileAsDataUrl') as Object;
      let gatewayToken = '';
      let gatewayMimeType = '';
      let gatewayDataUrl = '';

      Reflect.set(authSessionStoreObj, 'getAccessToken', (): string => 'default_token');
      Reflect.set(avatarUploadApiObj, 'readFileAsDataUrl', (_fileUriText: string, mimeType: string): string => {
        return `data:${mimeType};base64,EE==`;
      });
      Reflect.set(
        authGatewayObj,
        'updateAvatar',
        async (accessToken: string, imageDataUrl: string, mimeType: string): Promise<AuthApiResponse<UpdateAvatarResult>> => {
          gatewayToken = accessToken;
          gatewayDataUrl = imageDataUrl;
          gatewayMimeType = mimeType;
          const data = new UpdateAvatarResult();
          data.avatarUrl = 'https://example.com/default-callback.jpg';
          const response = new AuthApiResponse<UpdateAvatarResult>(data);
          response.code = 0;
          return response;
        }
      );

      try {
        const uploader = new AvatarUploadApi({
          now: (): number => 4001
        });
        const input = new AvatarUploadInput();
        input.userId = 'u_default_callback';
        input.fileUri = 'file://default-callback.jpg';
        input.mimeType = 'image/png';

        // Act
        const result = await uploader.uploadAvatar(input);

        // Assert
        expect(String(result.status)).assertEqual('SYNCED');
        expect(String(result.remoteUrl || '')).assertEqual('https://example.com/default-callback.jpg');
        expect(gatewayToken).assertEqual('default_token');
        expect(gatewayMimeType).assertEqual('image/png');
        expect(gatewayDataUrl).assertEqual('data:image/png;base64,EE==');
      } finally {
        Reflect.set(authSessionStoreObj, 'getAccessToken', originalGetAccessToken);
        Reflect.set(authGatewayObj, 'updateAvatar', originalUpdateAvatar);
        Reflect.set(avatarUploadApiObj, 'readFileAsDataUrl', originalReadFileAsDataUrl);
      }

      done();
    });

    it('boundary: upload_api_should_stop_at_default_session_store_when_token_missing', 0, async (done: () => void) => {
      // Arrange
      const authSessionStoreObj = AuthSessionStore as Object;
      const authGatewayObj = AuthGateway as Object;
      const avatarUploadApiObj = AvatarUploadApi as Object;
      const originalGetAccessToken = Reflect.get(authSessionStoreObj, 'getAccessToken') as Object;
      const originalUpdateAvatar = Reflect.get(authGatewayObj, 'updateAvatar') as Object;
      const originalReadFileAsDataUrl = Reflect.get(avatarUploadApiObj, 'readFileAsDataUrl') as Object;
      let encodeCalls = 0;
      let gatewayCalls = 0;

      Reflect.set(authSessionStoreObj, 'getAccessToken', (): string => '');
      Reflect.set(avatarUploadApiObj, 'readFileAsDataUrl', (): string => {
        encodeCalls += 1;
        return 'data:image/jpeg;base64,FF==';
      });
      Reflect.set(authGatewayObj, 'updateAvatar', async (): Promise<AuthApiResponse<UpdateAvatarResult>> => {
        gatewayCalls += 1;
        const response = new AuthApiResponse<UpdateAvatarResult>(new UpdateAvatarResult());
        response.code = 0;
        return response;
      });

      try {
        const uploader = new AvatarUploadApi({
          now: (): number => 4002
        });
        const input = new AvatarUploadInput();
        input.userId = 'u_default_session_missing';
        input.fileUri = 'file://default-session-missing.jpg';

        // Act
        const result = await uploader.uploadAvatar(input);

        // Assert
        expect(String(result.status)).assertEqual('LOCAL_ONLY');
        expect(String(result.errorCode || '')).assertEqual('NO_SESSION');
        expect(encodeCalls).assertEqual(0);
        expect(gatewayCalls).assertEqual(0);
      } finally {
        Reflect.set(authSessionStoreObj, 'getAccessToken', originalGetAccessToken);
        Reflect.set(authGatewayObj, 'updateAvatar', originalUpdateAvatar);
        Reflect.set(avatarUploadApiObj, 'readFileAsDataUrl', originalReadFileAsDataUrl);
      }

      done();
    });

    it('invalid: upload_api_should_map_default_gateway_non_zero_code_to_local_only', 0, async (done: () => void) => {
      // Arrange
      const authSessionStoreObj = AuthSessionStore as Object;
      const authGatewayObj = AuthGateway as Object;
      const avatarUploadApiObj = AvatarUploadApi as Object;
      const originalGetAccessToken = Reflect.get(authSessionStoreObj, 'getAccessToken') as Object;
      const originalUpdateAvatar = Reflect.get(authGatewayObj, 'updateAvatar') as Object;
      const originalReadFileAsDataUrl = Reflect.get(avatarUploadApiObj, 'readFileAsDataUrl') as Object;
      let capturedToken = '';
      let capturedMimeType = '';
      let capturedDataUrl = '';

      Reflect.set(authSessionStoreObj, 'getAccessToken', (): string => 'default_invalid_token');
      Reflect.set(avatarUploadApiObj, 'readFileAsDataUrl', (_fileUriText: string, mimeType: string): string => {
        return `data:${mimeType};base64,GG==`;
      });
      Reflect.set(
        authGatewayObj,
        'updateAvatar',
        async (accessToken: string, imageDataUrl: string, mimeType: string): Promise<AuthApiResponse<UpdateAvatarResult>> => {
          capturedToken = accessToken;
          capturedDataUrl = imageDataUrl;
          capturedMimeType = mimeType;
          const response = new AuthApiResponse<UpdateAvatarResult>(new UpdateAvatarResult());
          response.code = 401;
          response.message = 'token_expired';
          return response;
        }
      );

      try {
        const uploader = new AvatarUploadApi({
          now: (): number => 4003
        });
        const input = new AvatarUploadInput();
        input.userId = 'u_default_gateway_invalid';
        input.fileUri = 'file://default-gateway-invalid.jpg';
        input.mimeType = 'image/webp';

        // Act
        const result = await uploader.uploadAvatar(input);

        // Assert
        expect(String(result.status)).assertEqual('LOCAL_ONLY');
        expect(String(result.errorCode || '')).assertEqual('401');
        expect(capturedToken).assertEqual('default_invalid_token');
        expect(capturedMimeType).assertEqual('image/webp');
        expect(capturedDataUrl).assertEqual('data:image/webp;base64,GG==');
      } finally {
        Reflect.set(authSessionStoreObj, 'getAccessToken', originalGetAccessToken);
        Reflect.set(authGatewayObj, 'updateAvatar', originalUpdateAvatar);
        Reflect.set(avatarUploadApiObj, 'readFileAsDataUrl', originalReadFileAsDataUrl);
      }

      done();
    });

    it('regression: upload_api_should_map_default_gateway_exception_to_upload_exception', 0, async (done: () => void) => {
      // Arrange
      const authSessionStoreObj = AuthSessionStore as Object;
      const authGatewayObj = AuthGateway as Object;
      const avatarUploadApiObj = AvatarUploadApi as Object;
      const originalGetAccessToken = Reflect.get(authSessionStoreObj, 'getAccessToken') as Object;
      const originalUpdateAvatar = Reflect.get(authGatewayObj, 'updateAvatar') as Object;
      const originalReadFileAsDataUrl = Reflect.get(avatarUploadApiObj, 'readFileAsDataUrl') as Object;

      Reflect.set(authSessionStoreObj, 'getAccessToken', (): string => 'default_exception_token');
      Reflect.set(avatarUploadApiObj, 'readFileAsDataUrl', (): string => 'data:image/jpeg;base64,HH==');
      Reflect.set(authGatewayObj, 'updateAvatar', async (): Promise<AuthApiResponse<UpdateAvatarResult>> => {
        throw new Error('gateway_unreachable');
      });

      try {
        const uploader = new AvatarUploadApi({
          now: (): number => 4004
        });
        const input = new AvatarUploadInput();
        input.userId = 'u_default_gateway_exception';
        input.fileUri = 'file://default-gateway-exception.jpg';

        // Act
        const result = await uploader.uploadAvatar(input);

        // Assert
        expect(String(result.status)).assertEqual('LOCAL_ONLY');
        expect(String(result.errorCode || '')).assertEqual('UPLOAD_EXCEPTION');
        expect(String(result.requestId)).assertEqual('avatar_req_4004');
      } finally {
        Reflect.set(authSessionStoreObj, 'getAccessToken', originalGetAccessToken);
        Reflect.set(authGatewayObj, 'updateAvatar', originalUpdateAvatar);
        Reflect.set(avatarUploadApiObj, 'readFileAsDataUrl', originalReadFileAsDataUrl);
      }

      done();
    });

    it('combined: upload_api_should_keep_whitespace_access_token_on_remote_sync_path', 0, async (done: () => void) => {
      // Arrange
      let capturedToken = '';
      const uploader = new AvatarUploadApi({
        getAccessToken: (): string => '   ',
        encodeFileToDataUrl: (_fileUriText: string, _mimeType: string): string => 'data:image/jpeg;base64,II==',
        updateAvatar: async (accessToken: string): Promise<AuthApiResponse<UpdateAvatarResult>> => {
          capturedToken = accessToken;
          const data = new UpdateAvatarResult();
          data.avatarUrl = 'https://example.com/whitespace-token.jpg';
          const response = new AuthApiResponse<UpdateAvatarResult>(data);
          response.code = 0;
          return response;
        },
        now: (): number => 5001
      });
      const input = new AvatarUploadInput();
      input.userId = 'u_whitespace_token';
      input.fileUri = 'file://avatar-whitespace-token.jpg';

      // Act
      const result = await uploader.uploadAvatar(input);

      // Assert
      expect(String(result.status)).assertEqual('SYNCED');
      expect(String(result.requestId)).assertEqual('avatar_req_5001');
      expect(capturedToken).assertEqual('   ');
      expect(String(result.remoteUrl || '')).assertEqual('https://example.com/whitespace-token.jpg');
      done();
    });

    it('boundary: upload_api_should_forward_explicit_png_mime_type_to_encoder_and_gateway', 0, async (done: () => void) => {
      // Arrange
      let encodedMimeType = '';
      let gatewayMimeType = '';
      const uploader = new AvatarUploadApi({
        getAccessToken: (): string => 'token_png',
        encodeFileToDataUrl: (_fileUriText: string, mimeType: string): string => {
          encodedMimeType = mimeType;
          return 'data:image/png;base64,JJ==';
        },
        updateAvatar: async (_accessToken: string, _imageDataUrl: string, mimeType: string): Promise<AuthApiResponse<UpdateAvatarResult>> => {
          gatewayMimeType = mimeType;
          const data = new UpdateAvatarResult();
          data.avatarUrl = 'https://example.com/avatar.png';
          const response = new AuthApiResponse<UpdateAvatarResult>(data);
          response.code = 0;
          return response;
        },
        now: (): number => 5002
      });
      const input = new AvatarUploadInput();
      input.userId = 'u_png';
      input.fileUri = 'file://avatar-png.jpg';
      input.mimeType = 'image/png';

      // Act
      const result = await uploader.uploadAvatar(input);

      // Assert
      expect(String(result.status)).assertEqual('SYNCED');
      expect(encodedMimeType).assertEqual('image/png');
      expect(gatewayMimeType).assertEqual('image/png');
      done();
    });

    it('invalid: upload_api_should_map_encode_error_with_blank_message_to_upload_exception', 0, async (done: () => void) => {
      // Arrange
      const uploader = new AvatarUploadApi({
        getAccessToken: (): string => 'token_blank_error',
        encodeFileToDataUrl: (): string => {
          throw new Error('');
        },
        now: (): number => 5003
      });
      const input = new AvatarUploadInput();
      input.userId = 'u_blank_error';
      input.fileUri = 'file://avatar-blank-error.jpg';

      // Act
      const result = await uploader.uploadAvatar(input);

      // Assert
      expect(String(result.status)).assertEqual('LOCAL_ONLY');
      expect(String(result.errorCode || '')).assertEqual('UPLOAD_EXCEPTION');
      expect(String(result.requestId)).assertEqual('avatar_req_5003');
      done();
    });

    it('combined: upload_api_should_allow_synced_result_with_empty_remote_url_when_gateway_returns_zero', 0, async (done: () => void) => {
      // Arrange
      const uploader = new AvatarUploadApi({
        getAccessToken: (): string => 'token_empty_url',
        encodeFileToDataUrl: (_fileUriText: string, _mimeType: string): string => 'data:image/jpeg;base64,KK==',
        updateAvatar: async (): Promise<AuthApiResponse<UpdateAvatarResult>> => {
          const data = new UpdateAvatarResult();
          data.avatarUrl = '';
          const response = new AuthApiResponse<UpdateAvatarResult>(data);
          response.code = 0;
          return response;
        },
        now: (): number => 5004
      });
      const input = new AvatarUploadInput();
      input.userId = 'u_empty_url';
      input.fileUri = 'file://avatar-empty-url.jpg';

      // Act
      const result = await uploader.uploadAvatar(input);

      // Assert
      expect(String(result.status)).assertEqual('SYNCED');
      expect(String(result.remoteUrl || '')).assertEqual('');
      expect(String(result.requestId)).assertEqual('avatar_req_5004');
      done();
    });

    it('boundary: upload_api_read_file_as_data_url_should_fallback_to_default_mime_when_blank', 0, () => {
      // Arrange
      const privateApi = AvatarUploadApi as Object as AvatarUploadApiPrivate;
      const runtimeDepsHooks = new AvatarUploadRuntimeDepsHooks();
      runtimeDepsHooks.replace(new AvatarUploadRuntimeDepsStub(3, 1, 3) as Object);

      try {
        // Act
        const dataUrl = privateApi.readFileAsDataUrl('file://C:/avatar.jpg', '   ');

        // Assert
        expect(dataUrl).assertEqual('data:image/jpeg;base64,QUJD');
      } finally {
        runtimeDepsHooks.restore();
      }
    });

    it('normal: upload_api_read_file_as_data_url_should_keep_explicit_mime_when_present', 0, () => {
      // Arrange
      const privateApi = AvatarUploadApi as Object as AvatarUploadApiPrivate;
      const runtimeDepsHooks = new AvatarUploadRuntimeDepsHooks();
      runtimeDepsHooks.replace(new AvatarUploadRuntimeDepsStub(3, 1, 3) as Object);

      try {
        // Act
        const dataUrl = privateApi.readFileAsDataUrl('file://C:/avatar.png', ' image/png ');

        // Assert
        expect(dataUrl).assertEqual('data:image/png;base64,QUJD');
      } finally {
        runtimeDepsHooks.restore();
      }
    });

    it('invalid: upload_api_read_file_as_data_url_should_throw_when_file_is_empty', 0, () => {
      // Arrange
      const privateApi = AvatarUploadApi as Object as AvatarUploadApiPrivate;
      const runtimeDepsHooks = new AvatarUploadRuntimeDepsHooks();
      runtimeDepsHooks.replace(new AvatarUploadRuntimeDepsStub(0, 1, 0) as Object);
      let message = '';

      try {
        // Act
        privateApi.readFileAsDataUrl('file://C:/empty-avatar.jpg', 'image/png');
      } catch (error) {
        // Assert
        message = privateApi.errorMessage(error as Object);
      } finally {
        runtimeDepsHooks.restore();
      }

      expect(message).assertEqual('avatar_file_empty');
    });

    it('regression: upload_api_read_file_as_data_url_should_throw_when_read_size_is_zero', 0, () => {
      // Arrange
      const privateApi = AvatarUploadApi as Object as AvatarUploadApiPrivate;
      const runtimeDepsHooks = new AvatarUploadRuntimeDepsHooks();
      runtimeDepsHooks.replace(new AvatarUploadRuntimeDepsStub(4, 2, 0) as Object);
      let message = '';

      try {
        // Act
        privateApi.readFileAsDataUrl('file://C:/zero-read-avatar.jpg', 'image/jpeg');
      } catch (error) {
        // Assert
        message = privateApi.errorMessage(error as Object);
      } finally {
        runtimeDepsHooks.restore();
      }

      expect(message).assertEqual('avatar_file_read_empty');
    });
  });
}
