import { validate } from 'class-validator';
import {
  DeviceInfoDto,
  GuestCreateDto,
  SocialCredentialDto,
  SocialLoginDto,
  UpdateAvatarDto
} from '../src/modules/auth/dto/auth.dto';
import { SocialService } from '../src/modules/social/social.service';

describe('unit_test_case_generator_branch_backfill_ge_backend', () => {
  const makeDeviceInfo = (): DeviceInfoDto =>
    Object.assign(new DeviceInfoDto(), {
      deviceId: 'device-001',
      deviceName: 'demo-phone',
      platform: 'ohos'
    });

  it('boundary: auth_dto_should_accept_social_credential_with_single_optional_access_token', async () => {
    const credential = Object.assign(new SocialCredentialDto(), {
      accessToken: 'access-only'
    });

    const errors = await validate(credential);

    expect(errors.length).toBe(0);
  });

  it('invalid: auth_dto_should_reject_missing_device_info_and_empty_avatar_data', async () => {
    const guest = Object.assign(new GuestCreateDto(), {
      deviceInfo: null as unknown as DeviceInfoDto
    });
    const social = Object.assign(new SocialLoginDto(), {
      providerType: 'HUAWEI',
      credential: Object.assign(new SocialCredentialDto(), {}),
      deviceInfo: null as unknown as DeviceInfoDto
    });
    const avatar = Object.assign(new UpdateAvatarDto(), {
      imageDataUrl: ''
    });

    const guestErrors = await validate(guest);
    const socialErrors = await validate(social);
    const avatarErrors = await validate(avatar);

    expect(guestErrors.length).toBeGreaterThan(0);
    expect(socialErrors.length).toBeGreaterThan(0);
    expect(avatarErrors.length).toBeGreaterThan(0);
  });

  it('combined: social_service_should_trim_union_open_auth_and_idtoken_fallbacks', async () => {
    const service = new SocialService();

    const union = await service.verifyCredential('WX', {
      unionId: '  union-id  ',
      openId: 'open-id',
      authCode: 'auth-code',
      idToken: 'id-token'
    });
    const open = await service.verifyCredential('HW', {
      openId: '  open-id  ',
      authCode: 'auth-code'
    });
    const auth = await service.verifyCredential('QQ', {
      authCode: '  auth-code  ',
      idToken: 'id-token'
    });
    const idToken = await service.verifyCredential('GC', {
      idToken: '  id-token  '
    });

    expect(union).toBe('WX:union-id');
    expect(open).toBe('HW:open-id');
    expect(auth).toBe('QQ:auth-code');
    expect(idToken).toBe('GC:id-token');
  });

  it('combined: social_service_should_return_empty_when_all_priority_fields_are_blank_after_trim', async () => {
    const service = new SocialService();

    const result = await service.verifyCredential('NONE', {
      unionId: '   ',
      openId: '   ',
      authCode: ' ',
      idToken: ''
    });

    expect(result).toBe('');
  });

  it('boundary: auth_dto_should_allow_nested_device_info_object_with_valid_strings', async () => {
    const guest = Object.assign(new GuestCreateDto(), {
      deviceInfo: makeDeviceInfo()
    });
    const social = Object.assign(new SocialLoginDto(), {
      providerType: 'QQ',
      credential: Object.assign(new SocialCredentialDto(), {
        idToken: 'token-only'
      }),
      deviceInfo: makeDeviceInfo()
    });

    const guestErrors = await validate(guest);
    const socialErrors = await validate(social);

    expect(guestErrors.length).toBe(0);
    expect(socialErrors.length).toBe(0);
  });
});
