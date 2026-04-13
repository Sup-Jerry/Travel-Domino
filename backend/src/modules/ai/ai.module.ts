import { Module } from '@nestjs/common';
import { AppConfigModule } from '../../config/app-config.module';
import { AiController } from './ai.controller';
import { AiService } from './ai.service';

@Module({
  imports: [AppConfigModule],
  controllers: [AiController],
  providers: [AiService]
})
export class AiModule {}

