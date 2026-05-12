import { BadRequestException, UnauthorizedException } from '@nestjs/common';
import * as jwt from 'jsonwebtoken';
import { AuthService } from '../src/modules/auth/auth.service';
import { GuestCreateDto, SocialLoginDto, UpdateAvatarDto } from '../src/modules/auth/dto/auth.dto';

type QueryRow = Record<string, string | boolean | Date>;

interface QueryResultLike {
  rowCount: number;
  rows: QueryRow[];
}

class PgServiceMock {
  private readonly queue: QueryResultLike[] = [];
  public readonly executed: Array<{ sql: string; params: unknown[] }> = [];

  enqueue(rowCount: number, rows: QueryRow[]): void {
    this.queue.push({ rowCount, rows });
  }

  async query(sql: string, params: unknown[] = []): Promise<QueryResultLike> {
    this.executed.push({ sql, params });
    const next = this.queue.shift();
    if (!next) {
      return { rowCount: 0, rows: [] };
    }
    return next;
  }

  async withTransaction<T>(worker: (query: (sql: string, params?: unknown[]) => Promise<QueryResultLike>) => Promise<T>): Promise<T> {
    return worker(this.query.bind(this));
  }
}

function createService(pg: PgServiceMock): AuthService {
  const config = {
    jwtSecret: 'test_secret',
    authAccessTtlSeconds: 3600,
    authRefreshTtlSeconds: 7200
  };
  return new AuthService(config as never, pg as never);
}

function makeAccessToken(userId: string, sessionId: string): string {
  return jwt.sign({ userId, sessionId }, 'test_secret', { expiresIn: 3600 });
}

function createSocialDto(providerType: string, authCode: string, openId: string = '', unionId: string = ''): SocialLoginDto {
  const dto = new SocialLoginDto();
  dto.providerType = providerType;
  dto.credential = {
    authCode,
    openId,
    unionId
  };
  dto.deviceInfo = {
    deviceId: 'd-1',
    deviceName: 'mate',
    platform: 'HarmonyOS'
  };
  return dto;
}

function createGuestDto(): GuestCreateDto {
  const dto = new GuestCreateDto();
  dto.deviceInfo = {
    deviceId: 'guest_device_1',
    deviceName: 'guest_phone',
    platform: 'HarmonyOS'
  };
  return dto;
}

function enqueueProfileSelect(pg: PgServiceMock, userId: string, status: string = 'ACTIVE'): void {
  pg.enqueue(1, [{
    account_id: 'acc_union_1',
    user_id: userId,
    nickname: 'nick_1',
    avatar_url: 'data:image/png;base64,abc',
    mobile_masked: '138****0000',
    profile_completed: true,
    is_guest: false,
    default_login_method: 'HUAWEI',
    status
  }]);
}

