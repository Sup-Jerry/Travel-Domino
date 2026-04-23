import { AiController } from '../src/modules/ai/ai.controller';
import { AiChatCompletionsDto } from '../src/modules/ai/dto/ai.dto';

describe('AiController', () => {
  const buildController = () => {
    const aiService = {
      chatCompletions: jest.fn()
    };
    return {
      controller: new AiController(aiService as any),
      aiService
    };
  };

  const makeDto = (): AiChatCompletionsDto => ({
    messages: [{ role: 'user', content: 'hello' }],
    stream: false
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('normal: chat_completions_should_delegate_to_service_and_return_result', async () => {
    const { controller, aiService } = buildController();
    const dto = makeDto();
    const expected = { id: 'ok', choices: [] };
    aiService.chatCompletions.mockResolvedValue(expected);

    const result = await controller.chatCompletions(dto);

    expect(aiService.chatCompletions).toHaveBeenCalledWith(dto);
    expect(result).toEqual(expected);
  });

  it('boundary: chat_completions_should_allow_empty_optional_fields_and_log_zero_values', async () => {
    const { controller, aiService } = buildController();
    const dto = { messages: [] } as AiChatCompletionsDto;
    aiService.chatCompletions.mockResolvedValue({ ok: true });

    const result = await controller.chatCompletions(dto);

    expect(aiService.chatCompletions).toHaveBeenCalledWith(dto);
    expect(result).toEqual({ ok: true });
  });

  it('invalid: chat_completions_should_rethrow_error_instance_from_service', async () => {
    const { controller, aiService } = buildController();
    const dto = makeDto();
    aiService.chatCompletions.mockRejectedValue(new Error('AI_UPSTREAM_REQUEST_FAILED'));

    await expect(controller.chatCompletions(dto)).rejects.toThrow('AI_UPSTREAM_REQUEST_FAILED');
  });

  it('conflict: chat_completions_should_rethrow_non_error_rejections', async () => {
    const { controller, aiService } = buildController();
    aiService.chatCompletions.mockRejectedValue('raw_failure');

    await expect(controller.chatCompletions(makeDto())).rejects.toBe('raw_failure');
  });

  it('regression: chat_completions_should_preserve_stream_temperature_and_max_tokens_payload', async () => {
    const { controller, aiService } = buildController();
    const dto: AiChatCompletionsDto = {
      messages: [{ role: 'system', content: 'guard' }, { role: 'user', content: 'plan' }],
      stream: true,
      temperature: 0.8,
      max_tokens: 512,
      response_format: { type: 'json_object' }
    };
    aiService.chatCompletions.mockResolvedValue({ code: 'ok' });

    const result = await controller.chatCompletions(dto);

    expect(aiService.chatCompletions).toHaveBeenCalledWith(dto);
    expect(result).toEqual({ code: 'ok' });
  });

  it('combined: chat_completions_should_handle_success_then_failure_in_same_controller_instance', async () => {
    const { controller, aiService } = buildController();
    aiService.chatCompletions
      .mockResolvedValueOnce({ first: true })
      .mockRejectedValueOnce(new Error('AI_DEEPSEEK_RATE_LIMIT'));

    const success = await controller.chatCompletions(makeDto());
    await expect(controller.chatCompletions(makeDto())).rejects.toThrow('AI_DEEPSEEK_RATE_LIMIT');

    expect(success).toEqual({ first: true });
    expect(aiService.chatCompletions).toHaveBeenCalledTimes(2);
  });
});
