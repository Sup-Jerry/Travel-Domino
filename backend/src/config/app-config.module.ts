import { Module } from '@nestjs/common';
import { AppConfigService } from './app-config.service';
import { PgService } from './pg.service';

@Module({
  providers: [AppConfigService, PgService],
  exports: [AppConfigService, PgService]
})
export class AppConfigModule {}
