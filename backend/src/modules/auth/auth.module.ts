import { Module } from '@nestjs/common';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { SmsModule } from '../sms/sms.module';
import { SocialModule } from '../social/social.module';
import { RiskModule } from '../risk/risk.module';
import { AuditModule } from '../audit/audit.module';
import { AppConfigModule } from '../../config/app-config.module';

@Module({
  imports: [SmsModule, SocialModule, RiskModule, AuditModule, AppConfigModule],
  controllers: [AuthController],
  providers: [AuthService],
  exports: [AuthService]
})
export class AuthModule {}
