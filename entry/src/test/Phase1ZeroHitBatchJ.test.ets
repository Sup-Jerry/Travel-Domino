import { describe, expect, it } from '@ohos/hypium';
import { AuthApiClient } from '../main/ets/infrastructure/auth/AuthApiClient';
import { HttpRequestHelper } from '../main/ets/infrastructure/adapters/HttpRequestHelper';

interface ApiEnvelopeLike {
  code: number;
  message: string;
  requestId: string;
  data: string;
}

type ParseBodyFn = (rawResult: Object, traceName: string) => ApiEnvelopeLike;
type WithTimeoutFn = (task: Promise<string>, timeoutMs: number, traceName: string) => Promise<string>;

class DummyObject {
  ok: boolean = true;
}

class KeyValuePayload {
  k: string = 'v';
}

class AuthHttpHooksJ {
  private readonly originRequest: Object;

  constructor() {
    this.originRequest = Reflect.get(HttpRequestHelper as Object, 'request') as Object;
  }

  setRequest(
    fn: (ownerTag: string, requestName: string, url: string, options: Object) => Promise<Object>
  ): void {
    Reflect.set(HttpRequestHelper as Object, 'request', fn);
  }

  restore(): void {
    Reflect.set(HttpRequestHelper as Object, 'request', this.originRequest);
  }
}

function getParseBody(client: AuthApiClient): ParseBodyFn {
  return Reflect.get(client, 'parseBody') as ParseBodyFn;
}

function getWithTimeout(client: AuthApiClient): WithTimeoutFn {
  return Reflect.get(client, 'withTimeout') as WithTimeoutFn;
}

async function captureErrorMessage(action: () => Promise<Object>): Promise<string> {
  let message = '';
  try {
    await action();
  } catch (error) {
    message = (error as Error).message;
  }
  return message;
}

export default function phase1ZeroHitBatchJTest() {
  describe('phase1ZeroHitBatchJTest', () => {
    it('normal: auth_api_client_parse_body_should_parse_valid_json', 0, () => {
      // Arrange
      const client = new AuthApiClient();
      const parseBody = getParseBody(client);
      const raw = '{"code":0,"message":"ok","requestId":"r1","data":"payload"}';
      // Act
      const parsed = parseBody(raw, 'POST /demo');
      // Assert
      expect(parsed.code).assertEqual(0);
      expect(parsed.message).assertEqual('ok');
      expect(parsed.requestId).assertEqual('r1');
      expect(parsed.data).assertEqual('payload');
    });

    it('boundary: auth_api_client_with_timeout_should_return_when_task_resolves_fast', 0, async () => {
      // Arrange
      const client = new AuthApiClient();
      const withTimeout = getWithTimeout(client);
      // Act
      const result = await withTimeout(Promise.resolve('done'), 30, 'FAST');
      // Assert
      expect(result).assertEqual('done');
    });

    it('invalid: auth_api_client_parse_body_should_throw_on_invalid_json', 0, async () => {
      // Arrange
      const client = new AuthApiClient();
      const parseBody = getParseBody(client);
      // Act
      const message = await captureErrorMessage(async (): Promise<Object> => {
        parseBody('{invalid-json', 'GET /bad');
        return new DummyObject();
      });
      // Assert
      expect(message).assertEqual('auth_api_invalid_json_GET /bad');
    });

    it('conflict: auth_api_client_with_timeout_should_keep_original_task_rejection', 0, async () => {
      // Arrange
      const client = new AuthApiClient();
      const withTimeout = getWithTimeout(client);
      // Act
      const message = await captureErrorMessage(async (): Promise<Object> => {
        await withTimeout(Promise.reject(new Error('task_failed')), 50, 'TASK');
        return new DummyObject();
      });
      // Assert
      expect(message).assertEqual('task_failed');
    });

    it('regression: td-20260413-phase1-auth-api-client-with-timeout_should_emit_timeout_error', 0, async () => {
      // Arrange
      const client = new AuthApiClient();
      const withTimeout = getWithTimeout(client);
      // Act
      const message = await captureErrorMessage(async (): Promise<Object> => {
        await withTimeout(new Promise<string>(() => {}), 10, 'SLOW');
        return new DummyObject();
      });
      // Assert
      expect(message).assertEqual('auth_api_timeout_SLOW_10');
    });

    it('combined: auth_api_client_post_get_patch_should_be_callable_and_fail_as_error_messages', 0, async () => {
      // Arrange
      const client = new AuthApiClient();
      const hooks = new AuthHttpHooksJ();
      hooks.setRequest(async (_ownerTag: string, requestName: string): Promise<Object> => {
        return Promise.reject(new Error(`mock_${requestName}_fail`));
      });
      let postError = '';
      let getError = '';
      let patchError = '';
      // Act
      try {
        postError = await captureErrorMessage(async (): Promise<Object> => {
          await client.post<Object>('/auth/test-post', new KeyValuePayload(), '');
          return new DummyObject();
        });
        getError = await captureErrorMessage(async (): Promise<Object> => {
          await client.get<Object>('/auth/test-get', 'token');
          return new DummyObject();
        });
        patchError = await captureErrorMessage(async (): Promise<Object> => {
          await client.patch<Object>('/auth/test-patch', new KeyValuePayload(), 'token');
          return new DummyObject();
        });
      } finally {
        hooks.restore();
      }
      // Assert
      expect(postError).assertEqual('mock_POST /auth/test-post_fail');
      expect(getError).assertEqual('mock_GET /auth/test-get_fail');
      expect(patchError).assertEqual('mock_PATCH /auth/test-patch_fail');
    });
  });
}
