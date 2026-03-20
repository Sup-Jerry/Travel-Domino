import { Injectable, NestInterceptor, ExecutionContext, CallHandler } from '@nestjs/common';
import { map, Observable } from 'rxjs';

@Injectable()
export class ApiResponseInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    return next.handle().pipe(
      map((data) => {
        return {
          code: 0,
          message: 'ok',
          requestId: this.buildRequestId(context),
          data
        };
      })
    );
  }

  private buildRequestId(context: ExecutionContext): string {
    const req = context.switchToHttp().getRequest<{ headers?: Record<string, string> }>();
    const headerId = req?.headers?.['x-request-id'];
    if (headerId && headerId.trim().length > 0) {
      return headerId;
    }
    return `req_${Date.now()}_${Math.floor(Math.random() * 100000)}`;
  }
}
