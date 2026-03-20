import { Injectable } from '@nestjs/common';
import { PgService } from '../../config/pg.service';

@Injectable()
export class AuditService {
  constructor(private readonly pg: PgService) {}

  async write(actionType: string, userId: string | null, payload: Record<string, unknown>): Promise<void> {
    await this.pg.query(
      `insert into security_log(log_id,user_id,action_type,payload,created_at)
       values($1,$2,$3,$4::jsonb,now())`,
      [this.nextId('log'), userId, actionType, JSON.stringify(payload)]
    );
  }

  private nextId(prefix: string): string {
    return `${prefix}_${Date.now()}_${Math.floor(Math.random() * 100000)}`;
  }
}
