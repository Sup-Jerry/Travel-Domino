import { describe, it, expect } from '@ohos/hypium';
import { AiService, AiRawItem } from '../main/ets/infrastructure/services/AiService';

export default function aiServiceTest() {
  describe('aiServiceTest', () => {
    it('normal: parse_should_accept_markdown_wrapped_json', 0, () => {
      // Arrange
      // Act
      // Assert
      const content = '```json\n[{"name":"景点A","duration":90,"ai_reasoning":"推荐","type":0}]\n```';
      const items: AiRawItem[] = AiService.parseItemsForTest(content);
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('景点A');
      expect(items[0].duration).assertEqual(90);
    });

    it('normal: parse_should_accept_stringified_json_array', 0, () => {
      // Arrange
      // Act
      // Assert
      const content = '"[{\\"name\\":\\"景点B\\",\\"duration\\":80,\\"ai_reasoning\\":\\"推荐\\",\\"type\\":0}]"';
      const items: AiRawItem[] = AiService.parseItemsForTest(content);
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('景点B');
      expect(items[0].duration).assertEqual(80);
    });

    it('invalid: parse_should_fail_on_truncated_json', 0, () => {
      // Arrange
      // Act
      // Assert
      let message = '';
      try {
        AiService.parseItemsForTest('[{"name":"A","duration":30');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message).assertEqual('AI 返回内容不是合法 JSON');
    });

    it('invalid: parse_model_response_should_fail_when_choices_empty', 0, () => {
      // Arrange
      // Act
      // Assert
      let message = '';
      try {
        AiService.parseModelResponseForTest('{"choices":[]}');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message).assertEqual('AI 响应格式为空');
    });

    it('normal: parse_model_response_should_accept_array_message_content', 0, () => {
      // Arrange
      const response = '{"choices":[{"finish_reason":"stop","message":{"content":[{"type":"text","text":"[{\\"name\\":\\"景点C\\",\\"duration\\":90,\\"ai_reasoning\\":\\"推荐\\",\\"type\\":0}]"}]}}]}';
      // Act
      const items = AiService.parseModelResponseForTest(response);
      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('景点C');
      expect(items[0].duration).assertEqual(90);
    });

    it('normal: parse_should_normalize_duration_and_type', 0, () => {
      // Arrange
      // Act
      // Assert
      const content = '[{"name":"王府井","duration":500,"ai_reasoning":"","type":0},{"name":"未知类型","duration":40,"ai_reasoning":"x","type":9}]';
      const items: AiRawItem[] = AiService.parseItemsForTest(content);
      expect(items.length).assertEqual(2);
      expect(items[0].duration).assertEqual(180);
      expect(items[0].type).assertEqual(0);
      expect(items[1].type).assertEqual(0);
    });

    it('normal: resolve_requested_days_should_support_arabic_and_chinese', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(AiService.resolveRequestedDaysFromPrompt('帮我规划三日游')).assertEqual(3);
      expect(AiService.resolveRequestedDaysFromPrompt('想要2天旅行')).assertEqual(2);
      expect(AiService.resolveRequestedDaysFromPrompt('安排五日游')).assertEqual(5);
      expect(AiService.resolveRequestedDaysFromPrompt('随便逛逛')).assertEqual(1);
    });

    it('boundary: resolve_strategy_max_items_should_scale_by_requested_days', 0, () => {
      // Arrange
      // Act
      // Assert
      const oneDay = AiService.resolveStrategyMaxItemsForTest({
        userPrompt: '北京一日游',
        strategyMode: 0
      });
      const threeDays = AiService.resolveStrategyMaxItemsForTest({
        userPrompt: '北京三日游',
        strategyMode: 0
      });
      expect(oneDay).assertEqual(6);
      expect(threeDays).assertEqual(18);
    });

    it('boundary: resolve_strategy_min_items_should_scale_by_requested_days', 0, () => {
      // Arrange
      // Act
      // Assert
      const oneDay = AiService.resolveStrategyMinItemsForTest({
        userPrompt: '北京一日游',
        strategyMode: 0
      });
      const threeDays = AiService.resolveStrategyMinItemsForTest({
        userPrompt: '北京三日游',
        strategyMode: 0
      });
      expect(oneDay).assertEqual(4);
      expect(threeDays).assertEqual(12);
    });

    it('normal: resolve_strategy_range_should_apply_soldier_mode', 0, () => {
      // Arrange
      // Act
      // Assert
      const oneDayMin = AiService.resolveStrategyMinItemsForTest({
        userPrompt: '1天',
        strategyMode: 1
      });
      const oneDayMax = AiService.resolveStrategyMaxItemsForTest({
        userPrompt: '1天',
        strategyMode: 1
      });
      const threeDaysMin = AiService.resolveStrategyMinItemsForTest({
        userPrompt: '3天',
        strategyMode: 1
      });
      expect(oneDayMin).assertEqual(5);
      expect(oneDayMax).assertEqual(8);
      expect(threeDaysMin).assertEqual(15);
    });

    it('invalid: generate_with_strategy_should_throw_on_empty_items', 0, async () => {
      // Arrange
      // Act
      // Assert
      AiService.setRequesterForTest(async () => {
        return {
          responseCode: 200,
          result: '{"choices":[{"message":{"content":"[]"}}]}'
        };
      });

      let message = '';
      try {
        await AiService.generateItineraryWithStrategy({
          userPrompt: '三日游',
          strategyMode: -1,
          customStrategy: {
            density: 1,
            pace: 1,
            preference: 0,
            energy: 1
          }
        });
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        AiService.setRequesterForTest(null);
      }
      expect(message).assertEqual('AI 未返回可用地点，请调整描述后重试');
    });

    it('normal: generate_with_strategy_should_raise_token_budget_for_long_trip', 0, async () => {
      // Arrange
      const maxTokensSeen: number[] = [];
      let callCount = 0;
      AiService.setRequesterForTest(async (_url, options) => {
        callCount += 1;
        const extraData = options.extraData as Record<string, Object>;
        maxTokensSeen.push(Number(extraData['max_tokens']));
        return {
          responseCode: 200,
          result: '{"choices":[{"message":{"content":"[]"}}]}'
        };
      });
      // Act
      let message = '';
      try {
        await AiService.generateItineraryWithStrategy({
          userPrompt: '请帮我规划15天行程',
          strategyMode: 0
        });
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        AiService.setRequesterForTest(null);
      }
      // Assert
      expect(callCount).assertEqual(2);
      expect(maxTokensSeen.length).assertEqual(2);
      expect(maxTokensSeen[0]).assertEqual(2960);
      expect(maxTokensSeen[1]).assertEqual(3200);
      expect(message).assertEqual('AI 未返回可用地点，请调整描述后重试');
    });

    it('combined: generate_with_strategy_should_retry_when_multi_day_items_not_enough', 0, async () => {
      // Arrange
      // Act
      // Assert
      let callCount = 0;
      AiService.setRequesterForTest(async () => {
        callCount += 1;
        if (callCount === 1) {
          return {
            responseCode: 200,
            result: '{"choices":[{"message":{"content":"[{\\\"name\\\":\\\"地点A\\\",\\\"duration\\\":120,\\\"ai_reasoning\\\":\\\"推荐\\\",\\\"type\\\":0},{\\\"name\\\":\\\"地点B\\\",\\\"duration\\\":90,\\\"ai_reasoning\\\":\\\"推荐\\\",\\\"type\\\":1}]"}}]}'
          };
        }
        return {
          responseCode: 200,
          result: '{"choices":[{"message":{"content":"[{\\\"name\\\":\\\"地点1\\\",\\\"duration\\\":90,\\\"ai_reasoning\\\":\\\"推荐\\\",\\\"type\\\":0},{\\\"name\\\":\\\"地点2\\\",\\\"duration\\\":60,\\\"ai_reasoning\\\":\\\"推荐\\\",\\\"type\\\":1},{\\\"name\\\":\\\"地点3\\\",\\\"duration\\\":120,\\\"ai_reasoning\\\":\\\"推荐\\\",\\\"type\\\":0},{\\\"name\\\":\\\"地点4\\\",\\\"duration\\\":90,\\\"ai_reasoning\\\":\\\"推荐\\\",\\\"type\\\":1},{\\\"name\\\":\\\"地点5\\\",\\\"duration\\\":80,\\\"ai_reasoning\\\":\\\"推荐\\\",\\\"type\\\":0},{\\\"name\\\":\\\"地点6\\\",\\\"duration\\\":70,\\\"ai_reasoning\\\":\\\"推荐\\\",\\\"type\\\":1},{\\\"name\\\":\\\"地点7\\\",\\\"duration\\\":100,\\\"ai_reasoning\\\":\\\"推荐\\\",\\\"type\\\":0},{\\\"name\\\":\\\"地点8\\\",\\\"duration\\\":75,\\\"ai_reasoning\\\":\\\"推荐\\\",\\\"type\\\":1},{\\\"name\\\":\\\"地点9\\\",\\\"duration\\\":95,\\\"ai_reasoning\\\":\\\"推荐\\\",\\\"type\\\":0}]"}}]}'
        };
      });

      try {
        const items = await AiService.generateItineraryWithStrategy({
          userPrompt: '请给我一个三日游计划',
          strategyMode: 0
        });
        expect(callCount).assertEqual(2);
        expect(items.length).assertEqual(9);
      } finally {
        AiService.setRequesterForTest(null);
      }
    });

    it('invalid: generate_with_strategy_should_retry_after_timeout_error_and_succeed', 0, async () => {
      // Arrange
      // Act
      // Assert
      let callCount = 0;
      const successResult = '{"choices":[{"message":{"content":"[{\\\"name\\\":\\\"A1\\\",\\\"duration\\\":90,\\\"ai_reasoning\\\":\\\"r1\\\",\\\"type\\\":0},{\\\"name\\\":\\\"A2\\\",\\\"duration\\\":60,\\\"ai_reasoning\\\":\\\"r2\\\",\\\"type\\\":1},{\\\"name\\\":\\\"A3\\\",\\\"duration\\\":120,\\\"ai_reasoning\\\":\\\"r3\\\",\\\"type\\\":0},{\\\"name\\\":\\\"A4\\\",\\\"duration\\\":80,\\\"ai_reasoning\\\":\\\"r4\\\",\\\"type\\\":1},{\\\"name\\\":\\\"A5\\\",\\\"duration\\\":100,\\\"ai_reasoning\\\":\\\"r5\\\",\\\"type\\\":0},{\\\"name\\\":\\\"A6\\\",\\\"duration\\\":70,\\\"ai_reasoning\\\":\\\"r6\\\",\\\"type\\\":1},{\\\"name\\\":\\\"A7\\\",\\\"duration\\\":110,\\\"ai_reasoning\\\":\\\"r7\\\",\\\"type\\\":0},{\\\"name\\\":\\\"A8\\\",\\\"duration\\\":75,\\\"ai_reasoning\\\":\\\"r8\\\",\\\"type\\\":1},{\\\"name\\\":\\\"A9\\\",\\\"duration\\\":95,\\\"ai_reasoning\\\":\\\"r9\\\",\\\"type\\\":0},{\\\"name\\\":\\\"A10\\\",\\\"duration\\\":65,\\\"ai_reasoning\\\":\\\"r10\\\",\\\"type\\\":1},{\\\"name\\\":\\\"A11\\\",\\\"duration\\\":105,\\\"ai_reasoning\\\":\\\"r11\\\",\\\"type\\\":0},{\\\"name\\\":\\\"A12\\\",\\\"duration\\\":85,\\\"ai_reasoning\\\":\\\"r12\\\",\\\"type\\\":1}]"}}]}';
      AiService.setRequesterForTest(async () => {
        callCount += 1;
        if (callCount === 1) {
          throw new Error('[HTTP_TRACE][AiService][generateItinerary] request failed: {"code":2300028,"message":"Operation timeout"}');
        }
        return {
          responseCode: 200,
          result: successResult
        };
      });

      try {
        const items = await AiService.generateItineraryWithStrategy({
          userPrompt: '3天行程',
          strategyMode: 0
        });
        expect(callCount).assertEqual(2);
        expect(items.length).assertEqual(12);
      } finally {
        AiService.setRequesterForTest(null);
      }
    });

    it('normal: generate_with_soldier_mode_should_use_first_result_when_retry_timeout', 0, async () => {
      // Arrange
      // Act
      // Assert
      let callCount = 0;
      const firstResult = '{"choices":[{"message":{"content":"[{\\\"name\\\":\\\"A1\\\",\\\"duration\\\":90,\\\"ai_reasoning\\\":\\\"r1\\\",\\\"type\\\":0},{\\\"name\\\":\\\"A2\\\",\\\"duration\\\":60,\\\"ai_reasoning\\\":\\\"r2\\\",\\\"type\\\":1},{\\\"name\\\":\\\"A3\\\",\\\"duration\\\":120,\\\"ai_reasoning\\\":\\\"r3\\\",\\\"type\\\":0},{\\\"name\\\":\\\"A4\\\",\\\"duration\\\":80,\\\"ai_reasoning\\\":\\\"r4\\\",\\\"type\\\":1},{\\\"name\\\":\\\"A5\\\",\\\"duration\\\":100,\\\"ai_reasoning\\\":\\\"r5\\\",\\\"type\\\":0},{\\\"name\\\":\\\"A6\\\",\\\"duration\\\":70,\\\"ai_reasoning\\\":\\\"r6\\\",\\\"type\\\":1},{\\\"name\\\":\\\"A7\\\",\\\"duration\\\":110,\\\"ai_reasoning\\\":\\\"r7\\\",\\\"type\\\":0},{\\\"name\\\":\\\"A8\\\",\\\"duration\\\":75,\\\"ai_reasoning\\\":\\\"r8\\\",\\\"type\\\":1},{\\\"name\\\":\\\"A9\\\",\\\"duration\\\":95,\\\"ai_reasoning\\\":\\\"r9\\\",\\\"type\\\":0},{\\\"name\\\":\\\"A10\\\",\\\"duration\\\":65,\\\"ai_reasoning\\\":\\\"r10\\\",\\\"type\\\":1},{\\\"name\\\":\\\"A11\\\",\\\"duration\\\":105,\\\"ai_reasoning\\\":\\\"r11\\\",\\\"type\\\":0},{\\\"name\\\":\\\"A12\\\",\\\"duration\\\":85,\\\"ai_reasoning\\\":\\\"r12\\\",\\\"type\\\":1}]"}}]}';
      AiService.setRequesterForTest(async () => {
        callCount += 1;
        if (callCount === 1) {
          return {
            responseCode: 200,
            result: firstResult
          };
        }
        throw new Error('[HTTP_TRACE][AiService][generateItinerary] request failed: {"code":2300028,"message":"Operation timeout"}');
      });

      try {
        const items = await AiService.generateItineraryWithStrategy({
          userPrompt: 'trip 3天 soldier',
          strategyMode: 1
        });
        expect(callCount).assertEqual(2);
        expect(items.length).assertEqual(12);
      } finally {
        AiService.setRequesterForTest(null);
      }
    });

    it('invalid: generate_with_soldier_mode_should_fail_when_count_below_min', 0, async () => {
      // Arrange
      // Act
      // Assert
      let callCount = 0;
      AiService.setRequesterForTest(async () => {
        callCount += 1;
        return {
          responseCode: 200,
          result: '{"choices":[{"message":{"content":"[{\\\"name\\\":\\\"地点1\\\",\\\"duration\\\":90,\\\"ai_reasoning\\\":\\\"推荐\\\",\\\"type\\\":0},{\\\"name\\\":\\\"地点2\\\",\\\"duration\\\":60,\\\"ai_reasoning\\\":\\\"推荐\\\",\\\"type\\\":1},{\\\"name\\\":\\\"地点3\\\",\\\"duration\\\":120,\\\"ai_reasoning\\\":\\\"推荐\\\",\\\"type\\\":0},{\\\"name\\\":\\\"地点4\\\",\\\"duration\\\":90,\\\"ai_reasoning\\\":\\\"推荐\\\",\\\"type\\\":1},{\\\"name\\\":\\\"地点5\\\",\\\"duration\\\":80,\\\"ai_reasoning\\\":\\\"推荐\\\",\\\"type\\\":0}]"}}]}'
        };
      });

      let message = '';
      try {
        await AiService.generateItineraryWithStrategy({
          userPrompt: '3天特种兵模式',
          strategyMode: 1
        });
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        AiService.setRequesterForTest(null);
      }

      expect(callCount).assertEqual(2);
      expect(message).assertEqual('AI 返回地点数量不足，无法满足3天行程，请补充更多偏好后重试');
    });
  });
  describe('unit_test_case_generator_backfill_AiService', () => {
    it('conflict: multi_day_without_accommodation_should_reject_hotel_only_result', 0, async () => {
      // Arrange
      let callCount = 0;
      AiService.setRequesterForTest(async () => {
        callCount += 1;
        return {
          responseCode: 200,
          result: '{"choices":[{"message":{"content":"[{\\\"name\\\":\\\"hotel_a\\\",\\\"duration\\\":600,\\\"ai_reasoning\\\":\\\"r\\\",\\\"type\\\":2},{\\\"name\\\":\\\"hotel_b\\\",\\\"duration\\\":600,\\\"ai_reasoning\\\":\\\"r\\\",\\\"type\\\":2}]"}}]}'
        };
      });
      // Act
      let message = '';
      try {
        await AiService.generateItineraryWithStrategy({
          userPrompt: '帮我规划两天景点，不需要住宿',
          strategyMode: 0
        });
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        AiService.setRequesterForTest(null);
      }
      // Assert
      expect(callCount).assertEqual(2);
      expect(message.includes('无法满足')).assertEqual(true);
    });

    it('regression: td-20260411-resolve_requested_days_should_clamp_to_30', 0, () => {
      // Arrange
      const prompt = '请帮我规划120天行程';
      // Act
      const days = AiService.resolveRequestedDaysFromPrompt(prompt);
      // Assert
      expect(days).assertEqual(30);
    });
  });
}
