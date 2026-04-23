import { EventEmitter } from 'events';
import * as https from 'https';
import { BadGatewayException, BadRequestException } from '@nestjs/common';
import { AiChatCompletionsDto } from '../src/modules/ai/dto/ai.dto';
import { AiService, mapAiUpstreamHttpError } from '../src/modules/ai/ai.service';

interface RequestOptionsSnapshot {
  protocol?: string;
  hostname?: string;
  port?: number;
  path?: string;
  method?: string;
  headers?: Record<string, string>;
  timeout?: number;
}

class MockRequest extends EventEmitter {
  writes: string[] = [];
  ended = false;
  destroyedError: Error | null = null;

  write(chunk: string): void {
    this.writes.push(chunk);
  }

  end(): void {
    this.ended = true;
  }

  destroy(error?: Error): this {
    this.destroyedError = error ?? null;
    if (error) {
      this.emit('error', error);
    }
    return this;
  }
}

describe('unit_test_case_generator_autofill_ai_service', () => {
  const config = {
    aiUpstreamModel: 'deepseek-chat',
    aiUpstreamUrl: 'https://api.deepseek.com/v1/chat/completions?lang=zh',
    aiUpstreamKey: 'secret-key'
  };

  const buildService = (): AiService => new AiService(config as any);

  const makeDto = (): AiChatCompletionsDto => ({
    messages: [{ role: 'user', content: 'hello' }],
    stream: false
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('normal: map_ai_upstream_http_error_should_match_deepseek_status_codes', () => {
    expect(mapAiUpstreamHttpError(400)).toBe('AI_DEEPSEEK_BAD_REQUEST');
    expect(mapAiUpstreamHttpError(401)).toBe('AI_DEEPSEEK_AUTH_FAILED');
    expect(mapAiUpstreamHttpError(402)).toBe('AI_DEEPSEEK_INSUFFICIENT_BALANCE');
    expect(mapAiUpstreamHttpError(422)).toBe('AI_DEEPSEEK_INVALID_PARAMETERS');
    expect(mapAiUpstreamHttpError(429)).toBe('AI_DEEPSEEK_RATE_LIMIT');
    expect(mapAiUpstreamHttpError(500)).toBe('AI_DEEPSEEK_SERVER_ERROR');
    expect(mapAiUpstreamHttpError(503)).toBe('AI_DEEPSEEK_SERVER_BUSY');
  });

  it('boundary: map_ai_upstream_http_error_should_fallback_for_zero_status', () => {
    expect(mapAiUpstreamHttpError(0)).toBe('AI_UPSTREAM_HTTP_0');
  });

  it('invalid: map_ai_upstream_http_error_should_fallback_for_negative_status', () => {
    expect(mapAiUpstreamHttpError(-1)).toBe('AI_UPSTREAM_HTTP_-1');
  });

  it('conflict: map_ai_upstream_http_error_should_not_use_deepseek_map_for_unknown_5xx', () => {
    expect(mapAiUpstreamHttpError(599)).toBe('AI_UPSTREAM_HTTP_599');
  });

  it('regression: chat_completions_should_reject_empty_messages', async () => {
    const service = buildService();
    const dto = { messages: [] } as AiChatCompletionsDto;

    await expect(service.chatCompletions(dto)).rejects.toThrow(BadRequestException);
    await expect(service.chatCompletions(dto)).rejects.toThrow('AI_MESSAGES_REQUIRED');
  });

  it('combined: chat_completions_should_build_payload_with_optional_fields_and_parse_json', async () => {
    const service = buildService();
    const dto: AiChatCompletionsDto = {
      messages: [{ role: 'system', content: 's' }, { role: 'user', content: 'u' }],
      max_tokens: 321,
      temperature: 0.4,
      stream: true,
      response_format: { type: 'json_object' }
    };
    const postJson = jest.spyOn(service as any, 'postJson').mockResolvedValue({
      statusCode: 200,
      body: '{"id":"ok","choices":[]}'
    });

    const result = await service.chatCompletions(dto);

    expect(postJson).toHaveBeenCalledTimes(1);
    const [urlRaw, rawBody, apiKey] = postJson.mock.calls[0];
    const parsedBody = JSON.parse(rawBody as string);
    expect(urlRaw).toBe(config.aiUpstreamUrl);
    expect(apiKey).toBe(config.aiUpstreamKey);
    expect(parsedBody).toEqual({
      model: 'deepseek-chat',
      messages: dto.messages,
      max_tokens: 321,
      stream: true,
      temperature: 0.4,
      response_format: { type: 'json_object' }
    });
    expect(result).toEqual({ id: 'ok', choices: [] });
  });

  it('boundary: chat_completions_should_use_default_max_tokens_and_omit_optional_fields', async () => {
    const service = buildService();
    const dto = makeDto();
    const postJson = jest.spyOn(service as any, 'postJson').mockResolvedValue({
      statusCode: 200,
      body: '{"ok":true}'
    });

    const result = await service.chatCompletions(dto);

    const [, rawBody] = postJson.mock.calls[0];
    expect(JSON.parse(rawBody as string)).toEqual({
      model: 'deepseek-chat',
      messages: dto.messages,
      max_tokens: 2000,
      stream: false
    });
    expect(result).toEqual({ ok: true });
  });

  it('invalid: chat_completions_should_map_upstream_http_error_to_bad_gateway', async () => {
    const service = buildService();
    jest.spyOn(service as any, 'postJson').mockResolvedValue({ statusCode: 429, body: '{"error":true}' });

    await expect(service.chatCompletions(makeDto())).rejects.toThrow(BadGatewayException);
    await expect(service.chatCompletions(makeDto())).rejects.toThrow('AI_DEEPSEEK_RATE_LIMIT');
  });

  it('conflict: chat_completions_should_fallback_unknown_http_status_code', async () => {
    const service = buildService();
    jest.spyOn(service as any, 'postJson').mockResolvedValue({ statusCode: 418, body: 'teapot' });

    await expect(service.chatCompletions(makeDto())).rejects.toThrow('AI_UPSTREAM_HTTP_418');
  });

  it('regression: chat_completions_should_throw_invalid_json_when_upstream_body_is_not_json', async () => {
    const service = buildService();
    jest.spyOn(service as any, 'postJson').mockResolvedValue({ statusCode: 200, body: 'not-json' });

    await expect(service.chatCompletions(makeDto())).rejects.toThrow('AI_UPSTREAM_INVALID_JSON');
  });

  it('normal: post_json_should_send_https_request_and_collect_chunks', async () => {
    const service = buildService();
    const request = new MockRequest();
    let optionsSnapshot: RequestOptionsSnapshot | null = null;
    jest.spyOn(https, 'request').mockImplementation(((options: RequestOptionsSnapshot, callback: (res: EventEmitter & { statusCode?: number }) => void) => {
      optionsSnapshot = options;
      const response = new EventEmitter() as EventEmitter & { statusCode?: number };
      response.statusCode = 201;
      callback(response);
      response.emit('data', Buffer.from('{"ok":'));
      response.emit('data', 'true}');
      response.emit('end');
      return request as any;
    }) as any);

    const result = await (service as any).postJson(config.aiUpstreamUrl, '{"hello":"world"}', config.aiUpstreamKey);

    expect(optionsSnapshot).toMatchObject({
      protocol: 'https:',
      hostname: 'api.deepseek.com',
      port: 443,
      path: '/v1/chat/completions?lang=zh',
      method: 'POST',
      timeout: 65000
    });
    expect(optionsSnapshot).not.toBeNull();
    const captured: RequestOptionsSnapshot = optionsSnapshot!;
    expect(captured.headers).toMatchObject({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer secret-key'
    });
    expect(request.writes).toEqual(['{"hello":"world"}']);
    expect(request.ended).toBe(true);
    expect(result).toEqual({ statusCode: 201, body: '{"ok":true}' });
  });

  it('boundary: post_json_should_default_status_code_to_500_when_upstream_response_has_no_status', async () => {
    const service = buildService();
    jest.spyOn(https, 'request').mockImplementation((((_options: RequestOptionsSnapshot, callback: (res: EventEmitter & { statusCode?: number }) => void) => {
      const response = new EventEmitter() as EventEmitter & { statusCode?: number };
      callback(response);
      response.emit('end');
      return new MockRequest() as any;
    })) as any);

    const result = await (service as any).postJson(config.aiUpstreamUrl, '{}', config.aiUpstreamKey);

    expect(result).toEqual({ statusCode: 500, body: '' });
  });

  it('invalid: post_json_should_reject_invalid_url', async () => {
    const service = buildService();

    await expect((service as any).postJson('not-a-url', '{}', config.aiUpstreamKey)).rejects.toThrow('AI_UPSTREAM_URL_INVALID');
  });

  it('invalid: post_json_should_reject_non_https_url', async () => {
    const service = buildService();

    await expect((service as any).postJson('http://example.com/a', '{}', config.aiUpstreamKey)).rejects.toThrow('AI_UPSTREAM_URL_NOT_HTTPS');
  });

  it('conflict: post_json_should_reject_request_errors', async () => {
    const service = buildService();
    jest.spyOn(https, 'request').mockImplementation((((_options: RequestOptionsSnapshot, _callback: (res: EventEmitter & { statusCode?: number }) => void) => {
      const request = new MockRequest();
      setImmediate(() => request.emit('error', new Error('socket hang up')));
      return request as any;
    })) as any);

    await expect((service as any).postJson(config.aiUpstreamUrl, '{}', config.aiUpstreamKey)).rejects.toThrow('AI_UPSTREAM_REQUEST_FAILED');
  });

  it('combined: post_json_should_reject_timeout_once_and_destroy_request', async () => {
    const service = buildService();
    const request = new MockRequest();
    jest.spyOn(https, 'request').mockImplementation((((_options: RequestOptionsSnapshot, _callback: (res: EventEmitter & { statusCode?: number }) => void) => {
      setImmediate(() => request.emit('timeout'));
      return request as any;
    })) as any);

    await expect((service as any).postJson(config.aiUpstreamUrl, '{}', config.aiUpstreamKey)).rejects.toThrow('AI_UPSTREAM_TIMEOUT');
    expect(request.destroyedError?.message).toBe('AI_UPSTREAM_TIMEOUT');
  });
});
