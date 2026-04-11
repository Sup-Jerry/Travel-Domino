import { ArgumentsHost, BadRequestException } from '@nestjs/common';
import { AllExceptionsFilter } from '../src/common/filters/all-exceptions.filter';

function buildHost(response: {
  status: (code: number) => { json: (body: unknown) => void };
}): ArgumentsHost {
  return {
    switchToHttp: () => ({
      getResponse: () => response
    })
  } as unknown as ArgumentsHost;
}

describe('unit_test_case_generator_autofill_all_exceptions_filter', () => {
  it('normal: filter_should_map_http_exception_status_and_message', () => {
    // Arrange
    const filter = new AllExceptionsFilter();
    const json = jest.fn();
    const status = jest.fn().mockReturnValue({ json });
    const host = buildHost({ status });
    const exception = new BadRequestException('bad_input');
    // Act
    filter.catch(exception, host);
    // Assert
    expect(status).toHaveBeenCalledWith(400);
    expect(json).toHaveBeenCalledWith(expect.objectContaining({
      code: 400,
      message: 'bad_input',
      data: {}
    }));
  });

  it('boundary: filter_should_stringify_non_string_http_message', () => {
    // Arrange
    const filter = new AllExceptionsFilter();
    const json = jest.fn();
    const status = jest.fn().mockReturnValue({ json });
    const host = buildHost({ status });
    const exception = new BadRequestException({ message: ['m1', 'm2'] });
    // Act
    filter.catch(exception, host);
    // Assert
    expect(status).toHaveBeenCalledWith(400);
    expect(json).toHaveBeenCalledWith(expect.objectContaining({
      message: 'm1,m2'
    }));
  });

  it('invalid: filter_should_map_unknown_error_to_internal_error', () => {
    // Arrange
    const filter = new AllExceptionsFilter();
    const json = jest.fn();
    const status = jest.fn().mockReturnValue({ json });
    const host = buildHost({ status });
    // Act
    filter.catch(new Error('boom'), host);
    // Assert
    expect(status).toHaveBeenCalledWith(500);
    expect(json).toHaveBeenCalledWith(expect.objectContaining({
      code: 500,
      message: 'internal_error'
    }));
  });

  it('conflict: filter_should_keep_request_payload_shape_for_http_exception', () => {
    // Arrange
    const filter = new AllExceptionsFilter();
    const json = jest.fn();
    const status = jest.fn().mockReturnValue({ json });
    const host = buildHost({ status });
    const exception = new BadRequestException('conflict_case');
    // Act
    filter.catch(exception, host);
    // Assert
    const body = json.mock.calls[0][0] as { requestId: string; data: Record<string, unknown> };
    expect(body.requestId.startsWith('req_')).toBe(true);
    expect(body.data).toEqual({});
  });

  it('regression: filter_should_not_throw_when_status_writer_called', () => {
    // Arrange
    const filter = new AllExceptionsFilter();
    const json = jest.fn();
    const status = jest.fn().mockReturnValue({ json });
    const host = buildHost({ status });
    const exception = new BadRequestException('stable');
    // Act
    const action = () => filter.catch(exception, host);
    // Assert
    expect(action).not.toThrow();
  });

  it('combined: filter_should_cover_unknown_and_http_exception_paths', () => {
    // Arrange
    const filter = new AllExceptionsFilter();
    const json = jest.fn();
    const status = jest.fn().mockReturnValue({ json });
    const host = buildHost({ status });
    // Act
    filter.catch(new Error('x'), host);
    filter.catch(new BadRequestException('y'), host);
    // Assert
    expect(status).toHaveBeenNthCalledWith(1, 500);
    expect(status).toHaveBeenNthCalledWith(2, 400);
  });
});
