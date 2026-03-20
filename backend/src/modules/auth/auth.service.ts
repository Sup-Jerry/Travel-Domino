import { BadRequestException, Injectable, UnauthorizedException } from '@nestjs/common';
import * as jwt from 'jsonwebtoken';
import { AppConfigService } from '../../config/app-config.service';
import { PgService } from '../../config/pg.service';
import {
  BindPhoneDto,
  BindSocialDto,
  CancelRequestDto,
  GuestCreateDto,
  GuestUpgradeDto,
  LogoutDto,
  PhoneLoginDto,
  RefreshSessionDto,
  SendCodeDto,
  SocialBindExistingPhoneDto,
  SocialCreateAccountDto,
  SocialLoginDto,
  UnbindDto
} from './dto/auth.dto';
import { SmsService } from '../sms/sms.service';
import { SocialService } from '../social/social.service';
import { RiskService } from '../risk/risk.service';
import { AuditService } from '../audit/audit.service';

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
    private readonly pg: PgService,
    private readonly sms: SmsService,
    private readonly social: SocialService,
    private readonly risk: RiskService,
    private readonly audit: AuditService
  ) {}

  async sendCode(dto: SendCodeDto, ip: string, deviceId: string): Promise<{ expireInSeconds: number; retryAfterSeconds: number }> {
    await this.risk.checkSmsRateLimit(dto.phoneNumber, ip, deviceId);
    const code = await this.sms.sendCode(dto.phoneNumber, dto.countryCode, dto.bizType);
    await this.pg.query(
      `insert into verification_code(code_id,biz_type,phone_number,code_hash,send_channel,expired_at,verify_status,retry_count,created_at)
       values($1,$2,$3,$4,$5,$6,'PENDING',0,now())`,
      [this.nextId('code'), dto.bizType, dto.phoneNumber, code.codeHash, code.channel, new Date(code.expiredAt)]
    );
    await this.audit.write('SMS_SEND', null, { phoneNumber: dto.phoneNumber, bizType: dto.bizType });
    return { expireInSeconds: 300, retryAfterSeconds: 60 };
  }

  async phoneLogin(dto: PhoneLoginDto, ip: string): Promise<unknown> {
    if (!dto.agreementAccepted) {
      throw new BadRequestException('AGREEMENT_NOT_ACCEPTED');
    }

    await this.verifyCode(dto.phoneNumber, dto.code);

    return this.pg.withTransaction(async (query) => {
      const idRes = await query(
        `select user_id from auth_identity where provider_type='PHONE' and phone_number=$1 and bind_status='BOUND' limit 1`,
        [dto.phoneNumber]
      );

      let userId = '';
      let isNewUser = false;

      if (idRes.rowCount === 0) {
        isNewUser = true;
        userId = this.nextId('u');
        await query(
          `insert into user_account(user_id,nickname,avatar_url,mobile_masked,status,is_guest,profile_completed,default_login_method,register_time,last_login_time,mobile_bind_time)
           values($1,$2,'','', 'ACTIVE', false, false, 'PHONE', now(), now(), now())`,
          [userId, `用户${Date.now()}`]
        );

        await query(
          `insert into auth_identity(identity_id,user_id,provider_type,provider_uid,provider_open_id,provider_union_id,phone_number,bind_status,bind_time,last_used_time)
           values($1,$2,'PHONE',$3,'','',$3,'BOUND',now(),now())`,
          [this.nextId('idn'), userId, dto.phoneNumber]
        );
      } else {
        userId = idRes.rows[0].user_id as string;
        await query(`update user_account set last_login_time=now(), default_login_method='PHONE' where user_id=$1`, [userId]);
      }

      const session = await this.issueSession(userId, dto.deviceInfo.deviceId, dto.deviceInfo.deviceName, dto.deviceInfo.platform, 'PHONE', ip);
      const profile = await this.loadProfile(userId);
      await this.audit.write('LOGIN_PHONE', userId, { isNewUser });

      return {
        isNewUser,
        user: profile,
        session
      };
    });
  }

  async socialLogin(dto: SocialLoginDto, ip: string): Promise<unknown> {
    if (!dto.agreementAccepted) {
      throw new BadRequestException('AGREEMENT_NOT_ACCEPTED');
    }

    const providerUid = await this.social.verifyCredential(dto.providerType, dto.credential);
    if (!providerUid) {
      throw new BadRequestException('THIRD_PARTY_AUTH_FAILED');
    }

    const idRes = await this.pg.query(
      `select user_id from auth_identity where provider_type=$1 and provider_uid=$2 and bind_status='BOUND' limit 1`,
      [dto.providerType, providerUid]
    );

    if (idRes.rowCount === 0) {
      const pendingToken = this.nextId('pt');
      await this.risk.savePendingSocial(pendingToken, dto.providerType, providerUid);
      return {
        action: 'NEED_BIND_OR_CREATE',
        pendingToken,
        providerProfile: {
          nickname: `${dto.providerType}_用户`,
          avatarUrl: ''
        },
        suggestedActions: ['BIND_EXISTING_PHONE_ACCOUNT', 'CREATE_NEW_ACCOUNT']
      };
    }

    const userId = idRes.rows[0].user_id as string;
    const session = await this.issueSession(userId, dto.deviceInfo.deviceId, dto.deviceInfo.deviceName, dto.deviceInfo.platform, dto.providerType, ip);
    const profile = await this.loadProfile(userId);
    await this.audit.write('LOGIN_SOCIAL', userId, { providerType: dto.providerType });
    return {
      action: 'LOGIN_SUCCESS',
      user: profile,
      session
    };
  }

  async socialCreateAccount(dto: SocialCreateAccountDto, ip: string): Promise<unknown> {
    const pending = await this.risk.consumePendingSocial(dto.pendingToken);
    if (!pending) {
      throw new BadRequestException('INVALID_PENDING_TOKEN');
    }

    return this.pg.withTransaction(async (query) => {
      const userId = this.nextId('u');
      await query(
        `insert into user_account(user_id,nickname,avatar_url,mobile_masked,status,is_guest,profile_completed,default_login_method,register_time,last_login_time,mobile_bind_time)
         values($1,$2,$3,'', 'ACTIVE', false, false, $4, now(), now(), null)`,
        [userId, dto.nickname, dto.avatarUrl || '', pending.providerType]
      );

      await query(
        `insert into auth_identity(identity_id,user_id,provider_type,provider_uid,provider_open_id,provider_union_id,phone_number,bind_status,bind_time,last_used_time)
         values($1,$2,$3,$4,'','','','BOUND',now(),now())`,
        [this.nextId('idn'), userId, pending.providerType, pending.providerUid]
      );

      const session = await this.issueSession(userId, dto.deviceInfo.deviceId, dto.deviceInfo.deviceName, dto.deviceInfo.platform, pending.providerType, ip);
      const profile = await this.loadProfile(userId);
      await this.audit.write('SOCIAL_CREATE_ACCOUNT', userId, { providerType: pending.providerType });
      return { user: profile, session };
    });
  }

  async socialBindExistingPhone(dto: SocialBindExistingPhoneDto, ip: string): Promise<unknown> {
    const pending = await this.risk.consumePendingSocial(dto.pendingToken);
    if (!pending) {
      throw new BadRequestException('INVALID_PENDING_TOKEN');
    }

    await this.verifyCode(dto.phoneNumber, dto.code);

    return this.pg.withTransaction(async (query) => {
      const phoneRes = await query(
        `select user_id from auth_identity where provider_type='PHONE' and phone_number=$1 and bind_status='BOUND' limit 1`,
        [dto.phoneNumber]
      );
      if (phoneRes.rowCount === 0) {
        throw new BadRequestException('ACCOUNT_NOT_FOUND');
      }
      const userId = phoneRes.rows[0].user_id as string;

      const existing = await query(
        `select user_id from auth_identity where provider_type=$1 and provider_uid=$2 and bind_status='BOUND' limit 1`,
        [pending.providerType, pending.providerUid]
      );
      if (existing.rowCount > 0 && (existing.rows[0].user_id as string) !== userId) {
        throw new BadRequestException('ACCOUNT_CONFLICT');
      }

      if (existing.rowCount === 0) {
        await query(
          `insert into auth_identity(identity_id,user_id,provider_type,provider_uid,provider_open_id,provider_union_id,phone_number,bind_status,bind_time,last_used_time)
           values($1,$2,$3,$4,'','','','BOUND',now(),now())`,
          [this.nextId('idn'), userId, pending.providerType, pending.providerUid]
        );
      }

      const session = await this.issueSession(userId, dto.deviceInfo.deviceId, dto.deviceInfo.deviceName, dto.deviceInfo.platform, pending.providerType, ip);
      const profile = await this.loadProfile(userId);
      await this.audit.write('SOCIAL_BIND_EXISTING_PHONE', userId, { providerType: pending.providerType });
      return { user: profile, session };
    });
  }

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

      const session = await this.issueSession(userId, dto.deviceInfo.deviceId, dto.deviceInfo.deviceName, dto.deviceInfo.platform, 'GUEST', ip);
      const profile = await this.loadProfile(userId);
      await this.audit.write('GUEST_CREATE', userId, {});
      return { user: profile, session };
    });
  }

  async guestUpgrade(dto: GuestUpgradeDto): Promise<unknown> {
    await this.pg.query(
      `insert into guest_migration(migration_id,guest_user_id,target_user_id,migrate_status,migrate_time,created_at)
       values($1,$2,$3,'DONE',now(),now())`,
      [this.nextId('mig'), dto.guestUserId, dto.targetUserId]
    );
    await this.audit.write('GUEST_UPGRADE', dto.targetUserId, { guestUserId: dto.guestUserId });
    return { migrateStatus: 'DONE' };
  }

  async refresh(dto: RefreshSessionDto, ip: string): Promise<unknown> {
    const res = await this.pg.query(
      `select session_id,user_id,status,refresh_expire_at from user_session where refresh_token=$1 limit 1`,
      [dto.refreshToken]
    );
    if (res.rowCount === 0) {
      throw new UnauthorizedException('SESSION_EXPIRED');
    }
    const row = res.rows[0] as Record<string, string | Date>;
    if (String(row.status) !== 'ACTIVE' || new Date(String(row.refresh_expire_at)).getTime() <= Date.now()) {
      throw new UnauthorizedException('SESSION_EXPIRED');
    }

    const session = await this.rotateSessionToken(String(row.session_id), String(row.user_id), ip);
    await this.audit.write('SESSION_REFRESH', String(row.user_id), {});
    return session;
  }

  async me(accessToken: string): Promise<unknown> {
    const session = await this.mustSession(accessToken);
    return this.loadProfile(session.userId);
  }

  async identities(accessToken: string): Promise<unknown> {
    const session = await this.mustSession(accessToken);
    const profile = await this.loadProfile(session.userId);
    const res = await this.pg.query(
      `select provider_type,phone_number,bind_status from auth_identity where user_id=$1`,
      [session.userId]
    );

    const providers = ['PHONE', 'HUAWEI', 'WECHAT', 'QQ'];
    return providers.map((providerType) => {
      const row = res.rows.find((x: Record<string, unknown>) => String(x.provider_type) === providerType && String(x.bind_status) === 'BOUND');
      if (!row) {
        return { providerType, displayName: '未绑定', bound: false, isPrimary: false };
      }
      return {
        providerType,
        displayName: providerType === 'PHONE' ? this.maskPhone(String(row.phone_number || '')) : `${providerType}已绑定`,
        bound: true,
        isPrimary: profile.defaultLoginMethod === providerType
      };
    });
  }

  async bindSocial(accessToken: string, dto: BindSocialDto): Promise<unknown> {
    const session = await this.mustSession(accessToken);
    const providerUid = await this.social.verifyCredential(dto.providerType, dto.credential);
    const hit = await this.pg.query(
      `select user_id from auth_identity where provider_type=$1 and provider_uid=$2 and bind_status='BOUND' limit 1`,
      [dto.providerType, providerUid]
    );
    if (hit.rowCount > 0 && String(hit.rows[0].user_id) !== session.userId) {
      throw new BadRequestException('ACCOUNT_CONFLICT');
    }
    if (hit.rowCount === 0) {
      await this.pg.query(
        `insert into auth_identity(identity_id,user_id,provider_type,provider_uid,provider_open_id,provider_union_id,phone_number,bind_status,bind_time,last_used_time)
         values($1,$2,$3,$4,'','','','BOUND',now(),now())`,
        [this.nextId('idn'), session.userId, dto.providerType, providerUid]
      );
    }
    await this.audit.write('IDENTITY_BIND_SOCIAL', session.userId, { providerType: dto.providerType });
    return { bindResult: 'SUCCESS' };
  }

  async bindPhone(accessToken: string, dto: BindPhoneDto): Promise<unknown> {
    const session = await this.mustSession(accessToken);
    await this.verifyCode(dto.phoneNumber, dto.code);

    const hit = await this.pg.query(
      `select user_id from auth_identity where provider_type='PHONE' and phone_number=$1 and bind_status='BOUND' limit 1`,
      [dto.phoneNumber]
    );
    if (hit.rowCount > 0 && String(hit.rows[0].user_id) !== session.userId) {
      throw new BadRequestException('ACCOUNT_CONFLICT');
    }

    if (hit.rowCount === 0) {
      await this.pg.query(
        `insert into auth_identity(identity_id,user_id,provider_type,provider_uid,provider_open_id,provider_union_id,phone_number,bind_status,bind_time,last_used_time)
         values($1,$2,'PHONE',$3,'','',$3,'BOUND',now(),now())`,
        [this.nextId('idn'), session.userId, dto.phoneNumber]
      );
    }

    await this.pg.query(`update user_account set mobile_bind_time=now(), mobile_masked=$2 where user_id=$1`, [session.userId, this.maskPhone(dto.phoneNumber)]);
    await this.audit.write('IDENTITY_BIND_PHONE', session.userId, {});
    return { bindResult: 'SUCCESS' };
  }

  async unbind(accessToken: string, dto: UnbindDto): Promise<unknown> {
    const session = await this.mustSession(accessToken);
    const res = await this.pg.query(
      `select identity_id,provider_type from auth_identity where user_id=$1 and bind_status='BOUND'`,
      [session.userId]
    );

    const target = res.rows.find((x: Record<string, unknown>) => String(x.provider_type) === dto.providerType);
    if (!target) {
      throw new BadRequestException('IDENTITY_NOT_FOUND');
    }
    if (res.rowCount <= 1) {
      throw new BadRequestException('LAST_LOGIN_METHOD_CANNOT_UNBIND');
    }

    await this.pg.query(`update auth_identity set bind_status='UNBOUND' where identity_id=$1`, [target.identity_id]);
    await this.audit.write('IDENTITY_UNBIND', session.userId, { providerType: dto.providerType });
    return { unbindResult: 'SUCCESS' };
  }

  async logout(accessToken: string, dto: LogoutDto): Promise<unknown> {
    const session = await this.mustSession(accessToken);
    await this.pg.query(`update user_session set status='REVOKED' where user_id=$1 and session_id=$2`, [session.userId, dto.sessionId]);
    await this.audit.write('LOGOUT', session.userId, { sessionId: dto.sessionId });
    return { logoutResult: 'SUCCESS' };
  }

  async logoutAll(accessToken: string): Promise<unknown> {
    const session = await this.mustSession(accessToken);
    await this.pg.query(`update user_session set status='REVOKED' where user_id=$1`, [session.userId]);
    await this.audit.write('LOGOUT_ALL', session.userId, {});
    return { logoutAllResult: 'SUCCESS' };
  }

  async sessions(accessToken: string): Promise<unknown> {
    const current = await this.mustSession(accessToken);
    const res = await this.pg.query(
      `select session_id,device_name,platform,login_method,last_active_time from user_session where user_id=$1 and status='ACTIVE'`,
      [current.userId]
    );

    return res.rows.map((row: Record<string, unknown>) => {
      return {
        sessionId: row.session_id,
        deviceName: row.device_name,
        platform: row.platform,
        loginMethod: row.login_method,
        lastActiveTime: row.last_active_time,
        current: row.session_id === current.sessionId
      };
    });
  }

  async cancelRequest(accessToken: string, dto: CancelRequestDto): Promise<unknown> {
    const session = await this.mustSession(accessToken);
    if (!dto.reauthToken || dto.reauthToken.trim().length === 0) {
      throw new BadRequestException('REAUTH_REQUIRED');
    }
    await this.pg.query(`update user_account set status='CANCEL_PENDING' where user_id=$1`, [session.userId]);
    await this.audit.write('CANCEL_REQUEST', session.userId, { reason: dto.reason || '' });
    return { cancelStatus: 'PENDING' };
  }

  private async verifyCode(phoneNumber: string, code: string): Promise<void> {
    const res = await this.pg.query(
      `select code_id,code_hash,expired_at,verify_status from verification_code
       where phone_number=$1 order by created_at desc limit 1`,
      [phoneNumber]
    );

    if (res.rowCount === 0) {
      throw new BadRequestException('SMS_CODE_INVALID');
    }

    const row = res.rows[0] as Record<string, string | Date>;
    if (String(row.verify_status) !== 'PENDING') {
      throw new BadRequestException('SMS_CODE_INVALID');
    }

    if (new Date(String(row.expired_at)).getTime() <= Date.now()) {
      await this.pg.query(`update verification_code set verify_status='EXPIRED' where code_id=$1`, [row.code_id]);
      throw new BadRequestException('SMS_CODE_EXPIRED');
    }

    if (String(row.code_hash) !== code) {
      await this.risk.increaseCodeFailure(phoneNumber);
      throw new BadRequestException('SMS_CODE_INVALID');
    }

    await this.pg.query(`update verification_code set verify_status='USED' where code_id=$1`, [row.code_id]);
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

  private async rotateSessionToken(sessionId: string, userId: string, ip: string): Promise<{ accessToken: string; refreshToken: string; expireAt: string }> {
    const accessExpireAt = new Date(Date.now() + this.config.authAccessTtlSeconds * 1000);
    const refreshExpireAt = new Date(Date.now() + this.config.authRefreshTtlSeconds * 1000);

    const accessToken = jwt.sign({ userId, sessionId }, this.config.jwtSecret, { expiresIn: this.config.authAccessTtlSeconds });
    const refreshToken = jwt.sign({ userId, sessionId, kind: 'refresh' }, this.config.jwtSecret, { expiresIn: this.config.authRefreshTtlSeconds });

    await this.pg.query(
      `update user_session set access_token=$2,refresh_token=$3,expire_at=$4,refresh_expire_at=$5,last_active_time=now(),ip=$6
       where session_id=$1`,
      [sessionId, accessToken, refreshToken, accessExpireAt, refreshExpireAt, ip]
    );

    return {
      accessToken,
      refreshToken,
      expireAt: accessExpireAt.toISOString()
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
      defaultLoginMethod: String(row.default_login_method || '')
    };
  }

  private maskPhone(phone: string): string {
    if (!phone || phone.length < 7) {
      return phone;
    }
    return `${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}`;
  }

  private nextId(prefix: string): string {
    return `${prefix}_${Date.now()}_${Math.floor(Math.random() * 100000)}`;
  }
}
