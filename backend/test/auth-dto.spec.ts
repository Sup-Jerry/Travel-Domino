import { validate } from 'class-validator';
import {
  DeviceInfoDto,
  GuestCreateDto,
  SocialCredentialDto,
  SocialLoginDto,
  UpdateAvatarDto,
  UpdateUsernameDto
} from '../src/modules/auth/dto/auth.dto';

describe('Auth DTO Validation', () => {
  const makeDeviceInfo = (): DeviceInfoDto =>
    Object.assign(new DeviceInfoDto(), {
      deviceId: 'device-001',
      deviceName: 'demo-phone',
      platform: 'ohos'
    });

  const makeCredential = (): SocialCredentialDto =>
    Object.assign(new SocialCredentialDto(), {
      openId: 'open-1',
      unionId: 'union-1'
    });

  it('normal: should pass validation for valid social login and avatar payloads', async () => {
    // Arrange
    const social = Object.assign(new SocialLoginDto(), {
      providerType: 'HUAWEI',
      credential: makeCredential(),
      deviceInfo: makeDeviceInfo()
    });
    const avatar = Object.assign(new UpdateAvatarDto(), {
      imageDataUrl: 'data:image/png;base64,AAAA',
      mimeType: 'image/png'
    });

    // Act
    const socialErrors = await validate(social);
    const avatarErrors = await validate(avatar);

    // Assert
    expect(socialErrors.length).toBe(0);
    expect(avatarErrors.length).toBe(0);
  });

  it('boundary: should allow optional social credential fields to be omitted', async () => {
    // Arrange
    const social = Object.assign(new SocialLoginDto(), {
      providerType: 'HUAWEI',
      credential: {},
      deviceInfo: makeDeviceInfo()
    });
    const avatar = Object.assign(new UpdateAvatarDto(), {
      imageDataUrl: 'data:image/jpeg;base64,BBBB'
    });

    // Act
    const socialErrors = await validate(social);
    const avatarErrors = await validate(avatar);

    // Assert
    expect(socialErrors.length).toBe(0);
    expect(avatarErrors.length).toBe(0);
  });

  it('invalid: should fail when username is empty', async () => {
    // Arrange
    const dto = Object.assign(new UpdateUsernameDto(), { username: '' });

    // Act
    const errors = await validate(dto);

    // Assert
    expect(errors.length).toBeGreaterThan(0);
    expect(errors[0].property).toBe('username');
  });

  it('conflict: should fail when credential and deviceInfo are non-object values', async () => {
    // Arrange
    const social = Object.assign(new SocialLoginDto(), {
      providerType: 'HUAWEI',
      credential: 'bad-credential' as unknown as SocialCredentialDto,
      deviceInfo: 'bad-device' as unknown as DeviceInfoDto
    });

    // Act
    const errors = await validate(social);
    const props = errors.map((e) => e.property);

    // Assert
    expect(errors.length).toBeGreaterThan(0);
    expect(props).toContain('credential');
    expect(props).toContain('deviceInfo');
  });

  it('regression: td-20260411-auth-dto-guest-create should require deviceInfo object', async () => {
    // Arrange
    const guest = Object.assign(new GuestCreateDto(), {
      deviceInfo: null as unknown as DeviceInfoDto
    });

    // Act
    const errors = await validate(guest);

    // Assert
    expect(errors.length).toBeGreaterThan(0);
    expect(errors[0].property).toBe('deviceInfo');
  });

  it('combined: should validate mixed dto set and isolate invalid items', async () => {
    // Arrange
    const validGuest = Object.assign(new GuestCreateDto(), { deviceInfo: makeDeviceInfo() });
    const invalidSocial = Object.assign(new SocialLoginDto(), {
      providerType: '',
      credential: makeCredential(),
      deviceInfo: makeDeviceInfo()
    });
    const invalidAvatar = Object.assign(new UpdateAvatarDto(), {
      imageDataUrl: ''
    });

    // Act
    const guestErrors = await validate(validGuest);
    const socialErrors = await validate(invalidSocial);
    const avatarErrors = await validate(invalidAvatar);

    // Assert
    expect(guestErrors.length).toBe(0);
    expect(socialErrors.length).toBeGreaterThan(0);
    expect(avatarErrors.length).toBeGreaterThan(0);
    expect(socialErrors[0].property).toBe('providerType');
    expect(avatarErrors[0].property).toBe('imageDataUrl');
  });

  it('boundary: should allow_social_login_with_access_token_only_credential', async () => {
    // Arrange
    // Act
    // Assert
    const social = Object.assign(new SocialLoginDto(), {
      providerType: 'HUAWEI',
      credential: Object.assign(new SocialCredentialDto(), {
        accessToken: 'access-token-only'
      }),
      deviceInfo: makeDeviceInfo()
    });

    const errors = await validate(social);

    expect(errors.length).toBe(0);
  });
});

