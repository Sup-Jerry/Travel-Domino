import { BadRequestException, Injectable, UnauthorizedException } from '@nestjs/common';
import * as jwt from 'jsonwebtoken';
import { AppConfigService } from '../../config/app-config.service';
import { PgService } from '../../config/pg.service';
import { GuestCreateDto } from './dto/auth.dto';

interface SessionTokenPayload {
  userId: string;
  sessionId: string;
}

interface AuthProfile {
  userId: string;
  nickname: string;
  avatarUrl: string;
  mobileMasked: string;
  profileCompleted: boolean;
  isGuest: boolean;
  defaultLoginMethod: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly config: AppConfigService,
    private readonly pg: PgService
  ) {}

  async guestCreate(dto: GuestCreateDto, ip: string): Promise<unknown> {
    return this.pg.withTransaction(async (query) => {
      const userId = this.nextId('g');
      await query(
        `insert into user_account(user_id,nickname,avatar_url,mobile_masked,status,is_guest,profile_completed,default_login_method,register_time,last_login_time,mobile_bind_time)
         values($1,'游客','','','ACTIVE',true,false,'GUEST',now(),now(),null)`,
        [userId]
      );

      await query(
        `insert into auth_identity(identity_id,user_id,provider_type,provider_uid,provider_open_id,provider_union_id,phone_number,bind_status,bind_time,last_used_time)
         values($1,$2,'GUEST',$3,'','','','BOUND',now(),now())`,
        [this.nextId('idn'), userId, `guest_${dto.deviceInfo.deviceId}_${Date.now()}`]
      );

      const session = await this.issueSession(
        userId,
        dto.deviceInfo.deviceId,
        dto.deviceInfo.deviceName,
        dto.deviceInfo.platform,
        'GUEST',
        ip
      );
      const profile = await this.loadProfile(userId);
      return { user: profile, session };
    });
  }

  async me(accessToken: string): Promise<unknown> {
    const session = await this.mustSession(accessToken);
    return this.loadProfile(session.userId);
  }

  private async issueSession(
    userId: string,
    deviceId: string,
    deviceName: string,
    platform: string,
    loginMethod: string,
    ip: string
  ): Promise<{ accessToken: string; refreshToken: string; expireAt: string; sessionId: string }> {
    const sessionId = this.nextId('s');
    const accessExpireAt = new Date(Date.now() + this.config.authAccessTtlSeconds * 1000);
    const refreshExpireAt = new Date(Date.now() + this.config.authRefreshTtlSeconds * 1000);
    const payload: SessionTokenPayload = { userId, sessionId };

    const accessToken = jwt.sign(payload, this.config.jwtSecret, { expiresIn: this.config.authAccessTtlSeconds });
    const refreshToken = jwt.sign({ ...payload, kind: 'refresh' }, this.config.jwtSecret, { expiresIn: this.config.authRefreshTtlSeconds });

    await this.pg.query(
      `insert into user_session(session_id,user_id,device_id,device_name,platform,access_token,refresh_token,issued_at,expire_at,refresh_expire_at,status,login_method,last_active_time,ip)
       values($1,$2,$3,$4,$5,$6,$7,now(),$8,$9,'ACTIVE',$10,now(),$11)`,
      [sessionId, userId, deviceId, deviceName, platform, accessToken, refreshToken, accessExpireAt, refreshExpireAt, loginMethod, ip]
    );

    return {
      accessToken,
      refreshToken,
      expireAt: accessExpireAt.toISOString(),
      sessionId
    };
  }

  private async mustSession(accessToken: string): Promise<{ userId: string; sessionId: string }> {
    const token = accessToken.replace('Bearer ', '').trim();
    if (!token) {
      throw new UnauthorizedException('SESSION_EXPIRED');
    }

    let payload: SessionTokenPayload;
    try {
      payload = jwt.verify(token, this.config.jwtSecret) as SessionTokenPayload;
    } catch {
      throw new UnauthorizedException('SESSION_EXPIRED');
    }

    const res = await this.pg.query(
      `select status,expire_at from user_session where session_id=$1 and user_id=$2 and access_token=$3 limit 1`,
      [payload.sessionId, payload.userId, token]
    );
    if (res.rowCount === 0) {
      throw new UnauthorizedException('SESSION_EXPIRED');
    }
    const row = res.rows[0] as Record<string, string | Date>;
    if (String(row.status) !== 'ACTIVE' || new Date(String(row.expire_at)).getTime() <= Date.now()) {
      throw new UnauthorizedException('SESSION_EXPIRED');
    }

    return payload;
  }

  private async loadProfile(userId: string): Promise<AuthProfile> {
    const res = await this.pg.query(
      `select user_id,nickname,avatar_url,mobile_masked,profile_completed,is_guest,default_login_method,status from user_account where user_id=$1 limit 1`,
      [userId]
    );
    if (res.rowCount === 0) {
      throw new BadRequestException('ACCOUNT_NOT_FOUND');
    }
    const row = res.rows[0] as Record<string, string | boolean>;
    if (String(row.status) === 'LOCKED' || String(row.status) === 'CANCEL_PENDING' || String(row.status) === 'CANCELLED') {
      throw new BadRequestException('RISK_BLOCKED');
    }
    return {
      userId: String(row.user_id || ''),
      nickname: String(row.nickname || ''),
      avatarUrl: String(row.avatar_url || ''),
      mobileMasked: String(row.mobile_masked || ''),
      profileCompleted: Boolean(row.profile_completed),
      isGuest: Boolean(row.is_guest),
      defaultLoginMethod: String(row.default_login_method || 'GUEST')
    };
  }

  private nextId(prefix: string): string {
    return `${prefix}_${Date.now()}_${Math.floor(Math.random() * 100000)}`;
  }
}
