import { BadGatewayException, BadRequestException, Injectable } from '@nestjs/common';
import * as https from 'https';
import { AppConfigService } from '../../config/app-config.service';
import { AiChatCompletionsDto } from './dto/ai.dto';

interface UpstreamResponse {
  statusCode: number;
  body: string;
}

@Injectable()
export class AiService {
  private static readonly DEFAULT_MAX_TOKENS = 2000;
  private static readonly REQUEST_TIMEOUT_MS = 65000;

  constructor(private readonly config: AppConfigService) {}

  async chatCompletions(dto: AiChatCompletionsDto): Promise<unknown> {
    if (!dto.messages || dto.messages.length === 0) {
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

    const raw = JSON.stringify(payload);
    const upstream = await this.postJson(
      this.config.aiUpstreamUrl,
      raw,
      this.config.aiUpstreamKey
    );

    if (upstream.statusCode < 200 || upstream.statusCode >= 300) {
      throw new BadGatewayException(`AI_UPSTREAM_HTTP_${upstream.statusCode}`);
    }

    try {
      return JSON.parse(upstream.body) as unknown;
    } catch (_error) {
      throw new BadGatewayException('AI_UPSTREAM_INVALID_JSON');
    }
  }

  private async postJson(urlRaw: string, body: string, apiKey: string): Promise<UpstreamResponse> {
    return new Promise<UpstreamResponse>((resolve, reject) => {
      let url: URL;
      try {
        url = new URL(urlRaw);
      } catch (_error) {
        reject(new BadGatewayException('AI_UPSTREAM_URL_INVALID'));
        return;
      }
      if (url.protocol !== 'https:') {
        reject(new BadGatewayException('AI_UPSTREAM_URL_NOT_HTTPS'));
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
            resolve({
              statusCode: res.statusCode || 500,
              body: Buffer.concat(chunks).toString('utf8')
            });
          });
        }
      );

      req.on('timeout', () => {
        req.destroy(new Error('AI_UPSTREAM_TIMEOUT'));
      });
      req.on('error', () => {
        reject(new BadGatewayException('AI_UPSTREAM_REQUEST_FAILED'));
      });

      req.write(body);
      req.end();
    });
  }
}

