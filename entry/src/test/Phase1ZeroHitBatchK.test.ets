import { describe, expect, it } from '@ohos/hypium';
import { AuthGateway } from '../main/ets/infrastructure/auth/AuthGateway';
import { AuthApiResponse, DeviceInfo, SocialCredential } from '../main/ets/domain/auth/AuthModels';

type PostMethod = <T>(path: string, payload: object, accessToken?: string) => Promise<AuthApiResponse<T>>;
type GetMethod = <T>(path: string, accessToken: string) => Promise<AuthApiResponse<T>>;
type PatchMethod = <T>(path: string, payload: object, accessToken: string) => Promise<AuthApiResponse<T>>;

interface AuthGatewayApiClientLike {
  post: PostMethod;
  get: GetMethod;
  patch: PatchMethod;
}

class CallCaptureState {
  postPath: string = '';
  postToken: string = '';
  postPayload: string = '';
  getPath: string = '';
  getToken: string = '';
  patchPath: string = '';
  patchToken: string = '';
  patchPayload: string = '';
  postCalls: number = 0;
  getCalls: number = 0;
  patchCalls: number = 0;
}

function getGatewayClient(): AuthGatewayApiClientLike {
  return Reflect.get(AuthGateway, 'apiClient') as AuthGatewayApiClientLike;
}

function getErrorMessage(error: Object): string {
  return (error as Error).message;
}

async function captureErrorMessage(task: () => Promise<void>): Promise<string> {
  let message = '';
  try {
    await task();
  } catch (error) {
    message = getErrorMessage(error as Object);
  }
  return message;
}

function createRejectingPost(state: CallCaptureState, message: string): PostMethod {
  return async <T>(path: string, payload: object, accessToken: string = ''): Promise<AuthApiResponse<T>> => {
    state.postCalls += 1;
    state.postPath = path;
    state.postToken = accessToken;
    state.postPayload = JSON.stringify(payload);
    throw new Error(message);
  };
}

function createRejectingGet(state: CallCaptureState, message: string): GetMethod {
  return async <T>(path: string, accessToken: string): Promise<AuthApiResponse<T>> => {
    state.getCalls += 1;
    state.getPath = path;
    state.getToken = accessToken;
    throw new Error(message);
  };
}

function createRejectingPatch(state: CallCaptureState, message: string): PatchMethod {
  return async <T>(path: string, payload: object, accessToken: string): Promise<AuthApiResponse<T>> => {
    state.patchCalls += 1;
    state.patchPath = path;
    state.patchToken = accessToken;
    state.patchPayload = JSON.stringify(payload);
    throw new Error(message);
  };
}

