import { Body, Controller, Logger, Post } from '@nestjs/common';
import { AiService } from './ai.service';
import { AiChatCompletionsDto } from './dto/ai.dto';

@Controller('ai')
export class AiController {
  private readonly logger = new Logger(AiController.name);

  constructor(private readonly aiService: AiService) {}

  @Post('chat/completions')
  async chatCompletions(@Body() dto: AiChatCompletionsDto): Promise<unknown> {
    const count = dto.messages?.length ?? 0;
    this.logger.log(
      `[airest]AI_BACKEND_TRACE[ai_chat_in] messages=${count}, stream=${dto.stream === true ? 1 : 0}, hasTemp=${typeof dto.temperature === 'number' ? 1 : 0}, maxTokens=${dto.max_tokens ?? 0}`
    );
    try {
      const result = await this.aiService.chatCompletions(dto);
      this.logger.log(`[airest]AI_BACKEND_TRACE[ai_chat_ok] messages=${count}`);
      return result;
    } catch (error) {
      const reason = error instanceof Error ? error.message : 'unknown';
      this.logger.error(`[airest]AI_BACKEND_TRACE[ai_chat_fail] reason=${reason}`);
      throw error;
    }
  }
}
