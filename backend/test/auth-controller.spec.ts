import { AuthController } from '../src/modules/auth/auth.controller';
import { GuestCreateDto, SocialLoginDto, UpdateAvatarDto, UpdateUsernameDto } from '../src/modules/auth/dto/auth.dto';

describe('AuthController', () => {
  const buildController = () => {
    const authService = {
      guestCreate: jest.fn(),
      socialLogin: jest.fn(),
      me: jest.fn(),
      updateUsername: jest.fn(),
      updateAvatar: jest.fn()
    };
    return {
      controller: new AuthController(authService as any),
      authService
    };
  };

  it('normal: guestCreate should delegate dto and ip to service', async () => {
    // Arrange
    const { controller, authService } = buildController();
    const dto: GuestCreateDto = {
      deviceInfo: {
        deviceId: 'd-001',
        deviceName: 'pixel',
        platform: 'android'
      }
    };
    const expected = { ok: true, source: 'guestCreate' };
    authService.guestCreate.mockResolvedValue(expected);

    // Act
    const result = await controller.guestCreate(dto, '10.0.0.1');

    // Assert
    expect(authService.guestCreate).toHaveBeenCalledWith(dto, '10.0.0.1');
    expect(result).toEqual(expected);
  });

  it('boundary: guestCreate should fallback device_id_length_to_zero_when_missing', async () => {
    const { controller, authService } = buildController();
    const dto = {
      deviceInfo: {
        deviceName: 'pixel',
        platform: 'android'
      }
    } as GuestCreateDto;
    authService.guestCreate.mockResolvedValue({ ok: 'guest-missing-device' });

    const result = await controller.guestCreate(dto, '');

    expect(authService.guestCreate).toHaveBeenCalledWith(dto, '');
    expect(result).toEqual({ ok: 'guest-missing-device' });
  });

  it('boundary: me should fallback to empty authorization when header missing', async () => {
    // Arrange
    const { controller, authService } = buildController();
    authService.me.mockResolvedValue({ ok: true });

    // Act
    await controller.me(undefined as unknown as string);

    // Assert
    expect(authService.me).toHaveBeenCalledWith('');
  });

  it('boundary: me should preserve non_empty_authorization_header', async () => {
    const { controller, authService } = buildController();
    authService.me.mockResolvedValue({ ok: 'with-header' });

    const result = await controller.me('Bearer token-x');

    expect(authService.me).toHaveBeenCalledWith('Bearer token-x');
    expect(result).toEqual({ ok: 'with-header' });
  });

  it('invalid: socialLogin should propagate service rejection', async () => {
    // Arrange
    const { controller, authService } = buildController();
    const dto: SocialLoginDto = {
      providerType: 'HUAWEI',
      credential: { openId: 'open-1' },
      deviceInfo: { deviceId: 'd', deviceName: 'n', platform: 'p' }
    };
    const expectedError = new Error('THIRD_PARTY_AUTH_FAILED');
    authService.socialLogin.mockRejectedValue(expectedError);

    // Act
    const run = async () => controller.socialLogin(dto, '127.0.0.1');

    // Assert
    await expect(run()).rejects.toThrow('THIRD_PARTY_AUTH_FAILED');
  });

  it('boundary: socialLogin should log truthy auth_code_open_id_and_union_id_branches', async () => {
    const { controller, authService } = buildController();
    const dto: SocialLoginDto = {
      providerType: 'HUAWEI',
      credential: { authCode: 'ac', openId: 'op', unionId: 'un' },
      deviceInfo: { deviceId: 'd', deviceName: 'n', platform: 'p' }
    };
    authService.socialLogin.mockResolvedValue({ ok: 'all-credential-flags' });

    const result = await controller.socialLogin(dto, '127.0.0.1');

    expect(authService.socialLogin).toHaveBeenCalledWith(dto, '127.0.0.1');
    expect(result).toEqual({ ok: 'all-credential-flags' });
  });

  it('conflict: patch and compat username endpoints should map to same service contract', async () => {
    // Arrange
    const { controller, authService } = buildController();
    const dto: UpdateUsernameDto = { username: 'traveler_01' };
    authService.updateUsername.mockResolvedValue({ ok: true });

    // Act
    await controller.updateUsername(dto, 'Bearer A');
    await controller.updateUsernameCompat(dto, 'Bearer B');

    // Assert
    expect(authService.updateUsername).toHaveBeenNthCalledWith(1, 'Bearer A', dto);
    expect(authService.updateUsername).toHaveBeenNthCalledWith(2, 'Bearer B', dto);
    expect(authService.updateUsername).toHaveBeenCalledTimes(2);
  });

  it('boundary: updateUsername should fallback to empty authorization when header missing', async () => {
    const { controller, authService } = buildController();
    const dto: UpdateUsernameDto = { username: 'fallback_name' };
    authService.updateUsername.mockResolvedValue({ ok: 'username-fallback' });

    const result = await controller.updateUsername(dto, undefined as unknown as string);

    expect(authService.updateUsername).toHaveBeenCalledWith('', dto);
    expect(result).toEqual({ ok: 'username-fallback' });
  });

  it('regression: td-20260411-auth-controller-avatar-post-compat should route to updateAvatar service', async () => {
    // Arrange
    const { controller, authService } = buildController();
    const dto: UpdateAvatarDto = {
      imageDataUrl: 'data:image/png;base64,AAAA',
      mimeType: 'image/png'
    };
    authService.updateAvatar.mockResolvedValue({ ok: true });

    // Act
    await controller.updateAvatarPost(dto, undefined as unknown as string);

    // Assert
    expect(authService.updateAvatar).toHaveBeenCalledWith('', dto);
  });

  it('boundary: updateAvatar should fallback to empty authorization when header missing', async () => {
    const { controller, authService } = buildController();
    const dto: UpdateAvatarDto = {
      imageDataUrl: 'data:image/png;base64,BBBB',
      mimeType: 'image/png'
    };
    authService.updateAvatar.mockResolvedValue({ ok: true });

    const result = await controller.updateAvatar(dto, undefined as unknown as string);

    expect(authService.updateAvatar).toHaveBeenCalledWith('', dto);
    expect(result).toEqual({ ok: true });
  });

  it('conflict: socialLogin should rethrow non-error rejection with empty provider fallback', async () => {
    const { controller, authService } = buildController();
    const dto = {
      providerType: '',
      credential: {},
      deviceInfo: { deviceId: 'd', deviceName: 'n', platform: 'p' }
    } as SocialLoginDto;
    authService.socialLogin.mockRejectedValue('raw_failure');

    await expect(controller.socialLogin(dto, undefined as unknown as string)).rejects.toBe('raw_failure');
  });

  it('boundary: updateUsernameCompat should fallback to empty authorization when header missing', async () => {
    const { controller, authService } = buildController();
    const dto: UpdateUsernameDto = { username: 'compat_name' };
    authService.updateUsername.mockResolvedValue({ ok: 'compat' });

    const result = await controller.updateUsernameCompat(dto, undefined as unknown as string);

    expect(authService.updateUsername).toHaveBeenCalledWith('', dto);
    expect(result).toEqual({ ok: 'compat' });
  });

  it('combined: should apply header/ip fallbacks across guest-social-me flow', async () => {
    // Arrange
    const { controller, authService } = buildController();
    const guestDto: GuestCreateDto = {
      deviceInfo: { deviceId: 'd1', deviceName: 'phone', platform: 'ios' }
    };
    const socialDto: SocialLoginDto = {
      providerType: 'HUAWEI',
      credential: { unionId: 'u-1' },
      deviceInfo: { deviceId: 'd2', deviceName: 'pad', platform: 'ios' }
    };
    authService.guestCreate.mockResolvedValue({ step: 'guest' });
    authService.socialLogin.mockResolvedValue({ step: 'social' });
    authService.me.mockResolvedValue({ step: 'me' });

    // Act
    const guestResult = await controller.guestCreate(guestDto, undefined as unknown as string);
    const socialResult = await controller.socialLogin(socialDto, undefined as unknown as string);
    const meResult = await controller.me(undefined as unknown as string);

    // Assert
    expect(authService.guestCreate).toHaveBeenCalledWith(guestDto, '');
    expect(authService.socialLogin).toHaveBeenCalledWith(socialDto, '');
    expect(authService.me).toHaveBeenCalledWith('');
    expect(guestResult).toEqual({ step: 'guest' });
    expect(socialResult).toEqual({ step: 'social' });
    expect(meResult).toEqual({ step: 'me' });
  });
});

