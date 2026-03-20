import { ArgumentsHost, Catch, ExceptionFilter, HttpException, HttpStatus } from '@nestjs/common';

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<{ status: (code: number) => { json: (body: unknown) => void } }>();

    const status = exception instanceof HttpException ? exception.getStatus() : HttpStatus.INTERNAL_SERVER_ERROR;
    const message = exception instanceof HttpException
      ? String((exception.getResponse() as { message?: string }).message || exception.message)
      : 'internal_error';

    response.status(status).json({
      code: status,
      message,
      requestId: `req_${Date.now()}_${Math.floor(Math.random() * 100000)}`,
      data: {}
    });
  }
}
