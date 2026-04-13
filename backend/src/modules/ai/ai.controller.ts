import { Body, Controller, Post } from '@nestjs/common';
import { AiService } from './ai.service';
import { AiChatCompletionsDto } from './dto/ai.dto';

@Controller('ai')
export class AiController {
  constructor(private readonly aiService: AiService) {}

  @Post('chat/completions')
  async chatCompletions(@Body() dto: AiChatCompletionsDto): Promise<unknown> {
    return this.aiService.chatCompletions(dto);
  }
}