export default function phase1ZeroHitBatchKTest() {
  describe('phase1ZeroHitBatchKTest', () => {
    it('normal: auth_gateway_create_guest_should_build_payload_and_route_to_guest_create', 0, async () => {
      // Arrange
      const state = new CallCaptureState();
      const apiClient = getGatewayClient();
      const originPost = apiClient.post;
      const originGet = apiClient.get;
      const originPatch = apiClient.patch;
      apiClient.post = createRejectingPost(state, 'post_guest_called');
      apiClient.get = createRejectingGet(state, 'get_unused');
      apiClient.patch = createRejectingPatch(state, 'patch_unused');
      const deviceInfo = new DeviceInfo('dev-1', 'mate', 'HarmonyOS');

      // Act
      const message = await captureErrorMessage(async () => {
        await AuthGateway.createGuest(deviceInfo);
      });

      // Assert
      expect(message).assertEqual('post_guest_called');
      expect(state.postCalls).assertEqual(1);
      expect(state.postPath).assertEqual('/auth/guest/create');
      expect(state.postPayload.indexOf('dev-1') >= 0).assertTrue();
      expect(state.postPayload.indexOf('HarmonyOS') >= 0).assertTrue();

      // Cleanup
      apiClient.post = originPost;
      apiClient.get = originGet;
      apiClient.patch = originPatch;
    });

    it('boundary: auth_gateway_me_should_pass_token_even_when_empty_string', 0, async () => {
      // Arrange
      const state = new CallCaptureState();
      const apiClient = getGatewayClient();
      const originPost = apiClient.post;
      const originGet = apiClient.get;
      const originPatch = apiClient.patch;
      apiClient.post = createRejectingPost(state, 'post_unused');
      apiClient.get = createRejectingGet(state, 'get_me_called');
      apiClient.patch = createRejectingPatch(state, 'patch_unused');

      // Act
      const message = await captureErrorMessage(async () => {
        await AuthGateway.me('');
      });

      // Assert
      expect(message).assertEqual('get_me_called');
      expect(state.getCalls).assertEqual(1);
      expect(state.getPath).assertEqual('/auth/me');
      expect(state.getToken).assertEqual('');

      // Cleanup
      apiClient.post = originPost;
      apiClient.get = originGet;
      apiClient.patch = originPatch;
    });

    it('invalid: auth_gateway_login_with_social_should_forward_provider_and_credential_fields', 0, async () => {
      // Arrange
      const state = new CallCaptureState();
      const apiClient = getGatewayClient();
      const originPost = apiClient.post;
      const originGet = apiClient.get;
      const originPatch = apiClient.patch;
      apiClient.post = createRejectingPost(state, 'post_social_called');
      apiClient.get = createRejectingGet(state, 'get_unused');
      apiClient.patch = createRejectingPatch(state, 'patch_unused');

      const credential = new SocialCredential();
      credential.authCode = '';
      credential.idToken = 'id-token';
      credential.openId = 'open-id';
      const deviceInfo = new DeviceInfo('dev-2', 'pura', 'HarmonyOS');

      // Act
      const message = await captureErrorMessage(async () => {
        await AuthGateway.loginWithSocial('HUAWEI', credential, deviceInfo);
      });

      // Assert
      expect(message).assertEqual('post_social_called');
      expect(state.postCalls).assertEqual(1);
      expect(state.postPath).assertEqual('/auth/social/login');
      expect(state.postPayload.indexOf('providerType') >= 0).assertTrue();
      expect(state.postPayload.indexOf('id-token') >= 0).assertTrue();
      expect(state.postPayload.indexOf('dev-2') >= 0).assertTrue();

      // Cleanup
      apiClient.post = originPost;
      apiClient.get = originGet;
      apiClient.patch = originPatch;
    });

    it('conflict: auth_gateway_update_username_and_avatar_should_route_to_different_patch_paths', 0, async () => {
      // Arrange
      const state = new CallCaptureState();
      const apiClient = getGatewayClient();
      const originPost = apiClient.post;
      const originGet = apiClient.get;
      const originPatch = apiClient.patch;
      apiClient.post = createRejectingPost(state, 'post_unused');
      apiClient.get = createRejectingGet(state, 'get_unused');
      apiClient.patch = createRejectingPatch(state, 'patch_called');

      // Act
      const usernameMessage = await captureErrorMessage(async () => {
        await AuthGateway.updateUsername('token-A', 'neo');
      });
      const usernamePath = state.patchPath;
      const usernamePayload = state.patchPayload;

      const avatarMessage = await captureErrorMessage(async () => {
        await AuthGateway.updateAvatar('token-B', 'data:image/png;base64,abc', 'image/png');
      });
      const avatarPath = state.patchPath;
      const avatarPayload = state.patchPayload;

      // Assert
      expect(usernameMessage).assertEqual('patch_called');
      expect(avatarMessage).assertEqual('patch_called');
      expect(state.patchCalls).assertEqual(2);
      expect(usernamePath).assertEqual('/auth/profile/username');
      expect(avatarPath).assertEqual('/auth/profile/avatar');
      expect(usernamePayload.indexOf('neo') >= 0).assertTrue();
      expect(avatarPayload.indexOf('image/png') >= 0).assertTrue();
      expect(avatarPayload.indexOf('data:image/png;base64,abc') >= 0).assertTrue();

      // Cleanup
      apiClient.post = originPost;
      apiClient.get = originGet;
      apiClient.patch = originPatch;
    });

    it('regression: td-20260413-phase1-auth-gateway-update-avatar_should_use_default_mime_type_when_not_provided', 0, async () => {
      // Arrange
      const state = new CallCaptureState();
      const apiClient = getGatewayClient();
      const originPost = apiClient.post;
      const originGet = apiClient.get;
      const originPatch = apiClient.patch;
      apiClient.post = createRejectingPost(state, 'post_unused');
      apiClient.get = createRejectingGet(state, 'get_unused');
      apiClient.patch = createRejectingPatch(state, 'patch_default_mime_called');

      // Act
      const message = await captureErrorMessage(async () => {
        await AuthGateway.updateAvatar('token-C', 'data:image/jpeg;base64,xyz');
      });

      // Assert
      expect(message).assertEqual('patch_default_mime_called');
      expect(state.patchCalls).assertEqual(1);
      expect(state.patchPath).assertEqual('/auth/profile/avatar');
      expect(state.patchToken).assertEqual('token-C');
      expect(state.patchPayload.indexOf('image/jpeg') >= 0).assertTrue();

      // Cleanup
      apiClient.post = originPost;
      apiClient.get = originGet;
      apiClient.patch = originPatch;
    });

    it('combined: auth_gateway_all_public_methods_should_dispatch_to_expected_http_verbs', 0, async () => {
      // Arrange
      const state = new CallCaptureState();
      const apiClient = getGatewayClient();
      const originPost = apiClient.post;
      const originGet = apiClient.get;
      const originPatch = apiClient.patch;
      apiClient.post = createRejectingPost(state, 'post_called');
      apiClient.get = createRejectingGet(state, 'get_called');
      apiClient.patch = createRejectingPatch(state, 'patch_called');
      const credential = new SocialCredential();
      const deviceInfo = new DeviceInfo('dev-x', 'mate-x', 'HarmonyOS');

      // Act
      const createGuestMessage = await captureErrorMessage(async () => {
        await AuthGateway.createGuest(deviceInfo);
      });
      const meMessage = await captureErrorMessage(async () => {
        await AuthGateway.me('token-1');
      });
      const socialMessage = await captureErrorMessage(async () => {
        await AuthGateway.loginWithSocial('HUAWEI', credential, deviceInfo);
      });
      const usernameMessage = await captureErrorMessage(async () => {
        await AuthGateway.updateUsername('token-2', 'alpha');
      });
      const avatarMessage = await captureErrorMessage(async () => {
        await AuthGateway.updateAvatar('token-3', 'data:image/png;base64,1', 'image/png');
      });

      // Assert
      expect(createGuestMessage).assertEqual('post_called');
      expect(meMessage).assertEqual('get_called');
      expect(socialMessage).assertEqual('post_called');
      expect(usernameMessage).assertEqual('patch_called');
      expect(avatarMessage).assertEqual('patch_called');
      expect(state.postCalls).assertEqual(2);
      expect(state.getCalls).assertEqual(1);
      expect(state.patchCalls).assertEqual(2);

      // Cleanup
      apiClient.post = originPost;
      apiClient.get = originGet;
      apiClient.patch = originPatch;
    });
  });
}
