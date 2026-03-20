import { Controller, Get } from '@nestjs/common';
import { PgService } from '../../config/pg.service';

@Controller('admin-health')
export class HealthController {
  constructor(private readonly pg: PgService) {}

  @Get()
  async health(): Promise<unknown> {
    const db = await this.pg.query('select 1 as ok');
    return {
      status: 'UP',
      db: db.rowCount > 0 ? 'UP' : 'DOWN',
      timestamp: new Date().toISOString()
    };
  }
}
