import { Module } from '@nestjs/common';
import { RiskService } from './risk.service';
import { AppConfigModule } from '../../config/app-config.module';

@Module({
  imports: [AppConfigModule],
  providers: [RiskService],
  exports: [RiskService]
})
export class RiskModule {}
