import { describe, expect, it } from '@ohos/hypium';
import { AiRawItem, AiService } from '../main/ets/infrastructure/services/AiService';
import { AiParserItem, AiResponseParser } from '../main/ets/infrastructure/services/AiResponseParser';

class ParserItemStub implements AiParserItem {
  name: string = '';
  duration: number = 0;
  ai_reasoning: string = '';
  type: number = 0;
}

class ParserPayloadHolder {
  payload: AiParserItem[] = [];
}

class ParserPayloadObjectHolder {
  payload: Object | null = null;
}

class ParserContentHolder {
  content: Object | null = null;
}

export default function aiResponseParserCoverageTest() {
  describe('aiResponseParserCoverageTest', () => {
    it('normal: parser_should_accept_array_under_unpreferred_object_key', 0, () => {
      // Arrange
      const content = '{"payload":[{"name":"payload_spot","duration":35,"ai_reasoning":"r","type":0}]}';

      // Act
      const items: AiRawItem[] = AiService.parseItemsForTest(content);

      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('payload_spot');
      expect(items[0].duration).assertEqual(35);
    });

    it('boundary: parser_should_reject_blank_content_after_line_short_circuit', 0, () => {
      // Arrange
      let message = '';

      // Act
      try {
        AiService.parseItemsForTest('   ');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }

      // Assert
      expect(message.length > 0).assertTrue();
    });

    it('invalid: parser_should_skip_empty_marker_line_and_keep_explicit_type_without_reason', 0, () => {
      // Arrange
      const content = [
        '-',
        'name: explicit dinner | duration: 45 | type: 1'
      ].join('\n');

      // Act
      const items: AiRawItem[] = AiService.parseItemsForTest(content);

      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('explicit dinner');
      expect(items[0].type).assertEqual(1);
      expect(items[0].ai_reasoning.length > 0).assertTrue();
    });

    it('conflict: parser_should_extract_array_from_nested_string_wrapper', 0, () => {
      // Arrange
      const content =
        '{"content":"prefix [{\\"name\\":\\"nested_spot\\",\\"duration\\":50,\\"ai_reasoning\\":\\"r\\",\\"type\\":0}] suffix"}';

      // Act
      const items: AiRawItem[] = AiService.parseItemsForTest(content);

      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('nested_spot');
      expect(items[0].duration).assertEqual(50);
    });

    it('regression: parser_should_reject_stringified_empty_object_without_items', 0, () => {
      // Arrange
      let message = '';

      // Act
      try {
        AiService.parseItemsForTest('"{}"');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }

      // Assert
      expect(message.length > 0).assertTrue();
    });

    it('combined: parser_should_ignore_non_text_segments_and_fallback_to_choice_text', 0, () => {
      // Arrange
      const response =
        '{"choices":[{"message":{"content":[123,{"text":""},{"content":""}]},"text":"[{\\"name\\":\\"fallback_from_choice\\",\\"duration\\":70,\\"ai_reasoning\\":\\"r\\",\\"type\\":0}]"}]}';

      // Act
      const items: AiRawItem[] = AiService.parseModelResponseForTest(response);

      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('fallback_from_choice');
      expect(items[0].duration).assertEqual(70);
    });

    it('combined: parser_private_object_branches_should_cover_array_and_null_nested_paths', 0, () => {
      // Arrange
      const pickArrayFromObject = Reflect.get(AiResponseParser as Object, 'pickArrayFromObject') as
        ((parsed: Object) => AiParserItem[] | null);
      const tryExtractItemsFromParsed = Reflect.get(AiResponseParser as Object, 'tryExtractItemsFromParsed') as
        ((parsed: Object, depth?: number) => AiParserItem[] | null);
      const payloadItem = new ParserItemStub();
      payloadItem.name = 'payload_private';
      payloadItem.duration = 55;
      payloadItem.ai_reasoning = 'r';
      payloadItem.type = 0;
      const payloadItems: AiParserItem[] = [payloadItem];
      const payloadHolder = new ParserPayloadHolder();
      payloadHolder.payload = payloadItems;
      const preferredNullHolder = new ParserContentHolder();
      preferredNullHolder.content = new ParserContentHolder();
      const genericNullHolder = new ParserPayloadObjectHolder();
      genericNullHolder.payload = new ParserContentHolder();

      // Act
      const picked = pickArrayFromObject(payloadHolder as Object);
      const preferredNull = tryExtractItemsFromParsed(preferredNullHolder as Object, 0);
      const genericNull = tryExtractItemsFromParsed(genericNullHolder as Object, 0);

      // Assert
      expect(picked !== null).assertTrue();
      expect((picked ?? []).length).assertEqual(1);
      expect(preferredNull === null).assertTrue();
      expect(genericNull === null).assertTrue();
    });

    it('boundary: parser_private_string_branches_should_cover_empty_text_and_line_text_fallback', 0, () => {
      // Arrange
      const inferItemTypeFromText = Reflect.get(AiResponseParser as Object, 'inferItemTypeFromText') as
        ((raw: string) => number);
      const tryExtractItemsFromParsed = Reflect.get(AiResponseParser as Object, 'tryExtractItemsFromParsed') as
        ((parsed: Object, depth?: number) => AiParserItem[] | null);

      // Act
      const emptyType = inferItemTypeFromText('');
      const lineParsed = tryExtractItemsFromParsed('name: private line | duration: 30' as Object, 0);

      // Assert
      expect(emptyType).assertEqual(0);
      expect(lineParsed !== null).assertTrue();
      expect((lineParsed ?? [])[0].name).assertEqual('private line');
    });

    it('invalid: parser_private_string_branches_should_cover_normalized_parse_failures', 0, () => {
      // Arrange
      const tryExtractItemsFromParsed = Reflect.get(AiResponseParser as Object, 'tryExtractItemsFromParsed') as
        ((parsed: Object, depth?: number) => AiParserItem[] | null);

      // Act
      const normalizedParseFail = tryExtractItemsFromParsed('prefix [not-json] suffix' as Object, 0);
      const normalizedNestedNull = tryExtractItemsFromParsed('```json\n{}\n```' as Object, 0);

      // Assert
      expect(normalizedParseFail === null).assertTrue();
      expect(normalizedNestedNull === null).assertTrue();
    });

    it('boundary: parser_should_fallback_when_message_content_is_non_object_scalar', 0, () => {
      // Arrange
      const response =
        '{"choices":[{"message":{"content":0},"text":"[{\\"name\\":\\"scalar_fallback\\",\\"duration\\":65,\\"ai_reasoning\\":\\"r\\",\\"type\\":0}]"}]}';

      // Act
      const items: AiRawItem[] = AiService.parseModelResponseForTest(response);

      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('scalar_fallback');
    });

    it('combined: parser_should_fallback_when_message_content_object_has_non_string_text', 0, () => {
      // Arrange
      const response =
        '{"choices":[{"message":{"content":{"text":123,"content":123}},"text":"[{\\"name\\":\\"object_fallback\\",\\"duration\\":66,\\"ai_reasoning\\":\\"r\\",\\"type\\":0}]"}]}';

      // Act
      const items: AiRawItem[] = AiService.parseModelResponseForTest(response);

      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('object_fallback');
    });
  });
}
