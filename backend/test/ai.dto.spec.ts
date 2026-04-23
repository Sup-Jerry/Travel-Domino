import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { AiChatCompletionsDto, AiChatMessageDto, AiResponseFormatDto } from '../src/modules/ai/dto/ai.dto';

describe('Ai DTO Validation', () => {
  const makeMessage = (): AiChatMessageDto => Object.assign(new AiChatMessageDto(), {
    role: 'user',
    content: 'hello'
  });

  it('normal: should pass_validation_for_valid_chat_completions_payload', async () => {
    const dto = plainToInstance(AiChatCompletionsDto, {
      messages: [{ role: 'system', content: 'guard' }, { role: 'user', content: 'hello' }],
      max_tokens: 256,
      temperature: 0.5,
      stream: true,
      response_format: { type: 'json_object' }
    });

    const errors = await validate(dto);

    expect(errors).toEqual([]);
    expect(dto.messages[0]).toBeInstanceOf(AiChatMessageDto);
    expect(dto.response_format).toBeInstanceOf(AiResponseFormatDto);
  });

  it('boundary: should allow_optional_fields_to_be_omitted', async () => {
    const dto = plainToInstance(AiChatCompletionsDto, {
      messages: [makeMessage()]
    });

    const errors = await validate(dto);

    expect(errors).toEqual([]);
  });

  it('invalid: should fail_when_messages_is_not_array', async () => {
    const dto = plainToInstance(AiChatCompletionsDto, {
      messages: 'bad'
    });

    const errors = await validate(dto);

    expect(errors.length).toBeGreaterThan(0);
    expect(errors[0].property).toBe('messages');
  });

  it('conflict: should_fail_when_nested_message_shape_is_invalid', async () => {
    const dto = plainToInstance(AiChatCompletionsDto, {
      messages: [{ role: 1, content: null }]
    });

    const errors = await validate(dto);

    expect(errors.length).toBeGreaterThan(0);
    expect(errors[0].property).toBe('messages');
    expect(errors[0].children?.length ?? 0).toBeGreaterThan(0);
  });

  it('regression: should_fail_when_response_format_type_is_not_json_object', async () => {
    const dto = plainToInstance(AiChatCompletionsDto, {
      messages: [makeMessage()],
      response_format: { type: 'text' }
    });

    const errors = await validate(dto);

    expect(errors.length).toBeGreaterThan(0);
    expect(errors[0].property).toBe('response_format');
  });

  it('combined: should_report_multiple_invalid_optional_fields_in_same_payload', async () => {
    const dto = plainToInstance(AiChatCompletionsDto, {
      messages: [makeMessage()],
      max_tokens: 0,
      temperature: 'high',
      stream: 'yes',
      response_format: { type: 'xml' }
    });

    const errors = await validate(dto);
    const properties = errors.map((item) => item.property).sort();

    expect(properties).toEqual(['max_tokens', 'response_format', 'stream', 'temperature']);
  });
});