describe('auth_service_core_branch_cover', () => {
  it('normal: social_login_should_use_existing_identity_and_issue_session', async () => {
    // Arrange
    const pg = new PgServiceMock();
    const service = createService(pg);
    const dto = createSocialDto(' huawei ', '', 'open_1', 'union_1');

    pg.enqueue(1, [{ identity_id: 'idn_1', user_id: 'u_exist_1' }]);
    pg.enqueue(1, []);
    pg.enqueue(1, []);
    pg.enqueue(1, []);
    enqueueProfileSelect(pg, 'u_exist_1');

    // Act
    const result = await service.socialLogin(dto, '10.0.0.1') as { user: { userId: string; defaultLoginMethod: string } };

    // Assert
    expect(result.user.userId).toBe('u_exist_1');
    expect(result.user.defaultLoginMethod).toBe('HUAWEI');
    expect(String(pg.executed[0].params[0])).toBe('HUAWEI');
    expect(String(pg.executed[0].params[1])).toBe('union_1');
  });

  it('boundary: social_login_should_fallback_provider_uid_to_auth_code_when_union_and_open_missing', async () => {
    // Arrange
    const pg = new PgServiceMock();
    const service = createService(pg);
    const dto = createSocialDto('HUAWEI', '  code_x  ', '', '');

    pg.enqueue(0, []);
    pg.enqueue(1, []);
    pg.enqueue(1, []);
    pg.enqueue(1, []);
    pg.enqueue(1, []);
    enqueueProfileSelect(pg, 'u_new_1');

    // Act
    await service.socialLogin(dto, '127.0.0.1');

    // Assert
    expect(String(pg.executed[0].params[0])).toBe('HUAWEI');
    expect(String(pg.executed[0].params[1])).toBe('code_x');
  });

  it('invalid: social_login_should_throw_when_provider_or_uid_missing', async () => {
    // Arrange
    const pg = new PgServiceMock();
    const service = createService(pg);
    const invalidProviderDto = createSocialDto('', 'code_1');
    const invalidUidDto = createSocialDto('HUAWEI', '   ', '', '');

    // Act
    const providerPromise = service.socialLogin(invalidProviderDto, '');
    const uidPromise = service.socialLogin(invalidUidDto, '');

    // Assert
    await expect(providerPromise).rejects.toBeInstanceOf(BadRequestException);
    await expect(uidPromise).rejects.toBeInstanceOf(BadRequestException);
  });

  it('boundary: social_login_should_use_empty_credential_object_when_dto_credential_missing', async () => {
    const pg = new PgServiceMock();
    const service = createService(pg);
    const dto = {
      providerType: 'HUAWEI',
      deviceInfo: { deviceId: 'd-1', deviceName: 'mate', platform: 'HarmonyOS' }
    } as SocialLoginDto;

    await expect(service.socialLogin(dto, '')).rejects.toBeInstanceOf(BadRequestException);
  });

  it('boundary: social_login_should_support_id_token_as_provider_uid_source', async () => {
    const pg = new PgServiceMock();
    const service = createService(pg);
    const dto = createSocialDto('HUAWEI', '', '', '');
    dto.credential = { idToken: 'id-token-only' };

    pg.enqueue(0, []);
    pg.enqueue(1, []);
    pg.enqueue(1, []);
    pg.enqueue(1, []);
    pg.enqueue(1, []);
    enqueueProfileSelect(pg, 'u_id_token_1');

    const result = await service.socialLogin(dto, '127.0.0.1') as { user: { userId: string } };

    expect(result.user.userId.length > 0).toBe(true);
    expect(String(pg.executed[0].params[1])).toBe('id-token-only');
  });

  it('conflict: must_session_should_reject_inactive_or_expired_rows', async () => {
    // Arrange
    const pg = new PgServiceMock();
    const service = createService(pg);
    const internals = service as unknown as {
      mustSession(accessToken: string): Promise<{ userId: string; sessionId: string }>;
    };

    const inactiveToken = makeAccessToken('u_inactive', 's_inactive');
    pg.enqueue(1, [{ status: 'REVOKED', expire_at: new Date(Date.now() + 60_000).toISOString() }]);

    const expiredToken = makeAccessToken('u_expired', 's_expired');
    pg.enqueue(1, [{ status: 'ACTIVE', expire_at: new Date(Date.now() - 60_000).toISOString() }]);

    // Act
    const inactivePromise = internals.mustSession(`Bearer ${inactiveToken}`);
    const expiredPromise = internals.mustSession(`Bearer ${expiredToken}`);

    // Assert
    await expect(inactivePromise).rejects.toBeInstanceOf(UnauthorizedException);
    await expect(expiredPromise).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('regression: td-20260413-auth-service-update-avatar_should_accept_default_jpeg_mime_and_persist', async () => {
    // Arrange
    const pg = new PgServiceMock();
    const service = createService(pg);
    const token = makeAccessToken('u_avatar_1', 's_avatar_1');
    const dto = new UpdateAvatarDto();
    dto.imageDataUrl = 'data:image/jpeg;base64,abc';

    pg.enqueue(1, [{ status: 'ACTIVE', expire_at: new Date(Date.now() + 60_000).toISOString() }]);
    enqueueProfileSelect(pg, 'u_avatar_1');
    pg.enqueue(1, []);
    enqueueProfileSelect(pg, 'u_avatar_1');

    // Act
    const result = await service.updateAvatar(`Bearer ${token}`, dto) as { avatarUrl: string };

    // Assert
    expect(result.avatarUrl).toContain('data:image/png;base64,abc');
    expect(pg.executed.length >= 4).toBe(true);
  });

  it('combined: load_profile_should_block_risk_status_and_update_avatar_should_reject_invalid_payload', async () => {
    // Arrange
    const pg = new PgServiceMock();
    const service = createService(pg);
    const internals = service as unknown as {
      loadProfile(userId: string): Promise<unknown>;
    };
    pg.enqueue(1, [{
      account_id: '',
      user_id: 'u_risk_1',
      nickname: '',
      avatar_url: '',
      mobile_masked: '',
      profile_completed: false,
      is_guest: false,
      default_login_method: 'HUAWEI',
      status: 'LOCKED'
    }]);

    const avatarPg = new PgServiceMock();
    const avatarService = createService(avatarPg);
    const token = makeAccessToken('u_avatar_2', 's_avatar_2');
    const avatarDto = new UpdateAvatarDto();
    avatarDto.imageDataUrl = 'data:text/plain;base64,abc';
    avatarDto.mimeType = 'text/plain';

    avatarPg.enqueue(1, [{ status: 'ACTIVE', expire_at: new Date(Date.now() + 60_000).toISOString() }]);
    enqueueProfileSelect(avatarPg, 'u_avatar_2');

    // Act
    const riskPromise = internals.loadProfile('u_risk_1');
    const avatarPromise = avatarService.updateAvatar(`Bearer ${token}`, avatarDto);

    // Assert
    await expect(riskPromise).rejects.toBeInstanceOf(BadRequestException);
    await expect(avatarPromise).rejects.toBeInstanceOf(BadRequestException);
  });

  it('normal: guest_create_should_create_guest_user_and_return_session', async () => {
    // Arrange
    const pg = new PgServiceMock();
    const service = createService(pg);
    const dto = createGuestDto();
    pg.enqueue(1, []);
    pg.enqueue(1, []);
    pg.enqueue(1, []);
    enqueueProfileSelect(pg, 'guest_user_1');

    // Act
    const result = await service.guestCreate(dto, '192.168.1.1') as {
      user: { defaultLoginMethod: string };
      session: { accessToken: string; refreshToken: string; sessionId: string };
    };

    // Assert
    expect(result.user.defaultLoginMethod).toBe('HUAWEI');
    expect(result.session.accessToken.length > 0).toBe(true);
    expect(result.session.refreshToken.length > 0).toBe(true);
    expect(result.session.sessionId.startsWith('s_')).toBe(true);
  });

  it('boundary: me_should_strip_bearer_prefix_and_return_profile', async () => {
    // Arrange
    const pg = new PgServiceMock();
    const service = createService(pg);
    const token = makeAccessToken('u_me_1', 's_me_1');
    pg.enqueue(1, [{ status: 'ACTIVE', expire_at: new Date(Date.now() + 60_000).toISOString() }]);
    enqueueProfileSelect(pg, 'u_me_1');

    // Act
    const profile = await service.me(`Bearer ${token}`) as { userId: string; accountId: string };

    // Assert
    expect(profile.userId).toBe('u_me_1');
    expect(profile.accountId).toBe('acc_union_1');
  });

  it('invalid: update_avatar_should_reject_guest_user_even_when_payload_valid', async () => {
    // Arrange
    const pg = new PgServiceMock();
    const service = createService(pg);
    const token = makeAccessToken('u_guest_avatar', 's_guest_avatar');
    const dto = new UpdateAvatarDto();
    dto.imageDataUrl = 'data:image/png;base64,abc';
    dto.mimeType = 'image/png';
    pg.enqueue(1, [{ status: 'ACTIVE', expire_at: new Date(Date.now() + 60_000).toISOString() }]);
    pg.enqueue(1, [{
      account_id: '',
      user_id: 'u_guest_avatar',
      nickname: '',
      avatar_url: '',
      mobile_masked: '',
      profile_completed: false,
      is_guest: true,
      default_login_method: 'GUEST',
      status: 'ACTIVE'
    }]);

    // Act
    const promise = service.updateAvatar(`Bearer ${token}`, dto);

    // Assert
    await expect(promise).rejects.toBeInstanceOf(BadRequestException);
  });

  it('invalid: must_session_should_reject_empty_invalid_token_and_missing_session_row', async () => {
    // Arrange
    const pg = new PgServiceMock();
    const service = createService(pg);
    const internals = service as unknown as {
      mustSession(accessToken: string): Promise<{ userId: string; sessionId: string }>;
    };
    const signedToken = makeAccessToken('u_missing', 's_missing');
    pg.enqueue(0, []);

    // Act
    const emptyTokenPromise = internals.mustSession('Bearer   ');
    const invalidTokenPromise = internals.mustSession('Bearer not-a-jwt');
    const missingRowPromise = internals.mustSession(`Bearer ${signedToken}`);

    // Assert
    await expect(emptyTokenPromise).rejects.toBeInstanceOf(UnauthorizedException);
    await expect(invalidTokenPromise).rejects.toBeInstanceOf(UnauthorizedException);
    await expect(missingRowPromise).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('boundary: update_username_should_reject_blank_and_too_long_name', async () => {
    // Arrange
    const pg = new PgServiceMock();
    const service = createService(pg);
    const token = makeAccessToken('u_name_1', 's_name_1');
    const tooLong = 'a'.repeat(33);

    // Act
    pg.enqueue(1, [{ status: 'ACTIVE', expire_at: new Date(Date.now() + 60_000).toISOString() }]);
    enqueueProfileSelect(pg, 'u_name_1');
    const blankPromise = service.updateUsername(`Bearer ${token}`, { username: '   ' });

    pg.enqueue(1, [{ status: 'ACTIVE', expire_at: new Date(Date.now() + 60_000).toISOString() }]);
    enqueueProfileSelect(pg, 'u_name_1');
    const tooLongPromise = service.updateUsername(`Bearer ${token}`, { username: tooLong });

    // Assert
    await expect(blankPromise).rejects.toBeInstanceOf(BadRequestException);
    await expect(tooLongPromise).rejects.toBeInstanceOf(BadRequestException);
  });

  it('invalid: load_profile_should_throw_account_not_found_when_row_missing', async () => {
    // Arrange
    const pg = new PgServiceMock();
    const service = createService(pg);
    const internals = service as unknown as {
      loadProfile(userId: string): Promise<unknown>;
    };
    pg.enqueue(0, []);

    // Act
    const promise = internals.loadProfile('u_not_found');

    // Assert
    await expect(promise).rejects.toBeInstanceOf(BadRequestException);
  });

  it('combined: update_avatar_should_reject_empty_non_image_or_non_base64_data_url', async () => {
    // Arrange
    const tokenA = makeAccessToken('u_avatar_3', 's_avatar_3');
    const tokenB = makeAccessToken('u_avatar_4', 's_avatar_4');
    const tokenC = makeAccessToken('u_avatar_5', 's_avatar_5');

    const pgA = new PgServiceMock();
    const serviceA = createService(pgA);
    const dtoA = new UpdateAvatarDto();
    dtoA.imageDataUrl = '';
    dtoA.mimeType = 'image/jpeg';
    pgA.enqueue(1, [{ status: 'ACTIVE', expire_at: new Date(Date.now() + 60_000).toISOString() }]);
    enqueueProfileSelect(pgA, 'u_avatar_3');

    const pgB = new PgServiceMock();
    const serviceB = createService(pgB);
    const dtoB = new UpdateAvatarDto();
    dtoB.imageDataUrl = 'data:text/plain;base64,abc';
    dtoB.mimeType = 'image/png';
    pgB.enqueue(1, [{ status: 'ACTIVE', expire_at: new Date(Date.now() + 60_000).toISOString() }]);
    enqueueProfileSelect(pgB, 'u_avatar_4');

    const pgC = new PgServiceMock();
    const serviceC = createService(pgC);
    const dtoC = new UpdateAvatarDto();
    dtoC.imageDataUrl = 'data:image/png,abc';
    dtoC.mimeType = 'image/png';
    pgC.enqueue(1, [{ status: 'ACTIVE', expire_at: new Date(Date.now() + 60_000).toISOString() }]);
    enqueueProfileSelect(pgC, 'u_avatar_5');

    // Act
    const emptyPromise = serviceA.updateAvatar(`Bearer ${tokenA}`, dtoA);
    const nonImagePromise = serviceB.updateAvatar(`Bearer ${tokenB}`, dtoB);
    const nonBase64Promise = serviceC.updateAvatar(`Bearer ${tokenC}`, dtoC);

    // Assert
    await expect(emptyPromise).rejects.toBeInstanceOf(BadRequestException);
    await expect(nonImagePromise).rejects.toBeInstanceOf(BadRequestException);
    await expect(nonBase64Promise).rejects.toBeInstanceOf(BadRequestException);
  });

  it('regression: social_login_should_wrap_unknown_query_failure_with_internal_phase_code', async () => {
    const pg = new PgServiceMock();
    const service = createService(pg);
    const dto = createSocialDto('HUAWEI', '', 'open_x', '');

    pg.enqueue(1, [{ identity_id: 'idn_1', user_id: 'u_exist_1' }]);
    pg.query = jest.fn()
      .mockResolvedValueOnce({ rowCount: 1, rows: [{ identity_id: 'idn_1', user_id: 'u_exist_1' }] })
      .mockRejectedValueOnce(new Error('db_down')) as never;

    await expect(service.socialLogin(dto, '127.0.0.1')).rejects.toThrow('social_login_internal_update_identity');
  });

  it('regression: social_login_should_map_non_error_failures_to_unknown_reason', async () => {
    const pg = new PgServiceMock();
    const service = createService(pg);
    const dto = createSocialDto('HUAWEI', '', 'open_primitive', '');
    pg.query = jest.fn()
      .mockResolvedValueOnce({ rowCount: 1, rows: [{ identity_id: 'idn_1', user_id: 'u_exist_1' }] })
      .mockRejectedValueOnce('primitive_failure') as never;

    await expect(service.socialLogin(dto, '127.0.0.1')).rejects.toThrow('social_login_internal_update_identity');
  });

  it('boundary: issue_session_should_use_default_pg_executor_when_query_executor_missing', async () => {
    const pg = new PgServiceMock();
    const service = createService(pg);
    const internals = service as unknown as {
      issueSession(
        userId: string,
        deviceId: string,
        deviceName: string,
        platform: string,
        loginMethod: string,
        ip: string
      ): Promise<{ accessToken: string; refreshToken: string; expireAt: string; sessionId: string }>;
    };
    pg.enqueue(1, []);

    const result = await internals.issueSession('u_issue_1', 'device_1', 'mate', 'HarmonyOS', 'HUAWEI', '10.0.0.1');

    expect(result.sessionId.startsWith('s_')).toBe(true);
    expect(result.accessToken.length > 0).toBe(true);
    expect(result.refreshToken.length > 0).toBe(true);
    expect(pg.executed).toHaveLength(1);
    expect(pg.executed[0].sql).toContain('insert into user_session');
  });

  it('boundary: load_profile_should_fallback_default_login_method_to_guest_when_row_empty', async () => {
    const pg = new PgServiceMock();
    const service = createService(pg);
    const internals = service as unknown as {
      loadProfile(userId: string): Promise<{ defaultLoginMethod: string; accountId: string }>;
    };
    pg.enqueue(1, [{
      account_id: '',
      user_id: 'u_guest_default',
      nickname: '',
      avatar_url: '',
      mobile_masked: '',
      profile_completed: false,
      is_guest: false,
      default_login_method: '',
      status: 'ACTIVE'
    }]);

    const profile = await internals.loadProfile('u_guest_default');

    expect(profile.defaultLoginMethod).toBe('GUEST');
    expect(profile.accountId).toBe('');
  });

  it('boundary: social_login_should_fallback_empty_identity_fields_when_existing_row_has_blanks', async () => {
    const pg = new PgServiceMock();
    const service = createService(pg);
    const dto = createSocialDto('HUAWEI', '', 'open_blank', '');

    pg.enqueue(1, [{ identity_id: '', user_id: '' }]);
    pg.enqueue(1, []);
    pg.enqueue(1, []);
    pg.enqueue(1, []);
    pg.enqueue(1, [{
      account_id: '',
      user_id: '',
      nickname: '',
      avatar_url: '',
      mobile_masked: '',
      profile_completed: false,
      is_guest: false,
      default_login_method: '',
      status: 'ACTIVE'
    }]);

    const result = await service.socialLogin(dto, '127.0.0.1') as { user: { defaultLoginMethod: string } };

    expect(result.user.defaultLoginMethod).toBe('GUEST');
    expect(String(pg.executed[1].params?.[0] || '')).toBe('');
    expect(String(pg.executed[1].params?.[2] || '')).toBe('');
    expect(String(pg.executed[2].params?.[0] || '')).toBe('');
  });

  it('boundary: social_login_should_fallback_open_id_to_empty_string_when_existing_identity_updates', async () => {
    const pg = new PgServiceMock();
    const service = createService(pg);
    const dto = createSocialDto('HUAWEI', 'code_only', '', 'union_keep');

    pg.enqueue(1, [{ identity_id: 'idn_open_fallback', user_id: 'u_open_fallback' }]);
    pg.enqueue(1, []);
    pg.enqueue(1, []);
    pg.enqueue(1, []);
    enqueueProfileSelect(pg, 'u_open_fallback');

    const result = await service.socialLogin(dto, '127.0.0.1') as { user: { userId: string } };

    expect(result.user.userId).toBe('u_open_fallback');
    expect(String(pg.executed[1].params?.[1] || '')).toBe('');
    expect(String(pg.executed[1].params?.[2] || '')).toBe('union_keep');
  });

  it('invalid: update_username_should_reject_illegal_characters', async () => {
    const pg = new PgServiceMock();
    const service = createService(pg);
    const token = makeAccessToken('u_name_2', 's_name_2');

    pg.enqueue(1, [{ status: 'ACTIVE', expire_at: new Date(Date.now() + 60_000).toISOString() }]);
    enqueueProfileSelect(pg, 'u_name_2');

    await expect(service.updateUsername(`Bearer ${token}`, { username: 'bad#name' })).rejects.toBeInstanceOf(BadRequestException);
  });

  it('boundary: username_and_avatar_internal_normalizers_should_fallback_when_raw_value_or_mime_missing', () => {
    const service = createService(new PgServiceMock());
    const internals = service as unknown as {
      normalizeAndValidateUsername(rawValue: string | undefined): string;
      normalizeAndValidateAvatarDataUrl(rawDataUrl: string, rawMimeType: string | undefined): string;
      buildProviderUid(credential: {
        unionId?: string;
        openId?: string;
        authCode?: string;
        idToken?: string;
      }): string;
    };

    expect(() => internals.normalizeAndValidateUsername(undefined)).toThrow(BadRequestException);
    expect(internals.normalizeAndValidateAvatarDataUrl('data:image/png;base64,abcd', undefined)).toBe('data:image/png;base64,abcd');
    expect(internals.buildProviderUid({})).toBe('');
  });

  it('combined: update_avatar_should_accept_webp_and_reject_oversized_payload', async () => {
    const validPg = new PgServiceMock();
    const validService = createService(validPg);
    const validToken = makeAccessToken('u_avatar_webp', 's_avatar_webp');
    const validDto = new UpdateAvatarDto();
    validDto.imageDataUrl = 'data:image/webp;base64,abcd';
    validDto.mimeType = 'image/webp';
    validPg.enqueue(1, [{ status: 'ACTIVE', expire_at: new Date(Date.now() + 60_000).toISOString() }]);
    enqueueProfileSelect(validPg, 'u_avatar_webp');
    validPg.enqueue(1, []);
    enqueueProfileSelect(validPg, 'u_avatar_webp');

    const invalidPg = new PgServiceMock();
    const invalidService = createService(invalidPg);
    const invalidToken = makeAccessToken('u_avatar_big', 's_avatar_big');
    const invalidDto = new UpdateAvatarDto();
    invalidDto.imageDataUrl = `data:image/png;base64,${'a'.repeat(3_500_001)}`;
    invalidDto.mimeType = 'image/png';
    invalidPg.enqueue(1, [{ status: 'ACTIVE', expire_at: new Date(Date.now() + 60_000).toISOString() }]);
    enqueueProfileSelect(invalidPg, 'u_avatar_big');

    const validResult = await validService.updateAvatar(`Bearer ${validToken}`, validDto) as { avatarUrl: string };
    const invalidPromise = invalidService.updateAvatar(`Bearer ${invalidToken}`, invalidDto);

    expect(validResult.avatarUrl).toContain('data:image/png;base64,abc');
    await expect(invalidPromise).rejects.toBeInstanceOf(BadRequestException);
  });

  it('boundary: issue_session_and_load_profile_should_use_default_executor_fallbacks', async () => {
    const pg = new PgServiceMock();
    const service = createService(pg);
    const internals = service as unknown as {
      issueSession(
        userId: string,
        deviceId: string,
        deviceName: string,
        platform: string,
        loginMethod: string,
        ip: string,
        queryExecutor: undefined
      ): Promise<{ sessionId: string }>;
      loadProfile(
        userId: string,
        queryExecutor: undefined
      ): Promise<{ userId: string; defaultLoginMethod: string }>;
    };
    pg.enqueue(1, []);
    enqueueProfileSelect(pg, 'u_default_executor');

    const session = await internals.issueSession(
      'u_default_executor',
      'device_default',
      'mate',
      'HarmonyOS',
      'HUAWEI',
      '10.0.0.2',
      undefined
    );
    const profile = await internals.loadProfile('u_default_executor', undefined);

    expect(session.sessionId.startsWith('s_')).toBe(true);
    expect(profile.userId).toBe('u_default_executor');
    expect(profile.defaultLoginMethod).toBe('HUAWEI');
    expect(pg.executed[0].sql).toContain('insert into user_session');
    expect(pg.executed[1].sql).toContain('from user_account ua');
  });
});
