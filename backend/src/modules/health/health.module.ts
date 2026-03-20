import { Module } from '@nestjs/common';
import { HealthController } from './health.controller';
import { AppConfigModule } from '../../config/app-config.module';

@Module({
  imports: [AppConfigModule],
  controllers: [HealthController]
})
export class HealthModule {}
