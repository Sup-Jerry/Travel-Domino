import { describe, it, expect } from '@ohos/hypium';
import { AiService, AiRawItem } from '../main/ets/infrastructure/services/AiService';

export default function aiServiceTest() {
  describe('aiServiceTest', () => {
    it('parse_should_accept_markdown_wrapped_json', 0, () => {
      const content = '```json\n[{"name":"景点A","duration":90,"ai_reasoning":"推荐","type":0}]\n```';
      const items: AiRawItem[] = AiService.parseItemsForTest(content);
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('景点A');
      expect(items[0].duration).assertEqual(90);
    });

    it('parse_should_fail_on_truncated_json', 0, () => {
      let message = '';
      try {
        AiService.parseItemsForTest('[{"name":"A","duration":30');
      } catch (_) {
        message = 'AI 返回内容不是合法 JSON';
      }
      expect(message).assertEqual('AI 返回内容不是合法 JSON');
    });

    it('parse_model_response_should_fail_when_choices_empty', 0, () => {
      let message = '';
      try {
        AiService.parseModelResponseForTest('{"choices":[]}');
      } catch (_) {
        message = 'AI 响应格式为空';
      }
      expect(message).assertEqual('AI 响应格式为空');
    });

    it('parse_should_normalize_duration_and_type', 0, () => {
      const content = '[{"name":"王府井","duration":500,"ai_reasoning":"","type":0},{"name":"未知类型","duration":40,"ai_reasoning":"x","type":9}]';
      const items: AiRawItem[] = AiService.parseItemsForTest(content);
      expect(items.length).assertEqual(2);
      expect(items[0].duration).assertEqual(180);
      expect(items[0].type).assertEqual(0);
      expect(items[1].type).assertEqual(0);
    });

  });
}
