import { Body, Controller, Get, Headers, Ip, Post, Req } from '@nestjs/common';
import { Request } from 'express';
import { AuthService } from './auth.service';
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

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('phone/send-code')
  async sendCode(@Body() dto: SendCodeDto, @Ip() ip: string, @Req() req: Request): Promise<unknown> {
    return this.authService.sendCode(dto, ip || '', String(req.headers['x-device-id'] || 'unknown'));
  }

  @Post('phone/login')
  async phoneLogin(@Body() dto: PhoneLoginDto, @Ip() ip: string): Promise<unknown> {
    return this.authService.phoneLogin(dto, ip || '');
  }

  @Post('social/login')
  async socialLogin(@Body() dto: SocialLoginDto, @Ip() ip: string): Promise<unknown> {
    return this.authService.socialLogin(dto, ip || '');
  }

  @Post('social/create-account')
  async socialCreate(@Body() dto: SocialCreateAccountDto, @Ip() ip: string): Promise<unknown> {
    return this.authService.socialCreateAccount(dto, ip || '');
  }

  @Post('social/bind-existing-phone')
  async socialBindExisting(@Body() dto: SocialBindExistingPhoneDto, @Ip() ip: string): Promise<unknown> {
    return this.authService.socialBindExistingPhone(dto, ip || '');
  }

  @Post('guest/create')
  async guestCreate(@Body() dto: GuestCreateDto, @Ip() ip: string): Promise<unknown> {
    return this.authService.guestCreate(dto, ip || '');
  }

  @Post('guest/upgrade')
  async guestUpgrade(@Body() dto: GuestUpgradeDto): Promise<unknown> {
    return this.authService.guestUpgrade(dto);
  }

  @Post('session/refresh')
  async refresh(@Body() dto: RefreshSessionDto, @Ip() ip: string): Promise<unknown> {
    return this.authService.refresh(dto, ip || '');
  }

  @Get('me')
  async me(@Headers('authorization') authHeader: string): Promise<unknown> {
    return this.authService.me(authHeader || '');
  }

  @Get('identities')
  async identities(@Headers('authorization') authHeader: string): Promise<unknown> {
    return this.authService.identities(authHeader || '');
  }

  @Post('identities/bind/social')
  async bindSocial(@Headers('authorization') authHeader: string, @Body() dto: BindSocialDto): Promise<unknown> {
    return this.authService.bindSocial(authHeader || '', dto);
  }

  @Post('identities/bind/phone')
  async bindPhone(@Headers('authorization') authHeader: string, @Body() dto: BindPhoneDto): Promise<unknown> {
    return this.authService.bindPhone(authHeader || '', dto);
  }

  @Post('identities/unbind')
  async unbind(@Headers('authorization') authHeader: string, @Body() dto: UnbindDto): Promise<unknown> {
    return this.authService.unbind(authHeader || '', dto);
  }

  @Post('logout')
  async logout(@Headers('authorization') authHeader: string, @Body() dto: LogoutDto): Promise<unknown> {
    return this.authService.logout(authHeader || '', dto);
  }

  @Post('logout-all')
  async logoutAll(@Headers('authorization') authHeader: string): Promise<unknown> {
    return this.authService.logoutAll(authHeader || '');
  }

  @Get('sessions')
  async sessions(@Headers('authorization') authHeader: string): Promise<unknown> {
    return this.authService.sessions(authHeader || '');
  }

  @Post('cancel/request')
  async cancelRequest(@Headers('authorization') authHeader: string, @Body() dto: CancelRequestDto): Promise<unknown> {
    return this.authService.cancelRequest(authHeader || '', dto);
  }
}
