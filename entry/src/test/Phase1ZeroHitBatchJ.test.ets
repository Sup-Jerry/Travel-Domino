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

class HttpResponseLikeJ {
  result: string = '';
}

class HeaderCaptureJ {
  authorization: string = '';
  contentType: string = '';
  method: number = -1;
}

class TimerCaptureJ {
  clearCount: number = 0;
  lastDelay: number = -1;
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

class TimerHooksJ {
  private readonly globalObj: Object;
  private readonly originSetTimeout: Object;
  private readonly originClearTimeout: Object;

  constructor() {
    this.globalObj = globalThis as Object;
    this.originSetTimeout = Reflect.get(this.globalObj, 'setTimeout') as Object;
    this.originClearTimeout = Reflect.get(this.globalObj, 'clearTimeout') as Object;
  }

  set(setTimeoutImpl: Object, clearTimeoutImpl: Object): void {
    Reflect.set(this.globalObj, 'setTimeout', setTimeoutImpl);
    Reflect.set(this.globalObj, 'clearTimeout', clearTimeoutImpl);
  }

  restore(): void {
    Reflect.set(this.globalObj, 'setTimeout', this.originSetTimeout);
    Reflect.set(this.globalObj, 'clearTimeout', this.originClearTimeout);
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

    it('normal: auth_api_client_post_should_hit_success_response_logging_path', 0, async () => {
      // Arrange
      const client = new AuthApiClient();
      const hooks = new AuthHttpHooksJ();
      hooks.setRequest(async (): Promise<Object> => {
        const response = new HttpResponseLikeJ();
        response.result = '{"code":0,"message":"ok","requestId":"r-success","data":"payload"}';
        return Promise.resolve(response);
      });

      // Act
      let envelope: ApiEnvelopeLike | null = null;
      try {
        envelope = await client.post<string>('/auth/test-success', new KeyValuePayload(), '');
      } finally {
        hooks.restore();
      }

      // Assert
      expect(envelope !== null).assertTrue();
      expect((envelope as ApiEnvelopeLike).code).assertEqual(0);
      expect((envelope as ApiEnvelopeLike).message).assertEqual('ok');
      expect((envelope as ApiEnvelopeLike).requestId).assertEqual('r-success');
      expect((envelope as ApiEnvelopeLike).data).assertEqual('payload');
    });

    it('boundary: auth_api_client_post_should_include_authorization_header_when_token_not_blank', 0, async () => {
      // Arrange
      const client = new AuthApiClient();
      const hooks = new AuthHttpHooksJ();
      const capture = new HeaderCaptureJ();
      hooks.setRequest(async (_ownerTag: string, _requestName: string, _url: string, options: Object): Promise<Object> => {
        const headers = Reflect.get(options, 'header') as Record<string, string>;
        capture.authorization = headers['Authorization'] ?? '';
        capture.contentType = headers['Content-Type'] ?? '';
        capture.method = Number(Reflect.get(options, 'method'));
        const response = new HttpResponseLikeJ();
        response.result = '{"code":0,"message":"ok","requestId":"r-token","data":"token-payload"}';
        return Promise.resolve(response);
      });

      // Act
      let envelope: ApiEnvelopeLike | null = null;
      try {
        envelope = await client.post<string>('/auth/token-post', new KeyValuePayload(), ' bearer_token ');
      } finally {
        hooks.restore();
      }

      // Assert
      expect(envelope !== null).assertTrue();
      expect(capture.authorization).assertEqual('Bearer  bearer_token ');
      expect(capture.contentType).assertEqual('application/json');
    });

    it('boundary: auth_api_client_parse_body_should_accept_empty_data_payload', 0, () => {
      // Arrange
      const client = new AuthApiClient();
      const parseBody = getParseBody(client);
      const raw = '{"code":200,"message":"empty","requestId":"r-empty","data":""}';

      // Act
      const parsed = parseBody(raw, 'GET /empty');

      // Assert
      expect(parsed.code).assertEqual(200);
      expect(parsed.message).assertEqual('empty');
      expect(parsed.requestId).assertEqual('r-empty');
      expect(parsed.data).assertEqual('');
    });

    it('invalid: auth_api_client_with_timeout_should_stringify_non_error_rejection', 0, async () => {
      // Arrange
      const client = new AuthApiClient();
      const withTimeout = getWithTimeout(client);

      // Act
      const message = await captureErrorMessage(async (): Promise<Object> => {
        await withTimeout(Promise.reject('plain_failure'), 50, 'PLAIN');
        return new DummyObject();
      });

      // Assert
      expect(message).assertEqual('plain_failure');
    });

    it('boundary: auth_api_client_get_and_patch_should_allow_blank_token_path', 0, async () => {
      // Arrange
      const client = new AuthApiClient();
      const hooks = new AuthHttpHooksJ();
      const getCapture = new HeaderCaptureJ();
      const patchCapture = new HeaderCaptureJ();
      hooks.setRequest(async (_ownerTag: string, requestName: string, _url: string, options: Object): Promise<Object> => {
        const headers = Reflect.get(options, 'header') as Record<string, string>;
        const method = Number(Reflect.get(options, 'method'));
        if (requestName === 'GET /auth/blank-get') {
          getCapture.authorization = headers['Authorization'] ?? '';
          getCapture.contentType = headers['Content-Type'] ?? '';
          getCapture.method = method;
        }
        if (requestName === 'PATCH /auth/blank-patch') {
          patchCapture.authorization = headers['Authorization'] ?? '';
          patchCapture.contentType = headers['Content-Type'] ?? '';
          patchCapture.method = method;
        }
        const response = new HttpResponseLikeJ();
        response.result = '{"code":0,"message":"ok","requestId":"r-blank","data":"done"}';
        return Promise.resolve(response);
      });

      // Act
      let getEnvelope: ApiEnvelopeLike | null = null;
      let patchEnvelope: ApiEnvelopeLike | null = null;
      try {
        getEnvelope = await client.get<string>('/auth/blank-get', '   ');
        patchEnvelope = await client.patch<string>('/auth/blank-patch', new KeyValuePayload(), '   ');
      } finally {
        hooks.restore();
      }

      // Assert
      expect(getEnvelope !== null).assertTrue();
      expect(patchEnvelope !== null).assertTrue();
      expect(getCapture.authorization).assertEqual('Bearer    ');
      expect(getCapture.contentType).assertEqual('application/json');
      expect(patchCapture.authorization).assertEqual('Bearer    ');
      expect(patchCapture.contentType).assertEqual('application/json');
    });

    it('boundary: auth_api_client_with_timeout_should_skip_clear_when_timer_id_is_negative', 0, async () => {
      // Arrange
      const client = new AuthApiClient();
      const withTimeout = getWithTimeout(client);
      const timerHooks = new TimerHooksJ();
      const capture = new TimerCaptureJ();
      timerHooks.set(
        (callback: () => void, delayMs: number): number => {
          capture.lastDelay = delayMs;
          return -1;
        },
        (_timerId: number): void => {
          capture.clearCount += 1;
        }
      );

      // Act
      let result = '';
      try {
        result = await withTimeout(Promise.resolve('negative_timer_ok'), 25, 'NEGATIVE');
      } finally {
        timerHooks.restore();
      }

      // Assert
      expect(result).assertEqual('negative_timer_ok');
      expect(capture.lastDelay).assertEqual(25);
      expect(capture.clearCount).assertEqual(0);
    });
  });
}
