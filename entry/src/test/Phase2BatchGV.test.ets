import { describe, expect, it } from '@ohos/hypium';
import { AiParserItem, AiResponseParser } from '../main/ets/infrastructure/services/AiResponseParser';

function identityGV(item: AiParserItem): AiParserItem {
  return item;
}

export default function phase2BatchGVTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchGV_ai_response_parser_quote_normalizer', () => {
    it('regression: ai_response_parser_should_escape_double_quotes_inside_single_quoted_fields', 0, () => {
      // Arrange
      const raw = "{items:[{name:'A \"B\" Museum',duration:45,ai_reasoning:'quote \"safe\"',type:0}]}";

      // Act
      const items = AiResponseParser.parseItemsFromContent(raw, identityGV);

      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('A "B" Museum');
      expect(items[0].ai_reasoning).assertEqual('quote "safe"');
      expect(items[0].duration).assertEqual(45);
      expect(items[0].type).assertEqual(0);
    });

    it('normal: ai_response_parser_should_read_direct_message_content_string', 0, () => {
      // Arrange
      const response =
        '{"choices":[{"message":{"content":"[{\\"name\\":\\"Tower\\",\\"duration\\":35,\\"ai_reasoning\\":\\"direct\\",\\"type\\":0}]"}}]}';

      // Act
      const items = AiResponseParser.parseModelResponseForTest(response, identityGV);

      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('Tower');
      expect(items[0].duration).assertEqual(35);
    });

    it('boundary: ai_response_parser_should_strip_wrapper_text_and_trailing_commas', 0, () => {
      // Arrange
      const raw = 'answer:\n```json\n{"items":[{"name":"Park","duration":45,"ai_reasoning":"ok","type":0,},],}\n```';

      // Act
      const items = AiResponseParser.parseItemsFromContent(raw, identityGV);

      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('Park');
      expect(items[0].duration).assertEqual(45);
    });

    it('invalid: ai_response_parser_should_throw_when_choices_empty', 0, () => {
      // Arrange
      const response = '{"choices":[]}';

      // Act
      let message = '';
      try {
        AiResponseParser.parseModelResponseForTest(response, identityGV);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }

      // Assert
      expect(message.length > 0).assertTrue();
    });

    it('conflict: ai_response_parser_should_throw_when_content_and_text_are_blank', 0, () => {
      // Arrange
      const response = '{"choices":[{"message":{"content":"   "},"text":"   "}]}';

      // Act
      let message = '';
      try {
        AiResponseParser.parseModelResponseForTest(response, identityGV);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }

      // Assert
      expect(message.length > 0).assertTrue();
    });

    it('combined: ai_response_parser_should_pick_array_from_nested_output_data_object', 0, () => {
      // Arrange
      const raw =
        '{"output":{"data":{"items":[{"name":"Gallery","duration":55,"ai_reasoning":"nested","type":2}]}}}';

      // Act
      const items = AiResponseParser.parseItemsFromContent(raw, identityGV);

      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('Gallery');
      expect(items[0].type).assertEqual(2);
    });
  });
}
