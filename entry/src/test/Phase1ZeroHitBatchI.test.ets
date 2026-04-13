import { describe, expect, it } from '@ohos/hypium';
import { http } from '@kit.NetworkKit';
import { HttpRequestHelper } from '../main/ets/infrastructure/adapters/HttpRequestHelper';

function buildOptions(connectTimeout: number, readTimeout: number): http.HttpRequestOptions {
  return {
    method: http.RequestMethod.GET,
    header: {
      'Content-Type': 'application/json'
    },
    connectTimeout: connectTimeout,
    readTimeout: readTimeout
  };
}

async function callAndCapture(
  ownerTag: string,
  requestName: string,
  url: string,
  options: http.HttpRequestOptions
): Promise<string> {
  let message = '';
  try {
    await HttpRequestHelper.request(ownerTag, requestName, url, options);
  } catch (error) {
    message = (error as Error).message;
  }
  return message;
}

export default function phase1ZeroHitBatchITest() {
  describe('phase1ZeroHitBatchITest', () => {
    it('normal: http_request_helper_should_throw_on_unreachable_local_endpoint', 0, async () => {
      // Arrange
      const options = buildOptions(20, 20);
      // Act
      const message = await callAndCapture(
        'Phase1ZeroHitBatchI',
        'normal-unreachable',
        'http://127.0.0.1:9/unreachable',
        options
      );
      // Assert
      expect(message.length > 0).assertTrue();
    });

    it('boundary: http_request_helper_should_handle_empty_owner_and_request_name', 0, async () => {
      // Arrange
      const options = buildOptions(20, 20);
      // Act
      const message = await callAndCapture('', '', 'http://127.0.0.1:9/boundary', options);
      // Assert
      expect(message.length > 0).assertTrue();
    });

    it('invalid: http_request_helper_should_throw_for_blank_url', 0, async () => {
      // Arrange
      const options = buildOptions(20, 20);
      // Act
      const message = await callAndCapture('Phase1ZeroHitBatchI', 'invalid-blank-url', '', options);
      // Assert
      expect(message.length > 0).assertTrue();
    });

    it('conflict: http_request_helper_should_handle_url_with_sensitive_query_params', 0, async () => {
      // Arrange
      const options = buildOptions(20, 20);
      const sensitiveUrl = 'http://127.0.0.1:9/conflict?token=abc&api_key=xyz&Authorization=raw&key=k';
      // Act
      const message = await callAndCapture('Phase1ZeroHitBatchI', 'conflict-sensitive', sensitiveUrl, options);
      // Assert
      expect(message.length > 0).assertTrue();
    });

    it('regression: td-20260413-phase1-http-helper-request_should_remain_callable_twice', 0, async () => {
      // Arrange
      const options = buildOptions(20, 20);
      // Act
      const first = await callAndCapture('Phase1ZeroHitBatchI', 'regression-1', 'http://127.0.0.1:9/r1', options);
      const second = await callAndCapture('Phase1ZeroHitBatchI', 'regression-2', 'http://127.0.0.1:9/r2', options);
      // Assert
      expect(first.length > 0).assertTrue();
      expect(second.length > 0).assertTrue();
    });

    it('combined: http_request_helper_should_support_parallel_failure_paths_without_throwing_test', 0, async () => {
      // Arrange
      const optionsA = buildOptions(20, 20);
      const optionsB = buildOptions(20, 20);
      // Act
      const results = await Promise.all([
        callAndCapture('Phase1ZeroHitBatchI', 'combined-a', 'http://127.0.0.1:9/a', optionsA),
        callAndCapture('Phase1ZeroHitBatchI', 'combined-b', 'http://127.0.0.1:9/b?token=abc', optionsB)
      ]);
      // Assert
      expect(results[0].length > 0).assertTrue();
      expect(results[1].length > 0).assertTrue();
    });
  });
}
