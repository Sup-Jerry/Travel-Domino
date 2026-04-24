import { CallHandler, ExecutionContext } from '@nestjs/common';
import { of, firstValueFrom } from 'rxjs';
import { ApiResponseInterceptor } from '../src/common/interceptors/api-response.interceptor';

function buildContext(requestId?: string): ExecutionContext {
  return {
    switchToHttp: () => ({
      getRequest: () => ({
        headers: requestId === undefined ? {} : { 'x-request-id': requestId }
      })
    })
  } as unknown as ExecutionContext;
}

describe('unit_test_case_generator_autofill_api_response_interceptor', () => {
  it('normal: interceptor_should_wrap_payload_with_success_shape', async () => {
    // Arrange
    const interceptor = new ApiResponseInterceptor();
    const context = buildContext('req-fixed-1');
    const next: CallHandler = { handle: () => of({ ok: true }) };
    // Act
    const result = await firstValueFrom(interceptor.intercept(context, next));
    // Assert
    expect(result).toEqual({
      code: 0,
      message: 'ok',
      requestId: 'req-fixed-1',
      data: { ok: true }
    });
  });

  it('boundary: interceptor_should_keep_empty_object_payload', async () => {
    // Arrange
    const interceptor = new ApiResponseInterceptor();
    const context = buildContext('req-fixed-2');
    const next: CallHandler = { handle: () => of({}) };
    // Act
    const result = await firstValueFrom(interceptor.intercept(context, next));
    // Assert
    expect(result).toMatchObject({ code: 0, message: 'ok', data: {} });
  });

  it('invalid: interceptor_should_generate_request_id_when_header_blank', async () => {
    // Arrange
    const interceptor = new ApiResponseInterceptor();
    const context = buildContext('   ');
    const next: CallHandler = { handle: () => of('x') };
    // Act
    const result = await firstValueFrom(interceptor.intercept(context, next)) as { requestId: string };
    // Assert
    expect(result.requestId.startsWith('req_')).toBe(true);
  });

  it('conflict: interceptor_should_generate_request_id_when_header_missing', async () => {
    // Arrange
    const interceptor = new ApiResponseInterceptor();
    const context = buildContext();
    const next: CallHandler = { handle: () => of(1) };
    // Act
    const result = await firstValueFrom(interceptor.intercept(context, next)) as { requestId: string };
    // Assert
    expect(result.requestId.startsWith('req_')).toBe(true);
  });

  it('regression: interceptor_should_not_modify_data_type', async () => {
    // Arrange
    const interceptor = new ApiResponseInterceptor();
    const context = buildContext('req-fixed-3');
    const next: CallHandler = { handle: () => of(['a', 'b']) };
    // Act
    const result = await firstValueFrom(interceptor.intercept(context, next)) as { data: string[] };
    // Assert
    expect(Array.isArray(result.data)).toBe(true);
    expect(result.data).toEqual(['a', 'b']);
  });

  it('combined: interceptor_should_support_nested_payload_and_fixed_request_id', async () => {
    // Arrange
    const interceptor = new ApiResponseInterceptor();
    const context = buildContext('req-combined');
    const next: CallHandler = {
      handle: () => of({ meta: { total: 2 }, list: [{ id: 1 }, { id: 2 }] })
    };
    // Act
    const result = await firstValueFrom(interceptor.intercept(context, next)) as { requestId: string; data: { meta: { total: number } } };
    // Assert
    expect(result.requestId).toBe('req-combined');
    expect(result.data.meta.total).toBe(2);
  });

  it('boundary: interceptor_should_keep_non_blank_request_id_header_without_trimming', async () => {
    // Arrange
    const interceptor = new ApiResponseInterceptor();
    const context = buildContext(' req-kept ');
    const next: CallHandler = { handle: () => of({ ok: 1 }) };
    // Act
    const result = await firstValueFrom(interceptor.intercept(context, next)) as { requestId: string };
    // Assert
    expect(result.requestId).toBe(' req-kept ');
  });

  it('combined: interceptor_should_wrap_null_payload_and_generated_request_id_together', async () => {
    // Arrange
    const interceptor = new ApiResponseInterceptor();
    const context = buildContext('');
    const next: CallHandler = { handle: () => of(null) };
    // Act
    const result = await firstValueFrom(interceptor.intercept(context, next)) as { requestId: string; data: null; code: number; message: string };
    // Assert
    expect(result.code).toBe(0);
    expect(result.message).toBe('ok');
    expect(result.data).toBeNull();
    expect(result.requestId.startsWith('req_')).toBe(true);
  });
});
