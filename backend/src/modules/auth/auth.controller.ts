import { Body, Controller, Get, Headers, Ip, Logger, Patch, Post } from '@nestjs/common';
import { AuthService } from './auth.service';
import { GuestCreateDto, SocialLoginDto, UpdateAvatarDto, UpdateUsernameDto } from './dto/auth.dto';

@Controller('auth')
export class AuthController {
  private readonly logger = new Logger(AuthController.name);

  constructor(private readonly authService: AuthService) {}

  @Post('guest/create')
  async guestCreate(@Body() dto: GuestCreateDto, @Ip() ip: string): Promise<unknown> {
    this.logger.log(`[airest]AI_BACKEND_TRACE[auth_guest_create_in] ip=${ip || ''}, deviceIdLen=${(dto.deviceInfo?.deviceId || '').length}`);
    return this.authService.guestCreate(dto, ip || '');
  }

  @Post('social/login')
  async socialLogin(@Body() dto: SocialLoginDto, @Ip() ip: string): Promise<unknown> {
    const provider = dto.providerType || '';
    this.logger.log(
      `[airest]AI_BACKEND_TRACE[auth_social_login_in] provider=${provider}, ip=${ip || ''}, hasAuthCode=${dto.credential?.authCode ? 1 : 0}, hasOpenId=${dto.credential?.openId ? 1 : 0}, hasUnionId=${dto.credential?.unionId ? 1 : 0}`
    );
    try {
      const result = await this.authService.socialLogin(dto, ip || '');
      this.logger.log(`[airest]AI_BACKEND_TRACE[auth_social_login_ok] provider=${provider}`);
      return result;
    } catch (error) {
      const reason = error instanceof Error ? error.message : 'unknown';
      this.logger.error(`[airest]AI_BACKEND_TRACE[auth_social_login_fail] provider=${provider}, reason=${reason}`);
      throw error;
    }
  }

  @Get('me')
  async me(@Headers('authorization') authHeader: string): Promise<unknown> {
    this.logger.log(`[airest]AI_BACKEND_TRACE[auth_me_in] hasAuthHeader=${authHeader ? 1 : 0}`);
    return this.authService.me(authHeader || '');
  }

  @Patch('profile/username')
  async updateUsername(
    @Body() dto: UpdateUsernameDto,
    @Headers('authorization') authHeader: string
  ): Promise<unknown> {
    return this.authService.updateUsername(authHeader || '', dto);
  }

  @Patch('profile/avatar')
  async updateAvatar(
    @Body() dto: UpdateAvatarDto,
    @Headers('authorization') authHeader: string
  ): Promise<unknown> {
    return this.authService.updateAvatar(authHeader || '', dto);
  }

  @Post('profile/avatar')
  async updateAvatarPost(
    @Body() dto: UpdateAvatarDto,
    @Headers('authorization') authHeader: string
  ): Promise<unknown> {
    return this.authService.updateAvatar(authHeader || '', dto);
  }

  @Post('profile/username')
  async updateUsernameCompat(
    @Body() dto: UpdateUsernameDto,
    @Headers('authorization') authHeader: string
  ): Promise<unknown> {
    return this.authService.updateUsername(authHeader || '', dto);
  }
}

