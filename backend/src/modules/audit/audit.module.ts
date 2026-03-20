import { Module } from '@nestjs/common';
import { AuditService } from './audit.service';
import { AppConfigModule } from '../../config/app-config.module';

@Module({
  imports: [AppConfigModule],
  providers: [AuditService],
  exports: [AuditService]
})
export class AuditModule {}
