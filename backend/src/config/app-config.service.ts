import { Injectable } from '@nestjs/common';
import { existsSync, readFileSync } from 'fs';
import { resolve } from 'path';

@Injectable()
export class AppConfigService {
  private static readonly localEnv: Map<string, string> = AppConfigService.loadLocalEnv();

  private static loadLocalEnv(): Map<string, string> {
    const env = new Map<string, string>();
    const cwd = process.cwd();
    const candidates = [
      resolve(cwd, '.env'),
      resolve(cwd, 'env'),
      resolve(cwd, '..', '.env'),
      resolve(cwd, '..', 'env')
    ];

    for (const filePath of candidates) {
      if (!existsSync(filePath)) {
        continue;
      }
      const text = readFileSync(filePath, 'utf8');
      const lines = text.split(/\r?\n/);
      for (const lineRaw of lines) {
        const line = lineRaw.trim();
        if (!line || line.startsWith('#')) {
          continue;
        }
        const eq = line.indexOf('=');
        if (eq <= 0) {
          continue;
        }
        const key = line.substring(0, eq).trim();
        const value = line.substring(eq + 1).trim();
        if (!env.has(key)) {
          env.set(key, value);
        }
      }
    }

    return env;
  }

  private readEnv(key: string, fallback: string = ''): string {
    const local = AppConfigService.localEnv.get(key);
    if (typeof local === 'string' && local.length > 0) {
      return local;
    }
    return process.env[key] || fallback;
  }

  get databaseUrl(): string {
    const val = this.readEnv('DATABASE_URL', '');
    if (!val) {
      throw new Error('DATABASE_URL is required');
    }
    return val;
  }

  get jwtSecret(): string {
    const val = this.readEnv('JWT_SECRET', '');
    if (!val) {
      throw new Error('JWT_SECRET is required');
    }
    return val;
  }

  get authAccessTtlSeconds(): number {
    return Number(this.readEnv('AUTH_ACCESS_TTL_SECONDS', '7200'));
  }

  get authRefreshTtlSeconds(): number {
    return Number(this.readEnv('AUTH_REFRESH_TTL_SECONDS', '2592000'));
  }

  get aiUpstreamUrl(): string {
    const val = this.readEnv('AI_UPSTREAM_URL', this.readEnv('AI_API_URL', ''));
    if (!val) {
      throw new Error('AI_UPSTREAM_URL is required');
    }
    return val;
  }

  get aiUpstreamKey(): string {
    const val = this.readEnv('AI_UPSTREAM_KEY', this.readEnv('AI_API_KEY', ''));
    if (!val) {
      throw new Error('AI_UPSTREAM_KEY is required');
    }
    return val;
  }

  get aiUpstreamModel(): string {
    const val = this.readEnv('AI_UPSTREAM_MODEL', 'glm-5');
    return val.trim() || 'glm-5';
  }
}
