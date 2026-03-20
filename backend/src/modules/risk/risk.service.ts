import { BadRequestException, Injectable } from '@nestjs/common';
import { PgService } from '../../config/pg.service';

interface PendingSocial {
  providerType: string;
  providerUid: string;
}

@Injectable()
export class RiskService {
  private pendingSocialStore: Map<string, PendingSocial> = new Map();

  constructor(private readonly pg: PgService) {}

  async checkSmsRateLimit(phoneNumber: string, ip: string, deviceId: string): Promise<void> {
    await this.assertCounter(`sms_phone:${phoneNumber}`, 10, 3600);
    await this.assertCounter(`sms_ip:${ip}`, 50, 3600);
    await this.assertCounter(`sms_device:${deviceId}`, 20, 3600);
    await this.assertCooldown(`sms_cooldown:${phoneNumber}`, 60);
  }

  async increaseCodeFailure(phoneNumber: string): Promise<void> {
    await this.assertCounter(`sms_verify_fail:${phoneNumber}`, 8, 1800, false);
  }

  async savePendingSocial(token: string, providerType: string, providerUid: string): Promise<void> {
    this.pendingSocialStore.set(token, { providerType, providerUid });
  }

  async consumePendingSocial(token: string): Promise<PendingSocial | null> {
    const hit = this.pendingSocialStore.get(token) || null;
    if (hit) {
      this.pendingSocialStore.delete(token);
    }
    return hit;
  }

  private async assertCooldown(key: string, cooldownSeconds: number): Promise<void> {
    const now = Date.now();
    const res = await this.pg.query(`select key_value,window_start from risk_counter where key_value=$1 limit 1`, [key]);
    if (res.rowCount === 0) {
      await this.pg.query(`insert into risk_counter(counter_id,key_value,window_start,count,updated_at) values($1,$2,now(),1,now())`, [this.nextId('risk'), key]);
      return;
    }
    const row = res.rows[0] as { window_start: Date };
    const diffSec = Math.floor((now - new Date(row.window_start).getTime()) / 1000);
    if (diffSec < cooldownSeconds) {
      throw new BadRequestException('SMS_SEND_TOO_FREQUENT');
    }
    await this.pg.query(`update risk_counter set window_start=now(),count=1,updated_at=now() where key_value=$1`, [key]);
  }

  private async assertCounter(key: string, max: number, windowSeconds: number, throwOnOverflow: boolean = true): Promise<void> {
    const now = Date.now();
    const res = await this.pg.query(`select counter_id,window_start,count from risk_counter where key_value=$1 limit 1`, [key]);
    if (res.rowCount === 0) {
      await this.pg.query(`insert into risk_counter(counter_id,key_value,window_start,count,updated_at) values($1,$2,now(),1,now())`, [this.nextId('risk'), key]);
      return;
    }

    const row = res.rows[0] as { window_start: Date; count: number };
    const diffSec = Math.floor((now - new Date(row.window_start).getTime()) / 1000);
    if (diffSec >= windowSeconds) {
      await this.pg.query(`update risk_counter set window_start=now(),count=1,updated_at=now() where key_value=$1`, [key]);
      return;
    }

    const nextCount = Number(row.count) + 1;
    await this.pg.query(`update risk_counter set count=$2,updated_at=now() where key_value=$1`, [key, nextCount]);

    if (nextCount > max && throwOnOverflow) {
      throw new BadRequestException('RISK_BLOCKED');
    }
  }

  private nextId(prefix: string): string {
    return `${prefix}_${Date.now()}_${Math.floor(Math.random() * 100000)}`;
  }
}
