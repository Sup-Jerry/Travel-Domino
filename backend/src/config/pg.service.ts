import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { AppConfigService } from './app-config.service';

const { Pool } = require('pg');

@Injectable()
export class PgService implements OnModuleDestroy {
  private readonly pool: any;

  constructor(config: AppConfigService) {
    this.pool = new Pool({
      connectionString: config.databaseUrl,
      max: Number(process.env.PG_POOL_SIZE || 20)
    });
  }

  async query(sql: string, params: unknown[] = []): Promise<{ rowCount: number; rows: any[] }> {
    return this.pool.query(sql, params);
  }

  async withTransaction<T>(fn: (query: (sql: string, params?: unknown[]) => Promise<{ rowCount: number; rows: any[] }>) => Promise<T>): Promise<T> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const result = await fn((sql, params = []) => client.query(sql, params));
      await client.query('COMMIT');
      return result;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async onModuleDestroy(): Promise<void> {
    await this.pool.end();
  }
}