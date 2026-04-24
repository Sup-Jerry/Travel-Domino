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
  });
}
