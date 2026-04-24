import { BadRequestException } from '@nestjs/common';
import { AuthService } from '../src/modules/auth/auth.service';

describe('unit_test_case_generator_branch_backfill_gf_backend', () => {
  const createService = (): AuthService =>
    new AuthService(
      {
        authAccessTtlSeconds: 3600,
        authRefreshTtlSeconds: 86400,
        jwtSecret: 'unit-test-secret'
      } as any,
      {
        query: jest.fn(),
        withTransaction: jest.fn()
      } as any
    );

  it('boundary: auth_service_username_should_trim_valid_text_and_keep_boundary_length', () => {
    const service = createService();
    const internals = service as unknown as {
      normalizeAndValidateUsername(rawValue: string): string;
    };
    const maxLengthName = 'a'.repeat(32);

    const trimmed = internals.normalizeAndValidateUsername('  travel_user  ');
    const boundary = internals.normalizeAndValidateUsername(maxLengthName);

    expect(trimmed).toBe('travel_user');
    expect(boundary).toBe(maxLengthName);
  });

  it('invalid: auth_service_username_should_reject_blank_overflow_and_illegal_character_values', () => {
    const service = createService();
    const internals = service as unknown as {
      normalizeAndValidateUsername(rawValue: string): string;
    };

    expect(() => internals.normalizeAndValidateUsername('   ')).toThrow(BadRequestException);
    expect(() => internals.normalizeAndValidateUsername('a'.repeat(33))).toThrow(BadRequestException);
    expect(() => internals.normalizeAndValidateUsername('bad#name')).toThrow(BadRequestException);
  });

  it('combined: auth_service_avatar_data_url_should_accept_supported_types_and_reject_invalid_variants', () => {
    const service = createService();
    const internals = service as unknown as {
      normalizeAndValidateAvatarDataUrl(rawDataUrl: string, rawMimeType: string): string;
    };

    const jpg = internals.normalizeAndValidateAvatarDataUrl('  data:image/jpeg;base64,abcd  ', ' IMAGE/JPG ');
    const png = internals.normalizeAndValidateAvatarDataUrl('data:image/png;base64,abcd', 'image/png');
    const webp = internals.normalizeAndValidateAvatarDataUrl('data:image/webp;base64,abcd', 'image/webp');

    expect(jpg).toBe('data:image/jpeg;base64,abcd');
    expect(png).toBe('data:image/png;base64,abcd');
    expect(webp).toBe('data:image/webp;base64,abcd');
    expect(() => internals.normalizeAndValidateAvatarDataUrl('data:text/plain;base64,abcd', 'image/png')).toThrow(BadRequestException);
    expect(() => internals.normalizeAndValidateAvatarDataUrl('data:image/png,abcd', 'image/png')).toThrow(BadRequestException);
    expect(() => internals.normalizeAndValidateAvatarDataUrl('data:image/png;base64,abcd', 'image/gif')).toThrow(BadRequestException);
  });

  it('combined: auth_service_provider_uid_should_follow_union_open_auth_idtoken_priority_and_trim_result', () => {
    const service = createService();
    const internals = service as unknown as {
      buildProviderUid(credential: {
        unionId?: string;
        openId?: string;
        authCode?: string;
        idToken?: string;
      }): string;
    };

    expect(internals.buildProviderUid({
      unionId: '  union-id  ',
      openId: 'open-id',
      authCode: 'auth-code',
      idToken: 'id-token'
    })).toBe('union-id');
    expect(internals.buildProviderUid({
      openId: '  open-id  ',
      authCode: 'auth-code',
      idToken: 'id-token'
    })).toBe('open-id');
    expect(internals.buildProviderUid({
      authCode: '  auth-code  ',
      idToken: 'id-token'
    })).toBe('auth-code');
    expect(internals.buildProviderUid({
      idToken: '  id-token  '
    })).toBe('id-token');
    expect(internals.buildProviderUid({
      unionId: ' ',
      openId: ' ',
      authCode: '',
      idToken: '   '
    })).toBe('');
  });
});
