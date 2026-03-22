import { Body, Controller, Get, Headers, Ip, Post } from '@nestjs/common';
import { AuthService } from './auth.service';
import { GuestCreateDto } from './dto/auth.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('guest/create')
  async guestCreate(@Body() dto: GuestCreateDto, @Ip() ip: string): Promise<unknown> {
    return this.authService.guestCreate(dto, ip || '');
  }

  @Get('me')
  async me(@Headers('authorization') authHeader: string): Promise<unknown> {
    return this.authService.me(authHeader || '');
  }
}
