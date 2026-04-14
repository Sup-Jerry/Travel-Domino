import { ArgumentsHost, Catch, ExceptionFilter, HttpException, HttpStatus, Logger } from '@nestjs/common';

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<{ status: (code: number) => { json: (body: unknown) => void } }>();
    const request = ctx.getRequest<{ method?: string; url?: string }>();

    const status = exception instanceof HttpException ? exception.getStatus() : HttpStatus.INTERNAL_SERVER_ERROR;
    const message = exception instanceof HttpException
      ? String((exception.getResponse() as { message?: string }).message || exception.message)
      : 'internal_error';
    const requestId = `req_${Date.now()}_${Math.floor(Math.random() * 100000)}`;
    const errorName = exception instanceof Error ? exception.name : 'UnknownError';
    const errorMessage = exception instanceof Error ? exception.message : String(exception || 'unknown');
    const method = request?.method || '';
    const url = request?.url || '';

    this.logger.error(
      `[AUTH_TRACE][http_exception] requestId=${requestId}, status=${status}, method=${method}, url=${url}, errorName=${errorName}, message=${errorMessage}`
    );

    response.status(status).json({
      code: status,
      message,
      requestId,
      data: {}
    });
  }
}

