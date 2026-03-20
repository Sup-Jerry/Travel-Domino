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

  get authUseStubProviders(): boolean {
    return String(process.env.AUTH_USE_STUB_PROVIDERS || 'false').toLowerCase() === 'true';
  }
}
