import { BadGatewayException, BadRequestException, Injectable, Logger } from '@nestjs/common';
import * as https from 'https';
import { AppConfigService } from '../../config/app-config.service';
import { AiChatCompletionsDto } from './dto/ai.dto';

interface UpstreamResponse {
  statusCode: number;
  body: string;
}

const DEEPSEEK_STATUS_ERROR_MAP: Record<number, string> = {
  400: 'AI_DEEPSEEK_BAD_REQUEST',
  401: 'AI_DEEPSEEK_AUTH_FAILED',
  402: 'AI_DEEPSEEK_INSUFFICIENT_BALANCE',
  422: 'AI_DEEPSEEK_INVALID_PARAMETERS',
  429: 'AI_DEEPSEEK_RATE_LIMIT',
  500: 'AI_DEEPSEEK_SERVER_ERROR',
  503: 'AI_DEEPSEEK_SERVER_BUSY'
};

export function mapAiUpstreamHttpError(statusCode: number): string {
  const direct = DEEPSEEK_STATUS_ERROR_MAP[statusCode];
  if (typeof direct === 'string' && direct.length > 0) {
    return direct;
  }
  return `AI_UPSTREAM_HTTP_${statusCode}`;
}

@Injectable()
export class AiService {
  private static readonly DEFAULT_MAX_TOKENS = 2000;
  private static readonly REQUEST_TIMEOUT_MS = 65000;
  private readonly logger = new Logger(AiService.name);

  constructor(private readonly config: AppConfigService) {}

  async chatCompletions(dto: AiChatCompletionsDto): Promise<unknown> {
    const startedAt = Date.now();
    if (!dto.messages || dto.messages.length === 0) {
      this.logger.error('[airest]AI_BACKEND_TRACE[ai_service_invalid_input] reason=empty_messages');
      throw new BadRequestException('AI_MESSAGES_REQUIRED');
    }

    const payload: Record<string, unknown> = {
      model: this.config.aiUpstreamModel,
      messages: dto.messages,
      max_tokens: dto.max_tokens ?? AiService.DEFAULT_MAX_TOKENS,
      stream: dto.stream === true
    };
    if (typeof dto.temperature === 'number') {
      payload.temperature = dto.temperature;
    }
    if (dto.response_format?.type === 'json_object') {
      payload.response_format = { type: 'json_object' };
    }

    const raw = JSON.stringify(payload);
    this.logger.log(
      `[airest]AI_BACKEND_TRACE[ai_service_upstream_request] model=${this.config.aiUpstreamModel}, messageCount=${dto.messages.length}, bodyLen=${raw.length}`
    );
    const upstream = await this.postJson(
      this.config.aiUpstreamUrl,
      raw,
      this.config.aiUpstreamKey
    );

    this.logger.log(
      `[airest]AI_BACKEND_TRACE[ai_service_upstream_response] status=${upstream.statusCode}, bodyLen=${upstream.body.length}, costMs=${Date.now() - startedAt}`
    );
    if (upstream.statusCode < 200 || upstream.statusCode >= 300) {
      const errorCode = mapAiUpstreamHttpError(upstream.statusCode);
      this.logger.error(
        `[airest]AI_BACKEND_TRACE[ai_service_upstream_http_fail] status=${upstream.statusCode}, code=${errorCode}`
      );
      throw new BadGatewayException(errorCode);
    }

    try {
      return JSON.parse(upstream.body) as unknown;
    } catch (_error) {
      this.logger.error('[airest]AI_BACKEND_TRACE[ai_service_upstream_json_fail]');
      throw new BadGatewayException('AI_UPSTREAM_INVALID_JSON');
    }
  }

  private async postJson(urlRaw: string, body: string, apiKey: string): Promise<UpstreamResponse> {
    return new Promise<UpstreamResponse>((resolve, reject) => {
      let settled = false;
      const safeReject = (error: BadGatewayException): void => {
        if (settled) {
          return;
        }
        settled = true;
        reject(error);
      };
      const safeResolve = (value: UpstreamResponse): void => {
        if (settled) {
          return;
        }
        settled = true;
        resolve(value);
      };

      let url: URL;
      try {
        url = new URL(urlRaw);
      } catch (_error) {
        this.logger.error('[airest]AI_BACKEND_TRACE[ai_service_url_invalid]');
        safeReject(new BadGatewayException('AI_UPSTREAM_URL_INVALID'));
        return;
      }
      if (url.protocol !== 'https:') {
        this.logger.error(`[airest]AI_BACKEND_TRACE[ai_service_url_not_https] protocol=${url.protocol}`);
        safeReject(new BadGatewayException('AI_UPSTREAM_URL_NOT_HTTPS'));
        return;
      }

      const req = https.request(
        {
          protocol: url.protocol,
          hostname: url.hostname,
          port: url.port ? Number(url.port) : 443,
          path: `${url.pathname}${url.search}`,
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${apiKey}`,
            'Content-Length': Buffer.byteLength(body).toString()
          },
          timeout: AiService.REQUEST_TIMEOUT_MS
        },
        (res) => {
          const chunks: Buffer[] = [];
          res.on('data', (chunk: Buffer | string) => {
            chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
          });
          res.on('end', () => {
            safeResolve({
              statusCode: res.statusCode || 500,
              body: Buffer.concat(chunks).toString('utf8')
            });
          });
        }
      );

      req.on('timeout', () => {
        this.logger.error('[airest]AI_BACKEND_TRACE[ai_service_request_timeout]');
        safeReject(new BadGatewayException('AI_UPSTREAM_TIMEOUT'));
        req.destroy(new Error('AI_UPSTREAM_TIMEOUT'));
      });
      req.on('error', (error: Error) => {
        this.logger.error(`[airest]AI_BACKEND_TRACE[ai_service_request_error] reason=${error.message}`);
        if (error.message === 'AI_UPSTREAM_TIMEOUT') {
          safeReject(new BadGatewayException('AI_UPSTREAM_TIMEOUT'));
          return;
        }
        safeReject(new BadGatewayException('AI_UPSTREAM_REQUEST_FAILED'));
      });

      req.write(body);
      req.end();
    });
  }
}
