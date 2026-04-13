import { Injectable } from '@nestjs/common';

@Injectable()
export class AppConfigService {
  get databaseUrl(): string {
    const val = process.env.DATABASE_URL || '';
    if (!val) {
      throw new Error('DATABASE_URL is required');
    }
    return val;
  }

  get jwtSecret(): string {
    const val = process.env.JWT_SECRET || '';
    if (!val) {
      throw new Error('JWT_SECRET is required');
    }
    return val;
  }

  get authAccessTtlSeconds(): number {
    return Number(process.env.AUTH_ACCESS_TTL_SECONDS || 7200);
  }

  get authRefreshTtlSeconds(): number {
    return Number(process.env.AUTH_REFRESH_TTL_SECONDS || 2592000);
  }

  get aiUpstreamUrl(): string {
    const val = process.env.AI_UPSTREAM_URL || process.env.AI_API_URL || '';
    if (!val) {
      throw new Error('AI_UPSTREAM_URL is required');
    }
    return val;
  }

  get aiUpstreamKey(): string {
    const val = process.env.AI_UPSTREAM_KEY || process.env.AI_API_KEY || '';
    if (!val) {
      throw new Error('AI_UPSTREAM_KEY is required');
    }
    return val;
  }

  get aiUpstreamModel(): string {
    const val = process.env.AI_UPSTREAM_MODEL || 'glm-5';
    return val.trim() || 'glm-5';
  }

}
