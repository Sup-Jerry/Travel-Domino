import { describe, expect, it } from '@ohos/hypium';
import { AiParserItem, AiResponseParser } from '../main/ets/infrastructure/services/AiResponseParser';

function normalizeCO(item: AiParserItem): AiParserItem {
  return {
    name: item.name.trim(),
    duration: Number(item.duration),
    ai_reasoning: item.ai_reasoning,
    type: Number(item.type)
  };
}

function assertThrowCO(action: () => void, expected: string): void {
  let message = '';
  try {
    action();
  } catch (error) {
    message = `${error}`;
  }
  expect(message.indexOf(expected) >= 0).assertTrue();
}

export default function phase2BatchCOTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchCO_ai_response_parser_extra', () => {
    it('normal: ai_response_parser_should_pick_array_from_preferred_object_key', 0, () => {
      // Arrange
      const content = '{"items":[{"name":"Museum","duration":45,"ai_reasoning":"r","type":0}]}';

      // Act
      const items = AiResponseParser.parseItemsFromContent(content, normalizeCO);

      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('Museum');
      expect(items[0].duration).assertEqual(45);
    });

    it('boundary: ai_response_parser_should_pick_first_array_from_unknown_object_key', 0, () => {
      // Arrange
      const content = '{"meta":{"source":"ai"},"unexpected":[{"name":"Gallery","duration":35,"ai_reasoning":"r","type":0}]}';

      // Act
      const items = AiResponseParser.parseItemsFromContent(content, normalizeCO);

      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('Gallery');
    });

    it('invalid: ai_response_parser_should_reject_blank_line_text_without_items', 0, () => {
      // Arrange
      const content = '   ';

      // Act
      // Assert
      assertThrowCO((): void => {
        AiResponseParser.parseItemsFromContent(content, normalizeCO);
      }, 'JSON');
    });

    it('conflict: ai_response_parser_should_infer_hotel_type_when_text_type_missing', 0, () => {
      // Arrange
      const content = '- Hotel Sunrise duration: 90min reason: stay near station';

      // Act
      const items = AiResponseParser.parseItemsFromContent(content, normalizeCO);

      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].type).assertEqual(2);
    });

    it('regression: ai_response_parser_should_infer_food_type_when_text_type_missing', 0, () => {
      // Arrange
      const content = '- Lakeside restaurant duration: 70min reason: dinner break';

      // Act
      const items = AiResponseParser.parseItemsFromContent(content, normalizeCO);

      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].type).assertEqual(1);
    });

    it('combined: ai_response_parser_should_extract_nested_model_content_object', 0, () => {
      // Arrange
      const nestedContent = '{"choices":[{"message":{"content":{"text":"{\\"payload\\":[{\\"name\\":\\"Park\\",\\"duration\\":40,\\"ai_reasoning\\":\\"r\\",\\"type\\":0}]}"}}}]}';

      // Act
      const items = AiResponseParser.parseModelResponseForTest(nestedContent, normalizeCO);

      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('Park');
      expect(items[0].type).assertEqual(0);
    });
  });
}
